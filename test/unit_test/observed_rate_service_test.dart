import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/strategy/domain/entity/weight_entry_entity.dart';
import 'package:opennutritracker/features/strategy/domain/service/observed_rate_service.dart';

void main() {
  test('observed weekly change is near zero for stable trend weight', () {
    final entries = List.generate(
      14,
      (index) => WeightEntryEntity(
        day: DateTime(2026, 4, 1 + index),
        weightKg: 80,
        source: WeightEntrySource.manual,
      ),
    );

    final observed = ObservedRateService.getObservedWeeklyKgChange(
      entries,
      endDate: DateTime(2026, 4, 14),
    );

    expect(observed, isNotNull);
    expect(observed!, closeTo(0, 0.0001));
  });

  test('observed weekly change is negative for a downward trend', () {
    final entries = List.generate(
      14,
      (index) => WeightEntryEntity(
        day: DateTime(2026, 4, 1 + index),
        weightKg: 80 - index * 0.1,
        source: WeightEntrySource.manual,
      ),
    );

    final observed = ObservedRateService.getObservedWeeklyKgChange(
      entries,
      endDate: DateTime(2026, 4, 14),
    );

    expect(observed, isNotNull);
    expect(observed!, lessThan(0));
  });
}
