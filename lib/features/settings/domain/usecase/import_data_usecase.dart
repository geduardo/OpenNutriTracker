import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
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

  ImportDataUsecase(
    this._intakeRepository,
    this._trackedDayRepository,
    this._weightEntryDataSource,
    this._expenditureStateDataSource,
    this._goalStrategyDataSource,
    this._checkInRecordDataSource,
  );

  Future<bool> importData(
    String userIntakeJsonFileName,
    String trackedDayJsonFileName,
    String weightEntryJsonFileName,
    String expenditureStateJsonFileName,
    String goalStrategyJsonFileName,
    String checkInRecordJsonFileName,
  ) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);

    if (result == null || result.files.single.path == null) {
      throw Exception('No file selected');
    }

    final file = File(result.files.single.path!);
    final zipBytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(zipBytes);

    final intakeFile = archive.findFile(userIntakeJsonFileName);
    if (intakeFile == null) {
      throw Exception('Intake file not found in the archive');
    }
    final intakeList = _decodeJsonList(intakeFile)
        .map((json) => Map<String, dynamic>.from(json as Map))
        .toList();
    final intakeDBOs =
        intakeList.map((json) => IntakeDBO.fromJson(json)).toList();
    await _intakeRepository.addAllIntakeDBOs(intakeDBOs);

    final trackedDayFile = archive.findFile(trackedDayJsonFileName);
    if (trackedDayFile == null) {
      throw Exception('Tracked day file not found in the archive');
    }
    final trackedDayList = _decodeJsonList(trackedDayFile)
        .map((json) => Map<String, dynamic>.from(json as Map))
        .toList();
    final trackedDayDBOs =
        trackedDayList.map((json) => TrackedDayDBO.fromJson(json)).toList();
    await _trackedDayRepository.addAllTrackedDays(trackedDayDBOs);

    final weightEntryFile = archive.findFile(weightEntryJsonFileName);
    if (weightEntryFile != null) {
      final weightEntryList = _decodeJsonList(weightEntryFile)
          .map((json) => Map<String, dynamic>.from(json as Map))
          .toList();
      for (final json in weightEntryList) {
        await _weightEntryDataSource.addEntry(WeightEntryDBO.fromJson(json));
      }
    }

    final expenditureStateFile = archive.findFile(expenditureStateJsonFileName);
    if (expenditureStateFile != null) {
      final expenditureStateList = _decodeJsonList(expenditureStateFile)
          .map((json) => Map<String, dynamic>.from(json as Map))
          .toList();
      for (final json in expenditureStateList) {
        await _expenditureStateDataSource
            .saveState(ExpenditureStateDBO.fromJson(json));
      }
    }

    final goalStrategyFile = archive.findFile(goalStrategyJsonFileName);
    if (goalStrategyFile != null) {
      final decoded = _decodeJson(goalStrategyFile);
      if (decoded is Map) {
        await _goalStrategyDataSource
            .saveCurrentStrategy(GoalStrategyDBO.fromJson(
          Map<String, dynamic>.from(decoded),
        ));
      }
    }

    final checkInRecordFile = archive.findFile(checkInRecordJsonFileName);
    if (checkInRecordFile != null) {
      final checkInRecordList = _decodeJsonList(checkInRecordFile)
          .map((json) => Map<String, dynamic>.from(json as Map))
          .toList();
      for (final json in checkInRecordList) {
        await _checkInRecordDataSource
            .saveRecord(CheckInRecordDBO.fromJson(json));
      }
    }

    return true;
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
}
