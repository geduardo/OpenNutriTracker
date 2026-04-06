import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/dbo/local_food_record_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/utils/food_identity.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';

/// Canonical local food catalog.
/// Foods are stored once by stable id, and lookup aliases point to those ids.
class LocalFoodDataSource {
  final log = Logger('LocalFoodDataSource');
  final Box<LocalFoodRecordDBO> _localFoodBox;
  final Box<String> _aliasBox;

  LocalFoodDataSource(this._localFoodBox, this._aliasBox);

  Future<LocalFoodRecordDBO> saveFood(
    MealDBO meal, {
    String? existingFoodId,
    List<String> lookupKeys = const [],
  }) async {
    final candidateAliases =
        FoodIdentity.candidateAliases(meal, lookupKeys: lookupKeys);
    final matchedFoodId =
        existingFoodId ?? await _findExistingFoodId(candidateAliases);
    final existingRecord =
        matchedFoodId == null ? null : await getFoodRecordById(matchedFoodId);
    final foodId = existingRecord?.id ?? IdGenerator.getUniqueID();
    final now = DateTime.now();
    final aliases = <String>{
      ...?existingRecord?.aliases,
      ...candidateAliases,
    }.toList()
      ..sort();

    log.fine(
      'Saving local food record: ${meal.name ?? meal.code ?? foodId} '
      '(foodId=$foodId, aliases=${aliases.length})',
    );

    final record = LocalFoodRecordDBO(
      id: foodId,
      meal: meal,
      aliases: aliases,
      createdAt: existingRecord?.createdAt ?? now,
      updatedAt: now,
    );

    await _localFoodBox.put(foodId, record);
    for (final alias in aliases) {
      await _aliasBox.put(alias, foodId);
    }
    return record;
  }

  Future<void> deleteFood(String foodId) async {
    final record = await getFoodRecordById(foodId);
    if (record == null) {
      return;
    }

    log.fine('Deleting local food record: $foodId');
    for (final alias in record.aliases) {
      final mappedFoodId = _aliasBox.get(alias);
      if (mappedFoodId == foodId) {
        await _aliasBox.delete(alias);
      }
    }
    await _localFoodBox.delete(foodId);
  }

  Future<MealDBO?> getFoodByKey(String key) async {
    return (await getFoodRecordByKey(key))?.meal;
  }

  Future<LocalFoodRecordDBO?> getFoodRecordByKey(String key) async {
    final foodId = _aliasBox.get(FoodIdentity.lookupAlias(key));
    if (foodId != null) {
      final record = _localFoodBox.get(foodId);
      if (record != null) {
        return record;
      }
      await _aliasBox.delete(FoodIdentity.lookupAlias(key));
    }

    final normalizedNameAlias = 'name:${FoodIdentity.normalizeText(key)}';
    final nameFoodId = _aliasBox.get(normalizedNameAlias);
    if (nameFoodId != null) {
      final record = _localFoodBox.get(nameFoodId);
      if (record != null) {
        return record;
      }
      await _aliasBox.delete(normalizedNameAlias);
    }

    return null;
  }

  Future<LocalFoodRecordDBO?> getFoodRecordById(String foodId) async {
    return _localFoodBox.get(foodId);
  }

  Future<List<LocalFoodRecordDBO>> searchByName(String query) async {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    final records = _localFoodBox.values
        .where((record) =>
            (record.meal.name ?? '').toLowerCase().contains(lowerQuery) ||
            (record.meal.brands ?? '').toLowerCase().contains(lowerQuery))
        .toList();
    records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return records;
  }

  Future<List<LocalFoodRecordDBO>> getAllFoodRecords() async {
    final records = _localFoodBox.values.toList();
    records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return records;
  }

  Future<List<MealDBO>> getAllLocalFoods() async {
    final records = await getAllFoodRecords();
    return records.map((record) => record.meal).toList(growable: false);
  }

  Future<String?> _findExistingFoodId(List<String> aliases) async {
    for (final alias in aliases) {
      final foodId = _aliasBox.get(alias);
      if (foodId != null && _localFoodBox.containsKey(foodId)) {
        return foodId;
      }
    }
    return null;
  }
}
