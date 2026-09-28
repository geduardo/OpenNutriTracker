import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opennutritracker/core/domain/usecase/get_config_usecase.dart';
import 'package:opennutritracker/core/utils/extensions.dart';
import 'package:opennutritracker/core/utils/meal_portion_helper.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_nutriments_entity.dart';

part 'edit_meal_state.dart';

part 'edit_meal_event.dart';

class EditMealBloc extends Bloc<EditMealEvent, EditMealState> {
  final GetConfigUsecase _getConfigUsecase;

  EditMealBloc(this._getConfigUsecase) : super(EditMealInitial()) {
    on<InitializeEditMealEvent>((event, emit) async {
      emit(EditMealLoadingState());

      final config = await _getConfigUsecase.getConfig();
      emit(EditMealLoadedState(usesImperialUnits: config.usesImperialUnits));
    });
  }

  MealEntity createNewMealEntity(
      MealEntity oldMealEntity,
      String nameText,
      String brandsText,
      String mealQuantityText,
      String servingLabelText,
      String servingQuantityText,
      String baseQuantity,
      String? unitText,
      String kcalText,
      String carbsText,
      String fatText,
      String proteinText) {
    final baseQuantityDouble = baseQuantity.toDoubleOrNull();

    final double factorTo100g =
        baseQuantityDouble != null ? (100 / baseQuantityDouble) : 1;

    double? multiplyIfNotNull(double? nutrimentValue) {
      return nutrimentValue != null ? nutrimentValue * factorTo100g : null;
    }

    // Only the values typed in the form are per base quantity; the others
    // are carried over and are already stored per 100 g/ml.
    final newMealNutriments = MealNutrimentsEntity(
        energyKcal100: multiplyIfNotNull(kcalText.toDoubleOrNull()),
        carbohydrates100: multiplyIfNotNull(carbsText.toDoubleOrNull()),
        fat100: multiplyIfNotNull(fatText.toDoubleOrNull()),
        proteins100: multiplyIfNotNull(proteinText.toDoubleOrNull()),
        sugars100: oldMealEntity.nutriments.sugars100,
        saturatedFat100: oldMealEntity.nutriments.saturatedFat100,
        fiber100: oldMealEntity.nutriments.fiber100,
        sodiumMg100: oldMealEntity.nutriments.sodiumMg100,
        caffeineMg100: oldMealEntity.nutriments.caffeineMg100,
        micronutrients100: oldMealEntity.nutriments.micronutrients100,
        nutritionDataKind: oldMealEntity.nutriments.nutritionDataKind);

    final servingQuantity = servingQuantityText.toDoubleOrNull();
    final baseUnit = unitText ?? oldMealEntity.mealUnit ?? 'g';
    final servingSize = MealPortionHelper.buildServingDisplayLabel(
      label: servingLabelText,
      amount: servingQuantity ?? 0,
      unit: baseUnit,
    );

    return MealEntity(
        code: oldMealEntity.code,
        name: nameText.toStringOrNull(),
        brands: brandsText.toStringOrNull(),
        url: oldMealEntity.url,
        thumbnailImageUrl: oldMealEntity.thumbnailImageUrl,
        mainImageUrl: oldMealEntity.mainImageUrl,
        mealQuantity: mealQuantityText.toStringOrNull(),
        mealUnit: baseUnit,
        servingQuantity: servingSize == null ? null : servingQuantity,
        servingUnit: servingSize == null ? null : baseUnit,
        servingSize: servingSize,
        nutriments: newMealNutriments,
        source: oldMealEntity.source);
  }
}
