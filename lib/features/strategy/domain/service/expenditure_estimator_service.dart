import 'dart:math';

import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/features/strategy/data/dbo/day_log_quality_dbo.dart';
import 'package:opennutritracker/features/strategy/domain/entity/expenditure_state_entity.dart';
import 'package:opennutritracker/features/strategy/domain/entity/weight_entry_entity.dart';
import 'package:opennutritracker/features/strategy/domain/service/trend_weight_service.dart';

/// Estimates daily energy expenditure from intake data and weight trend.
///
/// Algorithm from adaptive-calorie-engine-plan.md:
/// - 21-day lookback window
/// - Energy balance: expenditure ~= intake - change_in_body_energy
/// - EMA smoothing on raw expenditure (14-day half-life)
/// - Confidence from nutrition coverage + weigh-in frequency
class ExpenditureEstimatorService {
  static const int windowDays = 21;
  static const int minValidNutritionDays = 14;
  static const int idealValidNutritionDays = 21;
  static const int minRecentWeighIns = 1;
  static const int idealRecentWeighIns = 3;
  static const double bodyEnergyPerKg = 7700.0;
  static const double expenditureHalfLifeDays = 14.0;

  static final double beta = 1 - exp(-ln2 / expenditureHalfLifeDays);

  static ExpenditureStateEntity estimate({
    required List<TrackedDayDBO> trackedDays,
    required List<WeightEntryEntity> weightEntries,
    ExpenditureStateEntity? previousEstimate,
    required double seedTdee,
    DateTime? today,
  }) {
    final currentDay = DateUtils.dateOnly(today ?? DateTime.now());
    final windowStart = DateUtils.dateOnly(
        DateTime(currentDay.year, currentDay.month, currentDay.day - windowDays));

    final validDays = trackedDays.where((trackedDay) {
      final day = DateUtils.dateOnly(trackedDay.day);
      final quality = trackedDay.logQuality ?? DayLogQualityDBO.unlogged;
      return !day.isBefore(windowStart) &&
          !day.isAfter(currentDay) &&
          (quality == DayLogQualityDBO.complete ||
              quality == DayLogQualityDBO.fasted);
    }).toList();

    final validNutritionDays = validDays.length;
    final recentWeighIns =
        TrendWeightService.recentWeighInCount(weightEntries, days: 7);

    if (validNutritionDays < minValidNutritionDays ||
        recentWeighIns < minRecentWeighIns) {
      final previousExpenditure =
          previousEstimate?.estimatedExpenditureKcal ?? seedTdee;
      final status = previousEstimate == null
          ? ExpenditureStatus.seeded
          : ExpenditureStatus.holding;

      return ExpenditureStateEntity(
        day: currentDay,
        estimatedExpenditureKcal: previousExpenditure,
        rawExpenditureKcal: previousExpenditure,
        confidence: _computeConfidence(validNutritionDays, recentWeighIns),
        status: status,
        validNutritionDays: validNutritionDays,
        recentWeighInCount: recentWeighIns,
      );
    }

    final avgIntakeKcal = validDays.fold<double>(
            0, (sum, trackedDay) => sum + trackedDay.caloriesTracked) /
        validNutritionDays;

    final trendSeries = TrendWeightService.computeTrendSeries(weightEntries,
        endDate: currentDay);
    final trendToday = trendSeries[currentDay];
    final trendWindowStart = trendSeries[windowStart];

    if (trendToday == null || trendWindowStart == null) {
      final previousExpenditure =
          previousEstimate?.estimatedExpenditureKcal ?? seedTdee;
      return ExpenditureStateEntity(
        day: currentDay,
        estimatedExpenditureKcal: previousExpenditure,
        rawExpenditureKcal: previousExpenditure,
        confidence: _computeConfidence(validNutritionDays, recentWeighIns),
        status: ExpenditureStatus.holding,
        validNutritionDays: validNutritionDays,
        recentWeighInCount: recentWeighIns,
      );
    }

    final deltaTrendKg = trendToday - trendWindowStart;
    final bodyEnergyPerDay = bodyEnergyPerKg * deltaTrendKg / windowDays;
    final rawExpenditure = avgIntakeKcal - bodyEnergyPerDay;

    final previousExpenditure =
        previousEstimate?.estimatedExpenditureKcal ?? seedTdee;
    final estimatedExpenditure =
        beta * rawExpenditure + (1 - beta) * previousExpenditure;

    return ExpenditureStateEntity(
      day: currentDay,
      estimatedExpenditureKcal: estimatedExpenditure,
      rawExpenditureKcal: rawExpenditure,
      confidence: _computeConfidence(validNutritionDays, recentWeighIns),
      status: ExpenditureStatus.updating,
      validNutritionDays: validNutritionDays,
      recentWeighInCount: recentWeighIns,
    );
  }

  static double _computeConfidence(
      int validNutritionDays, int recentWeighIns) {
    final nutritionConfidence =
        (validNutritionDays / idealValidNutritionDays).clamp(0.0, 1.0);
    final weightConfidence =
        (recentWeighIns / idealRecentWeighIns).clamp(0.0, 1.0);
    return 0.65 * nutritionConfidence + 0.35 * weightConfidence;
  }
}
