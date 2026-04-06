import 'package:hive_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';

part 'local_food_record_dbo_adapter.dart';

@HiveType(typeId: 28)
class LocalFoodRecordDBO extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final MealDBO meal;

  @HiveField(2)
  final List<String> aliases;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime updatedAt;

  LocalFoodRecordDBO({
    required this.id,
    required this.meal,
    required this.aliases,
    required this.createdAt,
    required this.updatedAt,
  });
}
