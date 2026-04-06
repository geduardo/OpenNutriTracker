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
/// - Energy balance: expenditure ≈ intake - change_in_body_energy
/// - EMA smoothing on raw expenditure (14-day half-life)
/// - Confidence from nutrition coverage + weigh-in frequency
class ExpenditureEstimatorService {
  // Constants from the plan
  static const int windowDays = 21;
  static const int minValidNutritionDays = 14;
  static const int idealValidNutritionDays = 21;
  static const int minRecentWeighIns = 1;
  static const int idealRecentWeighIns = 3;
  static const double bodyEnergyPerKg = 7700.0; // kcal per kg body weight change
  static const double expenditureHalfLifeDays = 14.0;

  /// EMA smoothing factor for expenditure: beta = 1 - exp(-ln(2) / 14)
  static final double beta = 1 - exp(-ln2 / expenditureHalfLifeDays);

  /// Computes the current expenditure estimate.
  ///
  /// [trackedDays] — recent tracked days with calorie data and log quality
  /// [weightEntries] — weight history for trend calculation
  /// [previousEstimate] — prior expenditure state (for EMA continuity)
  /// [seedTdee] — startup TDEE from static calculation (used when seeded)
  static ExpenditureStateEntity estimate({
    required List<TrackedDayDBO> trackedDays,
    required List<WeightEntryEntity> weightEntries,
    ExpenditureStateEntity? previousEstimate,
    required double seedTdee,
  }) {
    final today = DateUtils.dateOnly(DateTime.now());
    final windowStart = DateUtils.dateOnly(
        DateTime(today.year, today.month, today.day - windowDays));

    // 1. Count valid intake days in the window
    final validDays = trackedDays.where((d) {
      final day = DateUtils.dateOnly(d.day);
      final quality = d.logQuality ?? DayLogQualityDBO.unlogged;
      return !day.isBefore(windowStart) &&
          !day.isAfter(today) &&
          (quality == DayLogQualityDBO.complete ||
              quality == DayLogQualityDBO.fasted);
    }).toList();

    final validNutritionDays = validDays.length;

    // 2. Count recent weigh-ins (last 7 days)
    final recentWeighIns =
        TrendWeightService.recentWeighInCount(weightEntries, days: 7);

    // 3. Check if we have enough data
    if (validNutritionDays < minValidNutritionDays ||
        recentWeighIns < minRecentWeighIns) {
      // Not enough data — hold or stay seeded
      final prevExp = previousEstimate?.estimatedExpenditureKcal ?? seedTdee;
      final status = previousEstimate != null
          ? ExpenditureStatus.holding
          : ExpenditureStatus.seeded;

      return ExpenditureStateEntity(
        day: today,
        estimatedExpenditureKcal: prevExp,
        rawExpenditureKcal: prevExp,
        confidence: _computeConfidence(validNutritionDays, recentWeighIns),
        status: status,
        validNutritionDays: validNutritionDays,
        recentWeighInCount: recentWeighIns,
      );
    }

    // 4. Compute average intake on valid days
    final avgIntakeKcal = validDays.fold<double>(
            0, (sum, d) => sum + d.caloriesTracked) /
        validNutritionDays;

    // 5. Compute trend weight change over window
    final trendSeries = TrendWeightService.computeTrendSeries(
        weightEntries,
        endDate: today);
    final trendToday = trendSeries[today];
    final trendWindowStart = trendSeries[windowStart];

    debugPrint('ExpEstimator: trendSeries=${trendSeries.length} entries, trendToday=$trendToday, trendWindowStart=$trendWindowStart');
    if (trendSeries.isNotEmpty) {
      final keys = trendSeries.keys.toList()..sort();
      debugPrint('ExpEstimator: range ${keys.first} to ${keys.last}');
      debugPrint('ExpEstimator: looking for today=$today windowStart=$windowStart');
    }

    if (trendToday == null || trendWindowStart == null) {
      // Can't compute delta — hold
      final prevExp = previousEstimate?.estimatedExpenditureKcal ?? seedTdee;
      return ExpenditureStateEntity(
        day: today,
        estimatedExpenditureKcal: prevExp,
        rawExpenditureKcal: prevExp,
        confidence: _computeConfidence(validNutritionDays, recentWeighIns),
        status: ExpenditureStatus.holding,
        validNutritionDays: validNutritionDays,
        recentWeighInCount: recentWeighIns,
      );
    }

    // 6. Energy balance calculation
    final deltaTrendKg = trendToday - trendWindowStart;
    final bodyEnergyPerDay = bodyEnergyPerKg * deltaTrendKg / windowDays;
    final rawExpenditure = avgIntakeKcal - bodyEnergyPerDay;

    // 7. EMA smooth the expenditure
    final prevEstimatedExp =
        previousEstimate?.estimatedExpenditureKcal ?? seedTdee;
    final estimatedExpenditure =
        beta * rawExpenditure + (1 - beta) * prevEstimatedExp;

    // 8. Confidence score
    final confidence =
        _computeConfidence(validNutritionDays, recentWeighIns);

    return ExpenditureStateEntity(
      day: today,
      estimatedExpenditureKcal: estimatedExpenditure,
      rawExpenditureKcal: rawExpenditure,
      confidence: confidence,
      status: ExpenditureStatus.updating,
      validNutritionDays: validNutritionDays,
      recentWeighInCount: recentWeighIns,
    );
  }

  /// Confidence = 0.65 * nutritionConfidence + 0.35 * weightConfidence
  static double _computeConfidence(
      int validNutritionDays, int recentWeighIns) {
    final nutritionConfidence =
        (validNutritionDays / idealValidNutritionDays).clamp(0.0, 1.0);
    final weightConfidence =
        (recentWeighIns / idealRecentWeighIns).clamp(0.0, 1.0);
    return 0.65 * nutritionConfidence + 0.35 * weightConfidence;
  }
}
