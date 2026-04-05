import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';

typedef Migration = Future<void> Function();

class MigrationRunner {
  static const int currentSchemaVersion = 1;

  final _log = Logger('MigrationRunner');
  final ConfigDataSource _configDataSource;

  MigrationRunner(this._configDataSource);

  /// Returns ordered list of migrations. Index 0 = migration from v0→v1, etc.
  /// Add new migrations to the end of this list.
  List<Migration> get _migrations => [
        // v0 → v1: baseline, no-op (existing data is already v1-compatible)
        () async {},
      ];

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
