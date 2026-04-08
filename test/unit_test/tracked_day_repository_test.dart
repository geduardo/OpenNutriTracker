import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:opennutritracker/core/data/data_source/tracked_day_data_source.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/features/strategy/data/dbo/day_log_quality_dbo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    Hive.init('.');
    if (!Hive.isAdapterRegistered(9)) {
      Hive.registerAdapter(TrackedDayDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(21)) {
      Hive.registerAdapter(DayLogQualityDBOAdapter());
    }
  });

  tearDown(() async {
    if (Hive.isBoxOpen('tracked_day_test')) {
      await Hive.box<TrackedDayDBO>('tracked_day_test').close();
    }
    await Hive.deleteBoxFromDisk('tracked_day_test');
  });

  test('new tracked days start as unlogged until intake is written',
      () async {
    final box = await Hive.openBox<TrackedDayDBO>('tracked_day_test');
    final repo = TrackedDayRepository(TrackedDayDataSource(box));
    final day = DateTime.utc(2026, 4, 6);

    await repo.addNewTrackedDay(day, 2200, 250, 70, 140);

    final trackedDay = await repo.getAllTrackedDaysDBO();
    expect(trackedDay.single.logQuality, DayLogQualityDBO.unlogged);
    expect(trackedDay.single.manuallyMarked, isFalse);
  });

  test('updating legacy tracked days backfills missing quality to complete',
      () async {
    final box = await Hive.openBox<TrackedDayDBO>('tracked_day_test');
    final dataSource = TrackedDayDataSource(box);
    final repo = TrackedDayRepository(dataSource);
    final day = DateTime.utc(2026, 4, 5);

    await box.put(
      day.toParsedDay(),
      TrackedDayDBO(
        day: day,
        calorieGoal: 2200,
        caloriesTracked: 0,
        carbsGoal: 250,
        carbsTracked: 0,
        fatGoal: 70,
        fatTracked: 0,
        proteinGoal: 140,
        proteinTracked: 0,
      ),
    );

    await repo.addDayTrackedCalories(day, 600);

    final trackedDay = await dataSource.getTrackedDay(day);
    expect(trackedDay?.logQuality, DayLogQualityDBO.complete);
    expect(trackedDay?.manuallyMarked, isFalse);
  });

  test('manual fasted quality survives aggregate reconciliation', () async {
    final box = await Hive.openBox<TrackedDayDBO>('tracked_day_test');
    final dataSource = TrackedDayDataSource(box);
    final repo = TrackedDayRepository(dataSource);
    final day = DateTime.utc(2026, 4, 7);

    await box.put(
      day.toParsedDay(),
      TrackedDayDBO(
        day: day,
        calorieGoal: 2200,
        caloriesTracked: 0,
        carbsGoal: 250,
        carbsTracked: 0,
        fatGoal: 70,
        fatTracked: 0,
        proteinGoal: 140,
        proteinTracked: 0,
        logQuality: DayLogQualityDBO.fasted,
        manuallyMarked: true,
      ),
    );

    await repo.setDayAggregates(
      day,
      caloriesTracked: 0,
      carbsTracked: 0,
      fatTracked: 0,
      proteinTracked: 0,
      sodiumTracked: 0,
      caffeineTracked: 0,
    );

    final trackedDay = await dataSource.getTrackedDay(day);
    expect(trackedDay?.logQuality, DayLogQualityDBO.fasted);
    expect(trackedDay?.manuallyMarked, isTrue);
  });
}
