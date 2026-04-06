import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/data/data_source/local_food_data_source.dart';
import 'package:opennutritracker/core/data/data_source/meal_preset_data_source.dart';
import 'package:opennutritracker/core/data/dbo/local_food_record_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_preset_dbo.dart';
import 'package:opennutritracker/features/add_meal/presentation/presets_screen.dart';
import 'package:opennutritracker/core/utils/food_image_storage.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/add_meal/data/dto/ai/ai_nutrition_dto.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/magic_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class AiResultScreen extends StatefulWidget {
  const AiResultScreen({super.key});

  @override
  State<AiResultScreen> createState() => _AiResultScreenState();
}

class _AiResultScreenState extends State<AiResultScreen> {
  late AiNutritionResponseDTO _response;
  late AddMealType _mealType;
  late DateTime _day;
  late MagicMode _mode;
  late bool _selectionMode;
  late List<_EditableItem> _items;
  Uint8List? _imageBytes;
  String? _imageFilePath;
  String? _savedImagePath; // cached after first save to avoid double-saving
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    final args =
        ModalRoute.of(context)?.settings.arguments as AiResultScreenArguments;
    _response = args.response;
    _mealType = args.mealType;
    _day = args.day;
    _mode = args.mode;
    _selectionMode = args.selectionMode;
    _imageBytes = args.imageBytes;
    _imageFilePath = args.imageFilePath;

    _items = _response.items
        .map((item) => _EditableItem(
              name: item.name,
              weightG: item.estimatedWeightG,
              confidence: item.confidence,
              per100g: item.per100g,
            ))
        .toList();

    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final totalKcal = _items.fold<double>(
        0, (sum, item) => sum + item.per100g.energyKcal * item.weightG / 100);

