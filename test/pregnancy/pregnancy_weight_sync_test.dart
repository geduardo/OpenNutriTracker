import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/pregnancy/pregnancy_controller.dart';
import 'package:opennutritracker/pregnancy/pregnancy_health_card.dart';
import 'package:opennutritracker/pregnancy/pregnancy_model.dart';
import 'package:opennutritracker/pregnancy/pregnancy_store.dart';
import 'package:opennutritracker/pregnancy/pregnancy_weight_reference.dart';
import 'package:opennutritracker/features/strategy/domain/service/health_connect_weight_service.dart';

class MemoryStore implements PregnancyStore {
  PregnancyData data;
  bool fail = false;
  MemoryStore(this.data);
  @override
  Future<PregnancyData> read() async => data;
  @override
  Future<void> write(PregnancyData next) async {
    if (fail) throw StateError('disk full');
    data = next;
  }

  @override
  Future<void> clear() async => data = PregnancyData();
}

class FakeHealth extends HealthConnectWeightService {
  bool granted = true, available = true, history = true, fail = false;
  int permissionRequests = 0, reads = 0, daysBack = 0;
  Completer<List<HealthConnectWeightSample>>? pending;
  List<HealthConnectWeightSample> samples = [];
  @override
  Future<HealthConnectStatus> getStatus() async => HealthConnectStatus(
      available: available,
      updateRequired: false,
      permissionsGranted: granted,
      historyPermissionGranted: history);
  @override
  Future<HealthConnectStatus> requestPermissions() async {
    permissionRequests++;
    return getStatus();
  }

  @override
  Future<List<HealthConnectWeightSample>> readWeights(
      {int daysBack = 3650}) async {
    reads++;
    this.daysBack = daysBack;
    if (fail) throw StateError('provider unavailable');
    return pending == null ? samples : await pending!.future;
  }
}

final now = DateTime(2026, 9, 28, 18);
PregnancyProfile profile(
        {double? height = 165, PregnancyType type = PregnancyType.singleton}) =>
    PregnancyProfile(
        dueDate:
            PregnancyDating.dueDateFromStage(onDate: now, weeks: 20, days: 3),
        prePregnancyKg: 59,
        heightCm: height,
        type: type);
HealthConnectWeightSample sample(DateTime time, double kg,
        [String source = 'scale']) =>
    HealthConnectWeightSample(
        time: time, weightKg: kg, sourcePackageName: source);
