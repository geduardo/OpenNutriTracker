import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';

/// Local food overrides database.
/// Stores user-corrected or AI-extracted food items keyed by barcode or custom ID.
/// When a barcode is scanned, this is checked FIRST before hitting OFF/FDC.
class LocalFoodDataSource {
  final log = Logger('LocalFoodDataSource');
  final Box<MealDBO> _localFoodBox;

  LocalFoodDataSource(this._localFoodBox);

  Future<void> saveFood(String key, MealDBO meal) async {
    log.fine('Saving local food override: $key');
    await _localFoodBox.put(key, meal);
  }

  Future<void> deleteFood(String key) async {
    log.fine('Deleting local food override: $key');
    await _localFoodBox.delete(key);
  }

  /// Look up a food by barcode or custom key.
  Future<MealDBO?> getFoodByKey(String key) async {
    return _localFoodBox.get(key);
  }

  /// Search local foods by name (case-insensitive substring match).
  Future<List<MealDBO>> searchByName(String query) async {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return _localFoodBox.values
        .where((meal) =>
            (meal.name ?? '').toLowerCase().contains(lowerQuery) ||
            (meal.brands ?? '').toLowerCase().contains(lowerQuery))
        .toList();
  }

  Future<List<MealDBO>> getAllLocalFoods() async {
    return _localFoodBox.values.toList();
  }
}
