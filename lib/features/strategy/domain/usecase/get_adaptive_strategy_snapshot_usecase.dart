import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';
import 'package:opennutritracker/features/strategy/data/data_source/check_in_record_data_source.dart';
import 'package:opennutritracker/features/strategy/data/data_source/expenditure_state_data_source.dart';
import 'package:opennutritracker/features/strategy/data/data_source/goal_strategy_data_source.dart';
import 'package:opennutritracker/features/strategy/data/dbo/check_in_record_dbo.dart';
import 'package:opennutritracker/features/strategy/data/dbo/goal_strategy_dbo.dart';
import 'package:opennutritracker/features/strategy/domain/entity/expenditure_state_entity.dart';
import 'package:opennutritracker/features/strategy/domain/entity/weight_entry_entity.dart';
import 'package:opennutritracker/features/strategy/domain/service/expenditure_estimator_service.dart';
import 'package:opennutritracker/features/strategy/domain/service/strategy_rate_policy.dart';
import 'package:opennutritracker/features/strategy/domain/service/trend_weight_service.dart';
import 'package:opennutritracker/features/strategy/domain/service/weekly_calorie_controller.dart';
import 'package:opennutritracker/features/strategy/data/data_source/weight_entry_data_source.dart';
import 'package:opennutritracker/core/data/data_source/tracked_day_data_source.dart';

class AdaptiveStrategySnapshot {
  final GoalStrategyDBO strategy;
  final ExpenditureStateEntity expenditureState;
  final double calorieTarget;
  final double staticTdee;
  final double staticCalorieGoal;
  final double? trendWeightKg;
  final List<WeightEntryEntity> weightEntries;
  final CheckInRecordDBO? currentCheckIn;

  const AdaptiveStrategySnapshot({
    required this.strategy,
    required this.expenditureState,
    required this.calorieTarget,
    required this.staticTdee,
    required this.staticCalorieGoal,
    required this.trendWeightKg,
    required this.weightEntries,
    required this.currentCheckIn,
  });
}

class _StrategySyncResult {
  final GoalStrategyDBO strategy;
  final bool changed;

  const _StrategySyncResult({
    required this.strategy,
    required this.changed,
  });
}

class GetAdaptiveStrategySnapshotUsecase {
  final UserRepository _userRepository;
  final ConfigRepository _configRepository;
  final TrackedDayDataSource _trackedDayDataSource;
  final WeightEntryDataSource _weightEntryDataSource;
  final ExpenditureStateDataSource _expenditureStateDataSource;
  final GoalStrategyDataSource _goalStrategyDataSource;
  final CheckInRecordDataSource _checkInRecordDataSource;

  GetAdaptiveStrategySnapshotUsecase(
    this._userRepository,
    this._configRepository,
    this._trackedDayDataSource,
    this._weightEntryDataSource,
    this._expenditureStateDataSource,
    this._goalStrategyDataSource,
    this._checkInRecordDataSource,
  );

  Future<AdaptiveStrategySnapshot> getSnapshot({
    UserEntity? userEntity,
    DateTime? today,
    bool forceCurrentWeekRebuild = false,
  }) async {
    final currentDay = DateUtils.dateOnly(today ?? DateTime.now());
    final user = userEntity ?? await _userRepository.getUserData();
    final config = await _configRepository.getConfig();

    final staticTdee = CalorieGoalCalc.getTdee(user);
    final staticCalorieGoal = CalorieGoalCalc.getTotalKcalGoal(
      user,
      0,
      kcalUserAdjustment: config.userKcalAdjustment,
    );

    final strategyResult = await _ensureStrategy(user, config);
    final strategy = strategyResult.strategy;
    final weightEntries = await _ensureWeightHistory(user, currentDay);
    final trendWeight =
        TrendWeightService.getLatestTrendWeight(weightEntries) ?? user.weightKG;

    final previousState = await _getPreviousDayEstimate(currentDay);
    final trackedDays = await _trackedDayDataSource.getAllTrackedDays();
    final expenditureState = ExpenditureEstimatorService.estimate(
      trackedDays: trackedDays,
      weightEntries: weightEntries,
      previousEstimate: previousState,
      seedTdee: staticTdee,
      today: currentDay,
    );
    await _expenditureStateDataSource.saveState(expenditureState.toDBO());

    final currentWeekStart = CheckInRecordDataSource.startOfWeek(currentDay);
    final currentWeekRecord =
        (strategyResult.changed || forceCurrentWeekRebuild)
            ? null
            : await _checkInRecordDataSource.getRecordForWeek(currentWeekStart);

    double calorieTarget = staticCalorieGoal;
    CheckInRecordDBO? appliedCheckIn = currentWeekRecord;

    if (strategy.adaptiveEnabled) {
      if (currentWeekRecord != null) {
        calorieTarget = currentWeekRecord.appliedCalorieTarget;
      } else if (expenditureState.status == ExpenditureStatus.updating) {
        final previousTarget = await _getPreviousTarget(staticCalorieGoal);
        final proposal = WeeklyCalorieController.computeWeeklyTarget(
          expenditureState: expenditureState,
          previousCalorieTarget: previousTarget,
          goalMode: _goalModeFromStrategy(strategy.mode),
          targetRatePctPerWeek: strategy.targetRatePctPerWeek,
          targetWeightKg: strategy.targetWeightKg,
          trendWeightKg: trendWeight,
        );

        appliedCheckIn = CheckInRecordDBO(
          weekStart: currentWeekStart,
          previousCalorieTarget: proposal.previousTarget,
          proposedCalorieTarget: proposal.proposedTarget,
          appliedCalorieTarget: proposal.appliedTarget,
          dismissed: false,
          expenditureAtCheckIn: proposal.estimatedExpenditure,
          trendWeightAtCheckIn: proposal.trendWeight,
          confidenceAtCheckIn: proposal.confidence,
        );
        await _checkInRecordDataSource.saveRecord(appliedCheckIn);
        calorieTarget = appliedCheckIn.appliedCalorieTarget;
      } else {
        calorieTarget = await _getPreviousTarget(staticCalorieGoal);
      }
    }

    return AdaptiveStrategySnapshot(
      strategy: strategy,
      expenditureState: expenditureState,
      calorieTarget: calorieTarget,
      staticTdee: staticTdee,
      staticCalorieGoal: staticCalorieGoal,
      trendWeightKg: trendWeight,
      weightEntries: weightEntries,
      currentCheckIn: appliedCheckIn,
    );
  }

