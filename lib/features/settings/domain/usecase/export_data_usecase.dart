import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/data_source/local_food_data_source.dart';
import 'package:opennutritracker/core/data/data_source/meal_preset_data_source.dart';
import 'package:opennutritracker/core/data/data_source/user_data_source.dart';
import 'package:opennutritracker/core/data/dbo/local_food_record_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_preset_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/utils/food_image_storage.dart';
import 'package:opennutritracker/features/settings/domain/entity/backup_bundle.dart';
import 'package:opennutritracker/features/strategy/data/data_source/check_in_record_data_source.dart';
import 'package:opennutritracker/features/strategy/data/data_source/expenditure_state_data_source.dart';
import 'package:opennutritracker/features/strategy/data/data_source/goal_strategy_data_source.dart';
import 'package:opennutritracker/features/strategy/data/data_source/weight_entry_data_source.dart';

class ExportDataUsecase {
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

  ExportDataUsecase(
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
  );

  Future<bool> exportData(String exportZipFileName) async {
    final fullIntake = await _intakeRepository.getAllIntakesDBO();
    final fullTrackedDay = await _trackedDayRepository.getAllTrackedDaysDBO();
    final fullWeightEntries = await _weightEntryDataSource.getAllEntries();
    final fullExpenditureStates =
        await _expenditureStateDataSource.getAllStates();
    final goalStrategy = await _goalStrategyDataSource.getCurrentStrategy();
    final fullCheckInRecords = await _checkInRecordDataSource.getAllRecords();
    final config = await _configDataSource.getConfig();
    final user = await _userDataSource.hasUserData()
        ? await _userDataSource.getUserData()
        : null;
    final localFoods = await _localFoodDataSource.getAllFoodRecords();
    final mealPresets = await _mealPresetDataSource.getAllPresets();

    final payloads = <String, Object?>{
      BackupBundle.intakeFileName:
          fullIntake.map((intake) => intake.toJson()).toList(),
      BackupBundle.trackedDayFileName:
          fullTrackedDay.map((trackedDay) => trackedDay.toJson()).toList(),
      BackupBundle.weightEntryFileName:
          fullWeightEntries.map((entry) => entry.toJson()).toList(),
      BackupBundle.expenditureStateFileName:
          fullExpenditureStates.map((state) => state.toJson()).toList(),
      BackupBundle.goalStrategyFileName: goalStrategy?.toJson(),
      BackupBundle.checkInRecordFileName:
          fullCheckInRecords.map((record) => record.toJson()).toList(),
      BackupBundle.configFileName: config.toJson(),
      BackupBundle.userFileName: user == null ? null : _userToJson(user),
      BackupBundle.localFoodFileName:
          localFoods.map(_localFoodRecordToJson).toList(),
      BackupBundle.mealPresetFileName:
          mealPresets.map(_mealPresetToJson).toList(),
    };

    final manifest = _buildManifest(payloads);
    final archive = Archive();
    for (final entry in payloads.entries) {
      _addJsonFile(archive, entry.key, entry.value);
    }
    _addJsonFile(archive, BackupBundle.manifestFileName, manifest);
    await _addMediaFiles(archive, manifest);

    final zipBytes = ZipEncoder().encode(archive);
    final result = await FilePicker.platform.saveFile(
      fileName: exportZipFileName,
      type: FileType.custom,
      allowedExtensions: ['zip'],
      bytes: Uint8List.fromList(zipBytes),
    );

    return result != null && result.isNotEmpty;
  }

  Map<String, dynamic> _buildManifest(Map<String, Object?> payloads) {
    final imageMap = <String, String>{};
    for (final payload in payloads.values) {
      _collectImagePaths(payload, imageMap);
    }

    return {
      'version': BackupBundle.version,
      'exportedAt': DateTime.now().toIso8601String(),
      'images': imageMap.entries
          .map((entry) => {
                'originalPath': entry.key,
                'archivePath': entry.value,
              })
          .toList(),
    };
  }

  void _collectImagePaths(Object? node, Map<String, String> imageMap) {
    if (node is List) {
      for (final item in node) {
        _collectImagePaths(item, imageMap);
      }
      return;
    }
    if (node is Map) {
      for (final entry in node.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (_isImageKey(key) &&
            value is String &&
            value.isNotEmpty &&
            FoodImageStorage.isLocalPath(value)) {
          imageMap.putIfAbsent(
            value,
            () => '${BackupBundle.mediaDirectory}/${p.basename(value)}',
          );
        }
        _collectImagePaths(value, imageMap);
      }
    }
  }

  Future<void> _addMediaFiles(
    Archive archive,
    Map<String, dynamic> manifest,
  ) async {
    final images = (manifest['images'] as List<dynamic>? ?? const [])
        .map((image) => Map<String, dynamic>.from(image as Map))
        .toList();

    for (final image in images) {
      final originalPath = image['originalPath'] as String?;
      final archivePath = image['archivePath'] as String?;
      if (originalPath == null || archivePath == null) {
        continue;
      }
      final file = File(originalPath);
      if (!file.existsSync()) {
        continue;
      }
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
    }
  }

  bool _isImageKey(String key) {
    return key == 'mainImageUrl' ||
        key == 'thumbnailImageUrl' ||
        key == 'imagePath';
  }

  Map<String, dynamic> _userToJson(UserDBO user) {
    return {
      'birthday': user.birthday.toIso8601String(),
      'heightCM': user.heightCM,
      'weightKG': user.weightKG,
      'gender': user.gender.name,
      'goal': user.goal.name,
      'pal': user.pal.name,
    };
  }

  Map<String, dynamic> _localFoodRecordToJson(LocalFoodRecordDBO record) {
    return {
      'id': record.id,
      'meal': record.meal.toJson(),
      'aliases': record.aliases,
      'createdAt': record.createdAt.toIso8601String(),
      'updatedAt': record.updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _mealPresetToJson(MealPresetDBO preset) {
    return {
      'id': preset.id,
      'name': preset.name,
      'imagePath': preset.imagePath,
      'items': preset.items
          .map((item) => {
                'meal': item.meal.toJson(),
                'amount': item.amount,
                'unit': item.unit,
                'foodId': item.foodId,
              })
          .toList(),
    };
  }

  void _addJsonFile(Archive archive, String fileName, Object? content) {
    final jsonBytes = utf8.encode(jsonEncode(content));
    archive.addFile(ArchiveFile(fileName, jsonBytes.length, jsonBytes));
  }
}
