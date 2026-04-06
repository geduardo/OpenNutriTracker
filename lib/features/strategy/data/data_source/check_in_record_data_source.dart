import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/features/strategy/data/dbo/check_in_record_dbo.dart';

class CheckInRecordDataSource {
  final _log = Logger('CheckInRecordDataSource');
  final Box<CheckInRecordDBO> _box;

  CheckInRecordDataSource(this._box);

  Future<void> saveRecord(CheckInRecordDBO record) async {
    final key = _weekKey(record.weekStart);
    _log.fine('Saving check-in record for $key');
    await _box.put(key, record);
  }

  Future<CheckInRecordDBO?> getRecordForWeek(DateTime weekStart) async {
    return _box.get(_weekKey(weekStart));
  }

  Future<void> deleteRecordForWeek(DateTime weekStart) async {
    await _box.delete(_weekKey(weekStart));
  }

  Future<CheckInRecordDBO?> getLatestRecord() async {
    if (_box.isEmpty) return null;
    final records = _box.values.toList()
      ..sort((a, b) => b.weekStart.compareTo(a.weekStart));
    return records.first;
  }

  Future<List<CheckInRecordDBO>> getAllRecords() async {
    final records = _box.values.toList()
      ..sort((a, b) => a.weekStart.compareTo(b.weekStart));
    return records;
  }

  Future<void> clear() async {
    await _box.clear();
  }

  static DateTime startOfWeek(DateTime day) {
    final date = DateUtils.dateOnly(day);
    final daysFromMonday = date.weekday - DateTime.monday;
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }

  String _weekKey(DateTime weekStart) {
    final day = DateUtils.dateOnly(weekStart);
    return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  }
}
