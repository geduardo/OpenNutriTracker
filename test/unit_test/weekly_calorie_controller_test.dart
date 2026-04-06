import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/strategy/domain/entity/expenditure_state_entity.dart';
import 'package:opennutritracker/features/strategy/domain/service/weekly_calorie_controller.dart';

void main() {
  test('weekly controller rate limits calorie changes', () {
    final expenditureState = ExpenditureStateEntity(
      day: DateTime(2026, 4, 6),
      estimatedExpenditureKcal: 2400,
      rawExpenditureKcal: 2400,
      confidence: 1.0,
      status: ExpenditureStatus.updating,
      validNutritionDays: 21,
      recentWeighInCount: 3,
    );

    final proposal = WeeklyCalorieController.computeWeeklyTarget(
      expenditureState: expenditureState,
      previousCalorieTarget: 2400,
      goalMode: GoalMode.lose,
      targetRatePctPerWeek: 0.5,
      trendWeightKg: 80,
    );

    expect(proposal.proposedTarget, closeTo(1960, 1));
    expect(proposal.appliedTarget, 2250);
  });

  test('maintenance mode holds target inside the deadband', () {
    final expenditureState = ExpenditureStateEntity(
      day: DateTime(2026, 4, 6),
      estimatedExpenditureKcal: 2300,
      rawExpenditureKcal: 2300,
      confidence: 0.7,
      status: ExpenditureStatus.updating,
      validNutritionDays: 18,
      recentWeighInCount: 2,
    );

    final proposal = WeeklyCalorieController.computeWeeklyTarget(
      expenditureState: expenditureState,
      previousCalorieTarget: 2300,
      goalMode: GoalMode.maintain,
      targetRatePctPerWeek: 0,
      targetWeightKg: 80,
      trendWeightKg: 80.3,
    );

    expect(proposal.targetEnergyBalancePerDay, 0);
    expect(proposal.proposedTarget, 2300);
    expect(proposal.appliedTarget, 2300);
  });
}
