import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/data_source/tracked_day_data_source.dart';
import 'package:opennutritracker/core/domain/usecase/get_kcal_goal_usecase.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/strategy/data/data_source/expenditure_state_data_source.dart';
import 'package:opennutritracker/features/strategy/data/repository/weight_entry_repository.dart';
import 'package:opennutritracker/features/strategy/domain/entity/expenditure_state_entity.dart';
import 'package:opennutritracker/features/strategy/domain/entity/weight_entry_entity.dart';
import 'package:opennutritracker/features/strategy/domain/service/expenditure_estimator_service.dart';
import 'package:opennutritracker/features/strategy/domain/service/trend_weight_service.dart';
import 'package:opennutritracker/features/strategy/presentation/widgets/weight_trend_chart.dart';
import 'package:opennutritracker/core/utils/debug_data_generator.dart';
import 'package:opennutritracker/features/strategy/data/dbo/day_log_quality_dbo.dart';
import 'package:opennutritracker/features/strategy/presentation/pages/weight_entry_page.dart';

class StrategyPage extends StatefulWidget {
  const StrategyPage({super.key});

  @override
  State<StrategyPage> createState() => _StrategyPageState();
}

class _StrategyPageState extends State<StrategyPage> {
  ExpenditureStateEntity? _expenditureState;
  double? _trendWeight;
  double? _staticTdee;
  int _totalWeighIns = 0;
  List<WeightEntryEntity> _weightEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _computeState();
  }

  Future<void> _computeState() async {
    final weightRepo = locator<WeightEntryRepository>();
    final trackedDayDataSource = locator<TrackedDayDataSource>();
    final expDataSource = locator<ExpenditureStateDataSource>();
    final kcalGoalUsecase = locator<GetKcalGoalUsecase>();

    final weightEntries = await weightRepo.getAllEntries();
    final trackedDays = await trackedDayDataSource.getAllTrackedDays();
    final previousState = await expDataSource.getLatestState();
    final staticTdee = await kcalGoalUsecase.getStaticTdee();

    final previous = previousState != null
        ? ExpenditureStateEntity.fromDBO(previousState)
        : null;

    // Only recompute if we haven't already computed today
    final today = DateUtils.dateOnly(DateTime.now());
    ExpenditureStateEntity state;

    if (previous != null && DateUtils.dateOnly(previous.day) == today) {
      // Already computed today — use saved state
      state = previous;
      debugPrint('Strategy: using cached estimate for today');
    } else {
      // New day or no prior state — recompute
      debugPrint('Strategy: ${trackedDays.length} tracked days, ${weightEntries.length} weight entries');

      state = ExpenditureEstimatorService.estimate(
        trackedDays: trackedDays,
        weightEntries: weightEntries,
        previousEstimate: previous,
        seedTdee: staticTdee,
      );
      debugPrint('Strategy: status=${state.status}, validDays=${state.validNutritionDays}, weighIns=${state.recentWeighInCount}, exp=${state.estimatedExpenditureKcal.toInt()}');

      // Persist the new state
      await expDataSource.saveState(state.toDBO());
    }

    final trendWeight = TrendWeightService.getLatestTrendWeight(weightEntries);

    if (mounted) {
      setState(() {
        _expenditureState = state;
        _trendWeight = trendWeight;
        _staticTdee = staticTdee;
        _totalWeighIns = weightEntries.length;
        _weightEntries = weightEntries;
        _isLoading = false;
      });
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
          // Weight trend chart
          if (_weightEntries.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: WeightTrendChart(entries: _weightEntries),
              ),
            ),
          const SizedBox(height: 12),

          // Estimator status card
          _buildStatusCard(context, state),
          const SizedBox(height: 12),

          // Key numbers
          Row(
            children: [
              Expanded(
                  child: _buildMetricCard(
                      context,
                      'Estimated TDEE',
                      '${state?.estimatedExpenditureKcal.toInt() ?? '—'} kcal',
                      Icons.local_fire_department)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildMetricCard(
                      context,
                      'Trend Weight',
                      _trendWeight != null
                          ? '${_trendWeight!.toStringAsFixed(1)} kg'
                          : '—',
                      Icons.trending_flat)),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                  child: _buildMetricCard(
                      context,
                      'Static TDEE',
                      '${_staticTdee?.toInt() ?? '—'} kcal',
                      Icons.calculate)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildMetricCard(
                      context,
                      'Confidence',
                      state != null
                          ? '${(state.confidence * 100).toInt()}%'
                          : '—',
                      Icons.speed)),
            ],
          ),
          const SizedBox(height: 12),

          // Data quality
          _buildDataQualityCard(context, state),
          const SizedBox(height: 12),

          // Weight history button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const WeightEntryPage()),
                );
                _computeState(); // Refresh after returning
              },
              icon: const Icon(Icons.monitor_weight),
              label: Text('Weight History ($_totalWeighIns entries)'),
            ),
          ),
          const SizedBox(height: 24),

          // Debug section
          Text('Debug', style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await DebugDataGenerator.generate30Days();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('30 days of fake data generated')),
                      );
                      _computeState();
                    }
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
                        content: const Text('This deletes ALL weight entries and tracked days.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                        ],
                      ),
                    );
                    if (confirmed == true && mounted) {
                      await DebugDataGenerator.clearAllData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All data cleared')),
                      );
                      _computeState();
                    }
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
      ),
    );
  }

  Widget _buildStatusCard(
      BuildContext context, ExpenditureStateEntity? state) {
    final statusText = switch (state?.status) {
      ExpenditureStatus.seeded => 'Seeded — using static TDEE estimate',
      ExpenditureStatus.holding =>
        'Holding — not enough recent data to update',
      ExpenditureStatus.updating => 'Active — updating from your data',
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
                  Text('Estimator Status',
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(statusText,
                      style: Theme.of(context).textTheme.bodySmall),
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
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
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
            Text('Data Quality',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _qualityRow(
                context,
                'Valid nutrition days (21d)',
                '${state?.validNutritionDays ?? 0} / 21',
                (state?.validNutritionDays ?? 0) >= 14),
            _qualityRow(
                context,
                'Recent weigh-ins (7d)',
                '${state?.recentWeighInCount ?? 0} / 3',
                (state?.recentWeighInCount ?? 0) >= 1),
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
          Icon(ok ? Icons.check_circle : Icons.warning,
              size: 16, color: ok ? Colors.green : Colors.orange),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
