import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/data_source/local_food_data_source.dart';
import 'package:opennutritracker/core/data/data_source/meal_preset_data_source.dart';
import 'package:opennutritracker/core/data/data_source/user_data_source.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/local_food_record_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_preset_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_gender_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_pal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_weight_goal_dbo.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:opennutritracker/core/utils/food_image_storage.dart';
import 'package:opennutritracker/features/settings/domain/entity/backup_bundle.dart';
import 'package:opennutritracker/features/strategy/data/data_source/check_in_record_data_source.dart';
import 'package:opennutritracker/features/strategy/data/data_source/expenditure_state_data_source.dart';
import 'package:opennutritracker/features/strategy/data/data_source/goal_strategy_data_source.dart';
import 'package:opennutritracker/features/strategy/data/data_source/weight_entry_data_source.dart';
import 'package:opennutritracker/features/strategy/data/dbo/check_in_record_dbo.dart';
import 'package:opennutritracker/features/strategy/data/dbo/expenditure_state_dbo.dart';
import 'package:opennutritracker/features/strategy/data/dbo/goal_strategy_dbo.dart';
import 'package:opennutritracker/features/strategy/data/dbo/weight_entry_dbo.dart';

class ImportDataUsecase {
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
  );

  Future<bool> importData() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);

    if (result == null || result.files.single.path == null) {
      throw Exception('No file selected');
    }

    final file = File(result.files.single.path!);
    final zipBytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(zipBytes);

    final imagePathMap = await _restoreImages(archive);

    await _clearExistingData();

    await _restoreIntakes(archive, imagePathMap);
    await _restoreTrackedDays(archive);
    await _restoreWeightEntries(archive);
    await _restoreExpenditureStates(archive);
    await _restoreGoalStrategy(archive);
    await _restoreCheckInRecords(archive);
    await _restoreConfig(archive);
    await _restoreUser(archive);
    await _restoreLocalFoods(archive, imagePathMap);
    await _restoreMealPresets(archive, imagePathMap);

    return true;
  }

  Future<void> _clearExistingData() async {
    await _intakeRepository.clearAll();
    await _trackedDayRepository.clearAll();
    await _weightEntryDataSource.clear();
    await _expenditureStateDataSource.clear();
    await _goalStrategyDataSource.clear();
    await _checkInRecordDataSource.clear();
    await _configDataSource.addConfig(ConfigDBO.empty());
    await _userDataSource.clear();
    await _localFoodDataSource.replaceAllRecords(const []);
    await _mealPresetDataSource.replaceAllPresets(const []);
  }

  Future<Map<String, String>> _restoreImages(Archive archive) async {
    final manifestFile = archive.findFile(BackupBundle.manifestFileName);
    if (manifestFile == null) {
      return {};
    }

    final decoded = _decodeJson(manifestFile);
    if (decoded is! Map) {
      return {};
    }

    final images = (decoded['images'] as List<dynamic>? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final restored = <String, String>{};

    for (final image in images) {
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

  Future<void> _restoreIntakes(
    Archive archive,
    Map<String, String> imagePathMap,
  ) async {
    final intakeFile = archive.findFile(BackupBundle.intakeFileName);
    if (intakeFile == null) {
      throw Exception('Intake file not found in the archive');
    }
    final intakeList = _decodeJsonList(intakeFile)
        .map((json) => _remapJsonImages(Map<String, dynamic>.from(json as Map), imagePathMap))
        .toList();
    final intakeDBOs =
        intakeList.map((json) => IntakeDBO.fromJson(json)).toList();
    await _intakeRepository.addAllIntakeDBOs(intakeDBOs);
  }

  Future<void> _restoreTrackedDays(Archive archive) async {
    final trackedDayFile = archive.findFile(BackupBundle.trackedDayFileName);
    if (trackedDayFile == null) {
      throw Exception('Tracked day file not found in the archive');
    }
    final trackedDayList = _decodeJsonList(trackedDayFile)
        .map((json) => Map<String, dynamic>.from(json as Map))
        .toList();
    final trackedDayDBOs =
        trackedDayList.map((json) => TrackedDayDBO.fromJson(json)).toList();
    await _trackedDayRepository.addAllTrackedDays(trackedDayDBOs);
  }

  Future<void> _restoreWeightEntries(Archive archive) async {
    final weightEntryFile = archive.findFile(BackupBundle.weightEntryFileName);
    if (weightEntryFile == null) {
      return;
    }
    final weightEntryList = _decodeJsonList(weightEntryFile)
        .map((json) => Map<String, dynamic>.from(json as Map))
        .toList();
    for (final json in weightEntryList) {
      await _weightEntryDataSource.addEntry(WeightEntryDBO.fromJson(json));
    }
  }

  Future<void> _restoreExpenditureStates(Archive archive) async {
    final expenditureStateFile =
        archive.findFile(BackupBundle.expenditureStateFileName);
    if (expenditureStateFile == null) {
      return;
    }
    final expenditureStateList = _decodeJsonList(expenditureStateFile)
        .map((json) => Map<String, dynamic>.from(json as Map))
        .toList();
    for (final json in expenditureStateList) {
      await _expenditureStateDataSource
          .saveState(ExpenditureStateDBO.fromJson(json));
    }
  }

  Future<void> _restoreGoalStrategy(Archive archive) async {
    final goalStrategyFile = archive.findFile(BackupBundle.goalStrategyFileName);
    if (goalStrategyFile == null) {
      return;
    }
    final decoded = _decodeJson(goalStrategyFile);
    if (decoded is Map) {
      await _goalStrategyDataSource
          .saveCurrentStrategy(GoalStrategyDBO.fromJson(
        Map<String, dynamic>.from(decoded),
      ));
    }
  }

  Future<void> _restoreCheckInRecords(Archive archive) async {
    final checkInRecordFile =
        archive.findFile(BackupBundle.checkInRecordFileName);
    if (checkInRecordFile == null) {
      return;
    }
    final checkInRecordList = _decodeJsonList(checkInRecordFile)
        .map((json) => Map<String, dynamic>.from(json as Map))
        .toList();
    for (final json in checkInRecordList) {
      await _checkInRecordDataSource
          .saveRecord(CheckInRecordDBO.fromJson(json));
    }
  }

  Future<void> _restoreConfig(Archive archive) async {
    final configFile = archive.findFile(BackupBundle.configFileName);
    if (configFile == null) {
      return;
    }
    final decoded = _decodeJson(configFile);
    if (decoded is Map<String, dynamic>) {
      await _configDataSource.addConfig(ConfigDBO.fromJson(decoded));
    }
  }

  Future<void> _restoreUser(Archive archive) async {
    final userFile = archive.findFile(BackupBundle.userFileName);
    if (userFile == null) {
      return;
    }
    final decoded = _decodeJson(userFile);
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    await _userDataSource.saveUserData(UserDBO(
      birthday: DateTime.parse(decoded['birthday'] as String),
      heightCM: (decoded['heightCM'] as num).toDouble(),
      weightKG: (decoded['weightKG'] as num).toDouble(),
      gender: UserGenderDBO.values.byName(decoded['gender'] as String),
      goal: UserWeightGoalDBO.values.byName(decoded['goal'] as String),
      pal: UserPALDBO.values.byName(decoded['pal'] as String),
    ));
  }

  Future<void> _restoreLocalFoods(
    Archive archive,
    Map<String, String> imagePathMap,
  ) async {
    final localFoodFile = archive.findFile(BackupBundle.localFoodFileName);
    if (localFoodFile == null) {
      return;
    }
    final localFoodList = _decodeJsonList(localFoodFile)
        .map((json) => _remapJsonImages(Map<String, dynamic>.from(json as Map), imagePathMap))
        .toList();
    final records = localFoodList
        .map(
          (json) => LocalFoodRecordDBO(
            id: json['id'] as String,
            meal: MealDBO.fromJson(Map<String, dynamic>.from(json['meal'] as Map)),
            aliases: (json['aliases'] as List<dynamic>).cast<String>(),
            createdAt: DateTime.parse(json['createdAt'] as String),
            updatedAt: DateTime.parse(json['updatedAt'] as String),
          ),
        )
        .toList();
    await _localFoodDataSource.replaceAllRecords(records);
  }

  Future<void> _restoreMealPresets(
    Archive archive,
    Map<String, String> imagePathMap,
  ) async {
    final mealPresetFile = archive.findFile(BackupBundle.mealPresetFileName);
    if (mealPresetFile == null) {
      return;
    }
    final presetList = _decodeJsonList(mealPresetFile)
        .map((json) => _remapJsonImages(Map<String, dynamic>.from(json as Map), imagePathMap))
        .toList();
    final presets = presetList
        .map(
          (json) => MealPresetDBO(
            id: json['id'] as String,
            name: json['name'] as String,
            imagePath: json['imagePath'] as String?,
            items: (json['items'] as List<dynamic>)
                .map(
                  (item) => MealPresetItemDBO(
                    meal: MealDBO.fromJson(
                      Map<String, dynamic>.from((item as Map)['meal'] as Map),
                    ),
                    amount: ((item)['amount'] as num).toDouble(),
                    unit: item['unit'] as String,
                    foodId: item['foodId'] as String?,
                  ),
                )
                .toList(),
          ),
        )
        .toList();
    await _mealPresetDataSource.replaceAllPresets(presets);
  }

  dynamic _decodeJson(ArchiveFile file) {
    return jsonDecode(utf8.decode(file.content as List<int>));
  }

  List<dynamic> _decodeJsonList(ArchiveFile file) {
    final decoded = _decodeJson(file);
    if (decoded is List<dynamic>) {
      return decoded;
    }
    return const [];
  }

  Map<String, dynamic> _remapJsonImages(
    Map<String, dynamic> json,
    Map<String, String> imagePathMap,
  ) {
    return _remapNode(json, imagePathMap) as Map<String, dynamic>;
  }

  dynamic _remapNode(dynamic node, Map<String, String> imagePathMap) {
    if (node is List) {
      return node.map((item) => _remapNode(item, imagePathMap)).toList();
    }
    if (node is Map) {
      return node.map(
        (key, value) => MapEntry(
          key,
          _isImageKey(key.toString()) && value is String
              ? imagePathMap[value] ?? value
              : _remapNode(value, imagePathMap),
        ),
      );
    }
    return node;
  }

  bool _isImageKey(String key) {
    return key == 'mainImageUrl' ||
        key == 'thumbnailImageUrl' ||
        key == 'imagePath';
  }
}