void main() {
  test(
      'published centile checkpoints, daily interpolation and no extrapolation',
      () {
    // Oxford's published table, independently transcribed checkpoints.
    expect(PregnancyWeightReference.atWeek(15), [-1.1, .4, 2.2]);
    expect(PregnancyWeightReference.atWeek(20), [1.2, 3.3, 5.8]);
    expect(PregnancyWeightReference.atWeek(28), [4.3, 7.5, 11.4]);
    expect(PregnancyWeightReference.atWeek(40), [8.7, 13.7, 20.1]);
    expect(PregnancyWeightReference.atWeek(20.5)![1], closeTo(3.55, .00001));
    for (final week in [14.99, 40.01, double.nan, double.infinity]) {
      expect(PregnancyWeightReference.atWeek(week), isNull);
    }
    final midpointOfEndpoints = (-1.1 + 8.7) / 2;
    expect(PregnancyWeightReference.atWeek(27.5)![0],
        isNot(closeTo(midpointOfEndpoints, .01)));
  });
  test(
      'study uses earliest 9–13+6 reading and its BMI, never pre-pregnancy BMI',
      () {
    final p = profile();
    final start = p.startDate;
    final early = WeightEntry(start.add(const Duration(days: 70)), 60);
    final later = WeightEntry(start.add(const Duration(days: 90)), 61);
    expect(PregnancyWeightReference.baseline(p, [later, early]), same(early));
    expect(PregnancyWeightReference.baseline(p, []), isNull);
    expect(
        PregnancyWeightReference.baseline(
            p, [WeightEntry(start, 60), WeightEntry(now, 65)]),
        isNull);
    expect(PregnancyWeightReference.baseline(profile(height: null), [early]),
        isNull);
    expect(
        PregnancyWeightReference.baseline(
            profile(type: PregnancyType.twins), [early]),
        isNull);
    expect(PregnancyWeightReference.baseline(p, [WeightEntry(early.date, 85)]),
        isNull);
    expect(
        PregnancyWeightReference.baseline(
            p, [WeightEntry(start.add(const Duration(days: 98)), 60)]),
        isNull);
    expect(
        PregnancyWeightReference.baseline(
            p, [WeightEntry(start.add(const Duration(days: 97)), 60)]),
        isNotNull);
  });
  test(
      'imports select latest local daily weight, protect manual, skip invalid/outside pregnancy',
      () {
    final p = profile();
    final yesterday = now.subtract(const Duration(days: 1));
    final data = PregnancyData(
        profile: p,
        healthSyncEnabled: true,
        weights: [WeightEntry(yesterday, 64)]);
    final merged = PregnancyController.mergeHealthWeights(
        data,
        [
          sample(DateTime(2026, 9, 28, 15), 66),
          sample(DateTime(2026, 9, 28, 8), 65),
          sample(yesterday, 90),
          sample(p.startDate.subtract(const Duration(days: 1)), 60),
          sample(now.add(const Duration(days: 1)), 67),
          sample(now, double.nan),
        ],
        now);
    expect(merged.weights.map((e) => e.kg), [64, 66]);
    expect(merged.weights.last.source, 'healthConnect');
    expect(merged.weights.last.sourcePackage, 'scale');
    final hidden = merged.withoutWeight(merged.weights.last);
    expect(
        PregnancyController.mergeHealthWeights(hidden, [sample(now, 66)], now)
            .weights
            .length,
        1);
    final restored = PregnancyData.fromJson(
        jsonDecode(jsonEncode(hidden.toJson())) as Map<String, dynamic>);
    expect(restored.hiddenHealthDays, hidden.hiddenHealthDays);
    expect(restored.healthSyncEnabled, isTrue);
    final manual = merged.withWeight(WeightEntry(now, 63));
    expect(
        PregnancyController.mergeHealthWeights(manual, [sample(now, 66)], now)
            .weights
            .last
            .kg,
        63);
    final old = PregnancyData.fromJson({
      'schema': 1,
      'profile': p.toJson(),
      'weights': [
        {'date': now.toIso8601String(), 'kg': 60}
      ]
    });
    expect(old.weights.single.source, 'manual');
    expect(old.healthSyncEnabled, isFalse);
  });
  test('permission denial, unavailable service and limited history are handled',
      () async {
    final store =
        MemoryStore(PregnancyData(profile: profile(), healthSyncEnabled: true));
    final health = FakeHealth()..granted = false;
    final controller = PregnancyController(store, store.data, health: health);
    await controller.syncHealth();
    expect(health.permissionRequests, 0);
    expect(health.reads, 0);
    await controller.syncHealth(requestPermission: true);
    expect(health.permissionRequests, 1);
    expect(health.reads, 0);
    health.available = false;
    await controller.syncHealth();
    expect(controller.healthMessage, contains('unavailable'));
    health.available = true;
    health.granted = true;
    health.history = false;
    await controller.syncHealth();
    expect(health.daysBack, 30);
    expect(store.data.lastHealthSync, isNotNull);
  });
  test(
      'repeated sync is idempotent; provider and persistence failures preserve data',
      () async {
    final today = DateTime.now();
    final p = PregnancyProfile(dueDate: today.add(const Duration(days: 100)));
    final store =
        MemoryStore(PregnancyData(profile: p, healthSyncEnabled: true));
    final health = FakeHealth()
      ..samples = [sample(today.subtract(const Duration(hours: 1)), 65)];
    final controller = PregnancyController(store, store.data, health: health);
    await controller.syncHealth();
    await controller.syncHealth();
    expect(controller.data.weights.length, 1);
    expect(controller.healthMessage, startsWith('0 new'));
    expect(
        PregnancyData.fromJson(jsonDecode(jsonEncode(store.data.toJson()))
                as Map<String, dynamic>)
            .weights
            .single
            .measuredAt,
        health.samples.single.time);
    health.samples = [sample(today.subtract(const Duration(hours: 1)), 66)];
    store.fail = true;
    await controller.syncHealth();
    expect(controller.data.weights.single.kg, 65);
    expect(controller.healthMessage, contains('Could not sync'));
    store.fail = false;
    health.fail = true;
    await controller.syncHealth();
    expect(controller.data.weights.single.kg, 65);
  });
  test('late imports cannot overwrite manual edits or a disconnect', () async {
    final today = DateTime.now();
    final store = MemoryStore(PregnancyData(
        profile:
            PregnancyProfile(dueDate: today.add(const Duration(days: 100))),
        healthSyncEnabled: true));
    final health = FakeHealth()..pending = Completer();
    final controller = PregnancyController(store, store.data, health: health);
    final task = controller.syncHealth();
    await Future<void>.delayed(Duration.zero);
    await controller.update((d) => d.withWeight(WeightEntry(today, 64)));
    health.pending!.complete([sample(today, 66)]);
    await task;
    expect(controller.data.weights.single.kg, 64);
    health.pending = Completer();
    final second = controller.syncHealth();
    await Future<void>.delayed(Duration.zero);
    await controller.setHealthEnabled(false);
    health.pending!
        .complete([sample(today.subtract(const Duration(days: 1)), 66)]);
    await second;
    expect(controller.data.weights.length, 1);
    expect(controller.data.healthSyncEnabled, isFalse);
  });
  testWidgets('weight connection is reachable and shows permission failure',
      (tester) async {
    final store = MemoryStore(PregnancyData(profile: profile()));
    final health = FakeHealth()..granted = false;
    final controller = PregnancyController(store, store.data, health: health);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: PregnancyHealthCard(controller: controller)))));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(health.permissionRequests, 1);
    expect(find.textContaining('Weight permission is needed'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
