import 'dart:convert';

import 'package:flutter/material.dart' show DateUtils;
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/data/data_source/local_food_data_source.dart';
import 'package:opennutritracker/core/data/data_source/meal_preset_data_source.dart';
import 'package:opennutritracker/core/data/data_source/tracked_day_data_source.dart';
import 'package:opennutritracker/core/data/data_source/user_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/domain/usecase/reconcile_tracked_days_usecase.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/features/strategy/data/dbo/day_log_quality_dbo.dart';
import 'package:opennutritracker/features/strategy/data/dbo/weight_entry_dbo.dart';
import 'package:opennutritracker/features/strategy/data/data_source/weight_entry_data_source.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

typedef Migration = Future<void> Function();

/// Every migration must be safe to run more than once: the schema version
/// is only advanced after a step succeeds, and imports can lower it again.
class MigrationRunner {
  static const int currentSchemaVersion = 3;

  final _log = Logger('MigrationRunner');
  final ConfigDataSource _configDataSource;
  final UserDataSource _userDataSource;
  final WeightEntryDataSource _weightEntryDataSource;
  final TrackedDayDataSource _trackedDayDataSource;
  final IntakeDataSource _intakeDataSource;
  final LocalFoodDataSource _localFoodDataSource;
  final MealPresetDataSource _mealPresetDataSource;
  final ReconcileTrackedDaysUsecase _reconcileTrackedDaysUsecase;
  final HiveDBProvider _hiveDBProvider;

  MigrationRunner(
    this._configDataSource,
    this._userDataSource,
    this._weightEntryDataSource,
    this._trackedDayDataSource,
    this._intakeDataSource,
    this._localFoodDataSource,
    this._mealPresetDataSource,
    this._reconcileTrackedDaysUsecase,
    this._hiveDBProvider,
  );

  /// Returns ordered list of migrations. Index 0 = migration from v0→v1, etc.
  /// Add new migrations to the end of this list.
  List<Migration> get _migrations => [
        // v0 → v1: baseline, no-op
        () async {},

        // v1 → v2: seed weight history + default day quality
        _migrateV1toV2,

        // v2 → v3: stable day keys, caffeine units, duplicate cleanup
        _migrateV2toV3,
      ];

  /// Migration v1 → v2:
  /// - Create initial weight entry from UserEntity.weightKG
  /// - Default existing tracked days with calories to 'complete'
  Future<void> _migrateV1toV2() async {
    // Seed weight history from current profile weight
    final entryCount = await _weightEntryDataSource.getEntryCount();
    if (entryCount == 0) {
      final hasUser = await _userDataSource.hasUserData();
      if (hasUser) {
        final user = await _userDataSource.getUserData();
        _log.info('Seeding weight history from profile');
        await _weightEntryDataSource.addEntry(WeightEntryDBO(
          day: DateTime.now(),
          weightKg: user.weightKG,
          source: WeightEntrySourceDBO.migratedProfileWeight,
        ));
      }
    }

    // Default existing tracked days to 'complete' if they have calories
    final allDays = await _trackedDayDataSource.getAllTrackedDays();
    for (final day in allDays) {
      if (day.logQuality == null) {
        if (day.caloriesTracked > 0) {
          day.logQuality = DayLogQualityDBO.complete;
        } else {
          day.logQuality = DayLogQualityDBO.unlogged;
        }
        day.manuallyMarked = false;
        await day.save();
      }
    }
    _log.info('Migrated ${allDays.length} tracked days with log quality');
  }

  /// Migration v2 → v3:
  /// - Re-key tracked days to yyyy-MM-dd (old keys followed the app language)
  ///   and merge duplicates created by a language switch
  /// - Remove duplicate intake ids left by older importers
  /// - Open Food Facts caffeine was stored in grams; convert to mg
  /// - Move foods from the pre-7 Apr 2026 LocalFoodBox into the catalog
  /// - Recompute every day's totals from its intakes
  Future<void> _migrateV2toV3() async {
    final mergedDays = await _trackedDayDataSource.rekeyByDay();
    final removedIntakes = await _intakeDataSource.removeDuplicateIds();

    final intakesFixed = await _intakeDataSource.updateMeals(offCaffeineToMg);
    final foodsFixed = await _localFoodDataSource.updateMeals(offCaffeineToMg);
    final presetsFixed =
        await _mealPresetDataSource.updateMeals(offCaffeineToMg);

    final legacyFoods = await _hiveDBProvider.readLegacyLocalFoods();
    for (final food in legacyFoods) {
      await _localFoodDataSource.saveFood(offCaffeineToMg(food) ?? food);
    }
    await _hiveDBProvider.deleteLegacyLocalFoodBox();

    await _recomputeAllDayTotals();

    _log.info('v3: merged $mergedDays days, removed $removedIntakes duplicate '
        'intakes, fixed caffeine in $intakesFixed intakes / $foodsFixed foods '
        '/ $presetsFixed saved meals, moved ${legacyFoods.length} legacy foods');
  }

  Future<void> _recomputeAllDayTotals() async {
    final intakes = await _intakeDataSource.getAllIntakes();
    final days = await _trackedDayDataSource.getAllTrackedDays();
    final dates = [
      ...intakes.map((intake) => intake.dateTime),
      ...days.map((day) => day.day),
    ];
    if (dates.isEmpty) return;
    dates.sort();
    await _reconcileTrackedDaysUsecase.reconcileTrackedDaysByRange(
      DateUtils.dateOnly(dates.first),
      DateUtils.dateOnly(dates.last),
    );
  }

  /// Returns a copy of an Open Food Facts meal with caffeine converted from
  /// grams to mg, or null if nothing needs to change.
  static MealDBO? offCaffeineToMg(MealDBO meal) {
    final caffeine = meal.nutriments.caffeineMg100;
    if (meal.source != MealSourceDBO.off || caffeine == null || caffeine == 0) {
      return null;
    }
    final json = jsonDecode(jsonEncode(meal.toJson())) as Map<String, dynamic>;
    (json['nutriments'] as Map<String, dynamic>)['caffeineMg100'] =
        caffeine * 1000;
    return MealDBO.fromJson(json);
  }

  Future<void> runMigrations() async {
    final config = await _configDataSource.getConfig();
    final currentVersion = config.schemaVersion ?? 0;

    if (currentVersion >= currentSchemaVersion) {
      _log.fine('Schema up to date (v$currentVersion)');
      return;
    }

    _log.info(
        'Running migrations from v$currentVersion to v$currentSchemaVersion');

    for (int v = currentVersion; v < currentSchemaVersion; v++) {
      try {
        if (v < _migrations.length) {
          _log.info('Running migration v$v → v${v + 1}');
          await _migrations[v]();
        }
        await _configDataSource.setSchemaVersion(v + 1);
      } catch (e, stackTrace) {
        // Stop here and retry on the next launch; the app keeps working on
        // the data as it is.
        _log.severe('Migration v$v → v${v + 1} failed', e, stackTrace);
        await Sentry.captureException(e, stackTrace: stackTrace);
        return;
      }
    }

    _log.info('Migrations complete. Schema now at v$currentSchemaVersion');
  }
}
