import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/add_meal/data/dto/ai/ai_nutrition_dto.dart';
import 'package:opennutritracker/features/add_meal/data/dto/off/off_product_nutriments_dto.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';
import 'package:opennutritracker/pregnancy/pregnancy_controller.dart';
import 'package:opennutritracker/pregnancy/pregnancy_dashboard.dart';
import 'package:opennutritracker/pregnancy/pregnancy_model.dart';
import 'package:opennutritracker/pregnancy/pregnancy_store.dart';
import 'package:opennutritracker/pregnancy/pregnancy_targets.dart';
import 'package:opennutritracker/pregnancy/pregnancy_theme.dart';

class MemoryStore implements PregnancyStore {
  PregnancyData data = PregnancyData();
  @override
  Future<PregnancyData> read() async => data;
  @override
  Future<void> write(PregnancyData next) async {
    data = next;
  }

  @override
  Future<void> clear() async {
    data = PregnancyData();
  }
}

final day = DateTime(2026, 9, 28);
PregnancyProfile profile(int weeks,
        {double? maintenance = 2000,
        double? clinician,
        PregnancyType type = PregnancyType.singleton}) =>
    PregnancyProfile(
        dueDate: PregnancyDating.dueDateFromStage(
            onDate: day, weeks: weeks, days: 0),
        maintenanceKcal: maintenance,
        clinicianEnergyKcal: clinician,
        type: type);
MealNutrimentsEntity nutrients(
        {Map<String, double> micros = const {}, String? kind}) =>
    MealNutrimentsEntity(
        energyKcal100: 200,
        carbohydrates100: 25,
        fat100: 8,
        proteins100: 10,
        sugars100: null,
        saturatedFat100: null,
        fiber100: 3,
        micronutrients100: micros,
        nutritionDataKind: kind);
