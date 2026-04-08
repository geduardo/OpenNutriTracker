import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/features/strategy/data/dbo/day_log_quality_dbo.dart';

class TrackedDayDataSource {
  final log = Logger('TrackedDayDataSource');
  final Box<TrackedDayDBO> _trackedDayBox;

  TrackedDayDataSource(this._trackedDayBox);

  Future<void> saveTrackedDay(TrackedDayDBO trackedDayDBO) async {
    log.fine('Updating tracked day in db');
    _applyAutomaticLogQuality(trackedDayDBO);
    await _trackedDayBox.put(trackedDayDBO.day.toParsedDay(), trackedDayDBO);
  }

  Future<void> saveAllTrackedDays(List<TrackedDayDBO> trackedDayDBOList) async {
    log.fine('Updating tracked days in db');
    for (final trackedDayDBO in trackedDayDBOList) {
      trackedDayDBO.manuallyMarked ??= false;
      if (trackedDayDBO.manuallyMarked != true &&
          trackedDayDBO.logQuality == null) {
        trackedDayDBO.logQuality = trackedDayDBO.caloriesTracked > 0
            ? DayLogQualityDBO.complete
            : DayLogQualityDBO.unlogged;
      }
    }
    await _trackedDayBox.putAll({
      for (var trackedDayDBO in trackedDayDBOList)
        trackedDayDBO.day.toParsedDay(): trackedDayDBO
    });
  }

  Future<List<TrackedDayDBO>> getAllTrackedDays() async {
    return _trackedDayBox.values.toList();
  }

  Future<void> clear() async {
    await _trackedDayBox.clear();
  }

  Future<TrackedDayDBO?> getTrackedDay(DateTime day) async {
    return _trackedDayBox.get(day.toParsedDay());
  }

  Future<List<TrackedDayDBO>> getTrackedDaysInRange(
      DateTime start, DateTime end) async {
    List<TrackedDayDBO> trackedDays = _trackedDayBox.values
        .where((trackedDay) =>
            (trackedDay.day.isAfter(start) && trackedDay.day.isBefore(end)))
        .toList();
    return trackedDays;
  }

  Future<bool> hasTrackedDay(DateTime day) async =>
      _trackedDayBox.get(day.toParsedDay()) != null;

  Future<void> updateDayCalorieGoal(DateTime day, double calorieGoal) async {
    log.fine('Updating tracked day total calories');
    final updateDay = await getTrackedDay(day);

    if (updateDay != null) {
      updateDay.calorieGoal = calorieGoal;
      await updateDay.save();
    }
  }

  Future<void> increaseDayCalorieGoal(DateTime day, double amount) async {
    log.fine('Increasing tracked day total calories');
    final updateDay = await getTrackedDay(day);

    if (updateDay != null) {
      updateDay.calorieGoal += amount;
      await updateDay.save();
    }
  }

  Future<void> reduceDayCalorieGoal(DateTime day, double amount) async {
    log.fine('Reducing tracked day total calories');
    final updateDay = await getTrackedDay(day);

    if (updateDay != null) {
      updateDay.calorieGoal -= amount;
      await updateDay.save();
    }
  }

  Future<void> addDayCaloriesTracked(DateTime day, double addCalories) async {
    log.fine('Adding new tracked day calories');
    final updateDay = await getTrackedDay(day);

    if (updateDay != null) {
      updateDay.caloriesTracked += addCalories;
      _applyAutomaticLogQuality(updateDay);
      await updateDay.save();
    }
  }

  /// Overwrite the cached aggregate fields for a day with the supplied
  /// authoritative totals (used by the diary self-healing pass that
  /// recomputes from actual intakes). Goals are left untouched. Does
  /// nothing if the day has no TrackedDay record.
  Future<void> setDayAggregates(
    DateTime day, {
    required double caloriesTracked,
    required double carbsTracked,
    required double fatTracked,
    required double proteinTracked,
    required double sodiumTracked,
    required double caffeineTracked,
  }) async {
    final updateDay = await getTrackedDay(day);
    if (updateDay == null) return;
    updateDay.caloriesTracked = caloriesTracked;
    updateDay.carbsTracked = carbsTracked;
    updateDay.fatTracked = fatTracked;
    updateDay.proteinTracked = proteinTracked;
    updateDay.sodiumTracked = sodiumTracked;
    updateDay.caffeineTracked = caffeineTracked;
    _applyAutomaticLogQuality(updateDay);
    await updateDay.save();
  }

  Future<void> decreaseDayCaloriesTracked(
      DateTime day, double addCalories) async {
    log.fine('Decreasing tracked day calories');
    final updateDay = await getTrackedDay(day);

    if (updateDay != null) {
      updateDay.caloriesTracked -= addCalories;
      _applyAutomaticLogQuality(updateDay);
      await updateDay.save();
    }
  }

