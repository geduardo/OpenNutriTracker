import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:opennutritracker/features/settings/domain/usecase/export_data_usecase.dart';
import 'package:opennutritracker/features/settings/domain/usecase/import_data_usecase.dart';
import 'package:opennutritracker/core/domain/usecase/add_tracked_day_usecase.dart';
import 'package:opennutritracker/core/data/repository/tracked_day_repository.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:opennutritracker/main.dart';
import 'package:opennutritracker/core/data/repository/intake_repository.dart';
import 'package:opennutritracker/core/domain/usecase/add_config_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/data/dto/ai/ai_nutrition_dto.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/ai_result_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/magic_screen.dart';
import 'package:opennutritracker/pregnancy/pregnancy_controller.dart';
import 'package:opennutritracker/pregnancy/pregnancy_model.dart';
import 'package:opennutritracker/pregnancy/pregnancy_store.dart';
import 'pregnancy_onboarding_test.dart' show reveal;
import 'pregnancy_weight_sync_test.dart' show FakeHealth, sample;
import 'package:opennutritracker/pregnancy/pregnancy_weight_page.dart';

class TestPaths extends PathProviderPlatform {
  final String path;
  TestPaths(this.path);
  @override
  Future<String> getApplicationDocumentsPath() async => path;
  @override
  Future<String> getApplicationSupportPath() async => path;
  @override
  Future<String> getTemporaryPath() async => path;
}

class Store implements PregnancyStore {
  PregnancyData data;
  Store(this.data);
  @override
  Future<PregnancyData> read() async => data;
  @override
  Future<void> write(PregnancyData value) async {
    data = value;
  }

