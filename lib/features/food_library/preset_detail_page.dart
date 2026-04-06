import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/data_source/meal_preset_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_preset_dbo.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
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
}
