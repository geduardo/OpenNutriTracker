import 'package:opennutritracker/features/strategy/data/dbo/goal_strategy_dbo.dart';

class StrategyRatePolicy {
  static const double maintainPctPerWeek = 0.0;
  static const double minLosePctPerWeek = 0.25;
  static const double defaultLosePctPerWeek = 0.5;
  static const double maxLosePctPerWeek = 1.0;
  static const double minGainPctPerWeek = 0.1;
  static const double defaultGainPctPerWeek = 0.25;
  static const double maxGainPctPerWeek = 0.5;

  static double defaultRateForMode(StrategyGoalModeDBO mode) => switch (mode) {
        StrategyGoalModeDBO.lose => defaultLosePctPerWeek,
        StrategyGoalModeDBO.maintain => maintainPctPerWeek,
        StrategyGoalModeDBO.gain => defaultGainPctPerWeek,
      };

  static double minRateForMode(StrategyGoalModeDBO mode) => switch (mode) {
        StrategyGoalModeDBO.lose => minLosePctPerWeek,
        StrategyGoalModeDBO.maintain => maintainPctPerWeek,
        StrategyGoalModeDBO.gain => minGainPctPerWeek,
      };

  static double maxRateForMode(StrategyGoalModeDBO mode) => switch (mode) {
        StrategyGoalModeDBO.lose => maxLosePctPerWeek,
        StrategyGoalModeDBO.maintain => maintainPctPerWeek,
        StrategyGoalModeDBO.gain => maxGainPctPerWeek,
      };

  static double clampRateForMode(
      StrategyGoalModeDBO mode, double ratePctPerWeek) {
    if (mode == StrategyGoalModeDBO.maintain) {
      return maintainPctPerWeek;
    }

    return ratePctPerWeek
        .clamp(minRateForMode(mode), maxRateForMode(mode))
        .toDouble();
  }

  static double toKgPerWeek({
    required double pctPerWeek,
    required double bodyWeightKg,
  }) {
    if (bodyWeightKg <= 0) {
      return 0.0;
    }

    return bodyWeightKg * pctPerWeek / 100;
  }

  static double toPctPerWeek({
    required double kgPerWeek,
    required double bodyWeightKg,
  }) {
    if (bodyWeightKg <= 0) {
      return 0.0;
    }

    return kgPerWeek * 100 / bodyWeightKg;
  }

  static double signedKgPerWeek({
    required StrategyGoalModeDBO mode,
    required double pctPerWeek,
    required double bodyWeightKg,
  }) {
    final absoluteKg =
        toKgPerWeek(pctPerWeek: pctPerWeek, bodyWeightKg: bodyWeightKg).abs();

    return switch (mode) {
      StrategyGoalModeDBO.lose => -absoluteKg,
      StrategyGoalModeDBO.maintain => 0.0,
      StrategyGoalModeDBO.gain => absoluteKg,
    };
  }
}