  @override
  Future<void> clear() async {
    data = PregnancyData();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Spanish Swiss-region phone onboards, imports weights and logs AI food',
      (tester) async {
    tester.platformDispatcher.localesTestValue = const [
      Locale('es', 'CH'),
      Locale('de', 'CH')
    ];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late Directory dir;
    final health = FakeHealth();
    await tester.runAsync(() async {
      final font = FontLoader('PregnancySans')
        ..addFont(rootBundle.load('fonts/Poppins-Regular.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final customIcons = FontLoader('CustomIcons')
        ..addFont(rootBundle.load('fonts/CustomIcons.ttf'));
      await customIcons.load();
      dir = await Directory.systemTemp.createTemp('pregnancy_app_flow_');
      PathProviderPlatform.instance = TestPaths(dir.path);
      FlutterSecureStorage.setMockInitialValues({});
      await initLocator();
      await locator<AddConfigUsecase>().setConfigDisclaimer(true);
    });
    final data = PregnancyData();
    locator.registerSingleton(
        PregnancyController(Store(data), data, health: health));
    final boundary = GlobalKey();
    await tester.pumpWidget(
        RepaintBoundary(key: boundary, child: const IntegratedPregnancyApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configurar embarazo y empezar a registrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sé mis semanas y días'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Semanas'), '20');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Días adicionales'), '3');
    await reveal(tester, find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Tus referencias diarias iniciales'), findsOneWidget);
    expect(find.text('Paso 2 de 2 · Lista para registrar'), findsOneWidget);
    await tester.runAsync(() async {
      final image = await (boundary.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('../pregnancy-onboarding-es-1.3.0.png')
          .writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.text('Empezar a registrar'));
    await tester.pumpAndSettle();
    expect(find.text('Plan de energía y macronutrientes'), findsNothing);
    final saved = locator<PregnancyController>().data.profile!;
    expect(saved.prePregnancyKg, isNull);
    expect(saved.maintenanceKcal, isNull);
    expect(saved.gestationDays(DateTime.now()), 143);
    // A later energy plan still participates in dated diary targets and backup.
    await locator<PregnancyController>().save(PregnancyData(
        profile: PregnancyProfile(
            dueDate: saved.dueDate,
            maintenanceKcal: 2000,
            prePregnancyKg: 62,
            heightCm: 168)));
    final pregnancyController = locator<PregnancyController>();
    final start = pregnancyController.data.profile!.startDate;
    health.samples = [
      sample(start.add(const Duration(days: 77)), 62),
      sample(DateTime.now().subtract(const Duration(hours: 1)), 66.5)
    ];
    await pregnancyController
        .update((d) => d.copyWith(healthSyncEnabled: true));
    // Verify the actual foreground lifecycle hook, without pressing Sync now.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(health.reads, 1);
    expect(pregnancyController.data.weights.length, 2);
    expect(pregnancyController.data.weights.last.source, 'healthConnect');
    await tester.tap(find.widgetWithText(NavigationDestination, 'Embarazo'));
    await tester.pumpAndSettle();
    expect(health.reads, 2);
    expect(pregnancyController.data.weights.length, 2);
    await reveal(tester, find.text('Importación automática de peso'));
    expect(find.text('Importar desde Health Connect'), findsOneWidget);
    await reveal(tester, find.byType(PregnancyWeightChart));
    await tester.ensureVisible(find.byType(PregnancyWeightChart));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image = await (boundary.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('../pregnancy-weight-es-1.3.0.png')
          .writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Inicio'));
    await tester.pumpAndSettle();
    expect(find.text('Registrar alimentos'), findsOneWidget);
    await tester.tap(find.text('Registrar alimentos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desayuno').last);
    await tester.pumpAndSettle();
    expect(find.text('Magia'), findsOneWidget);
    await tester.tap(find.text('Magia'));
    await tester.pumpAndSettle();
    expect(find.text('Cámara'), findsOneWidget);
    expect(find.text('Galería'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();
    nav.pushNamed(NavigationOptions.aiResultRoute,
        arguments: AiResultScreenArguments(
            response: const AiNutritionResponseDTO(
                source: AiNutritionSource.estimation,
                items: [
                  AiNutritionItemDTO(
                      name: 'Lentil bowl (test fixture)',
                      estimatedWeightG: 150,
                      confidence: 'medium',
                      per100g: AiNutrimentsPer100gDTO(
                          energyKcal: 120,
                          proteinG: 9,
                          carbohydratesG: 20,
                          fatG: 1,
                          fiberG: 8,
                          micronutrients: {
                            'iron_mg': 3,
                            'folate_dfe_ug': 180,
                            'calcium_mg': 25
                          }))
                ]),
            mealType: AddMealType.breakfastType,
            day: DateTime.now(),
            mode: MagicMode.singleItem));
    await tester.pumpAndSettle();
    expect(find.text('Revisar alimento'), findsOneWidget);
    expect(find.text('Nutrientes del embarazo'), findsOneWidget);
    // The inherited primary action says "Add food".
    final save = find.text('Añadir alimento');
    expect(save, findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(save);
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    final entries = await tester
        .runAsync(() => locator<IntakeRepository>().getAllIntakesDBO());
    expect(entries, hasLength(1));
    expect(entries!.single.meal.nutriments.micronutrients100['iron_mg'], 3);
    expect(entries.single.amount, 150);
    expect(entries.single.meal.nutriments.nutritionDataKind, 'ai_estimate');
    expect(find.text('Registrar alimentos'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final historical = DateTime.now().subtract(const Duration(days: 70));
      await locator<AddTrackedDayUsecase>()
          .addNewTrackedDay(historical, 999, 999, 999, 999);
      final tracked =
          await locator<TrackedDayRepository>().getTrackedDay(historical);
      expect(tracked!.calorieGoal,
          2000); // first trimester, not today's second trimester
      final zip = await locator<ExportDataUsecase>().buildBackupZipBytes();
      final archive = ZipDecoder().decodeBytes(zip);
      final saved = jsonDecode(utf8.decode(
          archive.findFile('PregnancyJournal.json')!.content as List<int>));
      expect(saved['profile']['maintenanceKcal'], 2000);
      final controller = locator<PregnancyController>();
      await controller.save(PregnancyData());
      await locator<ImportDataUsecase>().importFromBytes(zip);
      expect(controller.data.profile!.maintenanceKcal, 2000);
      expect(controller.data.healthSyncEnabled, isTrue);
      expect(controller.data.weights.length, 2);
      expect(controller.data.weights.last.source, 'healthConnect');
      expect(controller.data.lastHealthSync, isNotNull);
      expect(
          (await locator<IntakeRepository>().getAllIntakesDBO())
              .single
              .meal
              .nutriments
              .micronutrients100['iron_mg'],
          3);
    });
    await tester.pumpAndSettle();
    // Capture a reproducible phone-width preview using explicitly synthetic food.
    await tester.runAsync(() async {
      final image = await (boundary.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('../pregnancy-logging-es-1.3.0.png')
          .writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await Hive.close();
      await locator.reset();
      for (final file in dir.listSync()) {
        if (file is File) await file.delete();
      }
      expect(dir.absolute.path.startsWith(Directory.systemTemp.absolute.path),
          isTrue);
      await dir.delete(recursive: true);
    });
  });
}
