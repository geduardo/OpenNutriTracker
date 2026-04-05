// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'intake_dbo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IntakeDBO _$IntakeDBOFromJson(Map<String, dynamic> json) => IntakeDBO(
      id: json['id'] as String,
      unit: json['unit'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: $enumDecode(_$IntakeTypeDBOEnumMap, json['type']),
      meal: MealDBO.fromJson(json['meal'] as Map<String, dynamic>),
      dateTime: DateTime.parse(json['dateTime'] as String),
    );

Map<String, dynamic> _$IntakeDBOToJson(IntakeDBO instance) => <String, dynamic>{
      'id': instance.id,
      'unit': instance.unit,
      'amount': instance.amount,
      'type': _$IntakeTypeDBOEnumMap[instance.type]!,
      'meal': instance.meal,
      'dateTime': instance.dateTime.toIso8601String(),
    };

const _$IntakeTypeDBOEnumMap = {
  IntakeTypeDBO.breakfast: 'breakfast',
  IntakeTypeDBO.lunch: 'lunch',
  IntakeTypeDBO.dinner: 'dinner',
  IntakeTypeDBO.snack: 'snack',
};
