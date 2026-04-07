import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:opennutritracker/core/data/data_source/intake_data_source.dart';
import 'package:opennutritracker/core/data/data_source/meal_preset_data_source.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/get_intake_usecase.dart';
import 'package:opennutritracker/core/presentation/widgets/meal_multiplier_dialog.dart';
import 'package:opennutritracker/core/data/dbo/meal_preset_dbo.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

part 'recent_meal_event.dart';

part 'recent_meal_state.dart';

class RecentMealBloc extends Bloc<RecentMealEvent, RecentMealState> {
  final log = Logger('RecentMealBloc');

  final GetIntakeUsecase _getIntakeUsecase;
  final GetConfigUsecase _getConfigUsecase;
  final MealPresetDataSource _mealPresetDataSource;
  final IntakeDataSource _intakeDataSource;

  RecentMealBloc(
    this._getIntakeUsecase,
    this._getConfigUsecase,
    this._mealPresetDataSource,
    this._intakeDataSource,
  )
      : super(RecentMealInitial()) {
    on<LoadRecentMealEvent>((event, emit) async {
      emit(RecentMealLoadingState());
      try {
        final config = await _getConfigUsecase.getConfig();
        final recentIntake = await _getIntakeUsecase.getRecentIntake();
        final presets = await _mealPresetDataSource.getAllPresets();
        final allIntakes = await _intakeDataSource.getAllIntakes();
        final searchString = (event.searchString).toLowerCase();
        final presetImagesByBaseName = <String, String?>{
          for (final preset in presets) preset.name.toLowerCase(): preset.imagePath,
        };
        final groupedIntakes = <String, List<IntakeDBO>>{};

        for (final intake in allIntakes) {
          final groupId = intake.groupId?.trim();
          if (groupId == null || groupId.isEmpty) {
            continue;
          }
          groupedIntakes.putIfAbsent(groupId, () => []).add(intake);
        }

        final latestRecentMeals = <String, _RecentGroupedMeal>{};
        for (final entry in groupedIntakes.entries) {
          final groupIntakes = entry.value;
          if (groupIntakes.isEmpty) {
            continue;
          }

          final groupName = groupIntakes.first.groupName?.trim();
          if (groupName == null || groupName.isEmpty) {
            continue;
          }

          DateTime latestUsedAt = groupIntakes.first.dateTime;
          for (final intake in groupIntakes.skip(1)) {
            if (intake.dateTime.isAfter(latestUsedAt)) {
              latestUsedAt = intake.dateTime;
            }
          }

          final key = groupName.toLowerCase();
          final existing = latestRecentMeals[key];
          if (existing != null && !latestUsedAt.isAfter(existing.latestUsedAt)) {
            continue;
          }

          final baseName = parseMealGroupName(groupName).baseName.toLowerCase();
          latestRecentMeals[key] = _RecentGroupedMeal(
            latestUsedAt: latestUsedAt,
            preset: MealPresetDBO(
              id: entry.key,
              name: groupName,
              items: groupIntakes
                  .map((intake) => MealPresetItemDBO(
                        meal: intake.meal,
                        amount: intake.amount,
                        unit: intake.unit,
                      ))
                  .toList(),
              imagePath: presetImagesByBaseName[baseName],
            ),
          );
        }

        final recentPresets = latestRecentMeals.values.toList()
          ..sort((a, b) => b.latestUsedAt.compareTo(a.latestUsedAt));

        if (searchString.isEmpty) {
          emit(RecentMealLoadedState(
              recentFoods: recentIntake.map((intake) => intake.meal).toList(),
              recentPresets: recentPresets.map((entry) => entry.preset).toList(),
              usesImperialUnits: config.usesImperialUnits));
        } else {
          emit(RecentMealLoadedState(
              recentFoods: recentIntake
                  .where(matchesSearchString(searchString))
                  .map((intake) => intake.meal)
                  .toList(),
              recentPresets: recentPresets
                  .map((entry) => entry.preset)
                  .where(matchesPresetSearchString(searchString))
                  .toList(),
              usesImperialUnits: config.usesImperialUnits));
        }
      } catch (error) {
        log.severe(error);
        emit(RecentMealFailedState());
      }
    });
  }

  bool Function(IntakeEntity) matchesSearchString(String searchString) {
    return (intake) =>
        (intake.meal.name?.toLowerCase().contains(searchString) ?? false) ||
        (intake.meal.brands?.toLowerCase().contains(searchString) ?? false);
  }

  bool Function(MealPresetDBO) matchesPresetSearchString(String searchString) {
    return (preset) =>
        preset.name.toLowerCase().contains(searchString) ||
        preset.items.any((item) =>
            (item.meal.name?.toLowerCase().contains(searchString) ?? false));
  }
}

class _RecentGroupedMeal {
  final MealPresetDBO preset;
  final DateTime latestUsedAt;

  const _RecentGroupedMeal({
    required this.preset,
    required this.latestUsedAt,
  });
}
