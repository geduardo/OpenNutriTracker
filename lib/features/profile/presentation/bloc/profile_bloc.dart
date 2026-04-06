import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/domain/entity/config_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_bmi_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_entity.dart';
import 'package:opennutritracker/core/domain/entity/user_weight_goal_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_user_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/utils/calc/bmi_calc.dart';
import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/calendar_day_bloc.dart';
import 'package:opennutritracker/features/diary/presentation/bloc/diary_bloc.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/strategy/data/data_source/check_in_record_data_source.dart';
import 'package:opennutritracker/features/strategy/data/data_source/goal_strategy_data_source.dart';
import 'package:opennutritracker/features/strategy/data/dbo/goal_strategy_dbo.dart';
import 'package:opennutritracker/features/strategy/data/repository/weight_entry_repository.dart';
import 'package:opennutritracker/features/strategy/domain/entity/weight_entry_entity.dart';
import 'package:opennutritracker/features/strategy/domain/service/strategy_rate_policy.dart';

part 'profile_event.dart';

part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetUserUsecase _getUserUsecase;
  final AddUserUsecase _addUserUsecase;
  final AddTrackedDayUsecase _addTrackedDayUsecase;
  final GetConfigUsecase _getConfigUsecase;
  final GetKcalGoalUsecase _getKcalGoalUsecase;
  final GetMacroGoalUsecase _getMacroGoalUsecase;
  final WeightEntryRepository _weightEntryRepository;
  final GoalStrategyDataSource _goalStrategyDataSource;
  final CheckInRecordDataSource _checkInRecordDataSource;

  ProfileBloc(
      this._getUserUsecase,
      this._addUserUsecase,
      this._addTrackedDayUsecase,
      this._getConfigUsecase,
      this._getKcalGoalUsecase,
      this._getMacroGoalUsecase,
      this._weightEntryRepository,
      this._goalStrategyDataSource,
      this._checkInRecordDataSource)
      : super(ProfileInitial()) {
    on<LoadProfileEvent>((event, emit) async {
      emit(ProfileLoadingState());

      final user = await _getUserUsecase.getUserData();
      final userBMIValue = BMICalc.getBMI(user);
      final userBMIEntity = UserBMIEntity(
          bmiValue: userBMIValue,
          nutritionalStatus: BMICalc.getNutritionalStatus(userBMIValue));
      final userConfig = await _getConfigUsecase.getConfig();
      final desiredRatePct = await _getDesiredRatePct(user);
      final desiredRateKg = StrategyRatePolicy.signedKgPerWeek(
        mode: _goalModeToStrategy(user),
        pctPerWeek: desiredRatePct,
        bodyWeightKg: user.weightKG,
      );

      emit(ProfileLoadedState(
          userBMI: userBMIEntity,
          userEntity: user,
          usesImperialUnits: userConfig.usesImperialUnits,
          desiredWeeklyRatePct: desiredRatePct,
          desiredWeeklyRateKg: desiredRateKg));
    });
  }

  void updateUser(UserEntity userEntity) async {
    final previousUser = await _getUserUsecase.getUserData();

    // Update user in DB
    await _addUserUsecase.addUser(userEntity);

    if ((previousUser.weightKG - userEntity.weightKG).abs() > 0.001) {
      await _weightEntryRepository.addEntry(WeightEntryEntity(
        day: DateTime.now(),
        weightKg: userEntity.weightKG,
        source: WeightEntrySource.manual,
      ));
    }

    // Update Tracked Day
    await _updateTrackedDayCalorieGoal(userEntity, DateTime.now());

    _refreshPages();
  }

  Future<void> updateDesiredWeeklyRate(
      UserEntity userEntity, double targetRatePctPerWeek) async {
    final mode = _goalModeToStrategy(userEntity);
    if (mode == StrategyGoalModeDBO.maintain) {
      return;
    }

    final config = await _getConfigUsecase.getConfig();
    final existing = await _goalStrategyDataSource.getCurrentStrategy();
    final strategy =
        _buildStrategyForUser(userEntity, config, existing).copyWith(
      targetRatePctPerWeek:
          StrategyRatePolicy.clampRateForMode(mode, targetRatePctPerWeek),
    );

    await _goalStrategyDataSource.saveCurrentStrategy(strategy);
    await _checkInRecordDataSource.deleteRecordForWeek(
        CheckInRecordDataSource.startOfWeek(DateTime.now()));
    await _updateTrackedDayCalorieGoal(userEntity, DateTime.now());
    _refreshPages();
  }

  Future<void> _updateTrackedDayCalorieGoal(
      UserEntity user, DateTime day) async {
    final hasTrackedDay = await _addTrackedDayUsecase.hasTrackedDay(day);
    if (hasTrackedDay) {
      final totalKcalGoal =
          await _getKcalGoalUsecase.getKcalGoal(userEntity: user);
      final totalCarbsGoal =
          await _getMacroGoalUsecase.getCarbsGoal(totalKcalGoal);
      final totalFatGoal =
          await _getMacroGoalUsecase.getFatsGoal(totalKcalGoal);
      final totalProteinGoal =
          await _getMacroGoalUsecase.getProteinsGoal(totalKcalGoal);

      await _addTrackedDayUsecase.updateDayCalorieGoal(day, totalKcalGoal);
      await _addTrackedDayUsecase.updateDayMacroGoals(day,
          carbsGoal: totalCarbsGoal,
          fatGoal: totalFatGoal,
          proteinGoal: totalProteinGoal);
    }
  }

  /// Returns the user's height in cm or ft/in based on the user's config
  String getDisplayHeight(UserEntity user, bool usesImperialUnits) {
    if (usesImperialUnits) {
      // Convert cm to feet and inches
      return UnitCalc.cmToFeet(user.heightCM).toStringAsFixed(1);
    } else {
      return user.heightCM.roundToDouble().toStringAsFixed(0);
    }
  }

  /// Returns the user's weight in kg or lbs based on the user's config
  String getDisplayWeight(UserEntity user, bool usesImperialUnits) {
    if (usesImperialUnits) {
      return UnitCalc.kgToLbs(user.weightKG).toStringAsFixed(0);
    } else {
      return user.weightKG.roundToDouble().toStringAsFixed(0);
    }
  }

  Future<double> _getDesiredRatePct(UserEntity user) async {
    final strategy = await _goalStrategyDataSource.getCurrentStrategy();
    final mode = _goalModeToStrategy(user);

    if (strategy != null && strategy.mode == mode) {
      return StrategyRatePolicy.clampRateForMode(
          mode, strategy.targetRatePctPerWeek);
    }

    return StrategyRatePolicy.defaultRateForMode(mode);
  }

  GoalStrategyDBO _buildStrategyForUser(
      UserEntity user, ConfigEntity config, GoalStrategyDBO? existing) {
    final hasCustomMacros = config.userCarbGoalPct != null ||
        config.userProteinGoalPct != null ||
        config.userFatGoalPct != null;
    final mode = _goalModeToStrategy(user);

    return GoalStrategyDBO(
      mode: mode,
      targetWeightKg: mode == StrategyGoalModeDBO.maintain
          ? existing != null &&
                  existing.mode == StrategyGoalModeDBO.maintain &&
                  existing.targetWeightKg != null
              ? existing.targetWeightKg
              : user.weightKG
          : null,
      targetRatePctPerWeek: existing != null && existing.mode == mode
          ? StrategyRatePolicy.clampRateForMode(
              mode, existing.targetRatePctPerWeek)
          : StrategyRatePolicy.defaultRateForMode(mode),
      macroStyle: hasCustomMacros
          ? MacroProgramStyleDBO.manual
          : existing?.macroStyle ?? MacroProgramStyleDBO.balanced,
      adaptiveEnabled: existing?.adaptiveEnabled ?? true,
    );
  }

  StrategyGoalModeDBO _goalModeToStrategy(UserEntity user) =>
      switch (user.goal) {
        UserWeightGoalEntity.loseWeight => StrategyGoalModeDBO.lose,
        UserWeightGoalEntity.maintainWeight => StrategyGoalModeDBO.maintain,
        UserWeightGoalEntity.gainWeight => StrategyGoalModeDBO.gain,
      };

  void _refreshPages() {
    add(LoadProfileEvent());
    locator<HomeBloc>().add(const LoadItemsEvent());
    locator<DiaryBloc>().add(const LoadDiaryYearEvent());
    locator<CalendarDayBloc>().add(RefreshCalendarDayEvent());
  }
}
