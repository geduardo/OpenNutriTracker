import 'dart:math' as math;
import '../core/domain/entity/intake_entity.dart';
import '../features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'pregnancy_model.dart';

class NutrientReference {
  final String key, name, unit, kind;
  final double target;
  const NutrientReference(this.key, this.name, this.unit, this.target,
      [this.kind = 'RDA']);
}

const pregnancyMicroReferences = [
  NutrientReference('folate_dfe_ug', 'Folate', 'µg DFE', 600),
  NutrientReference('iron_mg', 'Iron', 'mg', 27),
  NutrientReference('calcium_mg', 'Calcium', 'mg', 1000),
  NutrientReference('iodine_ug', 'Iodine', 'µg', 220),
  NutrientReference('choline_mg', 'Choline', 'mg', 450, 'AI'),
  NutrientReference('vitamin_d_ug', 'Vitamin D', 'µg', 15),
  NutrientReference('vitamin_b12_ug', 'Vitamin B12', 'µg', 2.6),
];

/// Adult reference amounts. ACOG additions apply to known pre-pregnancy
/// maintenance, never to a deficit or an adaptive estimate from pregnancy gain.
class PregnancyTargets {
  final PregnancyProfile? profile;
  final DateTime day;
  PregnancyTargets(this.profile, this.day);
  bool get inPregnancy =>
      profile != null && PregnancyDating.supports(profile!, day);
  int get trimester => !inPregnancy
      ? 0
      : profile!.gestationDays(day) < 14 * 7
          ? 1
          : profile!.gestationDays(day) < 28 * 7
              ? 2
              : 3;
  double get extraKcal => trimester == 2
      ? 340
      : trimester == 3
          ? 450
          : 0;
  double? get energy {
    if (!inPregnancy) return null;
    if (profile!.clinicianEnergyKcal != null) {
      return profile!.clinicianEnergyKcal;
    }
    if (profile!.type != PregnancyType.singleton ||
        profile!.maintenanceKcal == null) {
      return null;
    }
    return profile!.maintenanceKcal! + extraKcal;
  }

  // Practical 50/20/30 plan if energy is supplied, not a unique DRI ratio.
  double get carbs => energy == null ? 175 : math.max(175, energy! * .50 / 4);
  double get protein => energy == null ? 71 : math.max(71, energy! * .20 / 4);
  double? get fat => energy == null ? null : energy! * .30 / 9;
}

/// Known totals and coverage are separate. Unknown != zero.
/// Inherited diary amounts are normalized to g/ml.
class NutrientTotal {
  final double amount;
  final int known, missing, estimated;
  const NutrientTotal(this.amount, this.known, this.missing, this.estimated);
  static NutrientTotal fromIntakes(Iterable<IntakeEntity> intakes, String key) {
    double total = 0;
    int known = 0, missing = 0, estimated = 0;
    for (final intake in intakes) {
      if (intake.amount <= 0) continue;
      final n = intake.meal.nutriments;
      final value = per100(n, key);
      if (value == null || !value.isFinite || value < 0) {
        missing++;
        continue;
      }
      total += value * intake.amount / 100;
      known++;
      if (n.nutritionDataKind == 'ai_estimate' ||
          (n.nutritionDataKind == null && intake.meal.source.name == 'ai')) {
        estimated++;
      }
    }
    return NutrientTotal(total, known, missing, estimated);
  }

  static double? per100(MealNutrimentsEntity n, String key) => switch (key) {
        'energy' => n.energyKcal100,
        'carbs' => n.carbohydrates100,
        'protein' => n.proteins100,
        'fat' => n.fat100,
        'fiber' => n.fiber100,
        'caffeine' => n.caffeineMg100,
        _ => n.micronutrients100[key],
      };
}
