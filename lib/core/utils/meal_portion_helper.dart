import 'package:opennutritracker/core/utils/calc/unit_calc.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

class MealPortionHelper {
  static const servingUnit = 'serving';
  static const teaspoonUnit = 'tsp';
  static const tablespoonUnit = 'tbsp';

  static const teaspoonEquivalent = 5.0;
  static const tablespoonEquivalent = 15.0;

  static String resolveBaseUnit(MealEntity meal) {
    if (meal.mealUnit == 'ml') {
      return 'ml';
    }
    if (meal.mealUnit == 'g') {
      return 'g';
    }
    if (meal.servingUnit == 'ml') {
      return 'ml';
    }
    return 'g';
  }

  static bool supportsSpoonUnits(MealEntity meal) {
    return meal.isLiquid || meal.isSolid || meal.mealUnit == 'g/ml';
  }

  static double toBaseAmount(MealEntity meal, double amount, String unit) {
    switch (unit) {
      case servingUnit:
        return amount * (meal.servingQuantity ?? 1);
      case teaspoonUnit:
        return amount * teaspoonEquivalent;
      case tablespoonUnit:
        return amount * tablespoonEquivalent;
      case 'oz':
        return UnitCalc.ozToG(amount);
      case 'fl oz':
      case 'fl.oz':
        return UnitCalc.flOzToMl(amount);
      default:
        return amount;
    }
  }

  static double fromBaseAmount(MealEntity meal, double baseAmount, String unit) {
    switch (unit) {
      case servingUnit:
        final equivalent = meal.servingQuantity ?? 1;
        return equivalent == 0 ? 0 : baseAmount / equivalent;
      case teaspoonUnit:
        return baseAmount / teaspoonEquivalent;
      case tablespoonUnit:
        return baseAmount / tablespoonEquivalent;
      case 'oz':
        return UnitCalc.gToOz(baseAmount);
      case 'fl oz':
      case 'fl.oz':
        return UnitCalc.mlToFlOz(baseAmount);
      default:
        return baseAmount;
    }
  }

  static String unitLabel(MealEntity meal, String unit) {
    switch (unit) {
      case servingUnit:
        return servingName(meal) ?? servingUnit;
      case tablespoonUnit:
        return 'tbsp';
      case teaspoonUnit:
        return 'tsp';
      case 'fl.oz':
        return 'fl oz';
      default:
        return unit;
    }
  }

  static String dropdownLabel(MealEntity meal, String unit) {
    switch (unit) {
      case servingUnit:
        return meal.servingSize ??
            '1 serving (${_format(meal.servingQuantity)} ${meal.servingUnit ?? resolveBaseUnit(meal)})';
      case tablespoonUnit:
        return '1 tbsp (${_format(tablespoonEquivalent)} ${resolveBaseUnit(meal)})';
      case teaspoonUnit:
        return '1 tsp (${_format(teaspoonEquivalent)} ${resolveBaseUnit(meal)})';
      default:
        return unitLabel(meal, unit);
    }
  }

  static String formatStoredAmount(
    MealEntity meal,
    double baseAmount,
    String unit,
  ) {
    final displayAmount = fromBaseAmount(meal, baseAmount, unit);
    return '${_format(displayAmount)} ${unitLabel(meal, unit)}';
  }

  static String? servingName(MealEntity meal) {
    final raw = meal.servingSize?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final match = RegExp(r'^\s*1\s+(.+?)\s*(?:\(|$)').firstMatch(raw);
    if (match != null) {
      final name = match.group(1)?.trim();
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }
    return raw;
  }

  static String? buildServingDisplayLabel({
    required String label,
    required double amount,
    required String unit,
  }) {
    final trimmed = label.trim();
    if (trimmed.isEmpty || amount <= 0) {
      return null;
    }
    return '1 $trimmed (${_format(amount)} $unit)';
  }

  static String formatValue(double value) => _format(value);

  static String _format(double? value) {
    if (value == null) {
      return '?';
    }

    final rounded = value.toStringAsFixed(2);
    if (rounded.endsWith('00')) {
      return rounded.substring(0, rounded.length - 3);
    }
    if (rounded.endsWith('0')) {
      return rounded.substring(0, rounded.length - 1);
    }
    return rounded;
  }
}
