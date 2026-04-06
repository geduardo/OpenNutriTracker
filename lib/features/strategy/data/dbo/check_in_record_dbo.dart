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
}
