import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:opennutritracker/core/presentation/widgets/food_image.dart';
import 'package:opennutritracker/core/presentation/widgets/image_edit_action_sheet.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/data/data_source/local_food_data_source.dart';
import 'package:opennutritracker/core/data/data_source/meal_preset_data_source.dart';
import 'package:opennutritracker/core/data/dbo/local_food_record_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_preset_dbo.dart';
import 'package:opennutritracker/core/utils/food_image_storage.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/meal_portion_helper.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/food_library/food_detail_page.dart';
import 'package:opennutritracker/features/settings/domain/entity/ai_settings_entity.dart';
import 'package:opennutritracker/features/settings/domain/service/ai_settings_service.dart';
import 'package:opennutritracker/generated/l10n.dart';

class PresetDetailPage extends StatefulWidget {
  final MealPresetDBO preset;

  const PresetDetailPage({super.key, required this.preset});

  @override
  State<PresetDetailPage> createState() => _PresetDetailPageState();
}

class _PresetDetailPageState extends State<PresetDetailPage> {
  late MealPresetDBO _preset;
  late TextEditingController _nameController;
  late final ImagePicker _imagePicker;

  @override
  void initState() {
    super.initState();
    _preset = widget.preset;
    _nameController = TextEditingController(text: _preset.name);
    _imagePicker = ImagePicker();
  }

