import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/features/strategy/data/dbo/expenditure_state_dbo.dart';

class ExpenditureStateDataSource {
  final _log = Logger('ExpenditureStateDataSource');
  final Box<ExpenditureStateDBO> _box;

  ExpenditureStateDataSource(this._box);

  Future<void> saveState(ExpenditureStateDBO state) async {
    final key = _dayKey(state.day);
    _log.fine('Saving expenditure state for $key');
    await _box.put(key, state);
  }

  Future<ExpenditureStateDBO?> getState(DateTime day) async {
    return _box.get(_dayKey(day));
  }

  Future<ExpenditureStateDBO?> getLatestState() async {
    if (_box.isEmpty) return null;
    final entries = _box.values.toList()
      ..sort((a, b) => b.day.compareTo(a.day));
    return entries.first;
  }

  Future<List<ExpenditureStateDBO>> getAllStates() async {
    final entries = _box.values.toList()
      ..sort((a, b) => a.day.compareTo(b.day));
    return entries;
  }

  String _dayKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
}
