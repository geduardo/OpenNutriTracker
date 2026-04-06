import 'dart:math';

/// Derives macro goals from a calorie target and body weight.
///
/// From adaptive-calorie-engine-plan.md section 5.
/// Order: calories → protein floor → fat floor → remaining to carbs
class MacroProgramService {
  /// Compute macro targets from calorie target and body weight.
  static MacroTargets computeMacros({
    required double calorieTarget,
    required double bodyWeightKg,
    required MacroStyle style,
  }) {
    // 1. Protein floor: 1.6g/kg, clamped 110-220g
    final proteinG = (1.6 * bodyWeightKg).clamp(110.0, 220.0);
    final proteinCal = proteinG * 4;

    // 2. Fat floor: max(0.6g/kg, 20% of calories)
    var fatG = max(0.6 * bodyWeightKg, calorieTarget * 0.20 / 9);

    // 3. Remaining calories for carbs/fat split
    final remainingCal = max(calorieTarget - proteinCal - fatG * 9, 0.0);

    // 4. Apply macro style to remaining calories
    double extraFatCal;
    double carbsCal;

    switch (style) {
      case MacroStyle.balanced:
        extraFatCal = remainingCal * 0.50;
        carbsCal = remainingCal * 0.50;
        break;
      case MacroStyle.highCarbLowFat:
        extraFatCal = remainingCal * 0.30;
        carbsCal = remainingCal * 0.70;
        break;
      case MacroStyle.lowCarbHighFat:
        extraFatCal = remainingCal * 0.70;
        carbsCal = remainingCal * 0.30;
        break;
      case MacroStyle.manual:
        // For manual, just split evenly — user overrides later
        extraFatCal = remainingCal * 0.50;
        carbsCal = remainingCal * 0.50;
        break;
    }

    fatG += extraFatCal / 9;
    final carbsG = max(carbsCal / 4, 0.0);

    return MacroTargets(
      calorieTarget: calorieTarget,
      proteinG: proteinG,
      fatG: fatG,
      carbsG: carbsG,
    );
  }
}

enum MacroStyle { balanced, highCarbLowFat, lowCarbHighFat, manual }

class MacroTargets {
  final double calorieTarget;
  final double proteinG;
  final double fatG;
  final double carbsG;

  const MacroTargets({
    required this.calorieTarget,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
  });

  double get proteinCal => proteinG * 4;
  double get fatCal => fatG * 9;
  double get carbsCal => carbsG * 4;
  double get totalCal => proteinCal + fatCal + carbsCal;
}
