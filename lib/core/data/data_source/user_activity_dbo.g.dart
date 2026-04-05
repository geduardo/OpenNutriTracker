// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_activity_dbo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserActivityDBO _$UserActivityDBOFromJson(Map<String, dynamic> json) =>
    UserActivityDBO(
      json['id'] as String,
      (json['duration'] as num).toDouble(),
      (json['burnedKcal'] as num).toDouble(),
      DateTime.parse(json['date'] as String),
      PhysicalActivityDBO.fromJson(
          json['physicalActivityDBO'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$UserActivityDBOToJson(UserActivityDBO instance) =>
    <String, dynamic>{
      'id': instance.id,
      'duration': instance.duration,
      'burnedKcal': instance.burnedKcal,
      'date': instance.date.toIso8601String(),
      'physicalActivityDBO': instance.physicalActivityDBO,
    };