    return Scaffold(
      appBar: AppBar(
        title:
            Text(_mode == MagicMode.singleItem ? 'Review item' : 'Review meal'),
      ),
      body: Column(
        children: [
          // Photo + total summary
          if (_imageBytes != null && _imageBytes!.isNotEmpty)
            SizedBox(
              height: 140,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_imageBytes!, fit: BoxFit.cover),
                  Container(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.7),
                  ),
                  Center(
                    child: Text(
                      '${totalKcal.toInt()} ${S.of(context).kcalLabel} total',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                '${totalKcal.toInt()} ${S.of(context).kcalLabel} total',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),

          // Items list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _items.length,
              itemBuilder: (context, index) => _buildItemCard(index),
            ),
          ),

          // Save button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveAll,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_isSaving
                    ? 'Saving...'
                    : _selectionMode
                        ? _mode == MagicMode.singleItem
                            ? 'Use item'
                            : 'Use items (${_items.length})'
                        : _mode == MagicMode.singleItem
                        ? 'Add item'
                        : 'Add all (${_items.length} items)'),
              ),
            ),
          ),
          if (!_selectionMode &&
              _mode == MagicMode.mealBreakdown &&
              _items.length > 1)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _saveAsPreset,
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Save as preset'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    final itemKcal = item.per100g.energyKcal * item.weightG / 100;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name and confidence
            Row(
              children: [
                Expanded(
                  child: Text(item.name,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                _confidenceBadge(item.confidence),
              ],
            ),
            const SizedBox(height: 8),

            // Editable weight
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: TextEditingController(
                        text: item.weightG.toInt().toString()),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      suffixText: 'g',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed != null) {
                        setState(() => _items[index].weightG = parsed);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Text('${itemKcal.toInt()} kcal',
                    style: Theme.of(context).textTheme.bodyLarge),
                const Spacer(),
                // Macros summary
                _macroChip('P', item.per100g.proteinG * item.weightG / 100),
                _macroChip(
                    'C', item.per100g.carbohydratesG * item.weightG / 100),
                _macroChip('F', item.per100g.fatG * item.weightG / 100),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _confidenceBadge(String confidence) {
    final color = switch (confidence) {
      'high' => Colors.green,
      'medium' => Colors.orange,
      _ => Colors.red,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(confidence,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Widget _macroChip(String label, double grams) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text('$label ${grams.toInt()}g',
          style: Theme.of(context).textTheme.bodySmall),
    );
  }

  Future<void> _saveAsPreset() async {
    // Use LLM-generated name, or fall back to joining item names
    final suggestedName =
        _response.mealName ?? _items.map((i) => i.name).join(' + ');

    // Check for duplicate names and append number if needed
    final dataSource = locator<MealPresetDataSource>();
    final existingPresets = await dataSource.getAllPresets();
    final existingNames = existingPresets.map((p) => p.name).toSet();
    var uniqueName = suggestedName;
    var counter = 2;
    while (existingNames.contains(uniqueName)) {
      uniqueName = '$suggestedName $counter';
      counter++;
    }

    if (!mounted) return;

    final nameController = TextEditingController(text: uniqueName);

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save & add as preset'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Preset name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Save & add'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty || !mounted) return;

    // Save photo to local storage if available
    final imagePath = await _savePhoto();

    // Build preset items from canonical food records.
    final presetItems = <MealPresetItemDBO>[];
    for (final item in _items) {
      final foodRecord = await _upsertLocalFood(_buildAiMeal(item));
      presetItems.add(
        MealPresetItemDBO(
          meal: foodRecord.meal,
          amount: item.weightG,
          unit: 'g',
          foodId: foodRecord.id,
        ),
      );
    }

    if (!mounted) return;

    // Save preset
    await saveAsPreset(context, name, presetItems, imagePath: imagePath);

    // Also log it now (same as _saveAll but with preset name as groupName)
    await _saveAllWithGroupName(name);
  }

  /// Save the photo to local storage. Returns the saved path, or reuses the
  /// cached path if already saved (avoids double-save when preset flow calls
  /// _saveAll internally).
  Future<String?> _savePhoto() async {
    if (_savedImagePath != null) return _savedImagePath;

    try {
      // Prefer bytes — we know they're valid because the preview renders them.
      if (_imageBytes != null && _imageBytes!.isNotEmpty) {
        _savedImagePath = await FoodImageStorage.saveImageBytes(_imageBytes!);
        debugPrint(
            'FoodImage: saved ${_imageBytes!.length} bytes → $_savedImagePath');
        return _savedImagePath;
      }
      // Fallback: copy from picker file path.
      if (_imageFilePath != null && _imageFilePath!.isNotEmpty) {
        _savedImagePath =
            await FoodImageStorage.saveImageFromPath(_imageFilePath!);
        debugPrint('FoodImage: copied $_imageFilePath → $_savedImagePath');
        return _savedImagePath;
      }
    } catch (e) {
      debugPrint('FoodImage: save failed: $e');
    }
    return null;
  }

  Future<void> _saveAllWithGroupName(String groupName) async {
    return _saveAll(overrideGroupName: groupName);
  }

  Future<void> _saveAll({String? overrideGroupName}) async {
    if (_selectionMode) {
      await _returnItemsForBuilder();
      return;
    }

    setState(() => _isSaving = true);

    try {
      final addIntakeUsecase = locator<AddIntakeUsecase>();
      final addTrackedDayUsecase = locator<AddTrackedDayUsecase>();
      final getKcalGoalUsecase = locator<GetKcalGoalUsecase>();
      final getMacroGoalUsecase = locator<GetMacroGoalUsecase>();

      // Save photo to local storage if available
      final imagePath = await _savePhoto();

      final intakeType = _mealType.getIntakeType();
      final groupId =
          _mode == MagicMode.mealBreakdown ? IdGenerator.getUniqueID() : null;
      final groupName = overrideGroupName ??
          (_mode == MagicMode.mealBreakdown && _items.length > 1
              ? _response.mealName ?? _items.map((i) => i.name).join(' + ')
              : null);

      // Ensure tracked day exists
      final hasTrackedDay = await addTrackedDayUsecase.hasTrackedDay(_day);
      if (!hasTrackedDay) {
        final totalKcalGoal = await getKcalGoalUsecase.getKcalGoal();
        final totalCarbsGoal =
            await getMacroGoalUsecase.getCarbsGoal(totalKcalGoal);
        final totalFatGoal =
            await getMacroGoalUsecase.getFatsGoal(totalKcalGoal);
        final totalProteinGoal =
            await getMacroGoalUsecase.getProteinsGoal(totalKcalGoal);
        await addTrackedDayUsecase.addNewTrackedDay(_day, totalKcalGoal,
            totalCarbsGoal, totalFatGoal, totalProteinGoal);
      }

      for (final item in _items) {
        // Only single-item saves get the photo on the item itself.
        // For breakdowns the photo belongs to the preset/group, not ingredients.
        final isSingleItem = _items.length == 1;
        final meal = _buildAiMeal(
          item,
          thumbnailImageUrl: isSingleItem ? imagePath : null,
          mainImageUrl: isSingleItem ? imagePath : null,
        );

        final intake = IntakeEntity(
          id: IdGenerator.getUniqueID(),
          unit: 'g',
          amount: item.weightG,
          type: intakeType,
          meal: meal,
          dateTime: _day,
          groupId: groupId,
          groupName: groupName,
        );

        await addIntakeUsecase.addIntake(intake);
        addTrackedDayUsecase.addDayCaloriesTracked(_day, intake.totalKcal);
        addTrackedDayUsecase.addDayMacrosTracked(_day,
            carbsTracked: intake.totalCarbsGram,
            fatTracked: intake.totalFatsGram,
            proteinTracked: intake.totalProteinsGram,
            sodiumTracked: intake.totalSodiumMg);

        // Save to local food DB so it appears in My Foods.
        // Strip the plate photo from individual ingredients — the photo
        // is of the whole meal, not this specific food.
        final mealForDb = _items.length > 1
            ? meal.copyWith(
                thumbnailImageUrl: null,
                mainImageUrl: null,
              )
            : meal;
        await _upsertLocalFood(mealForDb);
      }

      if (mounted) {
        // Refresh home page data then pop back
        locator<HomeBloc>().add(const LoadItemsEvent());
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  MealEntity _buildAiMeal(
    _EditableItem item, {
    String? thumbnailImageUrl,
    String? mainImageUrl,
  }) {
    final nutriments = MealNutrimentsEntity(
      energyKcal100: item.per100g.energyKcal,
      carbohydrates100: item.per100g.carbohydratesG,
      fat100: item.per100g.fatG,
      proteins100: item.per100g.proteinG,
      sugars100: item.per100g.sugarsG,
      saturatedFat100: item.per100g.saturatedFatG,
      fiber100: item.per100g.fiberG,
      sodiumMg100: item.per100g.sodiumMg,
    );

    return MealEntity(
      code: null,
      name: item.name,
      brands: null,
      url: null,
      thumbnailImageUrl: thumbnailImageUrl,
      mainImageUrl: mainImageUrl,
      mealQuantity: null,
      mealUnit: 'g',
      servingQuantity: null,
      servingUnit: null,
      servingSize: null,
      nutriments: nutriments,
      source: MealSourceEntity.ai,
    );
  }

  Future<LocalFoodRecordDBO> _upsertLocalFood(MealEntity meal) {
    return locator<LocalFoodDataSource>().saveFood(
      MealDBO.fromMealEntity(meal),
      existingFoodId: meal.localFoodId,
    );
  }

  Future<void> _returnItemsForBuilder() async {
    setState(() => _isSaving = true);
    try {
      final items = <MealPresetItemDBO>[];
      for (final item in _items) {
        final foodRecord = await _upsertLocalFood(_buildAiMeal(item));
        items.add(
          MealPresetItemDBO(
            meal: foodRecord.meal,
            amount: item.weightG,
            unit: 'g',
            foodId: foodRecord.id,
          ),
        );
      }

      if (mounted) {
        Navigator.of(context).pop(items);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _EditableItem {
  String name;
  double weightG;
  String confidence;
  AiNutrimentsPer100gDTO per100g;

  _EditableItem({
    required this.name,
    required this.weightG,
    required this.confidence,
    required this.per100g,
  });
}

class AiResultScreenArguments {
  final AiNutritionResponseDTO response;
  final AddMealType mealType;
  final DateTime day;
  final MagicMode mode;
  final Uint8List? imageBytes;
  final String? imageFilePath;
  final bool selectionMode;

  AiResultScreenArguments({
    required this.response,
    required this.mealType,
    required this.day,
    required this.mode,
    this.imageBytes,
    this.imageFilePath,
    this.selectionMode = false,
  });
}
