import 'dart:math';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/data_source/tracked_day_data_source.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/strategy/data/dbo/day_log_quality_dbo.dart';
import 'package:opennutritracker/features/strategy/data/dbo/weight_entry_dbo.dart';
import 'package:opennutritracker/features/strategy/data/data_source/expenditure_state_data_source.dart';
import 'package:opennutritracker/features/strategy/data/data_source/weight_entry_data_source.dart';

/// Generates 30 days of fake data for testing the adaptive calorie engine.
/// Call from a debug button or the strategy page.
class DebugDataGenerator {
  static final _log = Logger('DebugDataGenerator');
  static final _random = Random(42); // Fixed seed for reproducibility

  /// Generates 30 days of:
  /// - Weight entries (weigh-in ~5 days/week with noise)
  /// - Tracked days with calorie data marked as complete
  ///
  /// Simulates a person ~80kg eating ~2200 kcal/day in slight deficit.
  static Future<void> generate30Days() async {
    final weightDataSource = locator<WeightEntryDataSource>();
    final trackedDayDataSource = locator<TrackedDayDataSource>();

    final today = DateUtils.dateOnly(DateTime.now());

    // Simulation parameters
    const startWeight = 82.0; // kg
    const dailyWeightLossKg = 0.03; // ~0.21 kg/week (~0.5 lb/week)
    const weightNoiseStdDev = 0.6; // kg daily fluctuation
    const baseIntake = 2100.0; // kcal/day average
    const intakeNoiseStdDev = 200.0; // kcal variation
    const weighInProbability = 0.7; // ~5 days/week

    _log.info('Generating 30 days of fake data...');

    for (int daysAgo = 30; daysAgo >= 0; daysAgo--) {
      final day = today.subtract(Duration(days: daysAgo));

      // True weight = linear decline + noise
      final trueWeight = startWeight - (30 - daysAgo) * dailyWeightLossKg;
      final scaleWeight = trueWeight + _gaussian() * weightNoiseStdDev;

      // Weight entry (~70% of days)
      if (_random.nextDouble() < weighInProbability) {
        await weightDataSource.addEntry(WeightEntryDBO(
          day: day,
          weightKg: double.parse(scaleWeight.toStringAsFixed(1)),
          source: WeightEntrySourceDBO.manual,
        ));
      }

      // Tracked day with calorie data
      final intake = baseIntake + _gaussian() * intakeNoiseStdDev;
      final carbsG = intake * 0.45 / 4; // 45% carbs
      final fatG = intake * 0.30 / 9; // 30% fat
      final proteinG = intake * 0.25 / 4; // 25% protein

      // Check if tracked day already exists
      final existing = await trackedDayDataSource.getTrackedDay(day);
      if (existing == null) {
        final trackedDay = TrackedDayDBO(
          day: day,
          calorieGoal: 2200,
          caloriesTracked: double.parse(intake.toStringAsFixed(0)),
          carbsGoal: 250,
          carbsTracked: double.parse(carbsG.toStringAsFixed(1)),
          fatGoal: 73,
          fatTracked: double.parse(fatG.toStringAsFixed(1)),
          proteinGoal: 138,
          proteinTracked: double.parse(proteinG.toStringAsFixed(1)),
          logQuality: DayLogQualityDBO.complete,
          manuallyMarked: false,
        );
        await trackedDayDataSource.saveTrackedDay(trackedDay);
      }
    }

    // Clear today's cached expenditure state so it recomputes
    final expDataSource = locator<ExpenditureStateDataSource>();
    final allStates = await expDataSource.getAllStates();
    for (final s in allStates) {
      s.delete();
    }

    _log.info('Fake data generation complete: 30 days');
  }

  /// Box-Muller transform for normal distribution
  static double _gaussian() {
    final u1 = _random.nextDouble();
    final u2 = _random.nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  }

  /// Clears all generated test data
  static Future<void> clearAllData() async {
    final weightDataSource = locator<WeightEntryDataSource>();
    final trackedDayDataSource = locator<TrackedDayDataSource>();

    // Clear weight entries
    final entries = await weightDataSource.getAllEntries();
    for (final entry in entries) {
      await weightDataSource.deleteEntry(entry.day);
    }

    // Clear tracked days
    final days = await trackedDayDataSource.getAllTrackedDays();
    for (final day in days) {
      day.delete();
    }

    // Clear expenditure states
    final expDataSource = locator<ExpenditureStateDataSource>();
    final states = await expDataSource.getAllStates();
    for (final s in states) {
      s.delete();
    }

    _log.info('All data cleared');
  }
}
