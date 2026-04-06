import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/meal_portion_helper.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

void main() {
  MealEntity buildMeal({
    String? mealUnit = 'g',
    double? servingQuantity,
    String? servingUnit,
    String? servingSize,
  }) {
    return MealEntity(
      code: null,
      name: 'Test meal',
      localFoodId: null,
      brands: null,
      thumbnailImageUrl: null,
      mainImageUrl: null,
      url: null,
      mealQuantity: null,
      mealUnit: mealUnit,
      servingQuantity: servingQuantity,
      servingUnit: servingUnit,
      servingSize: servingSize,
      nutriments: const MealNutrimentsEntity(
        energyKcal100: 200,
        carbohydrates100: 20,
        fat100: 10,
        proteins100: 5,
        sugars100: null,
        saturatedFat100: null,
        fiber100: null,
        sodiumMg100: null,
      ),
      source: MealSourceEntity.custom,
    );
  }

  group('MealPortionHelper', () {
    test('converts servings to base amount', () {
      final meal = buildMeal(
        servingQuantity: 30,
        servingUnit: 'g',
        servingSize: '1 cookie (30 g)',
      );

      expect(
        MealPortionHelper.toBaseAmount(meal, 2, MealPortionHelper.servingUnit),
        60,
      );
      expect(
        MealPortionHelper.fromBaseAmount(
            meal, 60, MealPortionHelper.servingUnit),
        2,
      );
    });

    test('converts teaspoon and tablespoon to base amount', () {
      final meal = buildMeal(mealUnit: 'ml');

      expect(
        MealPortionHelper.toBaseAmount(meal, 2, MealPortionHelper.teaspoonUnit),
        10,
      );
      expect(
        MealPortionHelper.toBaseAmount(
            meal, 1.5, MealPortionHelper.tablespoonUnit),
        22.5,
      );
    });

    test('formats stored amount with custom serving name', () {
      final meal = buildMeal(
        servingQuantity: 30,
        servingUnit: 'g',
        servingSize: '1 cookie (30 g)',
      );

      expect(
        MealPortionHelper.formatStoredAmount(
            meal, 60, MealPortionHelper.servingUnit),
        '2 cookie',
      );
    });
  });
}
