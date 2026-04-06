import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/debug_data_generator.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/strategy/data/dbo/goal_strategy_dbo.dart';
import 'package:opennutritracker/features/strategy/domain/entity/expenditure_state_entity.dart';
import 'package:opennutritracker/features/strategy/domain/entity/weight_entry_entity.dart';
import 'package:opennutritracker/features/strategy/domain/service/observed_rate_service.dart';
import 'package:opennutritracker/features/strategy/domain/service/strategy_rate_policy.dart';
import 'package:opennutritracker/features/strategy/domain/usecase/get_adaptive_strategy_snapshot_usecase.dart';
import 'package:opennutritracker/features/strategy/domain/usecase/sync_health_connect_weights_usecase.dart';
import 'package:opennutritracker/features/strategy/presentation/pages/weight_entry_page.dart';
import 'package:opennutritracker/features/strategy/presentation/widgets/weight_trend_chart.dart';

class StrategyPage extends StatefulWidget {
  const StrategyPage({super.key});

  @override
  State<StrategyPage> createState() => _StrategyPageState();
}

class _StrategyPageState extends State<StrategyPage> {
  GoalStrategyDBO? _strategy;
  ExpenditureStateEntity? _expenditureState;
  double? _trendWeight;
  double? _staticTdee;
  double? _calorieTarget;
  int _totalWeighIns = 0;
  List<WeightEntryEntity> _weightEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _computeState();
  }

  Future<void> _computeState({bool forceCurrentWeekRebuild = false}) async {
    await _runSilentHealthConnectSync();

    final snapshot = await locator<GetAdaptiveStrategySnapshotUsecase>()
        .getSnapshot(forceCurrentWeekRebuild: forceCurrentWeekRebuild);

    if (!mounted) {
      return;
    }

    setState(() {
      _strategy = snapshot.strategy;
      _expenditureState = snapshot.expenditureState;
      _trendWeight = snapshot.trendWeightKg;
      _staticTdee = snapshot.staticTdee;
      _calorieTarget = snapshot.calorieTarget;
      _totalWeighIns = snapshot.weightEntries.length;
      _weightEntries = snapshot.weightEntries;
      _isLoading = false;
    });
  }

  Future<void> _runSilentHealthConnectSync() async {
    try {
      await locator<SyncHealthConnectWeightsUsecase>().sync();
    } on Exception catch (error) {
      debugPrint('Silent Health Connect sync failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final state = _expenditureState;

    return RefreshIndicator(
      onRefresh: _computeState,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_weightEntries.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: WeightTrendChart(entries: _weightEntries),
              ),
            ),
          if (_weightEntries.isNotEmpty) const SizedBox(height: 12),
          _buildStatusCard(context, state),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  context,
                  'Estimated TDEE',
                  '${state?.estimatedExpenditureKcal.toInt() ?? '-'} kcal',
                  Icons.local_fire_department,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  context,
                  'Current Target',
                  '${_calorieTarget?.toInt() ?? '-'} kcal',
                  Icons.flag,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  context,
                  'Trend Weight',
                  _trendWeight != null
                      ? '${_trendWeight!.toStringAsFixed(1)} kg'
                      : '-',
                  Icons.trending_flat,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  context,
                  'Static TDEE',
                  '${_staticTdee?.toInt() ?? '-'} kcal',
                  Icons.calculate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildWeeklyRateComparisonCard(context),
          const SizedBox(height: 12),
          _buildDataQualityCard(context, state),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WeightEntryPage()),
                );
                await _computeState();
              },
              icon: const Icon(Icons.monitor_weight),
              label: Text('Weight History ($_totalWeighIns entries)'),
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 24),
            Text(
              'Debug',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await DebugDataGenerator.generate30Days();
                      if (!context.mounted) {
                        return;
                      }
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('30 days of fake data generated'),
                        ),
                      );
                      await _computeState();
                    },
                    icon: const Icon(Icons.science, size: 18),
                    label: const Text('Generate 30d'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Clear all data?'),
                          content: const Text(
                            'This deletes ALL weight entries, tracked days, and adaptive estimates.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      );
                      if (!context.mounted || confirmed != true) {
                        return;
                      }
                      final messenger = ScaffoldMessenger.of(context);
                      await DebugDataGenerator.clearAllData();
                      if (!context.mounted) {
                        return;
                      }
                      messenger.showSnackBar(
                        const SnackBar(content: Text('All data cleared')),
                      );
                      await _computeState();
                    },
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    label: const Text('Clear all'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, ExpenditureStateEntity? state) {
    final statusText = switch (state?.status) {
      ExpenditureStatus.seeded => 'Seeded: using static TDEE estimate',
      ExpenditureStatus.holding => 'Holding: not enough recent data to update',
      ExpenditureStatus.updating => 'Active: updating from your data',
      null => 'No data yet',
    };

    final statusColor = switch (state?.status) {
      ExpenditureStatus.seeded => Colors.orange,
      ExpenditureStatus.holding => Colors.red,
      ExpenditureStatus.updating => Colors.green,
      null => Colors.grey,
    };

    return Card(
      color: statusColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.circle, size: 12, color: statusColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimator Status',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    statusText,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
      BuildContext context, String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildDataQualityCard(
      BuildContext context, ExpenditureStateEntity? state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data Quality', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _qualityRow(
              context,
              'Valid nutrition days (21d)',
              '${state?.validNutritionDays ?? 0} / 21',
              (state?.validNutritionDays ?? 0) >= 14,
            ),
            _qualityRow(
              context,
              'Recent weigh-ins (7d)',
              '${state?.recentWeighInCount ?? 0} / 3',
              (state?.recentWeighInCount ?? 0) >= 1,
            ),
            _qualityRow(
              context,
              'Confidence',
              state != null ? '${(state.confidence * 100).toInt()}%' : '-',
              (state?.confidence ?? 0) >= 0.5,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyRateComparisonCard(BuildContext context) {
    final strategy = _strategy;
    final currentWeightKg = _currentBodyWeightKg;
    final desiredKgPerWeek = strategy == null
        ? 0.0
        : StrategyRatePolicy.signedKgPerWeek(
            mode: strategy.mode,
            pctPerWeek: strategy.targetRatePctPerWeek,
            bodyWeightKg: currentWeightKg,
          );
    final observedKgPerWeek =
        ObservedRateService.getObservedWeeklyKgChange(_weightEntries);
    final observedPctPerWeek =
        ObservedRateService.getObservedWeeklyPctChange(_weightEntries);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Rate',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _rateRow(
              context,
              'Desired',
              _formatSignedKgPerWeek(desiredKgPerWeek),
              strategy != null
                  ? '${strategy.targetRatePctPerWeek.toStringAsFixed(2)}% / week'
                  : null,
            ),
            const SizedBox(height: 8),
            _rateRow(
              context,
              'Observed',
              observedKgPerWeek != null
                  ? _formatSignedKgPerWeek(observedKgPerWeek)
                  : 'Not enough trend data',
              observedPctPerWeek != null
                  ? '${observedPctPerWeek.toStringAsFixed(2)}% / week'
                  : 'Uses the last 7 days of trend weight',
            ),
          ],
        ),
      ),
    );
  }

  Widget _qualityRow(
      BuildContext context, String label, String value, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.warning,
            size: 16,
            color: ok ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  double get _currentBodyWeightKg {
    if (_trendWeight != null) {
      return _trendWeight!;
    }
    if (_weightEntries.isNotEmpty) {
      return _weightEntries.last.weightKg;
    }
    return 70.0;
  }

  String _formatSignedKgPerWeek(double kgPerWeek) {
    final sign = kgPerWeek > 0
        ? '+'
        : kgPerWeek < 0
            ? '-'
            : '';
    return '$sign${kgPerWeek.abs().toStringAsFixed(2)} kg/week';
  }

  Widget _rateRow(
      BuildContext context, String label, String primary, String? secondary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                primary,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (secondary != null)
                Text(
                  secondary,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
