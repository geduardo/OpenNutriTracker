import 'package:opennutritracker/features/strategy/data/dbo/weight_entry_dbo.dart';

enum WeightEntrySource { manual, migratedProfileWeight }

class WeightEntryEntity {
  final DateTime day;
  final double weightKg;
  final String? note;
  final WeightEntrySource source;

  const WeightEntryEntity({
    required this.day,
    required this.weightKg,
    this.note,
    required this.source,
  });

  factory WeightEntryEntity.fromDBO(WeightEntryDBO dbo) {
    return WeightEntryEntity(
      day: dbo.day,
      weightKg: dbo.weightKg,
      note: dbo.note,
      source: dbo.source == WeightEntrySourceDBO.manual
          ? WeightEntrySource.manual
          : WeightEntrySource.migratedProfileWeight,
    );
  }

  WeightEntryDBO toDBO() {
    return WeightEntryDBO(
      day: day,
      weightKg: weightKg,
      note: note,
      source: source == WeightEntrySource.manual
          ? WeightEntrySourceDBO.manual
          : WeightEntrySourceDBO.migratedProfileWeight,
    );
  }
}
