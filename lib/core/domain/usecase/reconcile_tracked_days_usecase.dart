import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/utils/calc/calorie_goal_calc.dart';
import 'package:opennutritracker/core/utils/calc/macro_calc.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/features/strategy/data/dbo/day_log_quality_dbo.dart';

class ReconcileTrackedDaysUsecase {
  static const double _eps = 0.5;
  static const double _defaultCalorieGoal = 2000;

  final _log = Logger('ReconcileTrackedDaysUsecase');
  final IntakeRepository _intakeRepository;
  final TrackedDayRepository _trackedDayRepository;
  final UserRepository _userRepository;
  final ConfigRepository _configRepository;

  ReconcileTrackedDaysUsecase(
    this._intakeRepository,
    this._trackedDayRepository,
    this._userRepository,
    this._configRepository,
  );

  Future<List<TrackedDayEntity>> reconcileTrackedDaysByRange(
    DateTime start,
    DateTime end,
  ) async {
    final rangeStart = DateUtils.dateOnly(start);
    final rangeEnd = DateUtils.dateOnly(end);

    final allIntakes = await _intakeRepository.getAllIntakes();
    final allTrackedDays = await _trackedDayRepository.getAllTrackedDaysDBO();

    final intakesByKey = <String, List<IntakeEntity>>{};
    final daysByKey = <String, DateTime>{};
    for (final intake in allIntakes) {
      final day = DateUtils.dateOnly(intake.dateTime);
      if (!_isWithinRange(day, rangeStart, rangeEnd)) {
        continue;
      }
      final key = day.toParsedDay();
      daysByKey[key] = day;
      (intakesByKey[key] ??= <IntakeEntity>[]).add(intake);
    }

    final trackedDaysByKey = <String, TrackedDayDBO>{};
    for (final trackedDay in allTrackedDays) {
      final day = DateUtils.dateOnly(trackedDay.day);
      if (!_isWithinRange(day, rangeStart, rangeEnd)) {
        continue;
      }
      final key = day.toParsedDay();
      daysByKey[key] = day;
      trackedDaysByKey[key] = trackedDay;
    }

    final orderedKeys = daysByKey.keys.toList()
      ..sort((a, b) => daysByKey[a]!.compareTo(daysByKey[b]!));

    final correctedDays = <TrackedDayEntity>[];
    for (final key in orderedKeys) {
      final day = daysByKey[key]!;
      final trackedDay = trackedDaysByKey[key];
      final totals = _sumDayTotals(intakesByKey[key] ?? const <IntakeEntity>[]);

      if (trackedDay == null) {
        final goals = await _resolveGoalsForBackfill(day, allTrackedDays);
        final correctedDay = TrackedDayEntity(
          day: day,
          calorieGoal: goals.calorieGoal,
          caloriesTracked: totals.kcal,
          carbsGoal: goals.carbsGoal,
          carbsTracked: totals.carbs,
          fatGoal: goals.fatGoal,
          fatTracked: totals.fat,
          proteinGoal: goals.proteinGoal,
          proteinTracked: totals.protein,
          sodiumGoal: goals.sodiumGoal,
          sodiumTracked: totals.sodium,
          caffeineGoal: goals.caffeineGoal,
          caffeineTracked: totals.caffeine,
        );
        await _trackedDayRepository.saveTrackedDay(correctedDay);
        _log.info(
            'Backfilled missing tracked day on $key from ${intakesByKey[key]?.length ?? 0} intake(s)');
        correctedDays.add(correctedDay);
        continue;
      }

      final needsAggregateRepair = _hasAggregateDrift(trackedDay, totals);
      final needsQualityRepair = _needsAutoQualityRefresh(trackedDay, totals.kcal);
      if (needsAggregateRepair || needsQualityRepair) {
        await _trackedDayRepository.setDayAggregates(
          trackedDay.day,
          caloriesTracked: totals.kcal,
          carbsTracked: totals.carbs,
          fatTracked: totals.fat,
          proteinTracked: totals.protein,
          sodiumTracked: totals.sodium,
          caffeineTracked: totals.caffeine,
        );
        _log.info(
            'Reconciled tracked day $key (kcal ${trackedDay.caloriesTracked.toInt()} -> ${totals.kcal.toInt()})');
      }

      correctedDays.add(TrackedDayEntity(
        day: trackedDay.day,
        calorieGoal: trackedDay.calorieGoal,
        caloriesTracked: totals.kcal,
        carbsGoal: trackedDay.carbsGoal,
        carbsTracked: totals.carbs,
        fatGoal: trackedDay.fatGoal,
        fatTracked: totals.fat,
        proteinGoal: trackedDay.proteinGoal,
        proteinTracked: totals.protein,
        sodiumGoal: trackedDay.sodiumGoal,
        sodiumTracked: totals.sodium,
        caffeineGoal: trackedDay.caffeineGoal,
        caffeineTracked: totals.caffeine,
      ));
    }

    return correctedDays;
  }

  bool _isWithinRange(DateTime day, DateTime start, DateTime end) {
    return !day.isBefore(start) && !day.isAfter(end);
  }

