import 'package:hive_flutter/hive_flutter.dart';

part 'goal_strategy_dbo_adapter.dart';

@HiveType(typeId: 24)
class GoalStrategyDBO extends HiveObject {
  @HiveField(0)
  final StrategyGoalModeDBO mode;

  @HiveField(1)
  final double? targetWeightKg;

  @HiveField(2)
  final double targetRatePctPerWeek;

  @HiveField(3)
  final MacroProgramStyleDBO macroStyle;

  @HiveField(4)
  final bool adaptiveEnabled;

  GoalStrategyDBO({
    required this.mode,
    this.targetWeightKg,
    required this.targetRatePctPerWeek,
    required this.macroStyle,
    required this.adaptiveEnabled,
  });

  factory GoalStrategyDBO.defaultStrategy() => GoalStrategyDBO(
        mode: StrategyGoalModeDBO.maintain,
        targetRatePctPerWeek: 0.0,
        macroStyle: MacroProgramStyleDBO.balanced,
        adaptiveEnabled: false,
      );
}

@HiveType(typeId: 25)
enum StrategyGoalModeDBO {
  @HiveField(0)
  lose,
  @HiveField(1)
  maintain,
  @HiveField(2)
  gain;
}

@HiveType(typeId: 26)
enum MacroProgramStyleDBO {
  @HiveField(0)
  balanced,
  @HiveField(1)
  highCarbLowFat,
  @HiveField(2)
  lowCarbHighFat,
  @HiveField(3)
  manual;
}
