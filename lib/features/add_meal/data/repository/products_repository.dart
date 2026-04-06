import 'package:opennutritracker/core/data/data_source/local_food_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/fdc_data_source.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/off_data_source.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/sp_fdc_data_source.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

class ProductsRepository {
  final OFFDataSource _offDataSource;
  final FDCDataSource _fdcDataSource;
  final SpFdcDataSource _spBackendDataSource;
  final LocalFoodDataSource _localFoodDataSource;

  ProductsRepository(this._offDataSource, this._fdcDataSource,
      this._spBackendDataSource, this._localFoodDataSource);

  Future<List<MealEntity>> getOFFProductsByString(String searchString) async {
    final offWordResponse =
        await _offDataSource.fetchSearchWordResults(searchString);

    final products = offWordResponse.products
        .map((offProduct) => MealEntity.fromOFFProduct(offProduct))
        .toList();

    return products;
  }

  Future<List<MealEntity>> getFDCFoodsByString(String searchString) async {
    final fdcWordResponse =
        await _fdcDataSource.fetchSearchWordResults(searchString);
    final products = fdcWordResponse.foods
        .map((food) => MealEntity.fromFDCFood(food))
        .toList();
    return products;
  }

  Future<List<MealEntity>> getSupabaseFDCFoodsByString(
      String searchString) async {
    final spFdcWordResponse =
        await _spBackendDataSource.fetchSearchWordResults(searchString);
    final products = spFdcWordResponse
        .map((foodItem) => MealEntity.fromSpFDCFood(foodItem))
        .toList();
    return products;
  }

  Future<MealEntity> getOFFProductByBarcode(String barcode) async {
    // Check local overrides first
    final localOverride = await _localFoodDataSource.getFoodByKey(barcode);
    if (localOverride != null) {
      return MealEntity.fromMealDBO(localOverride);
    }

    final productResponse = await _offDataSource.fetchBarcodeResults(barcode);
    return MealEntity.fromOFFProduct(productResponse.product);
  }

  Future<void> saveLocalFoodOverride(String key, MealEntity meal) async {
    await _localFoodDataSource.saveFood(
      MealDBO.fromMealEntity(meal),
      existingFoodId: meal.localFoodId,
      lookupKeys: [key],
    );
  }
}
