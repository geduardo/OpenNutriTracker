import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:opennutritracker/core/presentation/widgets/food_image.dart';
import 'package:opennutritracker/core/presentation/widgets/image_edit_action_sheet.dart';
import 'package:opennutritracker/core/data/data_source/local_food_data_source.dart';
import 'package:opennutritracker/core/data/data_source/meal_preset_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/utils/food_image_storage.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/meal_portion_helper.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/generated/l10n.dart';

class FoodDetailPage extends StatefulWidget {
  final MealEntity food;
  final bool returnSavedFood;
  final bool popOnSave;
  final String? title;

  const FoodDetailPage({
    super.key,
    required this.food,
    this.returnSavedFood = false,
    this.popOnSave = false,
    this.title,
  });

  @override
  State<FoodDetailPage> createState() => _FoodDetailPageState();
}

class _FoodDetailPageState extends State<FoodDetailPage> {
  late TextEditingController _nameController;
  late TextEditingController _brandsController;
  late TextEditingController _kcalController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _sugarController;
  late TextEditingController _fatController;
  late TextEditingController _fiberController;
  late TextEditingController _sodiumController;
  late TextEditingController _servingLabelController;
  late TextEditingController _servingQuantityController;
  late String _selectedBaseUnit;
  late final ImagePicker _imagePicker;
  String? _imagePath;
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
    _sugarController = TextEditingController(text: _fmt(n.sugars100));
    _fatController = TextEditingController(text: _fmt(n.fat100));
    _fiberController = TextEditingController(text: _fmt(n.fiber100));
    _sodiumController = TextEditingController(text: _fmt(n.sodiumMg100));
    _servingLabelController = TextEditingController(
      text: MealPortionHelper.servingName(widget.food) ?? '',
    );
    _servingQuantityController = TextEditingController(
      text: _fmt(widget.food.servingQuantity),
    );
    _imagePicker = ImagePicker();
    _imagePath = widget.food.mainImageUrl?.isNotEmpty == true
        ? widget.food.mainImageUrl
        : widget.food.thumbnailImageUrl;
    _selectedBaseUnit = widget.food.mealUnit == 'ml'
        ? 'ml'
        : widget.food.mealUnit == 'g'
            ? 'g'
            : 'g';
  }

  String _fmt(double? v) => v != null ? v.toStringAsFixed(1) : '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? widget.food.name ?? 'Food Detail'),
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
          _buildImageEditor(),
          const SizedBox(height: 16),

          // Source badge
          Row(
            children: [
              Icon(_sourceIcon,
                  size: 16, color: Theme.of(context).colorScheme.outline),
              const SizedBox(width: 4),
              Text(_sourceLabel, style: Theme.of(context).textTheme.bodySmall),
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

          Text('Base unit', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(value: 'g', label: Text('g')),
              ButtonSegment<String>(value: 'ml', label: Text('ml')),
            ],
            selected: {_selectedBaseUnit},
            onSelectionChanged: (selection) {
              setState(() {
                _selectedBaseUnit = selection.first;
                _hasChanges = true;
              });
            },
          ),
          const SizedBox(height: 20),

          Text('Nutrition per 100$_selectedBaseUnit',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                  child: _buildField(S.of(context).kcalLabel, _kcalController,
                      suffix: 'kcal')),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildField(
                      S.of(context).proteinLabel, _proteinController,
                      suffix: 'g')),
            ],
          ),
          Row(
            children: [
              Expanded(
                  child: _buildField(S.of(context).carbsLabel, _carbsController,
                      suffix: 'g')),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildField(S.of(context).fatLabel, _fatController,
                      suffix: 'g')),
            ],
          ),
          Row(
            children: [
              Expanded(
                  child: _buildField('Of which sugars', _sugarController,
                      suffix: 'g')),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildField('Fiber', _fiberController, suffix: 'g')),
            ],
          ),
          Row(
            children: [
              Expanded(
                  child:
                      _buildField('Sodium', _sodiumController, suffix: 'mg')),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),

          const SizedBox(height: 20),
          Text('Portion', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _buildField('Portion label', _servingLabelController),
          _buildField('One portion equals', _servingQuantityController,
              suffix: _selectedBaseUnit),
          Text(
            'Examples: cookie, slice, egg, piece, scoop, tbsp, tsp',
            style: Theme.of(context).textTheme.bodySmall,
          ),

          const SizedBox(height: 32),
          if (widget.food.localFoodId != null)
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
        keyboardType:
            suffix != null ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildImageEditor() {
    final hasImage = _imagePath != null && _imagePath!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _editImage,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 180,
                  child: hasImage
                      ? FoodImage(
                          imageUrl: _imagePath,
                          width: double.infinity,
                          height: 180,
                        )
                      : Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
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
                                  'Add food image',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline,
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
                    onPressed: _editImage,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(hasImage ? 'Change' : 'Add'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Food name is required.')),
      );
      return;
    }

    final updatedNutriments = MealNutrimentsEntity(
      energyKcal100: double.tryParse(_kcalController.text),
      proteins100: double.tryParse(_proteinController.text),
      carbohydrates100: double.tryParse(_carbsController.text),
      fat100: double.tryParse(_fatController.text),
      sugars100: double.tryParse(_sugarController.text),
      saturatedFat100: widget.food.nutriments.saturatedFat100,
      fiber100: double.tryParse(_fiberController.text),
      sodiumMg100: double.tryParse(_sodiumController.text),
    );
    final servingQuantity = double.tryParse(_servingQuantityController.text);
    final servingSize = MealPortionHelper.buildServingDisplayLabel(
      label: _servingLabelController.text,
      amount: servingQuantity ?? 0,
      unit: _selectedBaseUnit,
    );

    final updatedMeal = MealEntity(
      code: widget.food.code,
      name: name,
      localFoodId: widget.food.localFoodId,
      brands: _brandsController.text.trim().isEmpty
          ? null
          : _brandsController.text.trim(),
      url: widget.food.url,
      thumbnailImageUrl: _imagePath,
      mainImageUrl: _imagePath,
      mealQuantity: widget.food.mealQuantity,
      mealUnit: _selectedBaseUnit,
      servingQuantity: servingSize == null ? null : servingQuantity,
      servingUnit: servingSize == null ? null : _selectedBaseUnit,
      servingSize: servingSize,
      nutriments: updatedNutriments,
      source: widget.food.source,
    );

    final localFoodDataSource = locator<LocalFoodDataSource>();
    final foodRecord = await localFoodDataSource.saveFood(
      MealDBO.fromMealEntity(updatedMeal),
      existingFoodId: widget.food.localFoodId,
      lookupKeys: [
        if (widget.food.code != null && widget.food.code!.isNotEmpty)
          widget.food.code!,
      ],
    );
    await locator<MealPresetDataSource>()
        .syncFoodSnapshot(foodRecord.id, foodRecord.meal);

    if (mounted) {
      if (widget.returnSavedFood) {
        Navigator.pop(context, MealEntity.fromLocalFoodRecord(foodRecord));
        return;
      }
      if (widget.popOnSave) {
        Navigator.pop(context);
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Food saved')));
      setState(() {
        _imagePath = foodRecord.meal.mainImageUrl;
        _hasChanges = false;
      });
    }
  }

  Future<void> _editImage() async {
    final action = await showImageEditActionSheet(
      context,
      hasImage: _imagePath != null && _imagePath!.isNotEmpty,
    );
    if (action == null || !mounted) {
      return;
    }

    if (action == ImageEditAction.remove) {
      setState(() {
        _imagePath = null;
        _hasChanges = true;
      });
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

    setState(() {
      _imagePath = savedPath;
      _hasChanges = true;
    });
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
      final localFoodDataSource = locator<LocalFoodDataSource>();
      final foodId = widget.food.localFoodId ??
          (widget.food.code != null
              ? (await localFoodDataSource
                      .getFoodRecordByKey(widget.food.code!))
                  ?.id
              : widget.food.name != null
                  ? (await localFoodDataSource
                          .getFoodRecordByKey(widget.food.name!))
                      ?.id
                  : null);
      if (foodId != null) {
        await localFoodDataSource.deleteFood(foodId);
      }
      if (mounted) Navigator.pop(context);
    }
  }
}
