import 'dart:math';

import 'package:flutter/material.dart';
import 'package:opennutritracker/features/strategy/domain/entity/weight_entry_entity.dart';

/// Computes a trend-weight series from raw weigh-ins using EMA smoothing.
///
/// Algorithm from adaptive-calorie-engine-plan.md:
/// 1. Build daily series from weigh-ins (interpolate gaps, carry forward up to 7 days)
/// 2. Run EMA with half-life of 7 days
class TrendWeightService {
  static const double halfLifeDays = 7.0;
  static const int maxCarryForwardDays = 7;

  /// EMA smoothing factor: alpha = 1 - exp(-ln(2) / halfLifeDays)
  static final double alpha = 1 - exp(-ln2 / halfLifeDays);

  /// Computes the daily trend weight series from raw weigh-ins.
  ///
  /// Returns a map of date → trend weight for each day from the first
  /// weigh-in through [endDate] (defaults to today).
  static Map<DateTime, double> computeTrendSeries(
    List<WeightEntryEntity> entries, {
    DateTime? endDate,
  }) {
    if (entries.isEmpty) return {};

    final sorted = List<WeightEntryEntity>.from(entries)
      ..sort((a, b) => a.day.compareTo(b.day));

    final end = DateUtils.dateOnly(endDate ?? DateTime.now());
    final start = DateUtils.dateOnly(sorted.first.day);

    // Step 1: Build raw daily scale-weight series with interpolation
    final scaleSeries = _buildScaleSeries(sorted, start, end);

    // Step 2: Run EMA
    final trendSeries = <DateTime, double>{};
    double? prevTrend;

    var day = start;
    while (!day.isAfter(end)) {
      final scale = scaleSeries[day];
      if (scale != null) {
        if (prevTrend == null) {
          prevTrend = scale;
        } else {
          prevTrend = alpha * scale + (1 - alpha) * prevTrend;
        }
        trendSeries[day] = prevTrend;
      }
      // DST-safe day increment
      day = DateUtils.dateOnly(DateTime(day.year, day.month, day.day + 1));
    }

    return trendSeries;
  }

  /// Gets the latest trend weight value.
  static double? getLatestTrendWeight(List<WeightEntryEntity> entries) {
    final series = computeTrendSeries(entries);
    if (series.isEmpty) return null;
    final latestDay = series.keys.reduce((a, b) => a.isAfter(b) ? a : b);
    return series[latestDay];
  }

  /// Gets trend weight for a specific date.
  static double? getTrendWeightForDate(
      List<WeightEntryEntity> entries, DateTime date) {
    final series = computeTrendSeries(entries, endDate: date);
    return series[DateUtils.dateOnly(date)];
  }

  /// Checks if the latest weigh-in is older than [maxCarryForwardDays].
  static bool isWeightDataStale(List<WeightEntryEntity> entries) {
    if (entries.isEmpty) return true;
    final sorted = List<WeightEntryEntity>.from(entries)
      ..sort((a, b) => b.day.compareTo(a.day));
    final latestDay = DateUtils.dateOnly(sorted.first.day);
    final today = DateUtils.dateOnly(DateTime.now());
    return today.difference(latestDay).inDays > maxCarryForwardDays;
  }

  /// Counts weigh-ins in the last [days] days.
  static int recentWeighInCount(List<WeightEntryEntity> entries,
      {int days = 7}) {
    final now = DateTime.now();
    final cutoff =
        DateUtils.dateOnly(DateTime(now.year, now.month, now.day - days));
    return entries
        .where((e) => !DateUtils.dateOnly(e.day).isBefore(cutoff))
        .length;
  }

  /// Builds daily scale-weight series with linear interpolation between
  /// weigh-ins and carry-forward for up to 7 days after the last weigh-in.
  static Map<DateTime, double> _buildScaleSeries(
    List<WeightEntryEntity> sorted,
    DateTime start,
    DateTime end,
  ) {
    // Index weigh-ins by date
    final weighIns = <DateTime, double>{};
    for (final e in sorted) {
      weighIns[DateUtils.dateOnly(e.day)] = e.weightKg;
    }

    final series = <DateTime, double>{};
    final weighInDates = weighIns.keys.toList()..sort();

    if (weighInDates.isEmpty) return series;

    var day = start;
    while (!day.isAfter(end)) {
      if (weighIns.containsKey(day)) {
        // Actual weigh-in
        series[day] = weighIns[day]!;
      } else {
        // Find surrounding weigh-ins for interpolation
        DateTime? prevWeighIn;
        DateTime? nextWeighIn;

        for (final d in weighInDates) {
          if (!d.isAfter(day)) prevWeighIn = d;
          if (d.isAfter(day) && nextWeighIn == null) nextWeighIn = d;
        }

        if (prevWeighIn != null && nextWeighIn != null) {
          // Linear interpolation
          final totalDays = nextWeighIn.difference(prevWeighIn).inDays;
          final elapsed = day.difference(prevWeighIn).inDays;
          final ratio = totalDays > 0 ? elapsed / totalDays : 0.0;
          series[day] = weighIns[prevWeighIn]! +
              ratio * (weighIns[nextWeighIn]! - weighIns[prevWeighIn]!);
        } else if (prevWeighIn != null) {
          // Carry forward (up to maxCarryForwardDays)
          final daysSinceLast = day.difference(prevWeighIn).inDays;
          if (daysSinceLast <= maxCarryForwardDays) {
            series[day] = weighIns[prevWeighIn]!;
          }
          // Beyond carry-forward: no entry (gap)
        }
        // Before first weigh-in: no entry
      }
      // DST-safe day increment
      day = DateUtils.dateOnly(DateTime(day.year, day.month, day.day + 1));
    }

    return series;
  }
}