  double get _totalKcal => _preset.items.fold<double>(0, (sum, item) {
        final meal = MealEntity.fromMealDBO(item.meal);
        return sum + (item.amount * (meal.nutriments.energyPerUnit ?? 0));
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit saved meal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deletePreset,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildImageEditor(),
          const SizedBox(height: 16),

          // Name field
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Meal name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _saveName(),
          ),
          const SizedBox(height: 8),
          Text(
              '${_foodCountLabel(_preset.items.length)} · ${_totalKcal.toInt()} ${S.of(context).kcalLabel}',
              style: Theme.of(context).textTheme.bodyMedium),
          const Divider(height: 24),

          // Items
          ...List.generate(_preset.items.length, (index) {
            final item = _preset.items[index];
            final meal = MealEntity.fromMealDBO(item.meal);
            final itemKcal = item.amount * (meal.nutriments.energyPerUnit ?? 0);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(meal.name ?? '?'),
                subtitle: Text(
                    '${MealPortionHelper.formatStoredAmount(meal, item.amount, item.unit)} · ${itemKcal.toInt()} kcal · P:${(item.amount * (meal.nutriments.proteinsPerUnit ?? 0)).toInt()}g C:${(item.amount * (meal.nutriments.carbohydratesPerUnit ?? 0)).toInt()}g F:${(item.amount * (meal.nutriments.fatPerUnit ?? 0)).toInt()}g'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Edit quantity
                    IconButton(
                      icon: const Icon(Icons.scale, size: 20),
                      tooltip: 'Edit portion',
                      onPressed: () => _editItemQuantity(index, item),
                    ),
                    // Go to food detail
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 20),
                      tooltip: 'View food',
                      onPressed: () {
                        final mealWithLink =
                            meal.copyWith(localFoodId: item.foodId);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FoodDetailPage(food: mealWithLink),
                          ),
                        );
                      },
                    ),
                    // Remove from preset
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      tooltip: 'Remove food',
                      onPressed: () => _removeItem(index),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),

          // Add item button
          OutlinedButton.icon(
            onPressed: _addItemToPreset,
            icon: const Icon(Icons.add),
            label: const Text('Add food'),
          ),

          const SizedBox(height: 12),

          // AI edit button
          OutlinedButton.icon(
            onPressed: _aiEditPreset,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('AI edit meal'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty || newName == _preset.name) return;

    final updated = MealPresetDBO(
      id: _preset.id,
      name: newName,
      items: _preset.items,
      imagePath: _preset.imagePath,
    );
    await locator<MealPresetDataSource>().updatePreset(updated);
    setState(() => _preset = updated);
  }

  Widget _buildImageEditor() {
    final hasImage = _preset.imagePath != null && _preset.imagePath!.isNotEmpty;
    return GestureDetector(
      onTap: _editMealImage,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            SizedBox(
              width: double.infinity,
              height: 180,
              child: hasImage
                  ? FoodImage(
                      imageUrl: _preset.imagePath,
                      width: double.infinity,
                      height: 180,
                    )
                  : Container(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 36,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add meal image',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.outline,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: FilledButton.icon(
                onPressed: _editMealImage,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(hasImage ? 'Change' : 'Add'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editItemQuantity(int index, MealPresetItemDBO item) async {
    final meal = MealEntity.fromMealDBO(item.meal);
    final controller = TextEditingController(
      text: MealPortionHelper.formatValue(
        MealPortionHelper.fromBaseAmount(meal, item.amount, item.unit),
      ),
    );

    final newAmount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(meal.name ?? '?'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            suffixText: MealPortionHelper.unitLabel(meal, item.unit),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(ctx).dialogCancelLabel),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text);
              if (v == null) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(
                ctx,
                MealPortionHelper.toBaseAmount(meal, v, item.unit),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (newAmount != null && newAmount > 0) {
      final updatedItems = List<MealPresetItemDBO>.from(_preset.items);
      updatedItems[index] = MealPresetItemDBO(
        meal: item.meal,
        amount: newAmount,
        unit: item.unit,
        foodId: item.foodId,
      );
      final updated = MealPresetDBO(
        id: _preset.id,
        name: _preset.name,
        items: updatedItems,
        imagePath: _preset.imagePath,
      );
      await locator<MealPresetDataSource>().updatePreset(updated);
      setState(() => _preset = updated);
    }
  }

  Future<void> _removeItem(int index) async {
    final updatedItems = List<MealPresetItemDBO>.from(_preset.items);
    updatedItems.removeAt(index);

    if (updatedItems.isEmpty) {
      await _deletePreset();
      return;
    }

    final updated = MealPresetDBO(
      id: _preset.id,
      name: _preset.name,
      items: updatedItems,
      imagePath: _preset.imagePath,
    );
    await locator<MealPresetDataSource>().updatePreset(updated);
    setState(() => _preset = updated);
  }

  Future<void> _deletePreset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete saved meal?'),
        content: Text('Delete "${_preset.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.of(ctx).dialogCancelLabel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      await locator<MealPresetDataSource>().deletePreset(_preset.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _addItemToPreset() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Pick from existing foods'),
              onTap: () => Navigator.pop(ctx, 'existing'),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Create food manually'),
              onTap: () => Navigator.pop(ctx, 'manual'),
            ),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    if (choice == 'existing') {
      await _addExistingFoodToPreset();
    } else {
      await _addManualItemToPreset();
    }
  }

  Future<void> _addExistingFoodToPreset() async {
    // Load all available foods
    final intakeDataSource = locator<IntakeDataSource>();
    final localFoodDataSource = locator<LocalFoodDataSource>();

    final recentIntakes =
        await intakeDataSource.getRecentlyAddedIntake(number: 200);
    final localFoods = await localFoodDataSource.getAllFoodRecords();

    final seen = <String>{};
    final allFoods = <MealEntity>[];
    for (final record in localFoods) {
      final meal = MealEntity.fromLocalFoodRecord(record);
      final key = _foodPickerKey(meal);
      if (key.isNotEmpty && seen.add(key)) allFoods.add(meal);
    }
    for (final dbo in recentIntakes) {
      final meal = MealEntity.fromMealDBO(dbo.meal);
      final key = _foodPickerKey(meal);
      if (key.isNotEmpty && seen.add(key)) allFoods.add(meal);
    }

    if (!mounted) return;

    final result = await showModalBottomSheet<_FoodPickResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _FoodPickerSheet(foods: allFoods),
    );

    if (result == null || !mounted) return;

    final foodRecord = await _upsertLocalFood(result.food);
    final updatedItems = List<MealPresetItemDBO>.from(_preset.items)
      ..add(MealPresetItemDBO(
        meal: foodRecord.meal,
        amount: result.amount,
        unit: 'g',
        foodId: foodRecord.id,
      ));

    final updated = MealPresetDBO(
      id: _preset.id,
      name: _preset.name,
      items: updatedItems,
      imagePath: _preset.imagePath,
    );
    await locator<MealPresetDataSource>().updatePreset(updated);
    setState(() => _preset = updated);
  }

  Future<void> _addManualItemToPreset() async {
    final nameController = TextEditingController();
    final amountController = TextEditingController(text: '100');
    final kcalController = TextEditingController();
    final proteinController = TextEditingController();
    final carbsController = TextEditingController();
    final fatController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add food manually'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                    labelText: 'Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Amount (g)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextField(
                  controller: kcalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'kcal/100g',
                      border: OutlineInputBorder(),
                      isDense: true),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                  controller: proteinController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'P g/100g',
                      border: OutlineInputBorder(),
                      isDense: true),
                )),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextField(
                  controller: carbsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'C g/100g',
                      border: OutlineInputBorder(),
                      isDense: true),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                  controller: fatController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'F g/100g',
                      border: OutlineInputBorder(),
                      isDense: true),
                )),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.of(ctx).dialogCancelLabel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(S.of(ctx).addLabel)),
        ],
      ),
    );

    if (confirmed != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;

    final nutriments = MealNutrimentsEntity(
      energyKcal100: double.tryParse(kcalController.text),
      proteins100: double.tryParse(proteinController.text),
      carbohydrates100: double.tryParse(carbsController.text),
      fat100: double.tryParse(fatController.text),
      sugars100: null,
      saturatedFat100: null,
      fiber100: null,
    );

    final meal = MealEntity(
      code: null,
      name: name,
      brands: null,
      url: null,
      thumbnailImageUrl: null,
      mainImageUrl: null,
      mealQuantity: null,
      mealUnit: 'g',
      servingQuantity: null,
      servingUnit: null,
      servingSize: null,
      nutriments: nutriments,
      source: MealSourceEntity.custom,
    );

    final foodRecord = await _upsertLocalFood(meal);
    final updatedItems = List<MealPresetItemDBO>.from(_preset.items)
      ..add(MealPresetItemDBO(
        meal: foodRecord.meal,
        amount: double.tryParse(amountController.text) ?? 100,
        unit: 'g',
        foodId: foodRecord.id,
      ));

    final updated = MealPresetDBO(
        id: _preset.id,
        name: _preset.name,
        items: updatedItems,
        imagePath: _preset.imagePath);
    await locator<MealPresetDataSource>().updatePreset(updated);
    setState(() => _preset = updated);
  }

  Future<void> _aiEditPreset() async {
    final controller = TextEditingController();

    final instruction = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI Edit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Describe what changes you want:',
                style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText:
                    'e.g. "double the rice", "remove butter", "add 50g cheese"',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(ctx).dialogCancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (instruction == null || instruction.isEmpty || !mounted) return;

    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI is editing your saved meal...')),
    );

    try {
      final aiProvider = await locator<AiSettingsService>().buildProviderForTask(
        AiTaskType.foodEstimation,
      );

      // Build context about current preset
      final currentItems = _preset.items.map((item) {
        final meal = MealEntity.fromMealDBO(item.meal);
        return '${meal.name}: ${item.amount}g (${meal.nutriments.energyKcal100?.toInt() ?? 0} kcal/100g, P:${meal.nutriments.proteins100?.toInt() ?? 0}g C:${meal.nutriments.carbohydrates100?.toInt() ?? 0}g F:${meal.nutriments.fat100?.toInt() ?? 0}g per 100g)';
      }).join('\n');

      final prompt =
          'Current saved meal "${_preset.name}" contains:\n$currentItems\n\nUser wants: $instruction';

      // Use text-only estimation
      final response = await aiProvider.estimateFromPhoto(
        Uint8List(0),
        'text/plain',
        clarificationAnswer:
            'Return the COMPLETE updated ingredient list after applying changes. $prompt',
      );

      if (!mounted) return;

      if (response.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI could not process the edit.')),
        );
        return;
      }

      // Rebuild preset from AI response
      final newItems = <MealPresetItemDBO>[];
      for (final item in response.items) {
        final meal = MealEntity(
          code: null,
          name: item.name,
          brands: null,
          url: null,
          thumbnailImageUrl: null,
          mainImageUrl: null,
          mealQuantity: null,
          mealUnit: 'g',
          servingQuantity: null,
          servingUnit: null,
          servingSize: null,
          nutriments: MealNutrimentsEntity(
            energyKcal100: item.per100g.energyKcal,
            proteins100: item.per100g.proteinG,
            carbohydrates100: item.per100g.carbohydratesG,
            fat100: item.per100g.fatG,
            sugars100: item.per100g.sugarsG,
            saturatedFat100: item.per100g.saturatedFatG,
            fiber100: item.per100g.fiberG,
            sodiumMg100: item.per100g.sodiumMg,
          ),
          source: MealSourceEntity.ai,
        );
        final foodRecord = await _upsertLocalFood(meal);
        newItems.add(
          MealPresetItemDBO(
            meal: foodRecord.meal,
            amount: item.estimatedWeightG,
            unit: 'g',
            foodId: foodRecord.id,
          ),
        );
      }

      final newName = response.mealName ?? _preset.name;
      final updated = MealPresetDBO(
        id: _preset.id,
        name: newName,
        items: newItems,
        imagePath: _preset.imagePath,
      );
      await locator<MealPresetDataSource>().updatePreset(updated);

      _nameController.text = newName;
      setState(() => _preset = updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved meal updated by AI!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI error: $e')),
        );
      }
    }
  }

  Future<LocalFoodRecordDBO> _upsertLocalFood(MealEntity meal) {
    return locator<LocalFoodDataSource>().saveFood(
      MealDBO.fromMealEntity(meal),
      existingFoodId: meal.localFoodId,
      lookupKeys: [
        if (meal.code != null && meal.code!.isNotEmpty) meal.code!,
      ],
    );
  }

  String _foodPickerKey(MealEntity meal) {
    if (meal.code != null && meal.code!.trim().isNotEmpty) {
      return 'code:${meal.code!.trim().toLowerCase()}';
    }
    if (meal.name != null && meal.name!.trim().isNotEmpty) {
      return 'name:${meal.name!.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')}';
    }
    return '';
  }

  String _foodCountLabel(int count) {
    if (count == 1) {
      return '1 food';
    }
    return '$count foods';
  }

  Future<void> _editMealImage() async {
    final action = await showImageEditActionSheet(
      context,
      hasImage: _preset.imagePath != null && _preset.imagePath!.isNotEmpty,
    );
    if (action == null || !mounted) {
      return;
    }

    if (action == ImageEditAction.remove) {
      await _updatePresetImage(null);
      return;
    }

    final source = action == ImageEditAction.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );

    if (picked == null || !mounted) {
      return;
    }

    final savedPath = await FoodImageStorage.saveImageFromPath(picked.path);
    if (!mounted) {
      return;
    }

    await _updatePresetImage(savedPath);
  }

  Future<void> _updatePresetImage(String? imagePath) async {
    final updated = MealPresetDBO(
      id: _preset.id,
      name: _preset.name,
      items: _preset.items,
      imagePath: imagePath,
    );
    await locator<MealPresetDataSource>().updatePreset(updated);
    if (!mounted) {
      return;
    }
    setState(() => _preset = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          imagePath == null ? 'Meal image removed' : 'Meal image updated',
        ),
      ),
    );
  }
}

class _FoodPickResult {
  final MealEntity food;
  final double amount;

  _FoodPickResult(this.food, this.amount);
}

class _FoodPickerSheet extends StatefulWidget {
  final List<MealEntity> foods;

  const _FoodPickerSheet({required this.foods});

  @override
  State<_FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<_FoodPickerSheet> {
  String _query = '';

  List<MealEntity> get _filtered {
    if (_query.isEmpty) return widget.foods;
    final q = _query.toLowerCase();
    return widget.foods
        .where((f) =>
            (f.name ?? '').toLowerCase().contains(q) ||
            (f.brands ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search foods...',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: _filtered.length,
              itemBuilder: (ctx, index) {
                final food = _filtered[index];
                return ListTile(
                  title: Text(food.name ?? '?'),
                  subtitle: Text(
                      '${food.nutriments.energyKcal100?.toInt() ?? '?'} kcal/100g'),
                  onTap: () => _pickAmount(food),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _pickAmount(MealEntity food) async {
    final controller = TextEditingController(text: '100');

    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(food.name ?? '?'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Amount',
            suffixText: 'g',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text)),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (amount != null && amount > 0 && mounted) {
      Navigator.pop(context, _FoodPickResult(food, amount));
    }
  }
}
