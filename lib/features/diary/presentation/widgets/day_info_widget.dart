import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/copy_or_delete_dialog.dart';
import 'package:opennutritracker/core/presentation/widgets/copy_dialog.dart';
import 'package:opennutritracker/core/presentation/widgets/delete_dialog.dart';
import 'package:opennutritracker/core/utils/calc/macro_calc.dart';
import 'package:opennutritracker/core/utils/custom_icons.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/home/presentation/widgets/dashboard_widget.dart';
import 'package:opennutritracker/features/home/presentation/widgets/intake_vertical_list.dart';
import 'package:opennutritracker/generated/l10n.dart';

class DayInfoWidget extends StatelessWidget {
  final DateTime selectedDay;
  final TrackedDayEntity? trackedDayEntity;
  final List<IntakeEntity> breakfastIntake;
  final List<IntakeEntity> lunchIntake;
  final List<IntakeEntity> dinnerIntake;
  final List<IntakeEntity> snackIntake;

  final bool usesImperialUnits;
  final Function(IntakeEntity intake, TrackedDayEntity? trackedDayEntity)
      onDeleteIntake;
  final Function(IntakeEntity intake, TrackedDayEntity? trackedDayEntity,
      AddMealType? type) onCopyIntake;

  const DayInfoWidget({
    super.key,
    required this.selectedDay,
    required this.trackedDayEntity,
    required this.breakfastIntake,
    required this.lunchIntake,
    required this.dinnerIntake,
    required this.snackIntake,
    required this.usesImperialUnits,
    required this.onDeleteIntake,
    required this.onCopyIntake,
  });

