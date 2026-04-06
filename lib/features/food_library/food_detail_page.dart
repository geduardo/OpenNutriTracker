import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/data_source/local_food_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';

class FoodDetailPage extends StatefulWidget {
  final MealEntity food;

  const FoodDetailPage({super.key, required this.food});

  @override
  State<FoodDetailPage> createState() => _FoodDetailPageState();
}

class _FoodDetailPageState extends State<FoodDetailPage> {
  late TextEditingController _nameController;
  late TextEditingController _brandsController;
  late TextEditingController _kcalController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatController;
  late TextEditingController _fiberController;
  late TextEditingController _sodiumController;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final n = widget.food.nutriments;
    _nameController = TextEditingController(text: widget.food.name ?? '');
    _brandsController = TextEditingController(text: widget.food.brands ?? '');
    _kcalController = TextEditingController(text: _fmt(n.energyKcal100));
    _proteinController = TextEditingController(text: _fmt(n.proteins100));
    _carbsController = TextEditingController(text: _fmt(n.carbohydrates100));
    _fatController = TextEditingController(text: _fmt(n.fat100));
    _fiberController = TextEditingController(text: _fmt(n.fiber100));
    _sodiumController = TextEditingController(text: _fmt(n.sodiumMg100));
  }

  String _fmt(double? v) => v != null ? v.toStringAsFixed(1) : '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.food.name ?? 'Food Detail'),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _save,
              child: Text('Save',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Source badge
          Row(
            children: [
              Icon(_sourceIcon, size: 16, color: Theme.of(context).colorScheme.outline),
              const SizedBox(width: 4),
              Text(_sourceLabel,
                  style: Theme.of(context).textTheme.bodySmall),
              if (widget.food.code != null) ...[
                const SizedBox(width: 8),
                Text('Code: ${widget.food.code}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
          const SizedBox(height: 16),

          _buildField('Name', _nameController),
          _buildField('Brand', _brandsController),
          const Divider(height: 32),

          Text('Nutrition per 100g',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(child: _buildField(S.of(context).kcalLabel, _kcalController, suffix: 'kcal')),
              const SizedBox(width: 12),
              Expanded(child: _buildField(S.of(context).proteinLabel, _proteinController, suffix: 'g')),
            ],
          ),
          Row(
            children: [
              Expanded(child: _buildField(S.of(context).carbsLabel, _carbsController, suffix: 'g')),
              const SizedBox(width: 12),
              Expanded(child: _buildField(S.of(context).fatLabel, _fatController, suffix: 'g')),
            ],
          ),
          Row(
            children: [
              Expanded(child: _buildField('Fiber', _fiberController, suffix: 'g')),
              const SizedBox(width: 12),
              Expanded(child: _buildField('Sodium', _sodiumController, suffix: 'mg')),
            ],
          ),

          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete from library'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      {String? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        onChanged: (_) => setState(() => _hasChanges = true),
        keyboardType: suffix != null ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  IconData get _sourceIcon => switch (widget.food.source) {
        MealSourceEntity.ai => Icons.auto_awesome,
        MealSourceEntity.off => Icons.qr_code,
        MealSourceEntity.fdc => Icons.search,
        MealSourceEntity.custom => Icons.edit,
        _ => Icons.restaurant,
      };

  String get _sourceLabel => switch (widget.food.source) {
        MealSourceEntity.ai => 'AI Estimated',
        MealSourceEntity.off => 'OpenFoodFacts',
        MealSourceEntity.fdc => 'USDA FDC',
        MealSourceEntity.custom => 'Custom',
        _ => 'Unknown',
      };

  Future<void> _save() async {
    final updatedNutriments = MealNutrimentsEntity(
      energyKcal100: double.tryParse(_kcalController.text),
      proteins100: double.tryParse(_proteinController.text),
      carbohydrates100: double.tryParse(_carbsController.text),
      fat100: double.tryParse(_fatController.text),
      sugars100: widget.food.nutriments.sugars100,
      saturatedFat100: widget.food.nutriments.saturatedFat100,
      fiber100: double.tryParse(_fiberController.text),
      sodiumMg100: double.tryParse(_sodiumController.text),
    );

    final updatedMeal = MealEntity(
      code: widget.food.code,
      name: _nameController.text.trim(),
      brands: _brandsController.text.trim().isEmpty
          ? null
          : _brandsController.text.trim(),
      url: widget.food.url,
      thumbnailImageUrl: widget.food.thumbnailImageUrl,
      mainImageUrl: widget.food.mainImageUrl,
      mealQuantity: widget.food.mealQuantity,
      mealUnit: widget.food.mealUnit,
      servingQuantity: widget.food.servingQuantity,
      servingUnit: widget.food.servingUnit,
      servingSize: widget.food.servingSize,
      nutriments: updatedNutriments,
      source: widget.food.source,
    );

    // Save to local overrides
    final key = widget.food.code ?? widget.food.name ?? '';
    if (key.isNotEmpty) {
      final localFoodDataSource = locator<LocalFoodDataSource>();
      await localFoodDataSource.saveFood(key, MealDBO.fromMealEntity(updatedMeal));
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Food saved')));
      setState(() => _hasChanges = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete food?'),
        content: Text('Remove "${widget.food.name}" from your library?'),
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
      final key = widget.food.code ?? widget.food.name ?? '';
      if (key.isNotEmpty) {
        final localFoodDataSource = locator<LocalFoodDataSource>();
        await localFoodDataSource.deleteFood(key);
      }
      if (mounted) Navigator.pop(context);
    }
  }
}
