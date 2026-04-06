import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/features/strategy/data/repository/weight_entry_repository.dart';
import 'package:opennutritracker/features/strategy/domain/entity/weight_entry_entity.dart';
import 'package:opennutritracker/features/strategy/domain/service/health_connect_weight_service.dart';

enum HealthConnectSyncOutcome {
  synced,
  unavailable,
  permissionsRequired,
  permissionsDenied,
}

class HealthConnectSyncResult {
  final HealthConnectSyncOutcome outcome;
  final HealthConnectStatus status;
  final int importedCount;
  final int skippedCount;

  const HealthConnectSyncResult({
    required this.outcome,
    required this.status,
    this.importedCount = 0,
    this.skippedCount = 0,
  });

  bool get hasChanges => importedCount > 0;
}

class SyncHealthConnectWeightsUsecase {
  final HealthConnectWeightService _healthConnectWeightService;
  final WeightEntryRepository _weightEntryRepository;
  final UserRepository _userRepository;

  SyncHealthConnectWeightsUsecase(
    this._healthConnectWeightService,
    this._weightEntryRepository,
    this._userRepository,
  );

  Future<HealthConnectSyncResult> sync({
    bool requestPermissionsIfNeeded = false,
    int daysBack = 3650,
  }) async {
    var status = await _healthConnectWeightService.getStatus();
    if (!status.available) {
      return HealthConnectSyncResult(
        outcome: HealthConnectSyncOutcome.unavailable,
        status: status,
      );
    }

    if (!status.permissionsGranted) {
      if (!requestPermissionsIfNeeded) {
        return HealthConnectSyncResult(
          outcome: HealthConnectSyncOutcome.permissionsRequired,
          status: status,
        );
      }

      status = await _healthConnectWeightService.requestPermissions();
      if (!status.permissionsGranted) {
        return HealthConnectSyncResult(
          outcome: HealthConnectSyncOutcome.permissionsDenied,
          status: status,
        );
      }
    }

    final samples =
        await _healthConnectWeightService.readWeights(daysBack: daysBack);
    final importSummary = await _mergeHealthConnectWeights(samples);

    return HealthConnectSyncResult(
      outcome: HealthConnectSyncOutcome.synced,
      status: status,
      importedCount: importSummary.importedCount,
      skippedCount: importSummary.skippedCount,
    );
  }

  Future<_HealthConnectImportSummary> _mergeHealthConnectWeights(
    List<HealthConnectWeightSample> samples,
  ) async {
    final existingEntries = await _weightEntryRepository.getAllEntries();
    final entriesByDay = <String, WeightEntryEntity>{
      for (final entry in existingEntries) _dayKey(entry.day): entry,
    };

    final sortedSamples = List<HealthConnectWeightSample>.from(samples)
      ..sort((a, b) => a.time.compareTo(b.time));

    var importedCount = 0;
    var skippedCount = 0;

    for (final sample in sortedSamples) {
      final dayKey = _dayKey(sample.time);
      final existing = entriesByDay[dayKey];
      final importedEntry = WeightEntryEntity(
        day: sample.time,
        weightKg: sample.weightKg,
        note: sample.sourcePackageName,
        source: WeightEntrySource.healthConnect,
      );

      if (existing != null &&
          existing.source != WeightEntrySource.healthConnect &&
          existing.source != WeightEntrySource.migratedProfileWeight) {
        skippedCount++;
        continue;
      }

      if (existing != null &&
          existing.source == WeightEntrySource.healthConnect &&
          (existing.weightKg - sample.weightKg).abs() < 0.001 &&
          existing.note == sample.sourcePackageName) {
        continue;
      }

      await _weightEntryRepository.addEntry(importedEntry);
      entriesByDay[dayKey] = importedEntry;
      importedCount++;
    }

    final latestEntry = await _weightEntryRepository.getLatestEntry();
    if (latestEntry != null) {
      await _syncCurrentWeight(latestEntry.weightKg);
    }

    return _HealthConnectImportSummary(
      importedCount: importedCount,
      skippedCount: skippedCount,
    );
  }

  Future<void> _syncCurrentWeight(double weightKg) async {
    final user = await _userRepository.getUserData();
    if ((user.weightKG - weightKg).abs() <= 0.001) {
      return;
    }

    user.weightKG = weightKg;
    await _userRepository.updateUserData(user);
  }

  String _dayKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
}

class _HealthConnectImportSummary {
  final int importedCount;
  final int skippedCount;

  const _HealthConnectImportSummary({
    required this.importedCount,
    required this.skippedCount,
  });
}
