import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/locator.dart';
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
  late List<_EditableItem> _items;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    final args =
        ModalRoute.of(context)?.settings.arguments as AiResultScreenArguments;
    _response = args.response;
    _mealType = args.mealType;
    _day = args.day;
    _mode = args.mode;

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
        title: Text(_mode == MagicMode.singleItem ? 'Review item' : 'Review meal'),
      ),
      body: Column(
        children: [
          // Total summary bar
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
                    : _mode == MagicMode.singleItem
                        ? 'Add item'
                        : 'Add all (${_items.length} items)'),
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
                _macroChip('C', item.per100g.carbohydratesG * item.weightG / 100),
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
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Widget _macroChip(String label, double grams) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text('$label ${grams.toInt()}g',
          style: Theme.of(context).textTheme.bodySmall),
    );
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);

    try {
      final addIntakeUsecase = locator<AddIntakeUsecase>();
      final addTrackedDayUsecase = locator<AddTrackedDayUsecase>();
      final getKcalGoalUsecase = locator<GetKcalGoalUsecase>();
      final getMacroGoalUsecase = locator<GetMacroGoalUsecase>();

      final intakeType = _mealType.getIntakeType();
      final groupId = _mode == MagicMode.mealBreakdown
          ? IdGenerator.getUniqueID()
          : null;
      final groupName = _mode == MagicMode.mealBreakdown && _items.length > 1
          ? _items.map((i) => i.name).join(' + ')
          : null;

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

      for (final item in _items) {
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
            proteinTracked: intake.totalProteinsGram);
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

  AiResultScreenArguments({
    required this.response,
    required this.mealType,
    required this.day,
    required this.mode,
  });
}
