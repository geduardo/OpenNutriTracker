import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/data/data_source/tracked_day_data_source.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/core/utils/migration_runner.dart';
import 'package:opennutritracker/features/strategy/data/dbo/day_log_quality_dbo.dart';

const _dayBox = 'schema_v3_tracked_day_test';
const _intakeBox = 'schema_v3_intake_test';

TrackedDayDBO _day(DateTime day, {double kcal = 0, bool manual = false}) {
  return TrackedDayDBO(
    day: day,
    calorieGoal: 2000,
    caloriesTracked: kcal,
    logQuality: manual ? DayLogQualityDBO.fasted : DayLogQualityDBO.complete,
    manuallyMarked: manual,
  );
}

MealDBO _meal({MealSourceDBO source = MealSourceDBO.off, double? caffeine}) {
  return MealDBO(
    code: '9002490100070',
    name: 'Energy drink',
    brands: null,
    thumbnailImageUrl: null,
    mainImageUrl: null,
    url: null,
    mealQuantity: '250',
    mealUnit: 'ml',
    servingQuantity: null,
    servingUnit: null,
    servingSize: null,
    nutriments: MealNutrimentsDBO(
      energyKcal100: 45,
      carbohydrates100: 11,
      fat100: 0,
      proteins100: 0,
      sugars100: 11,
      saturatedFat100: 0,
      fiber100: 0,
      sodiumMg100: 40,
      caffeineMg100: caffeine,
    ),
    source: source,
  );
}

IntakeDBO _intake(String id) => IntakeDBO(
      id: id,
      unit: 'ml',
      amount: 250,
      type: IntakeTypeDBO.snack,
      meal: _meal(caffeine: 0.032),
      dateTime: DateTime(2026, 4, 8, 10),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    Hive.init('.');
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(IntakeDBOAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(MealDBOAdapter());
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(MealNutrimentsDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(9)) {
      Hive.registerAdapter(TrackedDayDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(13)) {
      Hive.registerAdapter(IntakeTypeDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(14)) {
      Hive.registerAdapter(MealSourceDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(21)) {
      Hive.registerAdapter(DayLogQualityDBOAdapter());
    }
  });

  tearDown(() async {
    if (Hive.isBoxOpen(_dayBox)) await Hive.box<TrackedDayDBO>(_dayBox).close();
    if (Hive.isBoxOpen(_intakeBox)) {
      await Hive.box<IntakeDBO>(_intakeBox).close();
    }
    await Hive.deleteBoxFromDisk(_dayBox);
    await Hive.deleteBoxFromDisk(_intakeBox);
  });

  test('day keys are ISO dates independent of the app language', () {
    expect(DateTime(2026, 9, 28, 23, 59).toParsedDay(), '2026-09-28');
    expect(DateTime(987, 1, 2).toParsedDay(), '0987-01-02');
  });

  test('re-keying moves legacy keys and merges duplicate dates', () async {
    final box = await Hive.openBox<TrackedDayDBO>(_dayBox);
    final dataSource = TrackedDayDataSource(box);

    // English and German keys for the same date, plus another day.
    await box.put('9/28/2026', _day(DateTime(2026, 9, 28), kcal: 1800));
    await box.put('28.9.2026', _day(DateTime(2026, 9, 28), kcal: 300));
    await box.put('9/27/2026',
        _day(DateTime(2026, 9, 27), kcal: 0, manual: true));

    final merged = await dataSource.rekeyByDay();

    expect(merged, 1);
    expect(box.keys, unorderedEquals(['2026-09-28', '2026-09-27']));
    expect(box.get('2026-09-28')!.caloriesTracked, 1800);
    expect(box.get('2026-09-27')!.manuallyMarked, isTrue);
    expect(box.get('2026-09-27')!.logQuality, DayLogQualityDBO.fasted);
    expect(await dataSource.getTrackedDay(DateTime(2026, 9, 28)), isNotNull);

    // Running it again changes nothing.
    expect(await dataSource.rekeyByDay(), 0);
    expect(box.length, 2);
  });

  test('duplicate intake ids are removed and OFF caffeine becomes mg',
      () async {
    final box = await Hive.openBox<IntakeDBO>(_intakeBox);
    final dataSource = IntakeDataSource(box);
    await box.addAll([_intake('a'), _intake('a'), _intake('b')]);

    expect(await dataSource.removeDuplicateIds(), 1);
    expect(box.values.map((i) => i.id), unorderedEquals(['a', 'b']));

    expect(await dataSource.updateMeals(MigrationRunner.offCaffeineToMg), 2);
    for (final intake in box.values) {
      expect(intake.meal.nutriments.caffeineMg100, closeTo(32, 1e-9));
      expect(intake.meal.nutriments.sodiumMg100, 40);
    }
  });

  test('caffeine conversion only touches Open Food Facts meals', () {
    expect(MigrationRunner.offCaffeineToMg(_meal(caffeine: null)), isNull);
    expect(MigrationRunner.offCaffeineToMg(
            _meal(source: MealSourceDBO.ai, caffeine: 80)),
        isNull);
    expect(MigrationRunner.offCaffeineToMg(
            _meal(source: MealSourceDBO.custom, caffeine: 80)),
        isNull);
    expect(
        MigrationRunner.offCaffeineToMg(_meal(caffeine: 0.05))!
            .nutriments
            .caffeineMg100,
        closeTo(50, 1e-9));
  });
}
