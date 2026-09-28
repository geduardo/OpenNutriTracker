import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/pregnancy/pregnancy_controller.dart';
import 'package:opennutritracker/pregnancy/pregnancy_model.dart';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/data_source/local_food_data_source.dart';
import 'package:opennutritracker/core/data/data_source/meal_preset_data_source.dart';
import 'package:opennutritracker/core/data/data_source/user_data_source.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/utils/food_image_storage.dart';
import 'package:opennutritracker/core/utils/migration_runner.dart';
import 'package:opennutritracker/features/settings/domain/entity/backup_bundle.dart';
import 'package:opennutritracker/features/settings/domain/service/backup_archive_parser.dart';
import 'package:opennutritracker/features/settings/domain/usecase/export_data_usecase.dart';
import 'package:opennutritracker/features/strategy/data/data_source/check_in_record_data_source.dart';
import 'package:opennutritracker/features/strategy/data/data_source/expenditure_state_data_source.dart';
import 'package:opennutritracker/features/strategy/data/data_source/goal_strategy_data_source.dart';
import 'package:opennutritracker/features/strategy/data/data_source/weight_entry_data_source.dart';

class ImportDataUsecase {
  static const _safetyBackupDir = 'backups';
  static const _safetyBackupsToKeep = 3;

  final log = Logger('ImportDataUsecase');

  final IntakeRepository _intakeRepository;
  final TrackedDayRepository _trackedDayRepository;
  final WeightEntryDataSource _weightEntryDataSource;
  final ExpenditureStateDataSource _expenditureStateDataSource;
  final GoalStrategyDataSource _goalStrategyDataSource;
  final CheckInRecordDataSource _checkInRecordDataSource;
  final ConfigDataSource _configDataSource;
  final UserDataSource _userDataSource;
  final LocalFoodDataSource _localFoodDataSource;
  final MealPresetDataSource _mealPresetDataSource;
  final ExportDataUsecase _exportDataUsecase;
  final MigrationRunner _migrationRunner;

  ImportDataUsecase(
    this._intakeRepository,
    this._trackedDayRepository,
    this._weightEntryDataSource,
    this._expenditureStateDataSource,
    this._goalStrategyDataSource,
    this._checkInRecordDataSource,
    this._configDataSource,
    this._userDataSource,
    this._localFoodDataSource,
    this._mealPresetDataSource,
    this._exportDataUsecase,
    this._migrationRunner,
  );

  /// Returns false if the user cancelled the file picker.
  Future<bool> importData() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = result?.files.single.path;
    if (path == null) {
      return false;
    }

    await importFromBytes(await File(path).readAsBytes());
    return true;
  }

  /// Validates the whole archive before changing anything, saves a safety
  /// backup of the current data, then replaces only the stores that the
  /// archive contains.
  Future<ParsedBackup> importFromBytes(List<int> zipBytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (e) {
      throw const InvalidBackupException('The file is not a zip archive');
    }

    // Dry run: throws before any image or record is written.
    BackupArchiveParser.parse(archive);

    final pregnancyFile = archive.findFile('PregnancyJournal.json');
    final pregnancy = pregnancyFile == null
        ? null
        : PregnancyData.fromJson(
            jsonDecode(utf8.decode(pregnancyFile.content as List<int>))
                as Map<String, dynamic>);
    await _writeSafetyBackup();

    final imagePathMap = await _restoreImages(archive);
    final backup =
        BackupArchiveParser.parse(archive, imagePathMap: imagePathMap);

    await _writeBackup(backup);
    if (pregnancy != null && locator.isRegistered<PregnancyController>()) {
      await locator<PregnancyController>().save(pregnancy);
    }
    // The restored config carries the schema version of the exporting app.
    await _migrationRunner.runMigrations();
    return backup;
  }

  Future<void> _writeBackup(ParsedBackup backup) async {
    if (backup.intakes != null) {
      await _intakeRepository.clearAll();
      await _intakeRepository.addAllIntakeDBOs(backup.intakes!);
    }
    if (backup.trackedDays != null) {
      await _trackedDayRepository.clearAll();
      await _trackedDayRepository.addAllTrackedDays(backup.trackedDays!);
    }
    if (backup.weightEntries != null) {
      await _weightEntryDataSource.clear();
      for (final entry in backup.weightEntries!) {
        await _weightEntryDataSource.addEntry(entry);
      }
    }
    if (backup.expenditureStates != null) {
      await _expenditureStateDataSource.clear();
      for (final state in backup.expenditureStates!) {
        await _expenditureStateDataSource.saveState(state);
      }
    }
    if (backup.hasGoalStrategyFile) {
      await _goalStrategyDataSource.clear();
      if (backup.goalStrategy != null) {
        await _goalStrategyDataSource.saveCurrentStrategy(backup.goalStrategy!);
      }
    }
    if (backup.checkInRecords != null) {
      await _checkInRecordDataSource.clear();
      for (final record in backup.checkInRecords!) {
        await _checkInRecordDataSource.saveRecord(record);
      }
    }
    if (backup.config != null) {
      await _configDataSource.addConfig(backup.config!);
    } else if (backup.isLegacyFormat) {
      // Legacy data predates every migration.
      await _configDataSource.setSchemaVersion(0);
    }
    if (backup.user != null) {
      await _userDataSource.saveUserData(backup.user!);
    }
    if (backup.localFoods != null) {
      await _localFoodDataSource.replaceAllRecords(backup.localFoods!);
    }
    if (backup.mealPresets != null) {
      await _mealPresetDataSource.replaceAllPresets(backup.mealPresets!);
    }
  }

  Future<void> _writeSafetyBackup() async {
    final bytes = await _exportDataUsecase.buildBackupZipBytes();
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_safetyBackupDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final timestamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final file = File('${dir.path}/pre-import-$timestamp.zip');
    await file.writeAsBytes(bytes, flush: true);
    log.info('Saved safety backup to ${file.path}');

    final previous = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('pre-import-'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final old in previous.skip(_safetyBackupsToKeep)) {
      await old.delete();
    }
  }

  Future<Map<String, String>> _restoreImages(Archive archive) async {
    final manifestFile = archive.findFile(BackupBundle.manifestFileName);
    if (manifestFile == null) {
      return {};
    }

    final decoded = jsonDecode(utf8.decode(manifestFile.content as List<int>));
    if (decoded is! Map) {
      return {};
    }

    final images = decoded['images'] as List<dynamic>? ?? const [];
    final restored = <String, String>{};

    for (final image in images.whereType<Map>()) {
      final originalPath = image['originalPath'] as String?;
      final archivePath = image['archivePath'] as String?;
      if (originalPath == null || archivePath == null) {
        continue;
      }
      final archiveFile = archive.findFile(archivePath);
      if (archiveFile == null) {
        continue;
      }
      final restoredPath = await FoodImageStorage.saveNamedImageBytes(
        archiveFile.content as List<int>,
        fileName: archivePath.split('/').last,
      );
      restored[originalPath] = restoredPath;
    }

    return restored;
  }
}
