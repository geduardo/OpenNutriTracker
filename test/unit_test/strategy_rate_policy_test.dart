import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/features/strategy/data/dbo/goal_strategy_dbo.dart';
import 'package:opennutritracker/features/strategy/domain/service/strategy_rate_policy.dart';

void main() {
  test('loss and gain rates clamp to supported bounds', () {
    expect(
      StrategyRatePolicy.clampRateForMode(StrategyGoalModeDBO.lose, 2.0),
      StrategyRatePolicy.maxLosePctPerWeek,
    );
    expect(
      StrategyRatePolicy.clampRateForMode(StrategyGoalModeDBO.gain, 0.01),
      StrategyRatePolicy.minGainPctPerWeek,
    );
    expect(
      StrategyRatePolicy.clampRateForMode(StrategyGoalModeDBO.maintain, 0.4),
      0,
    );
  });

  test('signed weekly kg change reflects goal direction', () {
    expect(
      StrategyRatePolicy.signedKgPerWeek(
        mode: StrategyGoalModeDBO.lose,
        pctPerWeek: 0.5,
        bodyWeightKg: 80,
      ),
      closeTo(-0.4, 0.0001),
    );
    expect(
      StrategyRatePolicy.signedKgPerWeek(
        mode: StrategyGoalModeDBO.gain,
        pctPerWeek: 0.25,
        bodyWeightKg: 80,
      ),
      closeTo(0.2, 0.0001),
    );
  });
}
