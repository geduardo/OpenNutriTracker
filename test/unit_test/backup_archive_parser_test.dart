import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/data/dbo/intake_dbo.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_nutriments_dbo.dart';
import 'package:opennutritracker/features/settings/domain/entity/backup_bundle.dart';
import 'package:opennutritracker/features/settings/domain/service/backup_archive_parser.dart';

Archive _archive(Map<String, Object?> files) {
  final archive = Archive();
  files.forEach((name, content) {
    final bytes = utf8.encode(jsonEncode(content));
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  return archive;
}

Map<String, dynamic> _intakeJson({
  String id = 'intake-1',
  String? imagePath,
  double amount = 150,
}) {
  final intake = IntakeDBO(
    id: id,
    unit: 'g',
    amount: amount,
    type: IntakeTypeDBO.lunch,
    meal: MealDBO(
      code: '123',
      name: 'Rice',
      brands: null,
      thumbnailImageUrl: null,
      mainImageUrl: imagePath,
      url: null,
      mealQuantity: null,
      mealUnit: 'g',
      servingQuantity: null,
      servingUnit: null,
      servingSize: null,
      nutriments: MealNutrimentsDBO(
        energyKcal100: 130,
        carbohydrates100: 28,
        fat100: 0.3,
        proteins100: 2.7,
        sugars100: null,
        saturatedFat100: null,
        fiber100: null,
      ),
      source: MealSourceDBO.custom,
    ),
    dateTime: DateTime(2026, 4, 8, 12),
  );
  // Same normalisation the exporter applies.
  return jsonDecode(jsonEncode(intake.toJson())) as Map<String, dynamic>;
}

void main() {
  test('current backup parses and remaps restored image paths', () {
    final archive = _archive({
      BackupBundle.intakeFileName: [
        _intakeJson(imagePath: '/old/food_images/a.jpg'),
      ],
      BackupBundle.trackedDayFileName: [],
      BackupBundle.weightEntryFileName: [
        {'day': '2026-04-08T00:00:00.000', 'weightKg': 74.3, 'source': 'manual'},
      ],
      BackupBundle.goalStrategyFileName: null,
      BackupBundle.userFileName: null,
    });

    final backup = BackupArchiveParser.parse(
      archive,
      imagePathMap: {'/old/food_images/a.jpg': '/new/food_images/a.jpg'},
    );

    expect(backup.isLegacyFormat, isFalse);
    expect(backup.intakes, hasLength(1));
    expect(backup.intakes!.single.meal.mainImageUrl, '/new/food_images/a.jpg');
    expect(backup.intakes!.single.amount, 150);
    expect(backup.trackedDays, isEmpty);
    expect(backup.weightEntries!.single.weightKg, 74.3);
    expect(backup.hasGoalStrategyFile, isTrue);
    expect(backup.goalStrategy, isNull);
    expect(backup.user, isNull);
  });

  test('stores missing from the archive stay null so they are not cleared',
      () {
    final backup = BackupArchiveParser.parse(_archive({
      BackupBundle.intakeFileName: [_intakeJson()],
    }));

    expect(backup.trackedDays, isNull);
    expect(backup.weightEntries, isNull);
    expect(backup.expenditureStates, isNull);
    expect(backup.hasGoalStrategyFile, isFalse);
    expect(backup.checkInRecords, isNull);
    expect(backup.config, isNull);
    expect(backup.user, isNull);
    expect(backup.localFoods, isNull);
    expect(backup.mealPresets, isNull);
  });

  test('upstream OpenNutriTracker backup with legacy file names is accepted',
      () {
    final archive = _archive({
      BackupBundle.legacyIntakeFileName: [
        {
          'id': 'up-1',
          'unit': 'g',
          'amount': 200,
          'type': 'breakfast',
          'meal': {
            'code': null,
            'name': 'Oats',
            'brands': null,
            'thumbnailImageUrl': null,
            'mainImageUrl': null,
            'url': null,
            'mealQuantity': null,
            'mealUnit': 'g',
            'servingQuantity': null,
            'servingUnit': null,
            'servingSize': null,
            'source': 'custom',
            'nutriments': {
              'energyKcal100': 370,
              'carbohydrates100': 60,
              'fat100': 7,
              'proteins100': 13,
              'sugars100': null,
              'saturatedFat100': null,
              'fiber100': null,
            },
          },
          'dateTime': '2025-01-10T08:00:00.000',
        },
      ],
      BackupBundle.legacyTrackedDayFileName: [
        {
          'day': '2025-01-10T00:00:00.000',
          'calorieGoal': 2000,
          'caloriesTracked': 740,
          'carbsGoal': 250,
          'carbsTracked': 120,
          'fatGoal': 60,
          'fatTracked': 14,
          'proteinGoal': 120,
          'proteinTracked': 26,
        },
      ],
      'user_activity.json': [],
    });

    final backup = BackupArchiveParser.parse(archive);

    expect(backup.isLegacyFormat, isTrue);
    expect(backup.intakes!.single.meal.name, 'Oats');
    expect(backup.intakes!.single.meal.nutriments.sodiumMg100, isNull);
    expect(backup.trackedDays!.single.caloriesTracked, 740);
    expect(backup.user, isNull);
    expect(backup.config, isNull);
  });

  test('duplicate intake ids from older importers are collapsed', () {
    final backup = BackupArchiveParser.parse(_archive({
      BackupBundle.intakeFileName: [
        _intakeJson(id: 'dup', amount: 100),
        _intakeJson(id: 'dup', amount: 100),
        _intakeJson(id: 'other'),
      ],
    }));

    expect(backup.intakes!.map((i) => i.id), unorderedEquals(['dup', 'other']));
  });

  test('archive without backup files is rejected', () {
    expect(
      () => BackupArchiveParser.parse(_archive({'random.json': []})),
      throwsA(isA<InvalidBackupException>()),
    );
  });

  test('corrupt record is rejected before anything is written', () {
    final broken = _intakeJson()..remove('meal');
    expect(
      () => BackupArchiveParser.parse(_archive({
        BackupBundle.intakeFileName: [broken],
      })),
      throwsA(isA<InvalidBackupException>()),
    );
  });
}
