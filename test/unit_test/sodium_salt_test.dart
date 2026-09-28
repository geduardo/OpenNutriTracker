import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/calc/sodium_calc.dart';
import 'package:opennutritracker/features/add_meal/data/dto/ai/ai_nutrition_dto.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

void main() {
  test('salt is 2.5 times sodium', () {
    expect(SodiumCalc.saltGToSodiumMg(1.0), closeTo(400, 1e-9));
    expect(SodiumCalc.sodiumMgToSaltG(2000), closeTo(5.0, 1e-9));
  });

  test('Open Food Facts sodium prefers the label salt value', () {
    // Corn Flakes: salt 1.1 g, sodium 0.44 g per 100 g.
    expect(MealNutrimentsEntity.offSodiumMg(saltG: 1.1, sodiumG: 0.44),
        closeTo(440, 1e-9));
    // Red Bull has a broken sodium field (40 g) next to salt 0.1 g.
    expect(MealNutrimentsEntity.offSodiumMg(saltG: 0.1, sodiumG: 40),
        closeTo(40, 1e-9));
    // Products that only list sodium.
    expect(MealNutrimentsEntity.offSodiumMg(sodiumG: 0.5), closeTo(500, 1e-9));
    expect(MealNutrimentsEntity.offSodiumMg(), isNull);
  });

  test('AI label values: salt is converted, sodium is kept', () {
    AiNutrimentsPer100gDTO parse(Map<String, dynamic> extra) =>
        AiNutrimentsPer100gDTO.fromJson({
          'energy_kcal': 100,
          'protein_g': 1,
          'carbohydrates_g': 1,
          'fat_g': 1,
          ...extra,
        });

    expect(parse({'salt_g': 1.2, 'sodium_mg': null}).resolvedSodiumMg,
        closeTo(480, 1e-9));
    expect(parse({'salt_g': 1.2, 'sodium_mg': 470}).resolvedSodiumMg, 470);
    expect(parse({'sodium_mg': 300}).resolvedSodiumMg, 300);
    expect(parse({}).resolvedSodiumMg, isNull);
  });
}
