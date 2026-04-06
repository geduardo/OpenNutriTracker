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

  factory WeightEntryDBO.fromJson(Map<String, dynamic> json) => WeightEntryDBO(
        day: DateTime.parse(json['day'] as String),
        weightKg: (json['weightKg'] as num).toDouble(),
        note: json['note'] as String?,
        source: _sourceFromJson(json['source'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'day': day.toIso8601String(),
        'weightKg': weightKg,
        'note': note,
        'source': source.name,
      };

  static WeightEntrySourceDBO _sourceFromJson(String? value) => switch (value) {
        'healthConnect' => WeightEntrySourceDBO.healthConnect,
        'migratedProfileWeight' => WeightEntrySourceDBO.migratedProfileWeight,
        _ => WeightEntrySourceDBO.manual,
      };
}

@HiveType(typeId: 20)
enum WeightEntrySourceDBO {
  @HiveField(0)
  manual,
  @HiveField(1)
  migratedProfileWeight,
  @HiveField(2)
  healthConnect;
}
