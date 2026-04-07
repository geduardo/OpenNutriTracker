import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';

class IntakeDataSource {
  final log = Logger('IntakeDataSource');
  final Box<IntakeDBO> _intakeBox;

  IntakeDataSource(this._intakeBox);

  Future<void> addIntake(IntakeDBO intakeDBO) async {
    log.fine('Adding new intake item to db');
    _intakeBox.add(intakeDBO);
  }

  Future<void> addAllIntakes(List<IntakeDBO> intakeDBOList) async {
    log.fine('Adding new intake items to db');
    _intakeBox.addAll(intakeDBOList);
  }

  Future<void> deleteIntakeFromId(String intakeId) async {
    log.fine('Deleting intake item from db');
    _intakeBox.values
        .where((dbo) => dbo.id == intakeId)
        .toList()
        .forEach((element) {
      element.delete();
    });
  }

  Future<IntakeDBO?> updateIntake(String intakeId, Map<String, dynamic> fields) async {
    log.fine('Updating intake $intakeId with fields ${fields.toString()} in db');
    var intakeObject = _intakeBox.values.indexed
      .where((indexedDbo) => indexedDbo.$2.id == intakeId).firstOrNull;
    if(intakeObject == null) {
      log.fine('Cannot update intake $intakeId as it is non existent');
      return null;
    }
    intakeObject.$2.amount = fields['amount'] ?? intakeObject.$2.amount;
    intakeObject.$2.groupName = fields['groupName'] ?? intakeObject.$2.groupName;
    _intakeBox.putAt(intakeObject.$1, intakeObject.$2);
    return _intakeBox.getAt(intakeObject.$1);
  }

  Future<IntakeDBO?> getIntakeById(String intakeId) async {
    return _intakeBox.values.firstWhereOrNull(
            (intake) => intake.id == intakeId
    );
  }

  Future<List<IntakeDBO>> getAllIntakes() async {
    return _intakeBox.values.toList();
  }

  Future<void> clear() async {
    await _intakeBox.clear();
  }

  Future<List<IntakeDBO>> getAllIntakesByDate(
      IntakeTypeDBO intakeType, DateTime dateTime) async {
    return _intakeBox.values
        .where((intake) =>
            DateUtils.isSameDay(dateTime, intake.dateTime) &&
            intake.type == intakeType)
        .toList();
  }

  Future<List<IntakeDBO>> getRecentlyAddedIntake({int number = 100}) async {
    final intakeList = _intakeBox.values.toList();

    // Count frequency per food item and track the most recent intake for each
    final frequencyMap = <String, int>{};
    final latestIntakeMap = <String, IntakeDBO>{};

    for (final intake in intakeList) {
      final key = intake.meal.code ?? intake.meal.name ?? "";
      frequencyMap[key] = (frequencyMap[key] ?? 0) + 1;
      final existing = latestIntakeMap[key];
      if (existing == null ||
          intake.dateTime.isAfter(existing.dateTime)) {
        latestIntakeMap[key] = intake;
      }
    }

    // Sort by recency first so "Recently" really reflects the latest logs,
    // then use frequency as a tiebreaker for equally recent items.
    final sortedEntries = latestIntakeMap.entries.toList()
      ..sort((a, b) {
        final recencyCompare = b.value.dateTime.compareTo(a.value.dateTime);
        if (recencyCompare != 0) return recencyCompare;
        return frequencyMap[b.key]!.compareTo(frequencyMap[a.key]!);
      });

    return sortedEntries.take(number).map((e) => e.value).toList();
  }

  /// Returns the most recent intake for a food identified by code or name.
  Future<IntakeDBO?> getLastIntakeForMeal(String? code, String? name) async {
    final key = code ?? name;
    if (key == null || key.isEmpty) return null;

    IntakeDBO? latest;
    for (final intake in _intakeBox.values) {
      final intakeKey = intake.meal.code ?? intake.meal.name ?? "";
      if (intakeKey == key) {
        if (latest == null || intake.dateTime.isAfter(latest.dateTime)) {
          latest = intake;
        }
      }
    }
    return latest;
  }
}
