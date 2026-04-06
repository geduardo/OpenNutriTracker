import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/features/strategy/data/dbo/weight_entry_dbo.dart';

class WeightEntryDataSource {
  final _log = Logger('WeightEntryDataSource');
  final Box<WeightEntryDBO> _box;

  WeightEntryDataSource(this._box);

  Future<void> addEntry(WeightEntryDBO entry) async {
    final key = _dayKey(entry.day);
    _log.fine('Adding weight entry for $key: ${entry.weightKg} kg');
    await _box.put(key, entry);
  }

  Future<void> deleteEntry(DateTime day) async {
    await _box.delete(_dayKey(day));
  }

  Future<WeightEntryDBO?> getEntry(DateTime day) async {
    return _box.get(_dayKey(day));
  }

  Future<List<WeightEntryDBO>> getAllEntries() async {
    final entries = _box.values.toList();
    entries.sort((a, b) => a.day.compareTo(b.day));
    return entries;
  }

  Future<List<WeightEntryDBO>> getEntriesInRange(
      DateTime start, DateTime end) async {
    return _box.values
        .where((e) =>
            !e.day.isBefore(DateUtils.dateOnly(start)) &&
            !e.day.isAfter(DateUtils.dateOnly(end)))
        .toList()
      ..sort((a, b) => a.day.compareTo(b.day));
  }

  Future<WeightEntryDBO?> getLatestEntry() async {
    if (_box.isEmpty) return null;
    final entries = _box.values.toList();
    entries.sort((a, b) => b.day.compareTo(a.day));
    return entries.first;
  }

  Future<int> getEntryCount() async => _box.length;

  /// Key format: yyyy-MM-dd
  String _dayKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
}
