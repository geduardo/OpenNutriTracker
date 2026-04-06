import 'package:hive_flutter/hive_flutter.dart';

part 'check_in_record_dbo_adapter.dart';

@HiveType(typeId: 27)
class CheckInRecordDBO extends HiveObject {
  @HiveField(0)
  final DateTime weekStart;

  @HiveField(1)
  final double previousCalorieTarget;

  @HiveField(2)
  final double proposedCalorieTarget;

  @HiveField(3)
  final double appliedCalorieTarget;

  @HiveField(4)
  final bool dismissed;

  @HiveField(5)
  final double expenditureAtCheckIn;

  @HiveField(6)
  final double trendWeightAtCheckIn;

  @HiveField(7)
  final double confidenceAtCheckIn;

  CheckInRecordDBO({
    required this.weekStart,
    required this.previousCalorieTarget,
    required this.proposedCalorieTarget,
    required this.appliedCalorieTarget,
    required this.dismissed,
    required this.expenditureAtCheckIn,
    required this.trendWeightAtCheckIn,
    required this.confidenceAtCheckIn,
  });

  factory CheckInRecordDBO.fromJson(Map<String, dynamic> json) =>
      CheckInRecordDBO(
        weekStart: DateTime.parse(json['weekStart'] as String),
        previousCalorieTarget:
            (json['previousCalorieTarget'] as num).toDouble(),
        proposedCalorieTarget:
            (json['proposedCalorieTarget'] as num).toDouble(),
        appliedCalorieTarget:
            (json['appliedCalorieTarget'] as num).toDouble(),
        dismissed: json['dismissed'] as bool,
        expenditureAtCheckIn:
            (json['expenditureAtCheckIn'] as num).toDouble(),
        trendWeightAtCheckIn:
            (json['trendWeightAtCheckIn'] as num).toDouble(),
        confidenceAtCheckIn:
            (json['confidenceAtCheckIn'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'weekStart': weekStart.toIso8601String(),
        'previousCalorieTarget': previousCalorieTarget,
        'proposedCalorieTarget': proposedCalorieTarget,
        'appliedCalorieTarget': appliedCalorieTarget,
        'dismissed': dismissed,
        'expenditureAtCheckIn': expenditureAtCheckIn,
        'trendWeightAtCheckIn': trendWeightAtCheckIn,
        'confidenceAtCheckIn': confidenceAtCheckIn,
      };
}
