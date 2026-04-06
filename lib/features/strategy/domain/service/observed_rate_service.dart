import 'package:flutter/material.dart';
import 'package:opennutritracker/features/strategy/domain/entity/weight_entry_entity.dart';
import 'package:opennutritracker/features/strategy/domain/service/trend_weight_service.dart';

class ObservedRateService {
  static const int defaultWindowDays = 7;

  static double? getObservedWeeklyKgChange(
    List<WeightEntryEntity> entries, {
    DateTime? endDate,
    int windowDays = defaultWindowDays,
  }) {
    if (entries.isEmpty) {
      return null;
    }

    final end = DateUtils.dateOnly(endDate ?? DateTime.now());
    final start = DateUtils.dateOnly(end.subtract(Duration(days: windowDays)));
    final latestTrend =
        TrendWeightService.getTrendWeightForDate(entries, end) ??
            TrendWeightService.getLatestTrendWeight(entries);
    final priorTrend = TrendWeightService.getTrendWeightForDate(entries, start);

    if (latestTrend == null || priorTrend == null) {
      return null;
    }

    return latestTrend - priorTrend;
  }

  static double? getObservedWeeklyPctChange(
    List<WeightEntryEntity> entries, {
    DateTime? endDate,
    int windowDays = defaultWindowDays,
  }) {
    final observedKg = getObservedWeeklyKgChange(
      entries,
      endDate: endDate,
      windowDays: windowDays,
    );
    final latestTrend = TrendWeightService.getLatestTrendWeight(entries);

    if (observedKg == null || latestTrend == null || latestTrend <= 0) {
      return null;
    }

    return observedKg * 100 / latestTrend;
  }
}
