import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:opennutritracker/core/data/dbo/app_theme_dbo.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_preset_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/core/data/dbo/tracked_day_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_gender_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_pal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/user_weight_goal_dbo.dart';
import 'package:opennutritracker/features/strategy/data/dbo/day_log_quality_dbo.dart';
import 'package:opennutritracker/features/strategy/data/dbo/weight_entry_dbo.dart';

class HiveDBProvider extends ChangeNotifier {
  static const configBoxName = 'ConfigBox';
  static const intakeBoxName = 'IntakeBox';
  static const userBoxName = 'UserBox';
  static const trackedDayBoxName = 'TrackedDayBox';
  static const mealPresetBoxName = 'MealPresetBox';
  static const localFoodBoxName = 'LocalFoodBox';
  static const weightEntryBoxName = 'WeightEntryBox';

  late Box<ConfigDBO> configBox;
  late Box<IntakeDBO> intakeBox;
  late Box<UserDBO> userBox;
  late Box<TrackedDayDBO> trackedDayBox;
  late Box<MealPresetDBO> mealPresetBox;
  late Box<MealDBO> localFoodBox;
  late Box<WeightEntryDBO> weightEntryBox;

  Future<void> initHiveDB(Uint8List encryptionKey) async {
    final encryptionCypher = HiveAesCipher(encryptionKey);
    await Hive.initFlutter();
    Hive.registerAdapter(ConfigDBOAdapter());
    Hive.registerAdapter(IntakeDBOAdapter());
    Hive.registerAdapter(MealDBOAdapter());
    Hive.registerAdapter(MealNutrimentsDBOAdapter());
    Hive.registerAdapter(MealSourceDBOAdapter());
    Hive.registerAdapter(IntakeTypeDBOAdapter());
    Hive.registerAdapter(UserDBOAdapter());
    Hive.registerAdapter(UserGenderDBOAdapter());
    Hive.registerAdapter(UserWeightGoalDBOAdapter());
    Hive.registerAdapter(UserPALDBOAdapter());
    Hive.registerAdapter(TrackedDayDBOAdapter());
    Hive.registerAdapter(AppThemeDBOAdapter());
    Hive.registerAdapter(MealPresetDBOAdapter());
    Hive.registerAdapter(MealPresetItemDBOAdapter());
    Hive.registerAdapter(WeightEntryDBOAdapter());
    Hive.registerAdapter(WeightEntrySourceDBOAdapter());
    Hive.registerAdapter(DayLogQualityDBOAdapter());

    configBox =
        await Hive.openBox(configBoxName, encryptionCipher: encryptionCypher);
    intakeBox =
        await Hive.openBox(intakeBoxName, encryptionCipher: encryptionCypher);
    userBox =
        await Hive.openBox(userBoxName, encryptionCipher: encryptionCypher);
    trackedDayBox = await Hive.openBox(trackedDayBoxName,
        encryptionCipher: encryptionCypher);
    mealPresetBox = await Hive.openBox(mealPresetBoxName,
        encryptionCipher: encryptionCypher);
    localFoodBox = await Hive.openBox(localFoodBoxName,
        encryptionCipher: encryptionCypher);
    weightEntryBox = await Hive.openBox(weightEntryBoxName,
        encryptionCipher: encryptionCypher);
  }

  static generateNewHiveEncryptionKey() => Hive.generateSecureKey();
}
