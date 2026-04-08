import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/data/data_source/tracked_day_data_source.dart';
import 'package:opennutritracker/core/data/repository/config_repository.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/domain/usecase/reconcile_tracked_days_usecase.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/strategy/data/dbo/day_log_quality_dbo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const intakeBoxName = 'reconcile_intake_test';
  const trackedDayBoxName = 'reconcile_tracked_day_test';

  setUpAll(() {
    Hive.init('.');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(IntakeDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(MealDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(MealNutrimentsDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(IntakeTypeDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(9)) {
      Hive.registerAdapter(TrackedDayDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(14)) {
      Hive.registerAdapter(MealSourceDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(21)) {
      Hive.registerAdapter(DayLogQualityDBOAdapter());
    }
  });

  tearDown(() async {
    if (Hive.isBoxOpen(intakeBoxName)) {
      await Hive.box<IntakeDBO>(intakeBoxName).close();
    }
    if (Hive.isBoxOpen(trackedDayBoxName)) {
      await Hive.box<TrackedDayDBO>(trackedDayBoxName).close();
    }
    await Hive.deleteBoxFromDisk(intakeBoxName);
    await Hive.deleteBoxFromDisk(trackedDayBoxName);
  });

  test('reconciliation repairs stale aggregates and backfills missing tracked days',
      () async {
    final intakeBox = await Hive.openBox<IntakeDBO>(intakeBoxName);
    final trackedDayBox = await Hive.openBox<TrackedDayDBO>(trackedDayBoxName);
    final intakeRepository = IntakeRepository(IntakeDataSource(intakeBox));
    final trackedDayRepository =
        TrackedDayRepository(TrackedDayDataSource(trackedDayBox));
    final reconcileUsecase = ReconcileTrackedDaysUsecase(
      intakeRepository,
      trackedDayRepository,
      _UnusedUserRepository(),
      _UnusedConfigRepository(),
    );

    final firstDay = DateTime.utc(2026, 4, 5);
    final secondDay = DateTime.utc(2026, 4, 6);
    final meal = MealEntity(
      code: 'meal-1',
      name: 'Test Meal',
      url: null,
      mealQuantity: null,
      mealUnit: 'g',
      servingQuantity: null,
      servingUnit: 'g',
      servingSize: '100 g',
      nutriments: const MealNutrimentsEntity(
        energyKcal100: 200,
        carbohydrates100: 20,
        fat100: 10,
        proteins100: 5,
        sugars100: 0,
        saturatedFat100: 0,
        fiber100: 0,
        sodiumMg100: 300,
        caffeineMg100: 80,
      ),
      source: MealSourceEntity.custom,
    );

    await trackedDayRepository.saveTrackedDay(TrackedDayEntity(
      day: DateTime.utc(2026, 4, 5),
      calorieGoal: 2200,
      caloriesTracked: 999,
      carbsGoal: 250,
      carbsTracked: 999,
      fatGoal: 70,
      fatTracked: 999,
      proteinGoal: 140,
      proteinTracked: 999,
      sodiumGoal: 2300,
      sodiumTracked: 999,
      caffeineGoal: 400,
      caffeineTracked: 999,
    ));

    await intakeRepository.addIntake(IntakeEntity(
      id: 'intake-1',
      unit: 'g',
      amount: 100,
      type: IntakeTypeEntity.breakfast,
      meal: meal,
      dateTime: firstDay,
    ));
    await intakeRepository.addIntake(IntakeEntity(
      id: 'intake-2',
      unit: 'g',
      amount: 150,
      type: IntakeTypeEntity.lunch,
      meal: meal,
      dateTime: secondDay,
    ));

    final correctedDays =
        await reconcileUsecase.reconcileTrackedDaysByRange(firstDay, secondDay);

    expect(correctedDays.length, 2);

    final repairedFirstDay =
        await trackedDayRepository.getTrackedDay(firstDay);
    final backfilledSecondDay =
        await trackedDayRepository.getTrackedDay(secondDay);
    final repairedFirstDayDbo = trackedDayBox.get(firstDay.toParsedDay());
    final backfilledSecondDayDbo = trackedDayBox.get(secondDay.toParsedDay());

    expect(repairedFirstDay?.caloriesTracked, 200);
    expect(repairedFirstDay?.carbsTracked, 20);
    expect(repairedFirstDay?.fatTracked, 10);
    expect(repairedFirstDay?.proteinTracked, 5);
    expect(repairedFirstDay?.sodiumTracked, 300);
    expect(repairedFirstDay?.caffeineTracked, 80);
    expect(repairedFirstDayDbo?.logQuality, DayLogQualityDBO.complete);

    expect(backfilledSecondDay, isNotNull);
    expect(backfilledSecondDay?.calorieGoal, 2200);
    expect(backfilledSecondDay?.carbsGoal, 250);
    expect(backfilledSecondDay?.fatGoal, 70);
    expect(backfilledSecondDay?.proteinGoal, 140);
    expect(backfilledSecondDay?.sodiumGoal, 2300);
    expect(backfilledSecondDay?.caffeineGoal, 400);
    expect(backfilledSecondDay?.caloriesTracked, 300);
    expect(backfilledSecondDay?.carbsTracked, 30);
    expect(backfilledSecondDay?.fatTracked, 15);
    expect(backfilledSecondDay?.proteinTracked, 7.5);
    expect(backfilledSecondDay?.sodiumTracked, 450);
    expect(backfilledSecondDay?.caffeineTracked, 120);
    expect(backfilledSecondDayDbo?.logQuality, DayLogQualityDBO.complete);
  });
}

class _UnusedUserRepository implements UserRepository {
  @override
  Future<bool> hasUserData() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedConfigRepository implements ConfigRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
