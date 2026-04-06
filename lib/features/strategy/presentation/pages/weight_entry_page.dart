import 'dart:io';

import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/data/repository/user_repository.dart';
import 'package:opennutritracker/features/strategy/data/repository/weight_entry_repository.dart';
import 'package:opennutritracker/features/strategy/domain/entity/weight_entry_entity.dart';
import 'package:opennutritracker/features/strategy/domain/service/health_connect_weight_service.dart';
import 'package:opennutritracker/features/strategy/domain/service/trend_weight_service.dart';
import 'package:opennutritracker/features/strategy/domain/usecase/sync_health_connect_weights_usecase.dart';

class WeightEntryPage extends StatefulWidget {
  const WeightEntryPage({super.key});

  @override
  State<WeightEntryPage> createState() => _WeightEntryPageState();
}

class _WeightEntryPageState extends State<WeightEntryPage> {
  final _weightController = TextEditingController();
  List<WeightEntryEntity> _entries = [];
  double? _trendWeight;
  bool _isLoading = true;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool syncHealthConnect = true}) async {
    if (syncHealthConnect) {
      await _runSilentHealthConnectSync();
    }

    final repo = locator<WeightEntryRepository>();
    final entries = await repo.getAllEntries();
    final trend = TrendWeightService.getLatestTrendWeight(entries);

    if (mounted) {
      setState(() {
        _entries = entries;
        _trendWeight = trend;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight History'),
        actions: [
          if (Platform.isAndroid)
            IconButton(
              onPressed: _isImporting ? null : _importFromHealthConnect,
              icon: _isImporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.health_and_safety_outlined),
              tooltip: 'Import from Health Connect',
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addWeight,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Trend weight summary
                if (_trendWeight != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Column(
                      children: [
                        Text('Trend Weight',
                            style: Theme.of(context).textTheme.bodyMedium),
                        Text(
                          '${_trendWeight!.toStringAsFixed(1)} kg',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        if (_entries.isNotEmpty)
                          Text(
                            'Last weigh-in: ${_entries.last.weightKg.toStringAsFixed(1)} kg',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),

                if (Platform.isAndroid)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _isImporting ? null : _importFromHealthConnect,
                        icon: _isImporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.health_and_safety_outlined),
                        label: const Text('Import from Health Connect'),
                      ),
                    ),
                  ),

                // Weight history list
                Expanded(
                  child: _entries.isEmpty
                      ? const Center(child: Text('No weight entries yet'))
                      : ListView.builder(
                          itemCount: _entries.length,
                          itemBuilder: (context, index) {
                            // Show newest first
                            final entry = _entries[_entries.length - 1 - index];
                            final trendForDay =
                                TrendWeightService.getTrendWeightForDate(
                                    _entries, entry.day);
                            return ListTile(
                              leading: Icon(
                                _iconForSource(entry.source),
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: Text(
                                  '${entry.weightKg.toStringAsFixed(1)} kg'),
                              subtitle: Text(_subtitleForEntry(entry)),
                              trailing: trendForDay != null
                                  ? Text(
                                      'trend: ${trendForDay.toStringAsFixed(1)}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall)
                                  : null,
                              onLongPress: () => _deleteEntry(entry),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _addWeight() {
    _weightController.text =
        _entries.isNotEmpty ? _entries.last.weightKg.toStringAsFixed(1) : '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Weight'),
        content: TextField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            suffixText: 'kg',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final weight =
                  double.tryParse(_weightController.text.replaceAll(',', '.'));
              if (weight != null && weight > 0) {
                Navigator.pop(ctx);
                final repo = locator<WeightEntryRepository>();
                await repo.addEntry(WeightEntryEntity(
                  day: DateTime.now(),
                  weightKg: weight,
                  source: WeightEntrySource.manual,
                ));
                await _syncCurrentWeight(weight);
                _loadData(syncHealthConnect: false);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEntry(WeightEntryEntity entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete?'),
        content: Text(
            'Delete ${entry.weightKg.toStringAsFixed(1)} kg on ${_formatDate(entry.day)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = locator<WeightEntryRepository>();
      await repo.deleteEntry(entry.day);
      final remainingEntries = await repo.getAllEntries();
      if (remainingEntries.isNotEmpty) {
        await _syncCurrentWeight(remainingEntries.last.weightKg);
      }
      _loadData(syncHealthConnect: false);
    }
  }

  Future<void> _syncCurrentWeight(double weightKg) async {
    final userRepository = locator<UserRepository>();
    final user = await userRepository.getUserData();
    if ((user.weightKG - weightKg).abs() <= 0.001) {
      return;
    }

    user.weightKG = weightKg;
    await userRepository.updateUserData(user);
  }

  Future<void> _importFromHealthConnect() async {
    setState(() {
      _isImporting = true;
    });

    try {
      final result = await locator<SyncHealthConnectWeightsUsecase>().sync(
        requestPermissionsIfNeeded: true,
      );

      if (result.outcome == HealthConnectSyncOutcome.unavailable) {
        await _showHealthConnectUnavailableDialog(result.status);
        return;
      }

      if (result.outcome == HealthConnectSyncOutcome.permissionsRequired ||
          result.outcome == HealthConnectSyncOutcome.permissionsDenied) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Health Connect access was not granted.'),
          ),
        );
        return;
      }

      if (!mounted) {
        return;
      }

      await _loadData(syncHealthConnect: false);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_buildImportMessage(result)),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not import Health Connect weights: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _runSilentHealthConnectSync() async {
    if (!Platform.isAndroid) {
      return;
    }

    if (mounted) {
      setState(() {
        _isImporting = true;
      });
    }

    try {
      await locator<SyncHealthConnectWeightsUsecase>().sync();
    } on Exception catch (error) {
      debugPrint('Silent Health Connect sync failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _showHealthConnectUnavailableDialog(
    HealthConnectStatus status,
  ) async {
    final service = locator<HealthConnectWeightService>();

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Health Connect unavailable'),
        content: Text(
          status.updateRequired
              ? 'Health Connect is installed but needs an update before weights can be imported.'
              : 'Health Connect is not available on this device yet. Install it from Google Play to import your Withings weights.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await service.openHealthConnectStore();
            },
            child: Text(status.updateRequired ? 'Update' : 'Install'),
          ),
        ],
      ),
    );
  }

  IconData _iconForSource(WeightEntrySource source) {
    return switch (source) {
      WeightEntrySource.manual => Icons.monitor_weight,
      WeightEntrySource.migratedProfileWeight => Icons.sync,
      WeightEntrySource.healthConnect => Icons.health_and_safety_outlined,
    };
  }

  String _subtitleForEntry(WeightEntryEntity entry) {
    final sourceLabel = switch (entry.source) {
      WeightEntrySource.manual => null,
      WeightEntrySource.migratedProfileWeight => 'Profile seed',
      WeightEntrySource.healthConnect => 'Health Connect',
    };

    if (sourceLabel == null) {
      return _formatDate(entry.day);
    }

    return '${_formatDate(entry.day)} - $sourceLabel';
  }

  String _buildImportMessage(HealthConnectSyncResult result) {
    if (result.importedCount == 0 && result.skippedCount == 0) {
      return 'No new Health Connect weights found.';
    }

    if (result.importedCount == 0) {
      return 'No new weights imported - skipped ${result.skippedCount} existing manual days.';
    }

    final skippedSuffix = result.skippedCount > 0
        ? ' - skipped ${result.skippedCount} existing manual days'
        : '';
    return 'Imported ${result.importedCount} weights$skippedSuffix.';
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
