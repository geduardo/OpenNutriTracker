import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/pregnancy/pregnancy_model.dart';

void main() {
  test('onboarding accepts every day of weeks 0 through 42', () {
    final today = DateTime(2026, 9, 28);
    for (var age = 0; age <= PregnancyDating.maxGestationDays; age++) {
      final due = PregnancyDating.dueDateFromStage(
          onDate: today, weeks: age ~/ 7, days: age % 7);
      final pregnancy = PregnancyProfile(dueDate: due);
      expect(pregnancy.gestationDays(today), age);
      expect(PregnancyDating.supports(pregnancy, today), isTrue);
    }
    expect(
        () =>
            PregnancyDating.dueDateFromStage(onDate: today, weeks: 20, days: 7),
        throwsArgumentError);
    expect(
        () =>
            PregnancyDating.dueDateFromStage(onDate: today, weeks: -1, days: 0),
        throwsArgumentError);
    expect(
        () =>
            PregnancyDating.dueDateFromStage(onDate: today, weeks: 43, days: 0),
        throwsArgumentError);
  });

  PregnancyProfile profile(double bmi,
          {PregnancyType type = PregnancyType.singleton}) =>
      PregnancyProfile(
          dueDate: DateTime(2027, 2, 15),
          prePregnancyKg: bmi * 4,
          heightCm: 200,
          type: type);

  test('BMI boundaries select the correct published total-gain ranges', () {
    final cases = [
      (18.49, 12.5, 18.0),
      (18.5, 11.5, 16.0),
      (24.99, 11.5, 16.0),
      (25.0, 7.0, 11.5),
      (29.99, 7.0, 11.5),
      (30.0, 5.0, 9.0)
    ];
    for (final (bmi, low, high) in cases) {
      final range = PregnancyReference.totalGain(profile(bmi))!;
      expect(range.low, low);
      expect(range.high, high);
    }
  });

  test('published weekly rates use pre-pregnancy BMI', () {
    for (final (bmi, low, high) in [
      (18.0, .44, .58),
      (22.0, .35, .50),
      (27.0, .23, .33),
      (32.0, .17, .27)
    ]) {
      final rate = PregnancyReference.weeklyRate(profile(bmi))!;
      expect([rate.low, rate.high], [low, high]);
    }
  });

  test('multiples and unknown baselines never get singleton ranges', () {
    for (final type in [PregnancyType.twins, PregnancyType.higherOrder]) {
      expect(PregnancyReference.totalGain(profile(22, type: type)), isNull);
      expect(PregnancyReference.weeklyRate(profile(22, type: type)), isNull);
    }
    final unknown = PregnancyProfile(dueDate: DateTime(2027, 2, 15));
    expect(unknown.prePregnancyBmi, isNull);
    expect(PregnancyReference.totalGain(unknown), isNull);
  });

  test('gestation is calendar based across DST, leap years and date edits', () {
    final p = PregnancyProfile(dueDate: DateTime(2027, 2, 15));
    expect(p.gestationDays(p.dueDate), 280);
    expect(
        p.gestationDays(DateTime(2026, 10, 26, 23)) -
            p.gestationDays(DateTime(2026, 10, 25, 1)),
        1);
    final leap = PregnancyProfile(dueDate: DateTime(2024, 10, 1));
    expect(
        leap.gestationDays(DateTime(2024, 3, 1)) -
            leap.gestationDays(DateTime(2024, 2, 28)),
        2);
    final edited = PregnancyProfile(dueDate: DateTime(2027, 2, 22));
    expect(
        p.gestationDays(DateTime(2026, 10, 1)) -
            edited.gestationDays(DateTime(2026, 10, 1)),
        7);
  });

  test('saving a calendar day replaces its weight and preserves ordering', () {
    var data = PregnancyData(profile: profile(22));
    data = data.withWeight(WeightEntry(DateTime(2026, 9, 28, 18), 70));
    data = data.withWeight(WeightEntry(DateTime(2026, 9, 27), 69));
    data = data.withWeight(WeightEntry(DateTime(2026, 9, 28, 8), 71));
    expect(data.weights.map((entry) => entry.kg), [69, 71]);
    expect(data.profile!.prePregnancyBmi,
        22); // Current readings never reclassify BMI.
    final newProfile = PregnancyProfile(dueDate: DateTime(2027, 3, 1));
    expect(data.withProfile(newProfile).weights.length, 2);
  });

  test('persistent data round trips without inventing unknown measurements',
      () {
    final data = PregnancyData(
        profile: PregnancyProfile(dueDate: DateTime(2027, 2, 15)),
        weights: [WeightEntry(DateTime(2026, 9, 28), 62.4)]);
    final restored = PregnancyData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>);
    expect(restored.profile!.prePregnancyKg, isNull);
    expect(restored.profile!.heightCm, isNull);
    expect(restored.weights.single.kg, 62.4);
    expect(() => PregnancyData.fromJson({'schema': 2}), throwsFormatException);
  });

  test('non-finite measurements cannot enter saved data', () {
    for (final weight in [0.0, -10.0, double.nan, double.infinity]) {
      expect(() => WeightEntry(DateTime(2026, 9, 28), weight),
          throwsArgumentError);
      expect(
          () => PregnancyProfile(
              dueDate: DateTime(2027, 2, 15), prePregnancyKg: weight),
          throwsArgumentError);
    }
  });
}
