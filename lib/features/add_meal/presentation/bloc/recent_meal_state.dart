part of 'recent_meal_bloc.dart';

abstract class RecentMealState extends Equatable {
  const RecentMealState();
}

class RecentMealInitial extends RecentMealState {
  @override
  List<Object> get props => [];
}

class RecentMealLoadingState extends RecentMealState {
  @override
  List<Object?> get props => [];
}

class RecentMealLoadedState extends RecentMealState {
  final List<MealEntity> recentFoods;
  final List<MealPresetDBO> recentPresets;
  final bool usesImperialUnits;

  const RecentMealLoadedState(
      {required this.recentFoods,
      required this.recentPresets,
      this.usesImperialUnits = false});

  @override
  List<Object?> get props => [recentFoods, recentPresets, usesImperialUnits];
}

class RecentMealFailedState extends RecentMealState {
  @override
  List<Object?> get props => [];
}
