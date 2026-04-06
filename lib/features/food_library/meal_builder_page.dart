import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/data/data_source/local_food_data_source.dart';
import 'package:opennutritracker/core/data/dbo/local_food_record_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_preset_dbo.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/meal_portion_helper.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/magic_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/presets_screen.dart';
import 'package:opennutritracker/features/food_library/food_detail_page.dart';
import 'package:opennutritracker/features/scanner/scanner_screen.dart';

class MealBuilderPage extends StatefulWidget {
  const MealBuilderPage({super.key});

  @override
  State<MealBuilderPage> createState() => _MealBuilderPageState();
}

class _MealBuilderPageState extends State<MealBuilderPage> {
  final _nameController = TextEditingController();
  final _draftQuantityController = TextEditingController();
  final List<MealPresetItemDBO> _items = [];

  bool _isSaving = false;

  MealEntity? _draftMeal;
  String? _draftFoodId;
  String? _draftUnit;
  int? _draftEditIndex;

  @override
  void dispose() {
    _nameController.dispose();
    _draftQuantityController.dispose();
    super.dispose();
  }

  double get _totalKcal => _items.fold<double>(0, (sum, item) {
        final meal = MealEntity.fromMealDBO(item.meal);
        return sum + item.amount * (meal.nutriments.energyPerUnit ?? 0);
      });

  bool get _hasDraft => _draftMeal != null && _draftUnit != null;

  double get _draftQuantity =>
      double.tryParse(_draftQuantityController.text.replaceAll(',', '.')) ?? 0;

  double get _draftBaseAmount => !_hasDraft
      ? 0
      : MealPortionHelper.toBaseAmount(_draftMeal!, _draftQuantity, _draftUnit!);

