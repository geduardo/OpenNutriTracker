import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
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

  ExportDataUsecase(
    this._intakeRepository,
    this._trackedDayRepository,
    this._weightEntryDataSource,
    this._expenditureStateDataSource,
    this._goalStrategyDataSource,
    this._checkInRecordDataSource,
  );

  Future<bool> exportData(
    String exportZipFileName,
    String userIntakeJsonFileName,
    String trackedDayJsonFileName,
    String weightEntryJsonFileName,
    String expenditureStateJsonFileName,
    String goalStrategyJsonFileName,
    String checkInRecordJsonFileName,
  ) async {
    final fullIntake = await _intakeRepository.getAllIntakesDBO();
    final fullTrackedDay = await _trackedDayRepository.getAllTrackedDaysDBO();
    final fullWeightEntries = await _weightEntryDataSource.getAllEntries();
    final fullExpenditureStates =
        await _expenditureStateDataSource.getAllStates();
    final goalStrategy = await _goalStrategyDataSource.getCurrentStrategy();
    final fullCheckInRecords = await _checkInRecordDataSource.getAllRecords();

    final archive = Archive();
    _addJsonFile(
      archive,
      userIntakeJsonFileName,
      fullIntake.map((intake) => intake.toJson()).toList(),
    );
    _addJsonFile(
      archive,
      trackedDayJsonFileName,
      fullTrackedDay.map((trackedDay) => trackedDay.toJson()).toList(),
    );
    _addJsonFile(
      archive,
      weightEntryJsonFileName,
      fullWeightEntries.map((entry) => entry.toJson()).toList(),
    );
    _addJsonFile(
      archive,
      expenditureStateJsonFileName,
      fullExpenditureStates.map((state) => state.toJson()).toList(),
    );
    _addJsonFile(
      archive,
      goalStrategyJsonFileName,
      goalStrategy?.toJson(),
    );
    _addJsonFile(
      archive,
      checkInRecordJsonFileName,
      fullCheckInRecords.map((record) => record.toJson()).toList(),
    );

    final zipBytes = ZipEncoder().encode(archive);
    final result = await FilePicker.platform.saveFile(
      fileName: exportZipFileName,
      type: FileType.custom,
      allowedExtensions: ['zip'],
      bytes: Uint8List.fromList(zipBytes),
    );

    return result != null && result.isNotEmpty;
  }

  void _addJsonFile(Archive archive, String fileName, Object? content) {
    final jsonBytes = utf8.encode(jsonEncode(content));
    archive.addFile(ArchiveFile(fileName, jsonBytes.length, jsonBytes));
  }
}