  Future<void> updateDayMacroGoals(DateTime day,
      {double? carbsGoal, double? fatGoal, double? proteinGoal, double? sodiumGoal}) async {
    log.fine('Updating tracked day macro goals');

    final updateDay = await getTrackedDay(day);

    if (updateDay != null) {
      if (carbsGoal != null) {
        updateDay.carbsGoal = carbsGoal;
      }
      if (fatGoal != null) {
        updateDay.fatGoal = fatGoal;
      }
      if (proteinGoal != null) {
        updateDay.proteinGoal = proteinGoal;
      }
      if (sodiumGoal != null) {
        updateDay.sodiumGoal = sodiumGoal;
      }
      await updateDay.save();
    }
  }

  Future<void> increaseDayMacroGoal(DateTime day,
      {double? carbsAmount, double? fatAmount, double? proteinAmount, double? sodiumAmount}) async {
    log.fine('Increasing tracked day macro goals');
    final updateDay = await getTrackedDay(day);

    if (updateDay != null) {
      if (carbsAmount != null) {
        updateDay.carbsGoal = (updateDay.carbsGoal ?? 0) + carbsAmount;
      }
      if (fatAmount != null) {
        updateDay.fatGoal = (updateDay.fatGoal ?? 0) + fatAmount;
      }
      if (proteinAmount != null) {
        updateDay.proteinGoal = (updateDay.proteinGoal ?? 0) + proteinAmount;
      }
      if (sodiumAmount != null) {
        updateDay.sodiumGoal = (updateDay.sodiumGoal ?? 0) + sodiumAmount;
      }
      await updateDay.save();
    }
  }

  Future<void> reduceDayMacroGoal(DateTime day,
      {double? carbsAmount, double? fatAmount, double? proteinAmount, double? sodiumAmount}) async {
    log.fine('Reducing tracked day macro goals');
    final updateDay = await getTrackedDay(day);

    if (updateDay != null) {
      if (carbsAmount != null) {
        updateDay.carbsGoal = (updateDay.carbsGoal ?? 0) - carbsAmount;
      }
      if (fatAmount != null) {
        updateDay.fatGoal = (updateDay.fatGoal ?? 0) - fatAmount;
      }
      if (proteinAmount != null) {
        updateDay.proteinGoal = (updateDay.proteinGoal ?? 0) - proteinAmount;
      }
      if (sodiumAmount != null) {
        updateDay.sodiumGoal = (updateDay.sodiumGoal ?? 0) - sodiumAmount;
      }
      await updateDay.save();
    }
  }

  Future<void> addDayMacroTracked(DateTime day,
      {double? carbsAmount,
      double? fatAmount,
      double? proteinAmount,
      double? sodiumAmount,
      double? caffeineAmount}) async {
    log.fine('Adding new tracked day macro');
    final updateDay = await getTrackedDay(day);

    if (updateDay != null) {
      if (carbsAmount != null) {
        updateDay.carbsTracked = (updateDay.carbsTracked ?? 0) + carbsAmount;
      }
      if (fatAmount != null) {
        updateDay.fatTracked = (updateDay.fatTracked ?? 0) + fatAmount;
      }
      if (proteinAmount != null) {
        updateDay.proteinTracked =
            (updateDay.proteinTracked ?? 0) + proteinAmount;
      }
      if (sodiumAmount != null) {
        updateDay.sodiumTracked =
            (updateDay.sodiumTracked ?? 0) + sodiumAmount;
      }
      if (caffeineAmount != null) {
        updateDay.caffeineTracked =
            (updateDay.caffeineTracked ?? 0) + caffeineAmount;
      }
      _applyAutomaticLogQuality(updateDay);
      await updateDay.save();
    }
  }

  Future<void> removeDayMacroTracked(DateTime day,
      {double? carbsAmount,
      double? fatAmount,
      double? proteinAmount,
      double? sodiumAmount,
      double? caffeineAmount}) async {
    log.fine('Removing tracked day macro');
    final updateDay = await getTrackedDay(day);

    if (updateDay != null) {
      if (carbsAmount != null) {
        updateDay.carbsTracked = (updateDay.carbsTracked ?? 0) - carbsAmount;
      }
      if (fatAmount != null) {
        updateDay.fatTracked = (updateDay.fatTracked ?? 0) - fatAmount;
      }
      if (proteinAmount != null) {
        updateDay.proteinTracked =
            (updateDay.proteinTracked ?? 0) - proteinAmount;
      }
      if (sodiumAmount != null) {
        updateDay.sodiumTracked =
            (updateDay.sodiumTracked ?? 0) - sodiumAmount;
      }
      if (caffeineAmount != null) {
        updateDay.caffeineTracked =
            (updateDay.caffeineTracked ?? 0) - caffeineAmount;
      }
      _applyAutomaticLogQuality(updateDay);
      await updateDay.save();
    }
  }

  void _applyAutomaticLogQuality(TrackedDayDBO trackedDay) {
    trackedDay.manuallyMarked ??= false;
    if (trackedDay.manuallyMarked == true) {
      return;
    }

    trackedDay.logQuality = trackedDay.caloriesTracked > 0
        ? DayLogQualityDBO.complete
        : DayLogQualityDBO.unlogged;
  }
}
