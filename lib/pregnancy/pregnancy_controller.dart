import 'dart:async';
import 'package:flutter/foundation.dart';
import '../features/strategy/domain/service/health_connect_weight_service.dart';
import 'pregnancy_model.dart';
import 'pregnancy_store.dart';

class PregnancyController extends ChangeNotifier {
  final PregnancyStore store;
  final HealthConnectWeightService health;
  PregnancyData data;
  bool syncing = false;
  HealthConnectStatus? healthStatus;
  String? healthMessage;
  Future<void>? _writes;
  PregnancyController(this.store, this.data,
      {HealthConnectWeightService? health})
      : health = health ?? HealthConnectWeightService();

  Future<void> update(PregnancyData Function(PregnancyData) change) {
    Future<void> apply() async {
      final next = change(data);
      await store.write(next);
      data = next;
      notifyListeners();
    }

    final result = _writes == null ? apply() : _writes!.then((_) => apply());
    final tail = result.catchError((Object _) {});
    _writes = tail;
    unawaited(tail.then((_) {
      if (identical(_writes, tail)) _writes = null;
    }));
    return result;
  }

  Future<void> save(PregnancyData next) => update((_) => next);
  Future<void> reload() async {
    await _writes;
    data = await store.read();
    notifyListeners();
  }

  Future<void> setHealthEnabled(bool enabled) async {
    await update((d) => d.copyWith(healthSyncEnabled: enabled));
    if (enabled) await syncHealth(requestPermission: true);
  }

  /// Foreground-only reads. Permission prompts occur only on an explicit tap.
  Future<void> syncHealth({bool requestPermission = false}) async {
    if (syncing || data.profile == null || !data.healthSyncEnabled) return;
    syncing = true;
    healthMessage = null;
    notifyListeners();
    try {
      var status = await health.getStatus();
      healthStatus = status;
      if (!status.available) {
        healthMessage = status.updateRequired
            ? 'Update Health Connect to import weights.'
            : 'Health Connect is unavailable on this device.';
        return;
      }
      if (!status.permissionsGranted && requestPermission) {
        status = await health.requestPermissions();
        healthStatus = status;
      }
      if (!status.permissionsGranted) {
        healthMessage =
            'Weight permission is needed. Tap Connect to allow access.';
        return;
      }
      final now = DateTime.now();
      final requestedDays = now.difference(data.profile!.startDate).inDays + 2;
      final samples = await health.readWeights(
          daysBack: status.historyPermissionGranted
              ? requestedDays.clamp(1, 3650)
              : 30);
      var changed = 0;
      await update((latest) {
        // A disconnect or profile change while Android was reading takes priority.
        if (!latest.healthSyncEnabled || latest.profile == null) return latest;
        final merged = mergeHealthWeights(latest, samples, now);
        changed = merged.weights
            .where((e) => !latest.weights.any((old) =>
                old.date == e.date &&
                old.kg == e.kg &&
                old.source == e.source &&
                old.measuredAt == e.measuredAt &&
                old.sourcePackage == e.sourcePackage))
            .length;
        return merged.copyWith(lastHealthSync: now);
      });
      healthMessage = data.healthSyncEnabled
          ? '$changed new or updated daily readings. Manual entries are kept.'
          : 'Automatic import is off.';
    } catch (_) {
      healthMessage =
          'Could not sync weights. Your saved readings are unchanged. Try again.';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  /// One latest sample per local calendar day; manual edits always win.
  /// Imported copies are retained if a source app later deletes its record.
  static PregnancyData mergeHealthWeights(PregnancyData data,
      List<HealthConnectWeightSample> samples, DateTime now) {
    final profile = data.profile;
    if (profile == null) return data;
    final byDay = {for (final e in data.weights) e.date: e};
    final sorted = [...samples]..sort((a, b) {
        final time = a.time.compareTo(b.time);
        if (time != 0) return time;
        final source =
            (a.sourcePackageName ?? '').compareTo(b.sourcePackageName ?? '');
        return source != 0 ? source : a.weightKg.compareTo(b.weightKg);
      });
    for (final sample in sorted) {
      final date = calendarDate(sample.time.toLocal());
      final age = profile.gestationDays(date);
      if (!sample.weightKg.isFinite ||
          sample.weightKg < 25 ||
          sample.weightKg > 350 ||
          sample.time.isAfter(now) ||
          age < 0 ||
          age > PregnancyDating.maxGestationDays ||
          data.hiddenHealthDays.contains(PregnancyData.dayKey(date))) {
        continue;
      }
      final existing = byDay[date];
      if (existing != null && existing.source != 'healthConnect') continue;
      byDay[date] = WeightEntry(date, sample.weightKg,
          source: 'healthConnect',
          sourcePackage: sample.sourcePackageName,
          measuredAt: sample.time);
    }
    return data.copyWith(weights: byDay.values.toList());
  }
}
