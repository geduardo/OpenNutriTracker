import 'dart:math';

import 'package:opennutritracker/features/strategy/domain/entity/expenditure_state_entity.dart';

/// Weekly calorie controller that turns expenditure estimate into a recommendation.
///
/// From adaptive-calorie-engine-plan.md section 4.
class WeeklyCalorieController {
  // Constants from the plan
  static const double bodyEnergyPerKg = 7700.0;
  static const double maintenanceBandKg = 0.68;
  static const double maintenanceNudgeRatePct = 0.15;
  static const double minWeeklyStep = 75.0;
  static const double maxWeeklyStep = 150.0;

  // Calorie floor — never recommend below this
  static const double absoluteMinCalories = 1200.0;

  /// Computes the proposed calorie target for the next week.
  ///
  /// [expenditureState] — latest expenditure estimate
  /// [previousCalorieTarget] — current calorie target
  /// [goalMode] — lose, maintain, or gain
  /// [targetRatePctPerWeek] — desired rate of change (% body weight / week)
  /// [targetWeightKg] — target weight for maintenance band (nullable)
  /// [trendWeightKg] — current trend weight
  static CheckInProposal computeWeeklyTarget({
    required ExpenditureStateEntity expenditureState,
    required double previousCalorieTarget,
    required GoalMode goalMode,
    required double targetRatePctPerWeek,
    double? targetWeightKg,
    required double trendWeightKg,
  }) {
    final estimatedExp = expenditureState.estimatedExpenditureKcal;
    final confidence = expenditureState.confidence;

    // 1. Determine effective rate based on goal mode
    double effectiveRatePct;
    if (goalMode == GoalMode.maintain) {
      effectiveRatePct = _maintenanceRate(
        trendWeightKg: trendWeightKg,
        targetWeightKg: targetWeightKg ?? trendWeightKg,
      );
    } else {
      effectiveRatePct = targetRatePctPerWeek;
    }

    // 2. Compute target energy balance
    final targetDeltaKgPerWeek = trendWeightKg * effectiveRatePct / 100;
    double targetEnergyBalancePerDay =
        bodyEnergyPerKg * targetDeltaKgPerWeek / 7;

    // Apply sign by mode
    if (goalMode == GoalMode.lose) {
      targetEnergyBalancePerDay = -targetEnergyBalancePerDay.abs();
    } else if (goalMode == GoalMode.gain) {
      targetEnergyBalancePerDay = targetEnergyBalancePerDay.abs();
    }
    // maintain: already signed by _maintenanceRate

    // 3. Proposed target
    final proposedCalories = estimatedExp + targetEnergyBalancePerDay;

    // 4. Controller smoothing — cap weekly step based on confidence
    final maxStep = _lerpDouble(minWeeklyStep, maxWeeklyStep, confidence);
    final delta = proposedCalories - previousCalorieTarget;
    final appliedDelta = delta.clamp(-maxStep, maxStep);
    var appliedCalories = previousCalorieTarget + appliedDelta;

    // 5. Floor
    appliedCalories = max(appliedCalories, absoluteMinCalories);

    return CheckInProposal(
      previousTarget: previousCalorieTarget,
      proposedTarget: proposedCalories,
      appliedTarget: appliedCalories,
      estimatedExpenditure: estimatedExp,
      trendWeight: trendWeightKg,
      confidence: confidence,
      effectiveRatePct: effectiveRatePct,
      targetEnergyBalancePerDay: targetEnergyBalancePerDay,
    );
  }

  /// Maintenance mode: if within band → 0 rate, outside → nudge
  static double _maintenanceRate({
    required double trendWeightKg,
    required double targetWeightKg,
  }) {
    final diff = trendWeightKg - targetWeightKg;
    if (diff.abs() <= maintenanceBandKg) {
      return 0.0; // Within band — no adjustment
    } else if (diff > 0) {
      return -maintenanceNudgeRatePct; // Above band — small loss
    } else {
      return maintenanceNudgeRatePct; // Below band — small gain
    }
  }

  static double _lerpDouble(double a, double b, double t) {
    return a + (b - a) * t.clamp(0.0, 1.0);
  }
}

enum GoalMode { lose, maintain, gain }

class CheckInProposal {
  final double previousTarget;
  final double proposedTarget;
  final double appliedTarget;
  final double estimatedExpenditure;
  final double trendWeight;
  final double confidence;
  final double effectiveRatePct;
  final double targetEnergyBalancePerDay;

  const CheckInProposal({
    required this.previousTarget,
    required this.proposedTarget,
    required this.appliedTarget,
    required this.estimatedExpenditure,
    required this.trendWeight,
    required this.confidence,
    required this.effectiveRatePct,
    required this.targetEnergyBalancePerDay,
  });
}
