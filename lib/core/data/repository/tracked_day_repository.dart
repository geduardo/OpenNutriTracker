import 'package:opennutritracker/core/data/data_source/tracked_day_data_source.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/features/strategy/data/dbo/day_log_quality_dbo.dart';

class TrackedDayRepository {
  final TrackedDayDataSource _trackedDayDataSource;

  TrackedDayRepository(this._trackedDayDataSource);

  Future<List<TrackedDayDBO>> getAllTrackedDaysDBO() async {
    return await _trackedDayDataSource.getAllTrackedDays();
  }

  Future<void> clearAll() async {
    await _trackedDayDataSource.clear();
  }

  Future<TrackedDayEntity?> getTrackedDay(DateTime day) async {
    final trackedDay = await _trackedDayDataSource.getTrackedDay(day);
    if (trackedDay != null) {
      return TrackedDayEntity.fromTrackedDayDBO(trackedDay);
    } else {
      return null;
    }
  }

  Future<bool> hasTrackedDay(DateTime day) async {
    final trackedDay = await getTrackedDay(day);
    if (trackedDay != null) {
      return true;
    } else {
      return false;
    }
  }

  Future<List<TrackedDayEntity>> getTrackedDayByRange(
      DateTime start, DateTime end) async {
    final List<TrackedDayDBO> trackedDaysDBO =
        await _trackedDayDataSource.getTrackedDaysInRange(start, end);

    return trackedDaysDBO
        .map((trackedDayDBO) =>
            TrackedDayEntity.fromTrackedDayDBO(trackedDayDBO))
        .toList();
  }

  Future<void> updateDayCalorieGoal(DateTime day, double calorieGoal) async {
    await _trackedDayDataSource.updateDayCalorieGoal(day, calorieGoal);
  }

  Future<void> increaseDayCalorieGoal(DateTime day, double amount) async {
    await _trackedDayDataSource.increaseDayCalorieGoal(day, amount);
  }

  Future<void> reduceDayCalorieGoal(DateTime day, double amount) async {
    await _trackedDayDataSource.reduceDayCalorieGoal(day, amount);
  }

  static const double defaultSodiumGoalMg = 2300;
  static const double defaultCaffeineGoalMg = 400;

  Future<void> addNewTrackedDay(
      DateTime day,
      double totalKcalGoal,
      double totalCarbsGoal,
      double totalFatGoal,
      double totalProteinGoal) async {
    await _trackedDayDataSource.saveTrackedDay(TrackedDayDBO(
        day: day,
        calorieGoal: totalKcalGoal,
        caloriesTracked: 0,
        carbsGoal: totalCarbsGoal,
        carbsTracked: 0,
        fatGoal: totalFatGoal,
        fatTracked: 0,
        proteinGoal: totalProteinGoal,
        proteinTracked: 0,
        sodiumGoal: defaultSodiumGoalMg,
        sodiumTracked: 0,
        caffeineGoal: defaultCaffeineGoalMg,
        caffeineTracked: 0,
        logQuality: DayLogQualityDBO.unlogged,
        manuallyMarked: false));
  }

  Future<void> addAllTrackedDays(List<TrackedDayDBO> trackedDaysDBO) async {
    await _trackedDayDataSource.saveAllTrackedDays(trackedDaysDBO);
  }

  Future<void> saveTrackedDay(TrackedDayEntity trackedDayEntity) async {
    await _trackedDayDataSource
        .saveTrackedDay(TrackedDayDBO.fromTrackedDayEntity(trackedDayEntity));
  }

  Future<void> addDayTrackedCalories(DateTime day, double addCalories) async {
    if (await _trackedDayDataSource.hasTrackedDay(day)) {
      await _trackedDayDataSource.addDayCaloriesTracked(day, addCalories);
    }
  }

  Future<void> removeDayTrackedCalories(
      DateTime day, double addCalories) async {
    if (await _trackedDayDataSource.hasTrackedDay(day)) {
      await _trackedDayDataSource.decreaseDayCaloriesTracked(day, addCalories);
    }
  }

  Future<void> updateDayMacroGoal(DateTime day,
      {double? carbGoal, double? fatGoal, double? proteinGoal}) async {
    await _trackedDayDataSource.updateDayMacroGoals(day,
        carbsGoal: carbGoal, fatGoal: fatGoal, proteinGoal: proteinGoal);
  }

  Future<void> increaseDayMacroGoal(DateTime day,
      {double? carbGoal, double? fatGoal, double? proteinGoal}) async {
    await _trackedDayDataSource.increaseDayMacroGoal(day,
        carbsAmount: carbGoal, fatAmount: fatGoal, proteinAmount: proteinGoal);
  }

  Future<void> reduceDayMacroGoal(DateTime day,
      {double? carbGoal, double? fatGoal, double? proteinGoal}) async {
    await _trackedDayDataSource.reduceDayMacroGoal(day,
        carbsAmount: carbGoal, fatAmount: fatGoal, proteinAmount: proteinGoal);
  }

  Future<void> addDayMacrosTracked(DateTime day,
      {double? carbsTracked,
      double? fatTracked,
      double? proteinTracked,
      double? sodiumTracked,
      double? caffeineTracked}) async {
    await _trackedDayDataSource.addDayMacroTracked(day,
        carbsAmount: carbsTracked,
        fatAmount: fatTracked,
        proteinAmount: proteinTracked,
        sodiumAmount: sodiumTracked,
        caffeineAmount: caffeineTracked);
  }

  Future<void> removeDayMacrosTracked(DateTime day,
      {double? carbsTracked,
      double? fatTracked,
      double? proteinTracked,
      double? sodiumTracked,
      double? caffeineTracked}) async {
    await _trackedDayDataSource.removeDayMacroTracked(day,
        carbsAmount: carbsTracked,
        fatAmount: fatTracked,
        proteinAmount: proteinTracked,
        sodiumAmount: sodiumTracked,
        caffeineAmount: caffeineTracked);
  }

  /// Overwrite all aggregate fields for a day with the supplied authoritative
  /// totals. Used by the diary self-healing pass to fix cache drift.
  Future<void> setDayAggregates(
    DateTime day, {
    required double caloriesTracked,
    required double carbsTracked,
    required double fatTracked,
    required double proteinTracked,
    required double sodiumTracked,
    required double caffeineTracked,
  }) async {
    await _trackedDayDataSource.setDayAggregates(
      day,
      caloriesTracked: caloriesTracked,
      carbsTracked: carbsTracked,
      fatTracked: fatTracked,
      proteinTracked: proteinTracked,
      sodiumTracked: sodiumTracked,
      caffeineTracked: caffeineTracked,
    );
  }
}
