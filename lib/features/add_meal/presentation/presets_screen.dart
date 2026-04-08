import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/presentation/widgets/food_image.dart';
import 'package:opennutritracker/core/data/data_source/meal_preset_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_preset_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/meal_multiplier_dialog.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/meal_portion_helper.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

class PresetsScreen extends StatefulWidget {
  const PresetsScreen({super.key});

  @override
  State<PresetsScreen> createState() => _PresetsScreenState();
}

class _PresetsScreenState extends State<PresetsScreen> {
  late AddMealType _mealType;
  late DateTime _day;
  List<MealPresetDBO> _presets = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    final args =
        ModalRoute.of(context)?.settings.arguments as PresetsScreenArguments;
    _mealType = args.mealType;
    _day = args.day;
    _loadPresets();
    super.didChangeDependencies();
  }

  Future<void> _loadPresets() async {
    final dataSource = locator<MealPresetDataSource>();
    final intakeDataSource = locator<IntakeDataSource>();
    final presets = await dataSource.getAllPresets();
    final intakes = await intakeDataSource.getAllIntakes();
    final latestUseByPresetName = <String, DateTime>{};

    for (final intake in intakes) {
      final groupName = intake.groupName?.trim();
      if (groupName == null || groupName.isEmpty) {
        continue;
      }

      final baseName = parseMealGroupName(groupName).baseName.toLowerCase();
      final previousUse = latestUseByPresetName[baseName];
      if (previousUse == null || intake.dateTime.isAfter(previousUse)) {
        latestUseByPresetName[baseName] = intake.dateTime;
      }
    }

    final sortedPresets = List<MealPresetDBO>.from(presets)
      ..sort((a, b) {
        final aUsed = latestUseByPresetName[a.name.toLowerCase()];
        final bUsed = latestUseByPresetName[b.name.toLowerCase()];
        if (aUsed != null && bUsed != null) {
          return bUsed.compareTo(aUsed);
        }
        if (aUsed != null) {
          return -1;
        }
        if (bUsed != null) {
          return 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    if (mounted) {
      setState(() {
        _presets = sortedPresets;
        _isLoading = false;
      });
    }
  }

  List<MealPresetDBO> get _filteredPresets {
    if (_searchQuery.trim().isEmpty) {
      return _presets;
    }

    final query = _searchQuery.trim().toLowerCase();
    return _presets.where((preset) {
      if (preset.name.toLowerCase().contains(query)) {
        return true;
      }

      return preset.items.any((item) =>
          (item.meal.name?.toLowerCase().contains(query) ?? false));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredPresets = _filteredPresets;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved meals'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: TextField(
                    onChanged: (value) =>
                        setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: S.of(context).searchLabel,
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      isDense: true,
                    ),
                  ),
                ),
                Expanded(
                  child: _presets.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.playlist_add,
                                    size: 64,
                                    color:
                                        Theme.of(context).colorScheme.outline),
                                const SizedBox(height: 16),
                                Text('No saved meals yet',
                                    style:
                                        Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 8),
                                Text(
                                    'Use Magic with "Meal breakdown" or build a meal in your library, then save it for reuse.',
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                          ),
                        )
                      : filteredPresets.isEmpty
                          ? const Center(child: Text('No saved meals match that search'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: filteredPresets.length,
                              itemBuilder: (context, index) =>
                                  _buildPresetCard(filteredPresets[index]),
                            ),
                ),
              ],
            ),
    );
  }

  Widget _buildPresetCard(MealPresetDBO preset) {
    final totalKcal = preset.items.fold<double>(0, (sum, item) {
      final meal = MealEntity.fromMealDBO(item.meal);
      return sum + (item.amount * (meal.nutriments.energyPerUnit ?? 0));
    });

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _showPresetDetail(preset),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FoodImage(
                  imageUrl: preset.imagePath,
                  width: 56,
                  height: 56,
                  placeholder: Container(
                    width: 56,
                    height: 56,
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: const Icon(Icons.playlist_add),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(preset.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${_foodCountLabel(preset.items.length)} · ${totalKcal.toInt()} ${S.of(context).kcalLabel}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preset.items
                          .map((i) =>
                              '${MealEntity.fromMealDBO(i.meal).name ?? "?"} ${MealPortionHelper.formatStoredAmount(MealEntity.fromMealDBO(i.meal), i.amount, i.unit)}')
                          .join(', '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Log saved meal',
                onPressed: () => _logPreset(preset),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPresetDetail(MealPresetDBO preset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PresetDetailSheet(
        preset: preset,
        onLog: () {
          Navigator.pop(ctx);
          _logPreset(preset);
        },
        onDelete: () {
          Navigator.pop(ctx);
          _deletePreset(preset);
        },
        onRename: () async {
          Navigator.pop(ctx);
          await _renamePreset(preset);
        },
        onUpdateItem: (index, newAmount) async {
          final dataSource = locator<MealPresetDataSource>();
          final updatedItems = List<MealPresetItemDBO>.from(preset.items);
          updatedItems[index] = MealPresetItemDBO(
            meal: updatedItems[index].meal,
            amount: newAmount,
            unit: updatedItems[index].unit,
            foodId: updatedItems[index].foodId,
          );
          final updated = MealPresetDBO(
            id: preset.id,
            name: preset.name,
            items: updatedItems,
            imagePath: preset.imagePath,
          );
          await dataSource.updatePreset(updated);
          _loadPresets();
        },
        onRemoveItem: (index) async {
          final dataSource = locator<MealPresetDataSource>();
          final updatedItems = List<MealPresetItemDBO>.from(preset.items);
          updatedItems.removeAt(index);
          if (updatedItems.isEmpty) {
            await dataSource.deletePreset(preset.id);
          } else {
            final updated = MealPresetDBO(
              id: preset.id,
              name: preset.name,
              items: updatedItems,
            );
            await dataSource.updatePreset(updated);
          }
          _loadPresets();
        },
      ),
    );
  }

  Future<void> _renamePreset(MealPresetDBO preset) async {
    final controller = TextEditingController(text: preset.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename saved meal'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(ctx).dialogCancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      final dataSource = locator<MealPresetDataSource>();
      final updated = MealPresetDBO(
        id: preset.id,
        name: newName,
        items: preset.items,
        imagePath: preset.imagePath,
      );
      await dataSource.updatePreset(updated);
      _loadPresets();
    }
  }

  Future<void> _logPreset(MealPresetDBO preset) async {
    final baseKcal = preset.items.fold<double>(0, (sum, item) {
      final meal = MealEntity.fromMealDBO(item.meal);
      return sum + (item.amount * (meal.nutriments.energyPerUnit ?? 0));
    });
    final multiplier = await showMealMultiplierDialog(
      context,
      mealName: preset.name,
      totalKcal: baseKcal,
      confirmLabel: 'Log meal',
    );
    if (multiplier == null || !mounted) {
      return;
    }

    final addIntakeUsecase = locator<AddIntakeUsecase>();
    final addTrackedDayUsecase = locator<AddTrackedDayUsecase>();
    final getKcalGoalUsecase = locator<GetKcalGoalUsecase>();
    final getMacroGoalUsecase = locator<GetMacroGoalUsecase>();

    final intakeType = _mealType.getIntakeType();
    final groupId = IdGenerator.getUniqueID();
    final groupName = buildMealGroupName(preset.name, multiplier);

    // Ensure tracked day exists
    final hasTrackedDay = await addTrackedDayUsecase.hasTrackedDay(_day);
    if (!hasTrackedDay) {
      final totalKcalGoal = await getKcalGoalUsecase.getKcalGoal();
      final totalCarbsGoal =
          await getMacroGoalUsecase.getCarbsGoal(totalKcalGoal);
      final totalFatGoal = await getMacroGoalUsecase.getFatsGoal(totalKcalGoal);
      final totalProteinGoal =
          await getMacroGoalUsecase.getProteinsGoal(totalKcalGoal);
      await addTrackedDayUsecase.addNewTrackedDay(
          _day, totalKcalGoal, totalCarbsGoal, totalFatGoal, totalProteinGoal);
    }

    for (final item in preset.items) {
      final meal = MealEntity.fromMealDBO(item.meal);
      final intake = IntakeEntity(
        id: IdGenerator.getUniqueID(),
        unit: item.unit,
        amount: item.amount * multiplier,
        type: intakeType,
        meal: meal,
        dateTime: _day,
        groupId: groupId,
        groupName: groupName,
      );

      await addIntakeUsecase.addIntake(intake);
      await addTrackedDayUsecase.addDayCaloriesTracked(_day, intake.totalKcal);
      await addTrackedDayUsecase.addDayMacrosTracked(_day,
          carbsTracked: intake.totalCarbsGram,
          fatTracked: intake.totalFatsGram,
          proteinTracked: intake.totalProteinsGram,
          sodiumTracked: intake.totalSodiumMg,
          caffeineTracked: intake.totalCaffeineMg);
    }

    locator<HomeBloc>().add(const LoadItemsEvent());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$groupName logged!')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _deletePreset(MealPresetDBO preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete saved meal?'),
        content: Text('Delete "${preset.name}"?'),
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
      final dataSource = locator<MealPresetDataSource>();
      await dataSource.deletePreset(preset.id);
      _loadPresets();
    }
  }

  String _foodCountLabel(int count) {
    if (count == 1) {
      return '1 food';
    }
    return '$count foods';
  }
}

/// Static helper to save a reusable meal from anywhere (e.g. after Magic meal
/// breakdown).
Future<void> saveAsPreset(
    BuildContext context, String name, List<MealPresetItemDBO> items,
    {String? imagePath}) async {
  final dataSource = locator<MealPresetDataSource>();
  final preset = MealPresetDBO(
    id: IdGenerator.getUniqueID(),
    name: name,
    items: items,
    imagePath: imagePath,
  );
  await dataSource.addPreset(preset);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved meal "$name" saved!')),
    );
  }
}

