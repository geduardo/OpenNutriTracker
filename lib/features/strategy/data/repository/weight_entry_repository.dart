import 'package:opennutritracker/features/strategy/data/data_source/weight_entry_data_source.dart';
import 'package:opennutritracker/features/strategy/domain/entity/weight_entry_entity.dart';

class WeightEntryRepository {
  final WeightEntryDataSource _dataSource;

  WeightEntryRepository(this._dataSource);

  Future<void> addEntry(WeightEntryEntity entry) async {
    await _dataSource.addEntry(entry.toDBO());
  }

  Future<void> deleteEntry(DateTime day) async {
    await _dataSource.deleteEntry(day);
  }

  Future<WeightEntryEntity?> getEntry(DateTime day) async {
    final dbo = await _dataSource.getEntry(day);
    return dbo == null ? null : WeightEntryEntity.fromDBO(dbo);
  }

  Future<List<WeightEntryEntity>> getAllEntries() async {
    final dbos = await _dataSource.getAllEntries();
    return dbos.map((d) => WeightEntryEntity.fromDBO(d)).toList();
  }

  Future<List<WeightEntryEntity>> getEntriesInRange(
      DateTime start, DateTime end) async {
    final dbos = await _dataSource.getEntriesInRange(start, end);
    return dbos.map((d) => WeightEntryEntity.fromDBO(d)).toList();
  }

  Future<WeightEntryEntity?> getLatestEntry() async {
    final dbo = await _dataSource.getLatestEntry();
    return dbo == null ? null : WeightEntryEntity.fromDBO(dbo);
  }

  Future<int> getEntryCount() async => _dataSource.getEntryCount();
}