  Future<_StrategySyncResult> _ensureStrategy(
      UserEntity user, ConfigEntity config) async {
    final existing = await _goalStrategyDataSource.getCurrentStrategy();
    final syncedStrategy = _buildStrategyFromUser(user, config, existing);
    if (existing != null &&
        existing.mode == syncedStrategy.mode &&
        existing.targetWeightKg == syncedStrategy.targetWeightKg &&
        existing.targetRatePctPerWeek == syncedStrategy.targetRatePctPerWeek &&
        existing.macroStyle == syncedStrategy.macroStyle &&
        existing.adaptiveEnabled == syncedStrategy.adaptiveEnabled) {
      return _StrategySyncResult(strategy: existing, changed: false);
    }

    await _goalStrategyDataSource.saveCurrentStrategy(syncedStrategy);
    return _StrategySyncResult(strategy: syncedStrategy, changed: true);
  }

  Future<List<WeightEntryEntity>> _ensureWeightHistory(
      UserEntity user, DateTime day) async {
    final existingDbos = await _weightEntryDataSource.getAllEntries();
    if (existingDbos.isNotEmpty) {
      return existingDbos.map(WeightEntryEntity.fromDBO).toList();
    }

    final seededEntry = WeightEntryEntity(
      day: day,
      weightKg: user.weightKG,
      source: WeightEntrySource.migratedProfileWeight,
    );
    await _weightEntryDataSource.addEntry(seededEntry.toDBO());
    return [seededEntry];
  }

  Future<ExpenditureStateEntity?> _getPreviousDayEstimate(
      DateTime today) async {
    final previousDbo =
        await _expenditureStateDataSource.getLatestStateBefore(today);
    return previousDbo == null
        ? null
        : ExpenditureStateEntity.fromDBO(previousDbo);
  }

  Future<double> _getPreviousTarget(double fallback) async {
    final latestRecord = await _checkInRecordDataSource.getLatestRecord();
    return latestRecord?.appliedCalorieTarget ?? fallback;
  }

  GoalMode _goalModeFromStrategy(StrategyGoalModeDBO mode) => switch (mode) {
        StrategyGoalModeDBO.lose => GoalMode.lose,
        StrategyGoalModeDBO.maintain => GoalMode.maintain,
        StrategyGoalModeDBO.gain => GoalMode.gain,
      };

  StrategyGoalModeDBO _goalModeToStrategy(UserWeightGoalEntity goal) =>
      switch (goal) {
        UserWeightGoalEntity.loseWeight => StrategyGoalModeDBO.lose,
        UserWeightGoalEntity.maintainWeight => StrategyGoalModeDBO.maintain,
        UserWeightGoalEntity.gainWeight => StrategyGoalModeDBO.gain,
      };

  GoalStrategyDBO _buildStrategyFromUser(
    UserEntity user,
    ConfigEntity config,
    GoalStrategyDBO? existing,
  ) {
    final hasCustomMacros = config.userCarbGoalPct != null ||
        config.userProteinGoalPct != null ||
        config.userFatGoalPct != null;
    final targetMode = _goalModeToStrategy(user.goal);

    return GoalStrategyDBO(
      mode: targetMode,
      targetWeightKg: targetMode == StrategyGoalModeDBO.maintain
          ? existing != null &&
                  existing.mode == StrategyGoalModeDBO.maintain &&
                  existing.targetWeightKg != null
              ? existing.targetWeightKg
              : user.weightKG
          : null,
      targetRatePctPerWeek: existing != null && existing.mode == targetMode
          ? StrategyRatePolicy.clampRateForMode(
              targetMode, existing.targetRatePctPerWeek)
          : StrategyRatePolicy.defaultRateForMode(targetMode),
      macroStyle: hasCustomMacros
          ? MacroProgramStyleDBO.manual
          : existing?.macroStyle ?? MacroProgramStyleDBO.balanced,
      adaptiveEnabled: existing?.adaptiveEnabled ?? true,
    );
  }
}
