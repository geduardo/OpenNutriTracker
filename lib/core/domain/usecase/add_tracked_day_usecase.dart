import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';

class AddTrackedDayUsecase {
  final TrackedDayRepository _trackedDayRepository;

  AddTrackedDayUsecase(this._trackedDayRepository);

  Future<void> updateDayCalorieGoal(DateTime day, double calorieGoal) async {
    await _trackedDayRepository.updateDayCalorieGoal(day, calorieGoal);
  }

  Future<void> increaseDayCalorieGoal(DateTime day, double amount) async {
    await _trackedDayRepository.increaseDayCalorieGoal(day, amount);
  }

  Future<void> reduceDayCalorieGoal(DateTime day, double amount) async {
    await _trackedDayRepository.reduceDayCalorieGoal(day, amount);
  }

  Future<bool> hasTrackedDay(DateTime day) async {
    return await _trackedDayRepository.hasTrackedDay(day);
  }

  Future<void> addNewTrackedDay(
      DateTime day,
      double totalKcalGoal,
      double totalCarbsGoal,
      double totalFatGoal,
      double totalProteinGoal) async {
    return await _trackedDayRepository.addNewTrackedDay(
        day, totalKcalGoal, totalCarbsGoal, totalFatGoal, totalProteinGoal);
  }

  Future<void> addDayCaloriesTracked(
      DateTime day, double caloriesTracked) async {
    await _trackedDayRepository.addDayTrackedCalories(day, caloriesTracked);
  }

  Future<void> removeDayCaloriesTracked(
      DateTime day, double caloriesTracked) async {
    await _trackedDayRepository.removeDayTrackedCalories(day, caloriesTracked);
  }

  Future<void> updateDayMacroGoals(DateTime day,
      {double? carbsGoal, double? fatGoal, double? proteinGoal}) async {
    await _trackedDayRepository.updateDayMacroGoal(day,
        carbGoal: carbsGoal, fatGoal: fatGoal, proteinGoal: proteinGoal);
  }

  Future<void> increaseDayMacroGoals(DateTime day,
      {double? carbsAmount, double? fatAmount, double? proteinAmount}) async {
    await _trackedDayRepository.increaseDayMacroGoal(day,
        carbGoal: carbsAmount, fatGoal: fatAmount, proteinGoal: proteinAmount);
  }

  Future<void> reduceDayMacroGoals(DateTime day,
      {double? carbsAmount, double? fatAmount, double? proteinAmount}) async {
    await _trackedDayRepository.reduceDayMacroGoal(day,
        carbGoal: carbsAmount, fatGoal: fatAmount, proteinGoal: proteinAmount);
  }

  Future<void> addDayMacrosTracked(DateTime day,
      {double? carbsTracked,
      double? fatTracked,
      double? proteinTracked,
      double? sodiumTracked,
      double? caffeineTracked}) async {
    await _trackedDayRepository.addDayMacrosTracked(day,
        carbsTracked: carbsTracked,
        fatTracked: fatTracked,
        proteinTracked: proteinTracked,
        sodiumTracked: sodiumTracked,
        caffeineTracked: caffeineTracked);
  }

  Future<void> removeDayMacrosTracked(DateTime day,
      {double? carbsTracked,
      double? fatTracked,
      double? proteinTracked,
      double? sodiumTracked,
      double? caffeineTracked}) async {
    await _trackedDayRepository.removeDayMacrosTracked(day,
        carbsTracked: carbsTracked,
        fatTracked: fatTracked,
        proteinTracked: proteinTracked,
        sodiumTracked: sodiumTracked,
        caffeineTracked: caffeineTracked);
  }

  /// Overwrite the cached aggregate fields for [day] with authoritative
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
    await _trackedDayRepository.setDayAggregates(
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
