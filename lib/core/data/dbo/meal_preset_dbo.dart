import 'package:hive_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';

part 'meal_preset_dbo.g.dart';

@HiveType(typeId: 15)
class MealPresetDBO extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final List<MealPresetItemDBO> items;

  MealPresetDBO({
    required this.id,
    required this.name,
    required this.items,
  });
}

@HiveType(typeId: 16)
class MealPresetItemDBO extends HiveObject {
  @HiveField(0)
  final MealDBO meal;

  @HiveField(1)
  final double amount;

  @HiveField(2)
  final String unit;

  MealPresetItemDBO({
    required this.meal,
    required this.amount,
    required this.unit,
  });
}
