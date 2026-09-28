import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/data_source/local_food_data_source.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/delete_dialog.dart';
import 'package:opennutritracker/core/presentation/widgets/edit_dialog.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/meal_portion_helper.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/food_library/food_detail_page.dart';
import 'package:opennutritracker/features/home/presentation/bloc/home_bloc.dart';
import 'package:opennutritracker/generated/l10n.dart';

enum _IntakeAction { editPortion, viewDetails, delete }

/// Action sheet shown when a logged item is tapped, shared by Home and Diary
/// so both screens offer the same actions.
class IntakeItemActions {
  static Future<void> show(
    BuildContext context,
    IntakeEntity intake,
    bool usesImperialUnits, {
    required VoidCallback onChanged,
    required Future<void> Function(IntakeEntity intake) onDelete,
  }) async {
    final s = S.of(context);
    final action = await showModalBottomSheet<_IntakeAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(intake.meal.name ?? '?'),
              subtitle: Text(
                  '${MealPortionHelper.formatStoredAmount(intake.meal, intake.amount, intake.unit)} · ${intake.totalKcal.round()} ${s.kcalLabel}'),
            ),
            ListTile(
              leading: const Icon(Icons.scale_outlined),
              title: Text(s.editPortionLabel),
              onTap: () =>
                  Navigator.pop(sheetContext, _IntakeAction.editPortion),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text(s.foodDetailsLabel),
              onTap: () =>
                  Navigator.pop(sheetContext, _IntakeAction.viewDetails),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(sheetContext).colorScheme.error),
              title: Text(s.deleteLabel),
              onTap: () => Navigator.pop(sheetContext, _IntakeAction.delete),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) {
      return;
    }

    switch (action) {
      case _IntakeAction.editPortion:
        await _editAmount(context, intake, usesImperialUnits, onChanged);
      case _IntakeAction.viewDetails:
        await _openFoodDetails(context, intake);
      case _IntakeAction.delete:
        final confirmed = await showDialog<bool>(
            context: context, builder: (_) => const DeleteDialog());
        if (confirmed == true) {
          await onDelete(intake);
          onChanged();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(S.of(context).itemDeletedSnackbar)));
          }
        }
    }
  }

  static Future<void> _editAmount(
    BuildContext context,
    IntakeEntity intake,
    bool usesImperialUnits,
    VoidCallback onChanged,
  ) async {
    final newAmount = await showDialog<double>(
      context: context,
      builder: (_) => EditDialog(
        intakeEntity: intake,
        usesImperialUnits: usesImperialUnits,
      ),
    );
    if (newAmount == null) return;

    await locator<HomeBloc>()
        .updateIntakeItem(intake.id, {'amount': newAmount});
    onChanged();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).itemUpdatedSnackbar)),
      );
    }
  }

  static Future<void> _openFoodDetails(
    BuildContext context,
    IntakeEntity intake,
  ) async {
    final meal = await _resolveMealForDetails(intake.meal);
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FoodDetailPage(food: meal)),
    );
  }

  static Future<MealEntity> _resolveMealForDetails(MealEntity meal) async {
    if (meal.localFoodId != null && meal.localFoodId!.isNotEmpty) {
      return meal;
    }

    final localFoodDataSource = locator<LocalFoodDataSource>();

    final code = meal.code?.trim();
    if (code != null && code.isNotEmpty) {
      final record = await localFoodDataSource.getFoodRecordByKey(code);
      if (record != null) {
        return MealEntity.fromLocalFoodRecord(record);
      }
    }

    final name = meal.name?.trim();
    if (name != null && name.isNotEmpty) {
      final record = await localFoodDataSource.getFoodRecordByKey(name);
      if (record != null) {
        return MealEntity.fromLocalFoodRecord(record);
      }
    }

    return meal;
  }
}