IntakeEntity intake(String id, double grams, MealNutrimentsEntity n) =>
    IntakeEntity(
        id: id,
        unit: 'g',
        amount: grams,
        type: IntakeTypeEntity.breakfast,
        dateTime: day,
        meal: MealEntity.empty().copyWith(name: 'Test food', nutriments: n));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() async {
    await locator.reset();
  });
  test(
      'trimester boundaries, override and multiples do not invoke weight-loss logic',
      () {
    expect(PregnancyTargets(profile(13), day).energy, 2000);
    expect(PregnancyTargets(profile(14), day).energy, 2340);
    expect(PregnancyTargets(profile(27), day).energy, 2340);
    expect(PregnancyTargets(profile(28), day).energy, 2450);
    expect(PregnancyTargets(profile(20, clinician: 2300), day).energy, 2300);
    expect(PregnancyTargets(profile(20, type: PregnancyType.twins), day).energy,
        isNull);
    expect(
        PregnancyTargets(profile(20, maintenance: null), day).energy, isNull);
    expect(PregnancyTargets(profile(20, maintenance: null), day).protein, 71);
    expect(PregnancyTargets(profile(20, maintenance: null), day).carbs, 175);
    expect(PregnancyTargets(profile(20, maintenance: null), day).fat, isNull);
    expect(
        PregnancyTargets(profile(20), day.add(const Duration(days: 200)))
            .energy,
        isNull);
  });
  test(
      'known totals scale by portion; missing values stay unknown, including legacy food',
      () {
    final foods = [
      intake('a', 150, nutrients(micros: {'iron_mg': 2}, kind: 'ai_estimate')),
      intake('b', 100, nutrients())
    ];
    final iron = NutrientTotal.fromIntakes(foods, 'iron_mg');
    expect(iron.amount, 3);
    expect(iron.known, 1);
    expect(iron.missing, 1);
    expect(iron.estimated, 1);
    expect(NutrientTotal.fromIntakes(foods, 'iodine_ug').known, 0);
    expect(
        NutrientTotal.fromIntakes([
          intake('zero', 100, nutrients(micros: {'iron_mg': 0}))
        ], 'iron_mg')
            .known,
        1);
    expect(NutrientTotal.fromIntakes([foods.first], 'iron_mg').missing, 0);
    expect(
        NutrientTotal.fromIntakes(
                [intake('a', 50, foods.first.meal.nutriments)], 'iron_mg')
            .amount,
        1);
  });
  test('AI parser preserves nullable micronutrients and label source', () {
    final response = AiNutritionResponseDTO.fromJson({
      'source': 'label_extraction',
      'items': [
        {
          'name': 'Food',
          'estimated_weight_g': 100,
          'per_100g': {
            'energy_kcal': 200,
            'protein_g': 10,
            'carbohydrates_g': 25,
            'fat_g': 8,
            'iron_mg': 2.5,
            'folate_dfe_ug': null,
            'calcium_mg': -1,
            'iodine_ug': 'unknown'
          }
        }
      ]
    });
    expect(response.source, AiNutritionSource.labelExtraction);
    expect(response.items.single.per100g.micronutrients, {'iron_mg': 2.5});
  });
  test('OFF micronutrient unit conversion does not invent folate DFE', () {
    final dto = OFFProductNutrimentsDTO.fromJson({
      'iron_100g': 0.002,
      'calcium_100g': 0.12,
      'iodine_100g': 0.00003,
      'vitamin-d_100g': 0.000005,
      'folates_100g': 0.0001
    });
    final n = MealNutrimentsEntity.fromOffNutriments(dto);
    expect(n.micronutrients100['iron_mg'], 2);
    expect(n.micronutrients100['calcium_mg'], 120);
    expect(n.micronutrients100['iodine_ug'], 30);
    expect(n.micronutrients100['vitamin_d_ug'], 5);
    expect(n.micronutrients100.containsKey('folate_dfe_ug'), isFalse);
  });
  test('micronutrients and provenance survive JSON backup and Hive reopening',
      () async {
    final dir = await Directory.systemTemp.createTemp('pregnancy_nutrients_');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(MealNutrimentsDBOAdapter());
    }
    final original = MealNutrimentsDBO.fromProductNutrimentsEntity(nutrients(
        micros: {'iron_mg': 2.4, 'folate_dfe_ug': 30}, kind: 'ai_estimate'));
    final jsonCopy =
        MealNutrimentsDBO.fromJson(jsonDecode(jsonEncode(original.toJson())));
    var box = await Hive.openBox<MealNutrimentsDBO>('pregnancy_values');
    await box.put('food', jsonCopy);
    await box.close();
    box = await Hive.openBox<MealNutrimentsDBO>('pregnancy_values');
    final restored =
        MealNutrimentsEntity.fromMealNutrimentsDBO(box.get('food')!);
    expect(restored.micronutrients100, original.micronutrients100);
    expect(restored.nutritionDataKind, 'ai_estimate');
    await box.close();
    await Hive.deleteBoxFromDisk('pregnancy_values');
    await dir.delete();
    final legacy = MealNutrimentsDBO.fromJson({'energyKcal100': 100});
    expect(legacy.micronutrients100, isEmpty);
  });
  test('profile updates retain existing weights and energy plan persists', () {
    final data =
        PregnancyData(profile: profile(20), weights: [WeightEntry(day, 70)]);
    final copy = PregnancyData.fromJson(jsonDecode(jsonEncode(data.toJson())));
    expect(copy.profile!.maintenanceKcal, 2000);
    expect(
        copy.withProfile(profile(21, clinician: 2300)).weights.single.kg, 70);
  });
  testWidgets('phone dashboard shows real logged micros and unknown coverage',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    locator.registerSingleton(PregnancyController(
        MemoryStore(), PregnancyData(profile: profile(20))));
    await tester.pumpWidget(MaterialApp(
        theme: pregnancyTheme(),
        home: Scaffold(
            body: SingleChildScrollView(
                child: PregnancyDashboard(day: day, intakes: [
          intake(
              'a', 150, nutrients(micros: {'iron_mg': 2}, kind: 'ai_estimate')),
          intake('b', 100, nutrients())
        ])))));
    await tester.tap(find.text('Pregnancy nutrients'));
    await tester.pumpAndSettle();
    expect(find.text('3 mg'), findsOneWidget);
    expect(find.textContaining('includes AI estimates'), findsWidgets);
    expect(find.text('Unknown'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
