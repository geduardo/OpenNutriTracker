// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracked_day_dbo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrackedDayDBO _$TrackedDayDBOFromJson(Map<String, dynamic> json) =>
    TrackedDayDBO(
      day: DateTime.parse(json['day'] as String),
      calorieGoal: (json['calorieGoal'] as num).toDouble(),
      caloriesTracked: (json['caloriesTracked'] as num).toDouble(),
      carbsGoal: (json['carbsGoal'] as num?)?.toDouble(),
      carbsTracked: (json['carbsTracked'] as num?)?.toDouble(),
      fatGoal: (json['fatGoal'] as num?)?.toDouble(),
      fatTracked: (json['fatTracked'] as num?)?.toDouble(),
      proteinGoal: (json['proteinGoal'] as num?)?.toDouble(),
      proteinTracked: (json['proteinTracked'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$TrackedDayDBOToJson(TrackedDayDBO instance) =>
    <String, dynamic>{
      'day': instance.day.toIso8601String(),
      'calorieGoal': instance.calorieGoal,
      'caloriesTracked': instance.caloriesTracked,
      'carbsGoal': instance.carbsGoal,
      'carbsTracked': instance.carbsTracked,
      'fatGoal': instance.fatGoal,
      'fatTracked': instance.fatTracked,
      'proteinGoal': instance.proteinGoal,
      'proteinTracked': instance.proteinTracked,
    };