  _AggregateTotals _sumDayTotals(List<IntakeEntity> intakes) {
    double kcal = 0;
    double carbs = 0;
    double fat = 0;
    double protein = 0;
    double sodium = 0;
    double caffeine = 0;

    for (final intake in intakes) {
      kcal += intake.totalKcal;
      carbs += intake.totalCarbsGram;
      fat += intake.totalFatsGram;
      protein += intake.totalProteinsGram;
      sodium += intake.totalSodiumMg;
      caffeine += intake.totalCaffeineMg;
    }

    return _AggregateTotals(
      kcal: kcal,
      carbs: carbs,
      fat: fat,
      protein: protein,
      sodium: sodium,
      caffeine: caffeine,
    );
  }

  bool _hasAggregateDrift(TrackedDayDBO trackedDay, _AggregateTotals totals) {
    return (trackedDay.caloriesTracked - totals.kcal).abs() > _eps ||
        ((trackedDay.carbsTracked ?? 0) - totals.carbs).abs() > _eps ||
        ((trackedDay.fatTracked ?? 0) - totals.fat).abs() > _eps ||
        ((trackedDay.proteinTracked ?? 0) - totals.protein).abs() > _eps ||
        ((trackedDay.sodiumTracked ?? 0) - totals.sodium).abs() > _eps ||
        ((trackedDay.caffeineTracked ?? 0) - totals.caffeine).abs() > _eps;
  }

  bool _needsAutoQualityRefresh(TrackedDayDBO trackedDay, double caloriesTracked) {
    if (trackedDay.manuallyMarked == true) {
      return false;
    }

    final desired = caloriesTracked > 0
        ? DayLogQualityDBO.complete
        : DayLogQualityDBO.unlogged;
    return trackedDay.logQuality != desired || trackedDay.manuallyMarked == null;
  }

  Future<_GoalSnapshot> _resolveGoalsForBackfill(
    DateTime day,
    Iterable<TrackedDayDBO> trackedDays,
  ) async {
    TrackedDayDBO? bestMatch;
    Duration? bestDistance;

    for (final trackedDay in trackedDays) {
      final trackedDate = DateUtils.dateOnly(trackedDay.day);
      final distance = trackedDate.difference(day).abs();
      if (bestDistance == null || distance < bestDistance) {
        bestDistance = distance;
        bestMatch = trackedDay;
      }
    }

    if (bestMatch != null) {
      return _GoalSnapshot.fromTrackedDay(bestMatch);
    }

    if (await _userRepository.hasUserData()) {
      final user = await _userRepository.getUserData();
      final config = await _configRepository.getConfig();
      final calorieGoal = CalorieGoalCalc.getTotalKcalGoal(
        user,
        0,
        kcalUserAdjustment: config.userKcalAdjustment,
      );
      return _GoalSnapshot(
        calorieGoal: calorieGoal,
        carbsGoal: MacroCalc.getTotalCarbsGoal(
          calorieGoal,
          userCarbsGoal: config.userCarbGoalPct,
        ),
        fatGoal: MacroCalc.getTotalFatsGoal(
          calorieGoal,
          userFatsGoal: config.userFatGoalPct,
        ),
        proteinGoal: MacroCalc.getTotalProteinsGoal(
          calorieGoal,
          userProteinsGoal: config.userProteinGoalPct,
        ),
        sodiumGoal: MacroCalc.defaultSodiumGoalMg,
        caffeineGoal: MacroCalc.defaultCaffeineGoalMg,
      );
    }

    return const _GoalSnapshot(
      calorieGoal: _defaultCalorieGoal,
      carbsGoal: 300,
      fatGoal: 55.6,
      proteinGoal: 75,
      sodiumGoal: MacroCalc.defaultSodiumGoalMg,
      caffeineGoal: MacroCalc.defaultCaffeineGoalMg,
    );
  }
}

class _AggregateTotals {
  final double kcal;
  final double carbs;
  final double fat;
  final double protein;
  final double sodium;
  final double caffeine;

  const _AggregateTotals({
    required this.kcal,
    required this.carbs,
    required this.fat,
    required this.protein,
    required this.sodium,
    required this.caffeine,
  });
}

class _GoalSnapshot {
  final double calorieGoal;
  final double carbsGoal;
  final double fatGoal;
  final double proteinGoal;
  final double sodiumGoal;
  final double caffeineGoal;

  const _GoalSnapshot({
    required this.calorieGoal,
    required this.carbsGoal,
    required this.fatGoal,
    required this.proteinGoal,
    required this.sodiumGoal,
    required this.caffeineGoal,
  });

  factory _GoalSnapshot.fromTrackedDay(TrackedDayDBO trackedDay) {
    final calorieGoal = trackedDay.calorieGoal;
    return _GoalSnapshot(
      calorieGoal: calorieGoal,
      carbsGoal:
          trackedDay.carbsGoal ?? MacroCalc.getTotalCarbsGoal(calorieGoal),
      fatGoal: trackedDay.fatGoal ?? MacroCalc.getTotalFatsGoal(calorieGoal),
      proteinGoal: trackedDay.proteinGoal ??
          MacroCalc.getTotalProteinsGoal(calorieGoal),
      sodiumGoal: trackedDay.sodiumGoal ?? MacroCalc.defaultSodiumGoalMg,
      caffeineGoal:
          trackedDay.caffeineGoal ?? MacroCalc.defaultCaffeineGoalMg,
    );
  }
}
