// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_dbo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MealDBO _$MealDBOFromJson(Map<String, dynamic> json) => MealDBO(
      code: json['code'] as String?,
      name: json['name'] as String?,
      brands: json['brands'] as String?,
      thumbnailImageUrl: json['thumbnailImageUrl'] as String?,
      mainImageUrl: json['mainImageUrl'] as String?,
      url: json['url'] as String?,
      mealQuantity: json['mealQuantity'] as String?,
      mealUnit: json['mealUnit'] as String?,
      servingQuantity: (json['servingQuantity'] as num?)?.toDouble(),
      servingUnit: json['servingUnit'] as String?,
      servingSize: json['servingSize'] as String?,
      nutriments: MealNutrimentsDBO.fromJson(
          json['nutriments'] as Map<String, dynamic>),
      source: $enumDecode(_$MealSourceDBOEnumMap, json['source']),
    );

Map<String, dynamic> _$MealDBOToJson(MealDBO instance) => <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'brands': instance.brands,
      'thumbnailImageUrl': instance.thumbnailImageUrl,
      'mainImageUrl': instance.mainImageUrl,
      'url': instance.url,
      'mealQuantity': instance.mealQuantity,
      'mealUnit': instance.mealUnit,
      'servingQuantity': instance.servingQuantity,
      'servingUnit': instance.servingUnit,
      'servingSize': instance.servingSize,
      'source': _$MealSourceDBOEnumMap[instance.source]!,
      'nutriments': instance.nutriments,
    };

const _$MealSourceDBOEnumMap = {
  MealSourceDBO.unknown: 'unknown',
  MealSourceDBO.custom: 'custom',
  MealSourceDBO.off: 'off',
  MealSourceDBO.fdc: 'fdc',
  MealSourceDBO.ai: 'ai',
};
