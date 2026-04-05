import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/data_source/meal_preset_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_preset_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/locator.dart';
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
    final presets = await dataSource.getAllPresets();
    if (mounted) {
      setState(() {
        _presets = presets;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Presets'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _presets.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.playlist_add,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('No presets yet',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                            'Use Magic with "Meal breakdown" to create a meal, then save it as a preset.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _presets.length,
                  itemBuilder: (context, index) =>
                      _buildPresetCard(_presets[index]),
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
        onTap: () => _logPreset(preset),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(preset.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${preset.items.length} items · ${totalKcal.toInt()} ${S.of(context).kcalLabel}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preset.items
                          .map((i) =>
                              '${MealEntity.fromMealDBO(i.meal).name ?? "?"} ${i.amount.toInt()}g')
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
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deletePreset(preset),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logPreset(MealPresetDBO preset) async {
    final addIntakeUsecase = locator<AddIntakeUsecase>();
    final addTrackedDayUsecase = locator<AddTrackedDayUsecase>();
    final getKcalGoalUsecase = locator<GetKcalGoalUsecase>();
    final getMacroGoalUsecase = locator<GetMacroGoalUsecase>();

    final intakeType = _mealType.getIntakeType();
    final groupId = IdGenerator.getUniqueID();

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
      await addTrackedDayUsecase.addNewTrackedDay(
          _day, totalKcalGoal, totalCarbsGoal, totalFatGoal, totalProteinGoal);
    }

    for (final item in preset.items) {
      final meal = MealEntity.fromMealDBO(item.meal);
      final intake = IntakeEntity(
        id: IdGenerator.getUniqueID(),
        unit: item.unit,
        amount: item.amount,
        type: intakeType,
        meal: meal,
        dateTime: _day,
        groupId: groupId,
        groupName: preset.name,
      );

      await addIntakeUsecase.addIntake(intake);
      addTrackedDayUsecase.addDayCaloriesTracked(_day, intake.totalKcal);
      addTrackedDayUsecase.addDayMacrosTracked(_day,
          carbsTracked: intake.totalCarbsGram,
          fatTracked: intake.totalFatsGram,
          proteinTracked: intake.totalProteinsGram);
    }

    locator<HomeBloc>().add(const LoadItemsEvent());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${preset.name} logged!')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _deletePreset(MealPresetDBO preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete preset?'),
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
}

/// Static helper to save a preset from anywhere (e.g. after Magic meal breakdown)
Future<void> saveAsPreset(
    BuildContext context, String name, List<MealPresetItemDBO> items) async {
  final dataSource = locator<MealPresetDataSource>();
  final preset = MealPresetDBO(
    id: IdGenerator.getUniqueID(),
    name: name,
    items: items,
  );
  await dataSource.addPreset(preset);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Preset "$name" saved!')),
    );
  }
}

class PresetsScreenArguments {
  final AddMealType mealType;
  final DateTime day;

  PresetsScreenArguments(this.mealType, this.day);
}
