import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/features/strategy/data/dbo/day_log_quality_dbo.dart';

void main() {
  test('tracked day json preserves adaptive logging fields', () {
    final trackedDay = TrackedDayDBO(
      day: DateTime.utc(2026, 4, 6),
      calorieGoal: 2200,
      caloriesTracked: 1800,
      carbsGoal: 250,
      carbsTracked: 180,
      fatGoal: 70,
      fatTracked: 60,
      proteinGoal: 140,
      proteinTracked: 145,
      logQuality: DayLogQualityDBO.partial,
      manuallyMarked: true,
    );

    final roundTrip = TrackedDayDBO.fromJson(trackedDay.toJson());

    expect(roundTrip.logQuality, DayLogQualityDBO.partial);
    expect(roundTrip.manuallyMarked, isTrue);
  });
}
