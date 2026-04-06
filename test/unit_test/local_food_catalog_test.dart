import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:opennutritracker/core/data/data_source/local_food_data_source.dart';
import 'package:opennutritracker/core/data/data_source/meal_preset_data_source.dart';
import 'package:opennutritracker/core/data/dbo/local_food_record_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_preset_dbo.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

const foodBoxName = 'local_food_catalog_test';
const aliasBoxName = 'local_food_alias_test';
const presetBoxName = 'local_food_preset_test';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    Hive.init('.');
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(MealDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(MealNutrimentsDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(14)) {
      Hive.registerAdapter(MealSourceDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(17)) {
      Hive.registerAdapter(MealPresetDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(18)) {
      Hive.registerAdapter(MealPresetItemDBOAdapter());
    }
    if (!Hive.isAdapterRegistered(28)) {
      Hive.registerAdapter(LocalFoodRecordDBOAdapter());
    }
  });

  tearDown(() async {
    if (Hive.isBoxOpen(foodBoxName)) {
      await Hive.box<LocalFoodRecordDBO>(foodBoxName).close();
    }
    if (Hive.isBoxOpen(aliasBoxName)) {
      await Hive.box<String>(aliasBoxName).close();
    }
    if (Hive.isBoxOpen(presetBoxName)) {
      await Hive.box<MealPresetDBO>(presetBoxName).close();
    }
    await Hive.deleteBoxFromDisk(foodBoxName);
    await Hive.deleteBoxFromDisk(aliasBoxName);
    await Hive.deleteBoxFromDisk(presetBoxName);
  });

  test('canonical local food upsert deduplicates AI foods by normalized name',
      () async {
    final dataSource = await _createLocalFoodDataSource();

    final first = await dataSource.saveFood(
      MealDBO.fromMealEntity(_buildMeal(name: ' Fried Egg ', kcal: 120)),
    );
    final second = await dataSource.saveFood(
      MealDBO.fromMealEntity(_buildMeal(name: 'fried   egg', kcal: 135)),
    );
    final allRecords = await dataSource.getAllFoodRecords();
    final resolved = await dataSource.getFoodByKey('Fried Egg');

    expect(first.id, second.id);
    expect(allRecords, hasLength(1));
    expect(allRecords.single.meal.nutriments.energyKcal100, 135);
    expect(resolved?.nutriments.energyKcal100, 135);
  });

  test('lookup aliases resolve barcode keyed foods', () async {
    final dataSource = await _createLocalFoodDataSource();
    const barcode = '7613035974684';

    final record = await dataSource.saveFood(
      MealDBO.fromMealEntity(
        _buildMeal(
          code: barcode,
          name: 'Chocolate Bar',
          kcal: 520,
          source: MealSourceEntity.ai,
        ),
      ),
      lookupKeys: [barcode],
    );

    final resolved = await dataSource.getFoodByKey(barcode);

    expect(record.meal.name, 'Chocolate Bar');
    expect(resolved?.name, 'Chocolate Bar');
    expect(resolved?.nutriments.energyKcal100, 520);
  });

  test('preset snapshot sync updates linked items and preserves others',
      () async {
    final presetBox = await Hive.openBox<MealPresetDBO>(presetBoxName);
    final presetDataSource = MealPresetDataSource(presetBox);

    await presetDataSource.addPreset(
      MealPresetDBO(
        id: 'preset-1',
        name: 'Breakfast',
        imagePath: null,
        items: [
          MealPresetItemDBO(
            meal: MealDBO.fromMealEntity(
                _buildMeal(name: 'Fried Egg', kcal: 120)),
            amount: 100,
            unit: 'g',
            foodId: 'food-1',
          ),
          MealPresetItemDBO(
            meal: MealDBO.fromMealEntity(_buildMeal(name: 'Toast', kcal: 260)),
            amount: 50,
            unit: 'g',
          ),
        ],
      ),
    );

    await presetDataSource.syncFoodSnapshot(
      'food-1',
      MealDBO.fromMealEntity(_buildMeal(name: 'Fried Egg Large', kcal: 145)),
    );

    final updatedPreset = await presetDataSource.getPresetById('preset-1');

    expect(updatedPreset, isNotNull);
    expect(updatedPreset!.items.first.meal.name, 'Fried Egg Large');
    expect(updatedPreset.items.first.foodId, 'food-1');
    expect(updatedPreset.items.last.meal.name, 'Toast');
    expect(updatedPreset.items.last.foodId, isNull);
  });
}

Future<LocalFoodDataSource> _createLocalFoodDataSource() async {
  final foodBox = await Hive.openBox<LocalFoodRecordDBO>(foodBoxName);
  final aliasBox = await Hive.openBox<String>(aliasBoxName);
  return LocalFoodDataSource(foodBox, aliasBox);
}

MealEntity _buildMeal({
  String? code,
  required String name,
  required double kcal,
  MealSourceEntity source = MealSourceEntity.ai,
}) {
  return MealEntity(
    code: code,
    name: name,
    brands: null,
    url: null,
    thumbnailImageUrl: null,
    mainImageUrl: null,
    mealQuantity: null,
    mealUnit: 'g',
    servingQuantity: null,
    servingUnit: null,
    servingSize: null,
    nutriments: MealNutrimentsEntity(
      energyKcal100: kcal,
      proteins100: 12,
      carbohydrates100: 1,
      fat100: 10,
      sugars100: null,
      saturatedFat100: null,
      fiber100: null,
      sodiumMg100: null,
    ),
    source: source,
  );
}