  @override
  Widget build(BuildContext context) {
    final trackedDay = trackedDayEntity;
    // Always compute the displayed totals from the loaded intake lists rather
    // than reading the cached aggregate on TrackedDayEntity. The cache can
    // drift out of sync with the actual intakes (rapid edit/delete sequences,
    // crashes mid-update, legacy records without macro fields, etc.) and the
    // home page never trusts it either — it sums on every render. Only the
    // goals come from the cached entity.
    final kcalSupplied = _sumKcal();
    final kcalGoal = trackedDay?.calorieGoal ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (trackedDay == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(S.of(context).nothingAddedLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7))),
          )
        else
          DashboardWidget(
            showDateHeader: false,
            totalKcalSupplied: kcalSupplied,
            totalKcalDaily: kcalGoal,
            totalKcalLeft: kcalGoal - kcalSupplied,
            totalCarbsIntake: _sumCarbs(),
            totalFatsIntake: _sumFats(),
            totalProteinsIntake: _sumProteins(),
            totalSugarsIntake: _sumSugars(),
            totalSodiumIntake: _sumSodium(),
            totalCarbsGoal: trackedDay.carbsGoal ?? 0,
            totalFatsGoal: trackedDay.fatGoal ?? 0,
            totalProteinsGoal: trackedDay.proteinGoal ?? 0,
            totalSodiumGoal:
                trackedDay.sodiumGoal ?? MacroCalc.defaultSodiumGoalMg,
          ),
        const SizedBox(height: 8.0),
        IntakeVerticalList(
          day: selectedDay,
          title: S.of(context).breakfastLabel,
          listIcon: Icons.bakery_dining_outlined,
          addMealType: AddMealType.breakfastType,
          intakeList: breakfastIntake,
          onDeleteIntakeCallback: onDeleteIntake,
          onItemLongPressedCallback: onIntakeItemLongPressed,
          onCopyIntakeCallback: DateUtils.isSameDay(selectedDay, DateTime.now())
              ? null
              : onCopyIntake,
          usesImperialUnits: usesImperialUnits,
          trackedDayEntity: trackedDay,
        ),
        IntakeVerticalList(
          day: selectedDay,
          title: S.of(context).lunchLabel,
          listIcon: Icons.lunch_dining_outlined,
          addMealType: AddMealType.lunchType,
          intakeList: lunchIntake,
          onDeleteIntakeCallback: onDeleteIntake,
          onItemLongPressedCallback: onIntakeItemLongPressed,
          usesImperialUnits: usesImperialUnits,
          onCopyIntakeCallback: DateUtils.isSameDay(selectedDay, DateTime.now())
              ? null
              : onCopyIntake,
          trackedDayEntity: trackedDay,
        ),
        IntakeVerticalList(
          day: selectedDay,
          title: S.of(context).dinnerLabel,
          listIcon: Icons.dinner_dining_outlined,
          addMealType: AddMealType.dinnerType,
          intakeList: dinnerIntake,
          onDeleteIntakeCallback: onDeleteIntake,
          onItemLongPressedCallback: onIntakeItemLongPressed,
          onCopyIntakeCallback: DateUtils.isSameDay(selectedDay, DateTime.now())
              ? null
              : onCopyIntake,
          usesImperialUnits: usesImperialUnits,
        ),
        IntakeVerticalList(
          day: selectedDay,
          title: S.of(context).snackLabel,
          listIcon: CustomIcons.food_apple_outline,
          addMealType: AddMealType.snackType,
          intakeList: snackIntake,
          onDeleteIntakeCallback: onDeleteIntake,
          onItemLongPressedCallback: onIntakeItemLongPressed,
          usesImperialUnits: usesImperialUnits,
          onCopyIntakeCallback: DateUtils.isSameDay(selectedDay, DateTime.now())
              ? null
              : onCopyIntake,
          trackedDayEntity: trackedDay,
        ),
        const SizedBox(height: 16.0),
      ],
    );
  }

  Iterable<IntakeEntity> get _allIntakes sync* {
    yield* breakfastIntake;
    yield* lunchIntake;
    yield* dinnerIntake;
    yield* snackIntake;
  }

  double _sumKcal() =>
      _allIntakes.fold<double>(0, (s, i) => s + i.totalKcal);

  double _sumCarbs() =>
      _allIntakes.fold<double>(0, (s, i) => s + i.totalCarbsGram);

  double _sumFats() =>
      _allIntakes.fold<double>(0, (s, i) => s + i.totalFatsGram);

  double _sumProteins() =>
      _allIntakes.fold<double>(0, (s, i) => s + i.totalProteinsGram);

  double _sumSugars() =>
      _allIntakes.fold<double>(0, (s, i) => s + i.totalSugarsGram);

  double _sumSodium() =>
      _allIntakes.fold<double>(0, (s, i) => s + i.totalSodiumMg);

  void showCopyOrDeleteIntakeDialog(
      BuildContext context, IntakeEntity intakeEntity) async {
    final copyOrDelete = await showDialog<bool>(
        context: context, builder: (context) => const CopyOrDeleteDialog());
    if (context.mounted) {
      if (copyOrDelete != null && !copyOrDelete) {
        showDeleteIntakeDialog(context, intakeEntity);
      } else if (copyOrDelete != null && copyOrDelete) {
        showCopyDialog(context, intakeEntity);
      }
    }
  }

  void showCopyDialog(BuildContext context, IntakeEntity intakeEntity) async {
    const copyDialog = CopyDialog();
    final selectedMealType = await showDialog<AddMealType>(
        context: context, builder: (context) => copyDialog);
    if (selectedMealType != null) {
      onCopyIntake(intakeEntity, null, selectedMealType);
    }
  }

  void showDeleteIntakeDialog(
      BuildContext context, IntakeEntity intakeEntity) async {
    final shouldDeleteIntake = await showDialog<bool>(
        context: context, builder: (context) => const DeleteDialog());
    if (shouldDeleteIntake != null) {
      onDeleteIntake(intakeEntity, trackedDayEntity);
    }
  }

  void onIntakeItemLongPressed(
      BuildContext context, IntakeEntity intakeEntity) async {
    if (DateUtils.isSameDay(selectedDay, DateTime.now())) {
      showDeleteIntakeDialog(context, intakeEntity);
    } else {
      showCopyOrDeleteIntakeDialog(context, intakeEntity);
    }
  }
}
