import 'package:hive_flutter/hive_flutter.dart';

part 'weight_entry_dbo_adapter.dart';

@HiveType(typeId: 19)
class WeightEntryDBO extends HiveObject {
  @HiveField(0)
  final DateTime day;

  @HiveField(1)
  final double weightKg;

  @HiveField(2)
  final String? note;

  @HiveField(3)
  final WeightEntrySourceDBO source;

  WeightEntryDBO({
    required this.day,
    required this.weightKg,
    this.note,
    required this.source,
  });
}

@HiveType(typeId: 20)
enum WeightEntrySourceDBO {
  @HiveField(0)
  manual,
  @HiveField(1)
  migratedProfileWeight;
}
