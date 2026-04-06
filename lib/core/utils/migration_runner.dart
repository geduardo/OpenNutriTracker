import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/data_source/tracked_day_data_source.dart';
import 'package:opennutritracker/core/data/data_source/user_data_source.dart';
import 'package:opennutritracker/features/strategy/data/dbo/day_log_quality_dbo.dart';
import 'package:opennutritracker/features/strategy/data/dbo/weight_entry_dbo.dart';
import 'package:opennutritracker/features/strategy/data/data_source/weight_entry_data_source.dart';

typedef Migration = Future<void> Function();

class MigrationRunner {
  static const int currentSchemaVersion = 2;

  final _log = Logger('MigrationRunner');
  final ConfigDataSource _configDataSource;
  final UserDataSource _userDataSource;
  final WeightEntryDataSource _weightEntryDataSource;
  final TrackedDayDataSource _trackedDayDataSource;

  MigrationRunner(
    this._configDataSource,
    this._userDataSource,
    this._weightEntryDataSource,
    this._trackedDayDataSource,
  );

  /// Returns ordered list of migrations. Index 0 = migration from v0→v1, etc.
  /// Add new migrations to the end of this list.
  List<Migration> get _migrations => [
        // v0 → v1: baseline, no-op
        () async {},

        // v1 → v2: seed weight history + default day quality
        _migrateV1toV2,
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
        _log.info('Seeding weight history from profile: ${user.weightKG} kg');
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
        day.save();
      }
    }
    _log.info('Migrated ${allDays.length} tracked days with log quality');
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
      if (v < _migrations.length) {
        _log.info('Running migration v$v → v${v + 1}');
        await _migrations[v]();
      }
    }

    await _configDataSource.setSchemaVersion(currentSchemaVersion);
    _log.info('Migrations complete. Schema now at v$currentSchemaVersion');
  }
}
