import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_preset_dbo.dart';

class MealPresetDataSource {
  final log = Logger('MealPresetDataSource');
  final Box<MealPresetDBO> _presetBox;

  MealPresetDataSource(this._presetBox);

  Future<void> addPreset(MealPresetDBO preset) async {
    log.fine('Adding meal preset: ${preset.name}');
    await _presetBox.put(preset.id, preset);
  }

  Future<void> deletePreset(String presetId) async {
    log.fine('Deleting meal preset: $presetId');
    await _presetBox.delete(presetId);
  }

  Future<void> updatePreset(MealPresetDBO preset) async {
    log.fine('Updating meal preset: ${preset.name}');
    await _presetBox.put(preset.id, preset);
  }

  Future<List<MealPresetDBO>> getAllPresets() async {
    return _presetBox.values.toList();
  }

  Future<MealPresetDBO?> getPresetById(String presetId) async {
    return _presetBox.get(presetId);
  }

  Future<void> replaceAllPresets(List<MealPresetDBO> presets) async {
    await _presetBox.clear();
    for (final preset in presets) {
      await _presetBox.put(preset.id, preset);
    }
  }

  /// Replaces the meal of every preset item for which [transform] returns a
  /// new meal. Returns the number of updated presets.
  Future<int> updateMeals(MealDBO? Function(MealDBO meal) transform) async {
    var updated = 0;
    for (final preset in _presetBox.values.toList()) {
      var changed = false;
      final items = preset.items.map((item) {
        final newMeal = transform(item.meal);
        if (newMeal == null) return item;
        changed = true;
        return MealPresetItemDBO(
          meal: newMeal,
          amount: item.amount,
          unit: item.unit,
          foodId: item.foodId,
        );
      }).toList();
      if (!changed) continue;
      await updatePreset(MealPresetDBO(
        id: preset.id,
        name: preset.name,
        items: items,
        imagePath: preset.imagePath,
      ));
      updated++;
    }
    return updated;
  }

  Future<void> syncFoodSnapshot(String foodId, MealDBO updatedMeal) async {
    final presets = _presetBox.values.toList();
    for (final preset in presets) {
      var changed = false;
      final updatedItems = preset.items.map((item) {
        if (item.foodId != foodId) {
          return item;
        }
        changed = true;
        return MealPresetItemDBO(
          meal: updatedMeal,
          amount: item.amount,
          unit: item.unit,
          foodId: item.foodId,
        );
      }).toList();

      if (changed) {
        await updatePreset(
          MealPresetDBO(
            id: preset.id,
            name: preset.name,
            items: updatedItems,
            imagePath: preset.imagePath,
          ),
        );
      }
    }
  }
}
