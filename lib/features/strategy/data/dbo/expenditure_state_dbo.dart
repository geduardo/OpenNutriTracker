import 'package:hive_flutter/hive_flutter.dart';

part 'expenditure_state_dbo_adapter.dart';

@HiveType(typeId: 22)
class ExpenditureStateDBO extends HiveObject {
  @HiveField(0)
  final DateTime day;

  @HiveField(1)
  final double estimatedExpenditureKcal;

  @HiveField(2)
  final double rawExpenditureKcal;

  @HiveField(3)
  final double confidence;

  @HiveField(4)
  final ExpenditureStatusDBO status;

  @HiveField(5)
  final int validNutritionDays;

  @HiveField(6)
  final int recentWeighInCount;

  ExpenditureStateDBO({
    required this.day,
    required this.estimatedExpenditureKcal,
    required this.rawExpenditureKcal,
    required this.confidence,
    required this.status,
    required this.validNutritionDays,
    required this.recentWeighInCount,
  });
}

@HiveType(typeId: 23)
enum ExpenditureStatusDBO {
  @HiveField(0)
  seeded,
  @HiveField(1)
  holding,
  @HiveField(2)
  updating;
}
