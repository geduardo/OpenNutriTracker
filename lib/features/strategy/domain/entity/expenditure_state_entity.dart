import 'package:opennutritracker/features/strategy/data/dbo/expenditure_state_dbo.dart';

enum ExpenditureStatus { seeded, holding, updating }

class ExpenditureStateEntity {
  final DateTime day;
  final double estimatedExpenditureKcal;
  final double rawExpenditureKcal;
  final double confidence;
  final ExpenditureStatus status;
  final int validNutritionDays;
  final int recentWeighInCount;

  const ExpenditureStateEntity({
    required this.day,
    required this.estimatedExpenditureKcal,
    required this.rawExpenditureKcal,
    required this.confidence,
    required this.status,
    required this.validNutritionDays,
    required this.recentWeighInCount,
  });

  factory ExpenditureStateEntity.fromDBO(ExpenditureStateDBO dbo) {
    return ExpenditureStateEntity(
      day: dbo.day,
      estimatedExpenditureKcal: dbo.estimatedExpenditureKcal,
      rawExpenditureKcal: dbo.rawExpenditureKcal,
      confidence: dbo.confidence,
      status: _statusFromDBO(dbo.status),
      validNutritionDays: dbo.validNutritionDays,
      recentWeighInCount: dbo.recentWeighInCount,
    );
  }

  ExpenditureStateDBO toDBO() {
    return ExpenditureStateDBO(
      day: day,
      estimatedExpenditureKcal: estimatedExpenditureKcal,
      rawExpenditureKcal: rawExpenditureKcal,
      confidence: confidence,
      status: _statusToDBO(status),
      validNutritionDays: validNutritionDays,
      recentWeighInCount: recentWeighInCount,
    );
  }

  static ExpenditureStatus _statusFromDBO(ExpenditureStatusDBO dbo) =>
      switch (dbo) {
        ExpenditureStatusDBO.seeded => ExpenditureStatus.seeded,
        ExpenditureStatusDBO.holding => ExpenditureStatus.holding,
        ExpenditureStatusDBO.updating => ExpenditureStatus.updating,
      };

  static ExpenditureStatusDBO _statusToDBO(ExpenditureStatus status) =>
      switch (status) {
        ExpenditureStatus.seeded => ExpenditureStatusDBO.seeded,
        ExpenditureStatus.holding => ExpenditureStatusDBO.holding,
        ExpenditureStatus.updating => ExpenditureStatusDBO.updating,
      };
}
