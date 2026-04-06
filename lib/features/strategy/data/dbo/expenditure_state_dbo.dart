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

  factory ExpenditureStateDBO.fromJson(Map<String, dynamic> json) =>
      ExpenditureStateDBO(
        day: DateTime.parse(json['day'] as String),
        estimatedExpenditureKcal:
            (json['estimatedExpenditureKcal'] as num).toDouble(),
        rawExpenditureKcal: (json['rawExpenditureKcal'] as num).toDouble(),
        confidence: (json['confidence'] as num).toDouble(),
        status: _statusFromJson(json['status'] as String?),
        validNutritionDays: (json['validNutritionDays'] as num).toInt(),
        recentWeighInCount: (json['recentWeighInCount'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'day': day.toIso8601String(),
        'estimatedExpenditureKcal': estimatedExpenditureKcal,
        'rawExpenditureKcal': rawExpenditureKcal,
        'confidence': confidence,
        'status': status.name,
        'validNutritionDays': validNutritionDays,
        'recentWeighInCount': recentWeighInCount,
      };

  static ExpenditureStatusDBO _statusFromJson(String? value) => switch (value) {
        'holding' => ExpenditureStatusDBO.holding,
        'updating' => ExpenditureStatusDBO.updating,
        _ => ExpenditureStatusDBO.seeded,
      };
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
