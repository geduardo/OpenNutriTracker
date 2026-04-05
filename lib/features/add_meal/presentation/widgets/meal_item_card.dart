import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/add_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_macro_goal_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/meal_value_unit_text.dart';
import 'package:opennutritracker/core/utils/id_generator.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class MealItemCard extends StatelessWidget {
  final DateTime day;
  final AddMealType addMealType;
  final MealEntity mealEntity;
  final bool usesImperialUnits;

  const MealItemCard(
      {super.key,
      required this.day,
      required this.mealEntity,
      required this.addMealType,
      required this.usesImperialUnits});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: InkWell(
        onTap: () => _showQuickAddSheet(context),
        onLongPress: () => _goToDetailScreen(context),
        child: SizedBox(
          height: 100,
          child: Center(
              child: ListTile(
            leading: mealEntity.thumbnailImageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      cacheManager: locator<CacheManager>(),
                      fit: BoxFit.cover,
                      width: 60,
                      height: 60,
                      imageUrl: mealEntity.thumbnailImageUrl ?? "",
                    ))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                        width: 60,
                        height: 60,
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        child: const Icon(Icons.restaurant_outlined)),
                  ),
            title: AutoSizeText.rich(
                TextSpan(
                    text: mealEntity.name ?? "?",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface),
                    children: [
                      TextSpan(
                          text: ' ${mealEntity.brands ?? ""}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.8))),
                    ]),
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            subtitle: mealEntity.mealQuantity != null
                ? MealValueUnitText(
                    value: double.parse(mealEntity.mealQuantity ?? "0"),
                    meal: mealEntity,
                    usesImperialUnits: usesImperialUnits)
                : const SizedBox(),
            trailing: IconButton(
              style: IconButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              icon: const Icon(Icons.info_outline),
              onPressed: () => _goToDetailScreen(context),
            ),
          )),
        ),
      ),
    );
  }

  void _goToDetailScreen(BuildContext context) {
    Navigator.of(context).pushNamed(NavigationOptions.mealDetailRoute,
        arguments: MealDetailScreenArguments(
            mealEntity, addMealType.getIntakeType(), day, usesImperialUnits));
  }

  void _showQuickAddSheet(BuildContext context) async {
    // Look up last-used quantity
    final getIntakeUsecase = locator<GetIntakeUsecase>();
    final lastIntake = await getIntakeUsecase.getLastIntakeForMeal(
        mealEntity.code, mealEntity.name);
    final defaultAmount = lastIntake?.amount ?? 100.0;
    final defaultAmountStr = defaultAmount == defaultAmount.roundToDouble()
        ? defaultAmount.toInt().toString()
        : defaultAmount.toString();

    if (!context.mounted) return;

    final quantityController = TextEditingController(text: defaultAmountStr);
    final kcalPer100 = mealEntity.nutriments.energyKcal100 ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final amount =
              double.tryParse(quantityController.text.replaceAll(',', '.')) ??
                  0;
          final totalKcal = amount * kcalPer100 / 100;

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mealEntity.name ?? '?',
                    style: Theme.of(ctx).textTheme.titleMedium),
                if (mealEntity.brands != null)
                  Text(mealEntity.brands!,
                      style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        decoration: const InputDecoration(
                          suffixText: 'g',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text('${totalKcal.toInt()} ${S.of(ctx).kcalLabel}',
                        style: Theme.of(ctx).textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: amount > 0
                        ? () => _quickAdd(ctx, amount)
                        : null,
                    icon: const Icon(Icons.add),
                    label: Text(S.of(ctx).addLabel),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _quickAdd(BuildContext context, double amount) async {
    final addIntakeUsecase = locator<AddIntakeUsecase>();
    final addTrackedDayUsecase = locator<AddTrackedDayUsecase>();
    final getKcalGoalUsecase = locator<GetKcalGoalUsecase>();
    final getMacroGoalUsecase = locator<GetMacroGoalUsecase>();

    final intakeType = addMealType.getIntakeType();

    final intake = IntakeEntity(
      id: IdGenerator.getUniqueID(),
      unit: 'g',
      amount: amount,
      type: intakeType,
      meal: mealEntity,
      dateTime: day,
    );

    await addIntakeUsecase.addIntake(intake);

    // Ensure tracked day exists
    final hasTrackedDay = await addTrackedDayUsecase.hasTrackedDay(day);
    if (!hasTrackedDay) {
      final totalKcalGoal = await getKcalGoalUsecase.getKcalGoal();
      final totalCarbsGoal =
          await getMacroGoalUsecase.getCarbsGoal(totalKcalGoal);
      final totalFatGoal =
          await getMacroGoalUsecase.getFatsGoal(totalKcalGoal);
      final totalProteinGoal =
          await getMacroGoalUsecase.getProteinsGoal(totalKcalGoal);
      await addTrackedDayUsecase.addNewTrackedDay(
          day, totalKcalGoal, totalCarbsGoal, totalFatGoal, totalProteinGoal);
    }

    addTrackedDayUsecase.addDayCaloriesTracked(day, intake.totalKcal);
    addTrackedDayUsecase.addDayMacrosTracked(day,
        carbsTracked: intake.totalCarbsGram,
        fatTracked: intake.totalFatsGram,
        proteinTracked: intake.totalProteinsGram);

    locator<HomeBloc>().add(const LoadItemsEvent());

    if (context.mounted) {
      Navigator.of(context).pop(); // close bottom sheet
      Navigator.of(context).pop(); // back to home
    }
  }
}
