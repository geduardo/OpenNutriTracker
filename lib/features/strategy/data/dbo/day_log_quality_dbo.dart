import 'package:hive_flutter/hive_flutter.dart';

part 'day_log_quality_dbo_adapter.dart';

@HiveType(typeId: 21)
enum DayLogQualityDBO {
  @HiveField(0)
  complete,
  @HiveField(1)
  partial,
  @HiveField(2)
  unlogged,
  @HiveField(3)
  fasted;
}
