import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
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
}
