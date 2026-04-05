// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_nutriments_dbo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MealNutrimentsDBO _$MealNutrimentsDBOFromJson(Map<String, dynamic> json) =>
    MealNutrimentsDBO(
      energyKcal100: (json['energyKcal100'] as num?)?.toDouble(),
      carbohydrates100: (json['carbohydrates100'] as num?)?.toDouble(),
      fat100: (json['fat100'] as num?)?.toDouble(),
      proteins100: (json['proteins100'] as num?)?.toDouble(),
      sugars100: (json['sugars100'] as num?)?.toDouble(),
      saturatedFat100: (json['saturatedFat100'] as num?)?.toDouble(),
      fiber100: (json['fiber100'] as num?)?.toDouble(),
      sodiumMg100: (json['sodiumMg100'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$MealNutrimentsDBOToJson(MealNutrimentsDBO instance) =>
    <String, dynamic>{
      'energyKcal100': instance.energyKcal100,
      'carbohydrates100': instance.carbohydrates100,
      'fat100': instance.fat100,
      'proteins100': instance.proteins100,
      'sugars100': instance.sugars100,
      'saturatedFat100': instance.saturatedFat100,
      'fiber100': instance.fiber100,
      'sodiumMg100': instance.sodiumMg100,
    };
