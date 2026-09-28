import 'dart:convert';

import 'package:archive/archive.dart';
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
import 'package:opennutritracker/features/settings/domain/entity/backup_bundle.dart';
import 'package:opennutritracker/features/strategy/data/dbo/check_in_record_dbo.dart';
import 'package:opennutritracker/features/strategy/data/dbo/expenditure_state_dbo.dart';
import 'package:opennutritracker/features/strategy/data/dbo/goal_strategy_dbo.dart';
import 'package:opennutritracker/features/strategy/data/dbo/weight_entry_dbo.dart';

class InvalidBackupException implements Exception {
  final String message;

  const InvalidBackupException(this.message);

  @override
  String toString() => 'InvalidBackupException: $message';
}

/// Fully decoded backup. A `null` list means the archive does not contain
/// that file, so the matching local store must be left untouched.
class ParsedBackup {
  final bool isLegacyFormat;
  final List<IntakeDBO>? intakes;
  final List<TrackedDayDBO>? trackedDays;
  final List<WeightEntryDBO>? weightEntries;
  final List<ExpenditureStateDBO>? expenditureStates;
  final bool hasGoalStrategyFile;
  final GoalStrategyDBO? goalStrategy;
  final List<CheckInRecordDBO>? checkInRecords;
  final ConfigDBO? config;
  final UserDBO? user;
  final List<LocalFoodRecordDBO>? localFoods;
  final List<MealPresetDBO>? mealPresets;

  const ParsedBackup({
    required this.isLegacyFormat,
    this.intakes,
    this.trackedDays,
    this.weightEntries,
    this.expenditureStates,
    this.hasGoalStrategyFile = false,
    this.goalStrategy,
    this.checkInRecords,
    this.config,
    this.user,
    this.localFoods,
    this.mealPresets,
  });
}

class BackupArchiveParser {
  /// Decodes every file of [archive] into DBOs without touching storage.
  /// Throws [InvalidBackupException] if the archive is not a backup or any
  /// record cannot be decoded.
  static ParsedBackup parse(
    Archive archive, {
    Map<String, String> imagePathMap = const {},
  }) {
    final intakeFile = archive.findFile(BackupBundle.intakeFileName) ??
        archive.findFile(BackupBundle.legacyIntakeFileName);
    final trackedDayFile = archive.findFile(BackupBundle.trackedDayFileName) ??
        archive.findFile(BackupBundle.legacyTrackedDayFileName);

    if (intakeFile == null && trackedDayFile == null) {
      throw const InvalidBackupException(
          'The file is not an OpenNutriTracker backup');
    }

    final isLegacy = archive.findFile(BackupBundle.intakeFileName) == null &&
        archive.findFile(BackupBundle.trackedDayFileName) == null;

    return _guard(() {
      final goalStrategyFile =
          archive.findFile(BackupBundle.goalStrategyFileName);
      final goalStrategyJson =
          goalStrategyFile == null ? null : _decodeMap(goalStrategyFile);

      return ParsedBackup(
        isLegacyFormat: isLegacy,
        intakes: intakeFile == null
            ? null
            : _dedupeIntakes(_decodeMapList(intakeFile)
                .map((json) => IntakeDBO.fromJson(
                    remapImagePaths(json, imagePathMap)))
                .toList()),
        trackedDays: trackedDayFile == null
            ? null
            : _decodeMapList(trackedDayFile)
                .map(TrackedDayDBO.fromJson)
                .toList(),
        weightEntries: _optionalList(
            archive, BackupBundle.weightEntryFileName, WeightEntryDBO.fromJson),
        expenditureStates: _optionalList(archive,
            BackupBundle.expenditureStateFileName, ExpenditureStateDBO.fromJson),
        hasGoalStrategyFile: goalStrategyFile != null,
        goalStrategy: goalStrategyJson == null
            ? null
            : GoalStrategyDBO.fromJson(goalStrategyJson),
        checkInRecords: _optionalList(archive,
            BackupBundle.checkInRecordFileName, CheckInRecordDBO.fromJson),
        config: _optionalMap(archive, BackupBundle.configFileName,
            (json) => ConfigDBO.fromJson(json)),
        user: _optionalMap(archive, BackupBundle.userFileName, _userFromJson),
        localFoods: _optionalList(
          archive,
          BackupBundle.localFoodFileName,
          (json) => _localFoodFromJson(remapImagePaths(json, imagePathMap)),
        ),
        mealPresets: _optionalList(
          archive,
          BackupBundle.mealPresetFileName,
          (json) => _mealPresetFromJson(remapImagePaths(json, imagePathMap)),
        ),
      );
    });
  }

