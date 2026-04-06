import 'package:hive_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/features/strategy/data/dbo/day_log_quality_dbo.dart';

part 'tracked_day_dbo.g.dart';
part 'tracked_day_dbo_adapter.dart';

@HiveType(typeId: 9)
@JsonSerializable()
class TrackedDayDBO extends HiveObject {
  @HiveField(0)
  DateTime day;
  @HiveField(1)
  double calorieGoal;
  @HiveField(2)
  double caloriesTracked;
  @HiveField(3)
  double? carbsGoal;
  @HiveField(4)
  double? carbsTracked;
  @HiveField(5)
  double? fatGoal;
  @HiveField(6)
  double? fatTracked;
  @HiveField(7)
  double? proteinGoal;
  @HiveField(8)
  double? proteinTracked;

  @HiveField(9)
  DayLogQualityDBO? logQuality;

  @HiveField(10)
  bool? manuallyMarked;

  @HiveField(11)
  double? sodiumGoal;
  @HiveField(12)
  double? sodiumTracked;

  TrackedDayDBO(
      {required this.day,
      required this.calorieGoal,
      required this.caloriesTracked,
      this.carbsGoal,
      this.carbsTracked,
      this.fatGoal,
      this.fatTracked,
      this.proteinGoal,
      this.proteinTracked,
      this.logQuality,
      this.manuallyMarked,
      this.sodiumGoal,
      this.sodiumTracked});

  factory TrackedDayDBO.fromTrackedDayEntity(TrackedDayEntity entity) {
    return TrackedDayDBO(
        day: entity.day,
        calorieGoal: entity.calorieGoal,
        caloriesTracked: entity.caloriesTracked,
        carbsGoal: entity.carbsGoal,
        carbsTracked: entity.carbsTracked,
        fatGoal: entity.fatGoal,
        fatTracked: entity.fatTracked,
        proteinGoal: entity.proteinGoal,
        proteinTracked: entity.proteinTracked,
        sodiumGoal: entity.sodiumGoal,
        sodiumTracked: entity.sodiumTracked);
  }

  factory TrackedDayDBO.fromJson(Map<String, dynamic> json) => TrackedDayDBO(
        day: DateTime.parse(json['day'] as String),
        calorieGoal: (json['calorieGoal'] as num).toDouble(),
        caloriesTracked: (json['caloriesTracked'] as num).toDouble(),
        carbsGoal: (json['carbsGoal'] as num?)?.toDouble(),
        carbsTracked: (json['carbsTracked'] as num?)?.toDouble(),
        fatGoal: (json['fatGoal'] as num?)?.toDouble(),
        fatTracked: (json['fatTracked'] as num?)?.toDouble(),
        proteinGoal: (json['proteinGoal'] as num?)?.toDouble(),
        proteinTracked: (json['proteinTracked'] as num?)?.toDouble(),
        logQuality: _logQualityFromJson(json['logQuality'] as String?),
        manuallyMarked: json['manuallyMarked'] as bool?,
        sodiumGoal: (json['sodiumGoal'] as num?)?.toDouble(),
        sodiumTracked: (json['sodiumTracked'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'day': day.toIso8601String(),
        'calorieGoal': calorieGoal,
        'caloriesTracked': caloriesTracked,
        'carbsGoal': carbsGoal,
        'carbsTracked': carbsTracked,
        'fatGoal': fatGoal,
        'fatTracked': fatTracked,
        'proteinGoal': proteinGoal,
        'proteinTracked': proteinTracked,
        'logQuality': logQuality?.name,
        'manuallyMarked': manuallyMarked,
        'sodiumGoal': sodiumGoal,
        'sodiumTracked': sodiumTracked,
      };

  static DayLogQualityDBO? _logQualityFromJson(String? value) {
    return switch (value) {
      'complete' => DayLogQualityDBO.complete,
      'partial' => DayLogQualityDBO.partial,
      'unlogged' => DayLogQualityDBO.unlogged,
      'fasted' => DayLogQualityDBO.fasted,
      _ => null,
    };
  }
}
