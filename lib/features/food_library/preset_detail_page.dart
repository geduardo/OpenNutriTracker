import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/data_source/meal_preset_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_preset_dbo.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/ai/ai_provider.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/food_library/food_detail_page.dart';
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

  @override
  void initState() {
    super.initState();
    _preset = widget.preset;
    _nameController = TextEditingController(text: _preset.name);
  }

  double get _totalKcal => _preset.items.fold<double>(0, (sum, item) {
        final meal = MealEntity.fromMealDBO(item.meal);
        return sum + (item.amount * (meal.nutriments.energyPerUnit ?? 0));
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Preset'),
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
          // Name field
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Preset name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _saveName(),
          ),
          const SizedBox(height: 8),
          Text('${_preset.items.length} items · ${_totalKcal.toInt()} ${S.of(context).kcalLabel}',
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
                    '${item.amount.toInt()}g · ${itemKcal.toInt()} kcal · P:${(item.amount * (meal.nutriments.proteinsPerUnit ?? 0)).toInt()}g C:${(item.amount * (meal.nutriments.carbohydratesPerUnit ?? 0)).toInt()}g F:${(item.amount * (meal.nutriments.fatPerUnit ?? 0)).toInt()}g'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Edit quantity
                    IconButton(
                      icon: const Icon(Icons.scale, size: 20),
                      tooltip: 'Edit quantity',
                      onPressed: () => _editItemQuantity(index, item),
                    ),
                    // Go to food detail
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 20),
                      tooltip: 'View food',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FoodDetailPage(food: meal),
                          ),
                        );
                      },
                    ),
                    // Remove from preset
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      tooltip: 'Remove',
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
            label: const Text('Add item'),
          ),

          const SizedBox(height: 12),

          // AI edit button
          OutlinedButton.icon(
            onPressed: _aiEditPreset,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('AI edit'),
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
    );
    await locator<MealPresetDataSource>().updatePreset(updated);
    setState(() => _preset = updated);
  }

  Future<void> _editItemQuantity(int index, MealPresetItemDBO item) async {
    final controller =
        TextEditingController(text: item.amount.toInt().toString());

    final newAmount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(MealEntity.fromMealDBO(item.meal).name ?? '?'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            suffixText: 'g',
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
              Navigator.pop(ctx, v);
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
      );
      final updated = MealPresetDBO(
        id: _preset.id,
        name: _preset.name,
        items: updatedItems,
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
    );
    await locator<MealPresetDataSource>().updatePreset(updated);
    setState(() => _preset = updated);
  }

  Future<void> _deletePreset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete preset?'),
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
    final nameController = TextEditingController();
    final amountController = TextEditingController(text: '100');
    final kcalController = TextEditingController();
    final proteinController = TextEditingController();
    final carbsController = TextEditingController();
    final fatController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add item'),
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: kcalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'kcal/100g', border: OutlineInputBorder(), isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: proteinController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'P g/100g', border: OutlineInputBorder(), isDense: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: carbsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'C g/100g', border: OutlineInputBorder(), isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fatController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'F g/100g', border: OutlineInputBorder(), isDense: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(ctx).dialogCancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.of(ctx).addLabel),
          ),
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

    final updatedItems = List<MealPresetItemDBO>.from(_preset.items)
      ..add(MealPresetItemDBO(
        meal: MealDBO.fromMealEntity(meal),
        amount: double.tryParse(amountController.text) ?? 100,
        unit: 'g',
      ));

    final updated = MealPresetDBO(
      id: _preset.id,
      name: _preset.name,
      items: updatedItems,
    );
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
                hintText: 'e.g. "double the rice", "remove butter", "add 50g cheese"',
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
      const SnackBar(content: Text('AI is editing your preset...')),
    );

    try {
      final aiProvider = locator<AiProvider>();

      // Build context about current preset
      final currentItems = _preset.items.map((item) {
        final meal = MealEntity.fromMealDBO(item.meal);
        return '${meal.name}: ${item.amount}g (${meal.nutriments.energyKcal100?.toInt() ?? 0} kcal/100g, P:${meal.nutriments.proteins100?.toInt() ?? 0}g C:${meal.nutriments.carbohydrates100?.toInt() ?? 0}g F:${meal.nutriments.fat100?.toInt() ?? 0}g per 100g)';
      }).join('\n');

      final prompt =
          'Current preset "${_preset.name}" contains:\n$currentItems\n\nUser wants: $instruction';

      // Use text-only estimation
      final response = await aiProvider.estimateFromPhoto(
        Uint8List(0),
        'text/plain',
        clarificationAnswer: 'Return the COMPLETE updated ingredient list after applying changes. $prompt',
      );

      if (!mounted) return;

      if (response.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI could not process the edit.')),
        );
        return;
      }

      // Rebuild preset from AI response
      final newItems = response.items.map((item) {
        final nutriments = MealNutrimentsEntity(
          energyKcal100: item.per100g.energyKcal,
          proteins100: item.per100g.proteinG,
          carbohydrates100: item.per100g.carbohydratesG,
          fat100: item.per100g.fatG,
          sugars100: item.per100g.sugarsG,
          saturatedFat100: item.per100g.saturatedFatG,
          fiber100: item.per100g.fiberG,
          sodiumMg100: item.per100g.sodiumMg,
        );

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
          nutriments: nutriments,
          source: MealSourceEntity.ai,
        );

        return MealPresetItemDBO(
          meal: MealDBO.fromMealEntity(meal),
          amount: item.estimatedWeightG,
          unit: 'g',
        );
      }).toList();

      final newName = response.mealName ?? _preset.name;
      final updated = MealPresetDBO(
        id: _preset.id,
        name: newName,
        items: newItems,
      );
      await locator<MealPresetDataSource>().updatePreset(updated);
      _nameController.text = newName;
      setState(() => _preset = updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preset updated by AI!')),
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
}
