// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'physical_activity_dbo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PhysicalActivityDBO _$PhysicalActivityDBOFromJson(Map<String, dynamic> json) =>
    PhysicalActivityDBO(
      json['code'] as String,
      json['specificActivity'] as String,
      json['description'] as String,
      (json['mets'] as num).toDouble(),
      (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
      $enumDecode(_$PhysicalActivityTypeDBOEnumMap, json['type']),
    );

Map<String, dynamic> _$PhysicalActivityDBOToJson(
        PhysicalActivityDBO instance) =>
    <String, dynamic>{
      'code': instance.code,
      'specificActivity': instance.specificActivity,
      'description': instance.description,
      'mets': instance.mets,
      'tags': instance.tags,
      'type': _$PhysicalActivityTypeDBOEnumMap[instance.type]!,
    };

const _$PhysicalActivityTypeDBOEnumMap = {
  PhysicalActivityTypeDBO.bicycling: 'bicycling',
  PhysicalActivityTypeDBO.conditioningExercise: 'conditioningExercise',
  PhysicalActivityTypeDBO.dancing: 'dancing',
  PhysicalActivityTypeDBO.running: 'running',
  PhysicalActivityTypeDBO.sport: 'sport',
  PhysicalActivityTypeDBO.waterActivities: 'waterActivities',
  PhysicalActivityTypeDBO.winterActivities: 'winterActivities',
};
