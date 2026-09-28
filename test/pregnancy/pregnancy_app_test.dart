import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/pregnancy/pregnancy_app.dart';
import 'package:opennutritracker/pregnancy/pregnancy_model.dart';
import 'package:opennutritracker/pregnancy/pregnancy_store.dart';

class MemoryStore implements PregnancyStore {
  PregnancyData data;
  bool failRead = false;
  bool failWrite = false;
  MemoryStore(this.data);
  @override
  Future<PregnancyData> read() async {
    if (failRead) throw StateError('unavailable');
    return data;
  }

  @override
  Future<void> write(PregnancyData value) async {
    if (failWrite) throw StateError('unavailable');
    data = value;
  }

  @override
  Future<void> clear() async {
    data = PregnancyData();
  }
}

void main() {
  testWidgets('weight chart renders at phone width and larger text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final now = calendarDate(DateTime.now());
    final store = MemoryStore(PregnancyData(
      profile: PregnancyProfile(
          dueDate: now.add(const Duration(days: 140)),
          prePregnancyKg: 60,
          heightCm: 165),
      weights: [
        WeightEntry(now.subtract(const Duration(days: 7)), 62),
        WeightEntry(now, 63)
      ],
    ));
    await tester.pumpWidget(PregnancyApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weight').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Readings'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('new user can read nutrition without old weight-loss onboarding',
      (tester) async {
    await tester.pumpWidget(PregnancyApp(store: MemoryStore(PregnancyData())));
    await tester.pumpAndSettle();
    expect(find.text('Set up pregnancy'), findsOneWidget);
    await tester.tap(find.text('Nutrition').last);
    await tester.pumpAndSettle();
    expect(find.text('Nutrients for pregnancy'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('600 µg DFE / day • RDA'), 220,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('600 µg DFE / day • RDA'), findsOneWidget);
    expect(find.textContaining('kcal left'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('weight entry saves and persists across app reload',
      (tester) async {
    final now = calendarDate(DateTime.now());
    final store = MemoryStore(PregnancyData(
        profile: PregnancyProfile(
            dueDate: now.add(const Duration(days: 140)),
            prePregnancyKg: 60,
            heightCm: 165)));
    await tester.pumpWidget(PregnancyApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weight').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log weight'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '64,2');
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();
    expect(store.data.weights.single.kg, 64.2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(PregnancyApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weight').last);
    await tester.pumpAndSettle();
    expect(find.text('4.2 kg since before pregnancy'), findsOneWidget);
  });

  testWidgets('read failure does not replace a saved journal', (tester) async {
    final store = MemoryStore(PregnancyData())..failRead = true;
    await tester.pumpWidget(PregnancyApp(store: store));
    await tester.pumpAndSettle();
    expect(find.textContaining('has not been replaced'), findsOneWidget);
    expect(find.text('Set up pregnancy'), findsNothing);
    store.failRead = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Set up pregnancy'), findsOneWidget);
  });

  testWidgets('failed weight save leaves previous readings unchanged',
      (tester) async {
    final store = MemoryStore(PregnancyData(
        profile: PregnancyProfile(
            dueDate: DateTime.now().add(const Duration(days: 140)))))
      ..failWrite = true;
    await tester.pumpWidget(PregnancyApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weight').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log weight'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '64');
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();
    expect(store.data.weights, isEmpty);
    expect(find.textContaining('Could not save.'), findsOneWidget);
  });
}