  double get _draftTotalKcal => !_hasDraft
      ? 0
      : _draftBaseAmount * (_draftMeal!.nutriments.energyPerUnit ?? 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create meal'),
        actions: [
          TextButton(
            onPressed: _items.isEmpty || _isSaving ? null : _saveMeal,
            child: Text(
              'Save',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Meal name',
              hintText: 'Chicken rice bowl, breakfast plate...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${_items.length} items · ${_totalKcal.toInt()} kcal',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_hasDraft) ...[
            const SizedBox(height: 16),
            _buildDraftEditor(),
          ],
          const SizedBox(height: 16),
          if (_items.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 40,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Add foods from your library, a barcode, Magic, or a manual item.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            )
          else
            ..._items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final meal = MealEntity.fromMealDBO(item.meal);
              final itemKcal =
                  item.amount * (meal.nutriments.energyPerUnit ?? 0);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(meal.name ?? '?'),
                  subtitle: Text(
                    '${MealPortionHelper.formatStoredAmount(meal, item.amount, item.unit)} · ${itemKcal.toInt()} kcal',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editItem(index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => setState(() => _items.removeAt(index)),
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

  Widget _buildDraftEditor() {
    final meal = _draftMeal!;
    final units = _unitsForMeal(meal);

    if (!units.contains(_draftUnit) && units.isNotEmpty) {
      _draftUnit = units.first;
    }

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _draftEditIndex == null
                        ? 'Add ${meal.name ?? "item"}'
                        : 'Edit ${meal.name ?? "item"}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: _clearDraft,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _draftQuantityController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: units
                  .map(
                    (unit) => ChoiceChip(
                      label: Text(MealPortionHelper.dropdownLabel(meal, unit)),
                      selected: _draftUnit == unit,
                      onSelected: (_) => _setDraftUnit(unit),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Text(
              '${MealPortionHelper.formatStoredAmount(meal, _draftBaseAmount, _draftUnit!)} · ${_draftTotalKcal.toInt()} kcal',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearDraft,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _draftQuantity > 0 ? _applyDraft : null,
                    child: Text(_draftEditIndex == null ? 'Add' : 'Update'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addItem() async {
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
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Scan barcode'),
              onTap: () => Navigator.pop(ctx, 'barcode'),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Use Magic photo/text'),
              onTap: () => Navigator.pop(ctx, 'magic'),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Create manual item'),
              onTap: () => Navigator.pop(ctx, 'manual'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) {
      return;
    }

    switch (choice) {
      case 'existing':
        await _addExistingFood();
        break;
      case 'barcode':
        await _addBarcodeFood();
        break;
      case 'magic':
        await _addMagicItems();
        break;
      case 'manual':
        await _addManualFood();
        break;
    }
  }

  Future<void> _addExistingFood() async {
    final foods = await _loadAvailableFoods();
    if (!mounted) {
      return;
    }

    final selected = await showModalBottomSheet<MealEntity>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FoodSelectionSheet(foods: foods),
    );

    if (selected == null || !mounted) {
      return;
    }

    final foodRecord = await _upsertLocalFood(selected);
    _beginDraft(
      meal: MealEntity.fromLocalFoodRecord(foodRecord),
      foodId: foodRecord.id,
    );
  }

  Future<void> _addManualFood() async {
    final createdFood = await Navigator.push<MealEntity>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodDetailPage(
          food: const MealEntity(
            code: null,
            name: null,
            localFoodId: null,
            brands: null,
            thumbnailImageUrl: null,
            mainImageUrl: null,
            url: null,
            mealQuantity: null,
            mealUnit: 'g',
            servingQuantity: null,
            servingUnit: null,
            servingSize: null,
            nutriments: MealNutrimentsEntity(
              energyKcal100: null,
              carbohydrates100: null,
              fat100: null,
              proteins100: null,
              sugars100: null,
              saturatedFat100: null,
              fiber100: null,
              sodiumMg100: null,
            ),
            source: MealSourceEntity.custom,
          ),
          title: 'Create food',
          returnSavedFood: true,
        ),
      ),
    );

    if (createdFood == null || !mounted) {
      return;
    }

    final foodRecord = await _upsertLocalFood(createdFood);
    _beginDraft(
      meal: MealEntity.fromLocalFoodRecord(foodRecord),
      foodId: foodRecord.id,
      initialUnit: createdFood.hasServingValues
          ? MealPortionHelper.servingUnit
          : MealPortionHelper.resolveBaseUnit(createdFood),
      initialQuantity: createdFood.hasServingValues ? 1 : 100,
    );
  }

  Future<void> _addBarcodeFood() async {
    final scannedFood = await Navigator.of(context).pushNamed(
      NavigationOptions.scannerRoute,
      arguments: ScannerScreenArguments(
        DateTime.now(),
        AddMealType.snackType.getIntakeType(),
        selectionMode: true,
      ),
    );

    if (scannedFood is! MealEntity || !mounted) {
      return;
    }

    final foodRecord = await _upsertLocalFood(scannedFood);
    _beginDraft(
      meal: MealEntity.fromLocalFoodRecord(foodRecord),
      foodId: foodRecord.id,
    );
  }

  Future<void> _addMagicItems() async {
    final result = await Navigator.of(context).pushNamed(
      NavigationOptions.magicRoute,
      arguments: MagicScreenArguments(
        DateTime.now(),
        AddMealType.snackType,
        selectionMode: true,
      ),
    );

    if (result is! List<MealPresetItemDBO> || !mounted) {
      return;
    }

    setState(() {
      _items.addAll(result);
      _clearDraftInternal();
    });
  }

  void _editItem(int index) {
    final item = _items[index];
    final meal = MealEntity.fromMealDBO(item.meal).copyWith(
      localFoodId: item.foodId,
    );

    _beginDraft(
      meal: meal,
      foodId: item.foodId,
      editIndex: index,
      initialUnit: item.unit,
      initialBaseAmount: item.amount,
    );
  }

  void _beginDraft({
    required MealEntity meal,
    String? foodId,
    int? editIndex,
    String? initialUnit,
    double? initialBaseAmount,
    double? initialQuantity,
  }) {
    final units = _unitsForMeal(meal);
    var selectedUnit = initialUnit ??
        (meal.hasServingValues
            ? MealPortionHelper.servingUnit
            : meal.isLiquid
                ? 'ml'
                : 'g');

    if (!units.contains(selectedUnit) && units.isNotEmpty) {
      selectedUnit = units.first;
    }

    final seededQuantity = initialBaseAmount != null
        ? MealPortionHelper.fromBaseAmount(meal, initialBaseAmount, selectedUnit)
        : initialQuantity ??
            (selectedUnit == MealPortionHelper.servingUnit ? 1 : 100);

    setState(() {
      _draftMeal = meal;
      _draftFoodId = foodId ?? meal.localFoodId;
      _draftUnit = selectedUnit;
      _draftEditIndex = editIndex;
      _draftQuantityController.text =
          MealPortionHelper.formatValue(seededQuantity);
    });
  }

  List<String> _unitsForMeal(MealEntity meal) {
    return {
      if (meal.hasServingValues) MealPortionHelper.servingUnit,
      if (MealPortionHelper.supportsSpoonUnits(meal))
        MealPortionHelper.tablespoonUnit,
      if (MealPortionHelper.supportsSpoonUnits(meal))
        MealPortionHelper.teaspoonUnit,
      if (meal.isSolid || (!meal.isSolid && !meal.isLiquid)) 'g',
      if (meal.isSolid || (!meal.isSolid && !meal.isLiquid)) 'oz',
      if (meal.isLiquid || (!meal.isSolid && !meal.isLiquid)) 'ml',
      if (meal.isLiquid || (!meal.isSolid && !meal.isLiquid)) 'fl.oz',
    }.toList();
  }

  void _setDraftUnit(String unit) {
    if (!_hasDraft || _draftUnit == unit) {
      return;
    }

    final meal = _draftMeal!;
    final currentBaseAmount = MealPortionHelper.toBaseAmount(
      meal,
      _draftQuantity,
      _draftUnit!,
    );

    setState(() {
      _draftUnit = unit;
      _draftQuantityController.text = MealPortionHelper.formatValue(
        MealPortionHelper.fromBaseAmount(
          meal,
          currentBaseAmount,
          _draftUnit!,
        ),
      );
    });
  }

  void _applyDraft() {
    if (!_hasDraft || _draftQuantity <= 0) {
      return;
    }

    final item = MealPresetItemDBO(
      meal: MealDBO.fromMealEntity(_draftMeal!),
      amount: _draftBaseAmount,
      unit: _draftUnit!,
      foodId: _draftFoodId,
    );

    setState(() {
      if (_draftEditIndex != null) {
        _items[_draftEditIndex!] = item;
      } else {
        _items.add(item);
      }
      _clearDraftInternal();
    });
  }

  void _clearDraft() {
    setState(_clearDraftInternal);
  }

  void _clearDraftInternal() {
    _draftMeal = null;
    _draftFoodId = null;
    _draftUnit = null;
    _draftEditIndex = null;
    _draftQuantityController.clear();
  }

  Future<List<MealEntity>> _loadAvailableFoods() async {
    final intakeDataSource = locator<IntakeDataSource>();
    final localFoodDataSource = locator<LocalFoodDataSource>();
    final recentIntakes =
        await intakeDataSource.getRecentlyAddedIntake(number: 300);
    final localFoods = await localFoodDataSource.getAllFoodRecords();

    final seen = <String>{};
    final allFoods = <MealEntity>[];
    for (final record in localFoods) {
      final meal = MealEntity.fromLocalFoodRecord(record);
      final key = _libraryKey(meal);
      if (key.isNotEmpty && seen.add(key)) {
        allFoods.add(meal);
      }
    }
    for (final dbo in recentIntakes) {
      final meal = MealEntity.fromMealDBO(dbo.meal);
      final key = _libraryKey(meal);
      if (key.isNotEmpty && seen.add(key)) {
        allFoods.add(meal);
      }
    }

    return allFoods;
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

  Future<void> _saveMeal() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a meal name first.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await saveAsPreset(context, name, _items);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _libraryKey(MealEntity meal) {
    if (meal.code != null && meal.code!.trim().isNotEmpty) {
      return 'code:${meal.code!.trim().toLowerCase()}';
    }
    if (meal.name != null && meal.name!.trim().isNotEmpty) {
      return 'name:${meal.name!.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')}';
    }
    return '';
  }
}

class _FoodSelectionSheet extends StatefulWidget {
  final List<MealEntity> foods;

  const _FoodSelectionSheet({required this.foods});

  @override
  State<_FoodSelectionSheet> createState() => _FoodSelectionSheetState();
}

class _FoodSelectionSheetState extends State<_FoodSelectionSheet> {
  String _query = '';

  List<MealEntity> get _filtered {
    if (_query.isEmpty) {
      return widget.foods;
    }
    final q = _query.toLowerCase();
    return widget.foods
        .where(
          (food) =>
              (food.name ?? '').toLowerCase().contains(q) ||
              (food.brands ?? '').toLowerCase().contains(q),
        )
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
              onChanged: (value) => setState(() => _query = value),
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search foods...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
                    '${food.nutriments.energyKcal100?.toInt() ?? '?'} kcal/100${MealPortionHelper.resolveBaseUnit(food)}',
                  ),
                  onTap: () => Navigator.pop(context, food),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