  /// Returns a copy of [json] where local image paths are replaced by the
  /// paths the images were restored to.
  static Map<String, dynamic> remapImagePaths(
    Map<String, dynamic> json,
    Map<String, String> imagePathMap,
  ) {
    return _remapMap(json, imagePathMap);
  }

  static bool isImageKey(String key) {
    return key == 'mainImageUrl' ||
        key == 'thumbnailImageUrl' ||
        key == 'imagePath';
  }

  static Map<String, dynamic> _remapMap(
    Map<dynamic, dynamic> map,
    Map<String, String> imagePathMap,
  ) {
    final result = <String, dynamic>{};
    for (final entry in map.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      result[key] = isImageKey(key) && value is String
          ? imagePathMap[value] ?? value
          : _remapValue(value, imagePathMap);
    }
    return result;
  }

  static dynamic _remapValue(dynamic value, Map<String, String> imagePathMap) {
    if (value is Map) return _remapMap(value, imagePathMap);
    if (value is List) {
      return value.map((item) => _remapValue(item, imagePathMap)).toList();
    }
    return value;
  }

  /// Older importers appended intakes without clearing, which could leave
  /// several records with the same id in a backup. Keep the last one.
  static List<IntakeDBO> _dedupeIntakes(List<IntakeDBO> intakes) {
    final byId = <String, IntakeDBO>{};
    for (final intake in intakes) {
      byId[intake.id] = intake;
    }
    return byId.values.toList();
  }

  static T _guard<T>(T Function() body) {
    try {
      return body();
    } on InvalidBackupException {
      rethrow;
    } catch (e) {
      throw InvalidBackupException('The backup contains invalid data ($e)');
    }
  }

  static dynamic _decode(ArchiveFile file) {
    return jsonDecode(utf8.decode(file.content as List<int>));
  }

  static List<Map<String, dynamic>> _decodeMapList(ArchiveFile file) {
    final decoded = _decode(file);
    if (decoded == null) return const [];
    if (decoded is! List) {
      throw InvalidBackupException('${file.name} is not a list');
    }
    return decoded
        .map((item) => _remapMap(item as Map, const {}))
        .toList();
  }

  static Map<String, dynamic>? _decodeMap(ArchiveFile file) {
    final decoded = _decode(file);
    if (decoded == null) return null;
    if (decoded is! Map) {
      throw InvalidBackupException('${file.name} is not an object');
    }
    return _remapMap(decoded, const {});
  }

  static List<T>? _optionalList<T>(
    Archive archive,
    String fileName,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final file = archive.findFile(fileName);
    if (file == null) return null;
    return _decodeMapList(file).map(fromJson).toList();
  }

  static T? _optionalMap<T>(
    Archive archive,
    String fileName,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final file = archive.findFile(fileName);
    if (file == null) return null;
    final json = _decodeMap(file);
    return json == null ? null : fromJson(json);
  }

  static UserDBO _userFromJson(Map<String, dynamic> json) {
    return UserDBO(
      birthday: DateTime.parse(json['birthday'] as String),
      heightCM: (json['heightCM'] as num).toDouble(),
      weightKG: (json['weightKG'] as num).toDouble(),
      gender: UserGenderDBO.values.byName(json['gender'] as String),
      goal: UserWeightGoalDBO.values.byName(json['goal'] as String),
      pal: UserPALDBO.values.byName(json['pal'] as String),
    );
  }

  static LocalFoodRecordDBO _localFoodFromJson(Map<String, dynamic> json) {
    return LocalFoodRecordDBO(
      id: json['id'] as String,
      meal: MealDBO.fromJson(json['meal'] as Map<String, dynamic>),
      aliases: (json['aliases'] as List<dynamic>).cast<String>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  static MealPresetDBO _mealPresetFromJson(Map<String, dynamic> json) {
    return MealPresetDBO(
      id: json['id'] as String,
      name: json['name'] as String,
      imagePath: json['imagePath'] as String?,
      items: (json['items'] as List<dynamic>).map((raw) {
        final item = raw as Map<String, dynamic>;
        return MealPresetItemDBO(
          meal: MealDBO.fromJson(item['meal'] as Map<String, dynamic>),
          amount: (item['amount'] as num).toDouble(),
          unit: item['unit'] as String,
          foodId: item['foodId'] as String?,
        );
      }).toList(),
    );
  }
}
