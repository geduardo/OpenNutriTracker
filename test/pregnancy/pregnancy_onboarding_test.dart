import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/pregnancy/pregnancy_app.dart';
import 'package:opennutritracker/pregnancy/pregnancy_model.dart';
import 'pregnancy_app_test.dart' show MemoryStore;

Future<void> reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 180,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

Future<void> stage(WidgetTester tester, int weeks, int days) async {
  await tester.tap(find.text('Set up pregnancy'));
  await tester.pumpAndSettle();
  await reveal(tester, find.text('I know my weeks + days'));
  await tester.tap(find.text('I know my weeks + days'));
  await tester.pumpAndSettle();
  final weeksField = find.widgetWithText(TextFormField, 'Weeks');
  await reveal(tester, weeksField);
  await tester.enterText(weeksField, '$weeks');
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Additional days'), '$days');
  await reveal(tester, find.byType(CheckboxListTile));
  await tester.tap(find.byType(CheckboxListTile));
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

void main() {
  for (final weeks in [6, 20, 38, 42]) {
    testWidgets('join at $weeks weeks + 3 days without past weights',
        (tester) async {
      final store = MemoryStore(PregnancyData());
      await tester.pumpWidget(PregnancyApp(store: store));
      await tester.pumpAndSettle();
      await stage(tester, weeks, 3);
      expect(find.text('Step 2 of 2 · Ready to log'), findsOneWidget);
      expect(find.text('Your daily starting references'), findsOneWidget);
      if (weeks == 20) {
        await reveal(tester, find.text('Add weight & height (optional)'));
        await tester.tap(find.text('Add weight & height (optional)'));
        await tester.pumpAndSettle();
        final todayWeight =
            find.widgetWithText(TextFormField, 'Today’s weight (kg)');
        await reveal(tester, todayWeight);
        await tester.enterText(todayWeight, '64.2');
      }
      await tester.tap(find.text('Start logging'));
      await tester.pumpAndSettle();
      expect(store.data.profile!.gestationDays(DateTime.now()), weeks * 7 + 3);
      expect(store.data.profile!.prePregnancyKg, isNull);
      expect(store.data.profile!.heightCm, isNull);
      expect(PregnancyReference.totalGain(store.data.profile!), isNull);
      expect(store.data.weights.length, weeks == 20 ? 1 : 0);
      if (weeks == 20) expect(store.data.weights.single.kg, 64.2);
      expect(find.text('Week $weeks + 3 days'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'editing through the due-date route preserves readings and baseline',
      (tester) async {
    final today = calendarDate(DateTime.now());
    final profile = PregnancyProfile(
        dueDate: today.add(const Duration(days: 56)),
        prePregnancyKg: 59,
        heightCm: 165,
        maintenanceKcal: 2100,
        clinicianEnergyKcal: 2400);
    final store = MemoryStore(PregnancyData(
        profile: profile,
        weights: [WeightEntry(today.subtract(const Duration(days: 10)), 67)]));
    await tester.pumpWidget(PregnancyApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pregnancy profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(store.data.profile!.dueDate, profile.dueDate);
    expect(store.data.profile!.prePregnancyKg, 59);
    expect(store.data.profile!.maintenanceKcal, 2100);
    expect(store.data.profile!.clinicianEnergyKcal, 2400);
    expect(store.data.weights.single.kg, 67);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'optional baseline calculates a gain range and rejects invalid weight',
      (tester) async {
    final store = MemoryStore(PregnancyData());
    await tester.pumpWidget(PregnancyApp(store: store));
    await tester.pumpAndSettle();
    await stage(tester, 20, 3);
    await reveal(tester, find.text('Add weight & height (optional)'));
    await tester.tap(find.text('Add weight & height (optional)'));
    await tester.pumpAndSettle();
    final weight =
        find.widgetWithText(TextFormField, 'Weight before pregnancy (kg)');
    await reveal(tester, weight);
    await tester.enterText(weight, '0');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Start logging'));
    await tester.pumpAndSettle();
    expect(store.data.profile, isNull);
    await tester.enterText(weight, '60');
    final height = find.widgetWithText(TextFormField, 'Height (cm)');
    await reveal(tester, height);
    await tester.enterText(height, '165');
    await tester.pumpAndSettle();
    await reveal(
        tester, find.textContaining('Recommended total pregnancy gain:'));
    expect(find.textContaining('11.5–16.0 kg'), findsOneWidget);
    await tester.tap(find.text('Start logging'));
    await tester.pumpAndSettle();
    expect(store.data.profile!.prePregnancyKg, 60);
    expect(store.data.weights, isEmpty);
  });

  testWidgets('an invalid additional day does not advance setup',
      (tester) async {
    final store = MemoryStore(PregnancyData());
    await tester.pumpWidget(PregnancyApp(store: store));
    await tester.pumpAndSettle();
    await stage(tester, 20, 7);
    expect(find.text('Step 1 of 2 · Your stage'), findsOneWidget);
    expect(store.data.profile, isNull);
  });
}