class PresetsScreenArguments {
  final AddMealType mealType;
  final DateTime day;

  PresetsScreenArguments(this.mealType, this.day);
}

class _PresetDetailSheet extends StatefulWidget {
  final MealPresetDBO preset;
  final VoidCallback onLog;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final Future<void> Function(int index, double newAmount) onUpdateItem;
  final Future<void> Function(int index) onRemoveItem;

  const _PresetDetailSheet({
    required this.preset,
    required this.onLog,
    required this.onDelete,
    required this.onRename,
    required this.onUpdateItem,
    required this.onRemoveItem,
  });

  @override
  State<_PresetDetailSheet> createState() => _PresetDetailSheetState();
}

class _PresetDetailSheetState extends State<_PresetDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final totalKcal = widget.preset.items.fold<double>(0, (sum, item) {
      final meal = MealEntity.fromMealDBO(item.meal);
      return sum + (item.amount * (meal.nutriments.energyPerUnit ?? 0));
    });

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (widget.preset.imagePath != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FoodImage(
                    imageUrl: widget.preset.imagePath,
                    width: double.infinity,
                    height: 160,
                  ),
                ),
              ),

            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.preset.name,
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(
                          '${_foodCountLabel(widget.preset.items.length)} · ${totalKcal.toInt()} ${S.of(context).kcalLabel}',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Rename',
                  onPressed: widget.onRename,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete',
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            const Divider(),

            // Items list
            ...widget.preset.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final meal = MealEntity.fromMealDBO(item.meal);
              final itemKcal =
                  item.amount * (meal.nutriments.energyPerUnit ?? 0);

              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(meal.name ?? '?'),
                subtitle:
                    Text('${MealPortionHelper.formatStoredAmount(meal, item.amount, item.unit)} · ${itemKcal.toInt()} kcal'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => _editItemAmount(index, item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      onPressed: () {
                        widget.onRemoveItem(index);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),

            // Log button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.onLog,
                icon: const Icon(Icons.add),
                label: Text('Log ${widget.preset.name}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editItemAmount(int index, MealPresetItemDBO item) {
    final meal = MealEntity.fromMealDBO(item.meal);
    final controller = TextEditingController(
      text: MealPortionHelper.formatValue(
        MealPortionHelper.fromBaseAmount(meal, item.amount, item.unit),
      ),
    );

    showDialog(
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
              final newAmount = double.tryParse(controller.text);
              if (newAmount != null && newAmount > 0) {
                widget.onUpdateItem(
                  index,
                  MealPortionHelper.toBaseAmount(meal, newAmount, item.unit),
                );
                Navigator.pop(ctx);
                Navigator.pop(context); // close bottom sheet too
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  String _foodCountLabel(int count) {
    if (count == 1) {
      return '1 food';
    }
    return '$count foods';
  }
}
