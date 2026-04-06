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

  GoalStrategyDBO copyWith({
    StrategyGoalModeDBO? mode,
    double? targetWeightKg,
    bool clearTargetWeightKg = false,
    double? targetRatePctPerWeek,
    MacroProgramStyleDBO? macroStyle,
    bool? adaptiveEnabled,
  }) {
    return GoalStrategyDBO(
      mode: mode ?? this.mode,
      targetWeightKg:
          clearTargetWeightKg ? null : (targetWeightKg ?? this.targetWeightKg),
      targetRatePctPerWeek: targetRatePctPerWeek ?? this.targetRatePctPerWeek,
      macroStyle: macroStyle ?? this.macroStyle,
      adaptiveEnabled: adaptiveEnabled ?? this.adaptiveEnabled,
    );
  }

  factory GoalStrategyDBO.fromJson(Map<String, dynamic> json) =>
      GoalStrategyDBO(
        mode: _modeFromJson(json['mode'] as String?),
        targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
        targetRatePctPerWeek: (json['targetRatePctPerWeek'] as num).toDouble(),
        macroStyle: _macroStyleFromJson(json['macroStyle'] as String?),
        adaptiveEnabled: json['adaptiveEnabled'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'targetWeightKg': targetWeightKg,
        'targetRatePctPerWeek': targetRatePctPerWeek,
        'macroStyle': macroStyle.name,
        'adaptiveEnabled': adaptiveEnabled,
      };

  factory GoalStrategyDBO.defaultStrategy() => GoalStrategyDBO(
        mode: StrategyGoalModeDBO.maintain,
        targetRatePctPerWeek: 0.0,
        macroStyle: MacroProgramStyleDBO.balanced,
        adaptiveEnabled: false,
      );

  static StrategyGoalModeDBO _modeFromJson(String? value) => switch (value) {
        'lose' => StrategyGoalModeDBO.lose,
        'gain' => StrategyGoalModeDBO.gain,
        _ => StrategyGoalModeDBO.maintain,
      };

  static MacroProgramStyleDBO _macroStyleFromJson(String? value) =>
      switch (value) {
        'highCarbLowFat' => MacroProgramStyleDBO.highCarbLowFat,
        'lowCarbHighFat' => MacroProgramStyleDBO.lowCarbHighFat,
        'manual' => MacroProgramStyleDBO.manual,
        _ => MacroProgramStyleDBO.balanced,
      };
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
