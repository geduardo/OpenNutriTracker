import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/strategy/data/dbo/check_in_record_dbo.dart';
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
  CheckInRecordDBO? _currentCheckIn;
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
      _currentCheckIn = snapshot.currentCheckIn;
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
          _buildTargetCard(context, state),
          if (_weightEntries.isNotEmpty) const SizedBox(height: 12),
          if (_shouldShowAttentionCard(state)) ...[
            _buildAttentionCard(context, state),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  context,
                  'Estimated maintenance',
                  '${state?.estimatedExpenditureKcal.toInt() ?? '-'} kcal',
                  Icons.local_fire_department_outlined,
                  subtitle: 'learned from your data',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  context,
                  'True Weight',
                  _trendWeight != null
                      ? '${_trendWeight!.toStringAsFixed(1)} kg'
                      : '-',
                  Icons.monitor_weight_outlined,
                  subtitle: 'smoothed',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildWhyTargetCard(context, state),
          const SizedBox(height: 12),
          if (_weightEntries.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: WeightTrendChart(entries: _weightEntries),
              ),
            ),
          if (_weightEntries.isNotEmpty) const SizedBox(height: 12),
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
        ],
      ),
    );
  }

  Widget _buildTargetCard(BuildContext context, ExpenditureStateEntity? state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This week\'s target',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _calorieTarget != null
                  ? '${_calorieTarget!.toInt()} kcal/day'
                  : '-',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  context,
                  _statusLabel(state),
                  _statusColor(state),
                  Icons.insights_outlined,
                ),
                _buildInfoChip(
                  context,
                  _goalSummaryLabel(),
                  Theme.of(context).colorScheme.secondary,
                  Icons.flag_outlined,
                ),
                if (state != null)
                  _buildInfoChip(
                    context,
                    '${(state.confidence * 100).toInt()}% confidence',
                    Theme.of(context).colorScheme.primary,
                    Icons.data_usage_outlined,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _buildTargetStatusText(state),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttentionCard(
      BuildContext context, ExpenditureStateEntity? state) {
    final color = Theme.of(context).colorScheme.secondary;

    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To improve the estimate',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              _buildAttentionText(state),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    String? subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            if (subtitle != null)
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhyTargetCard(
      BuildContext context, ExpenditureStateEntity? state) {
    final maintenance = state?.estimatedExpenditureKcal;
    final checkIn = _currentCheckIn;
    final goalAdjustment = checkIn != null
        ? checkIn.proposedCalorieTarget - checkIn.expenditureAtCheckIn
        : null;
    final weeklyChange = checkIn != null
        ? checkIn.appliedCalorieTarget - checkIn.previousCalorieTarget
        : null;
    final finalTarget = checkIn?.appliedCalorieTarget ?? _calorieTarget;
    final usingController = checkIn != null &&
        (checkIn.appliedCalorieTarget - checkIn.proposedCalorieTarget).abs() >=
            1;
    final shouldShowProfileEstimate = _staticTdee != null &&
        (maintenance == null ||
            (maintenance - _staticTdee!).abs() >= 25 ||
            state?.status != ExpenditureStatus.updating);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Why this target',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _buildBreakdownRow(
              context,
              'Estimated maintenance',
              _formatKcal(maintenance),
              state?.status == ExpenditureStatus.updating
                  ? 'recent intake + weight trend'
                  : 'current best estimate',
            ),
            if (goalAdjustment != null)
              _buildBreakdownRow(
                context,
                'Goal adjustment',
                _formatSignedKcal(goalAdjustment),
                _goalAdjustmentDetail(),
              ),
            if (weeklyChange != null)
              _buildBreakdownRow(
                context,
                'Weekly change',
                _formatSignedKcal(weeklyChange),
                usingController ? 'limited to avoid a big jump' : null,
              ),
            _buildBreakdownRow(
              context,
              'Final target',
              _formatKcal(finalTarget),
              null,
              emphasize: true,
            ),
            if (shouldShowProfileEstimate)
              _buildBreakdownRow(
                context,
                'Profile estimate',
                _formatKcal(_staticTdee),
                'static fallback from your profile',
              ),
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
            Text('Estimator inputs',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _qualityRow(
              context,
              'Complete nutrition days (21d)',
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
              'Weekly weight change',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _rateRow(
              context,
              'Goal',
              _formatSignedKgPerWeek(desiredKgPerWeek),
              strategy != null
                  ? '${strategy.targetRatePctPerWeek.toStringAsFixed(2)}% / week'
                  : null,
            ),
            const SizedBox(height: 8),
            _rateRow(
              context,
              'Actual',
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

  bool _shouldShowAttentionCard(ExpenditureStateEntity? state) {
    return state == null || state.status != ExpenditureStatus.updating;
  }

  String _buildTargetStatusText(ExpenditureStateEntity? state) {
    if (state == null) {
      return 'Add a few complete days and a recent weigh-in to start adapting.';
    }

    if (state.status == ExpenditureStatus.updating) {
      return 'Updated from your recent logs and weight trend.';
    }

    if (state.status == ExpenditureStatus.seeded) {
      return 'Still using your profile estimate until enough data comes in.';
    }

    return 'Holding the current estimate until there is enough recent data again.';
  }

  String _buildAttentionText(ExpenditureStateEntity? state) {
    if (state == null) {
      return 'Log a few complete days and add a weigh-in.';
    }

    if (state.validNutritionDays < 14 && state.recentWeighInCount < 1) {
      return 'Log more complete days and add a recent weigh-in.';
    }

    if (state.validNutritionDays < 14) {
      return 'Log more complete nutrition days. The estimator wants about 14 good days in the last 21.';
    }

    if (state.recentWeighInCount < 1) {
      return 'Add a recent weigh-in. Weight data is the missing piece right now.';
    }

    return 'Keep logging normally for another week so the estimate can stabilize.';
  }

  String _statusLabel(ExpenditureStateEntity? state) {
    return switch (state?.status) {
      ExpenditureStatus.seeded => 'Seeded',
      ExpenditureStatus.holding => 'Holding',
      ExpenditureStatus.updating => 'Live',
      null => 'No data',
    };
  }

  Color _statusColor(ExpenditureStateEntity? state) {
    return switch (state?.status) {
      ExpenditureStatus.seeded => Colors.orange,
      ExpenditureStatus.holding => Colors.red,
      ExpenditureStatus.updating => Colors.green,
      null => Colors.grey,
    };
  }

  String _goalSummaryLabel() {
    final strategy = _strategy;
    if (strategy == null) {
      return 'Goal';
    }

    return switch (strategy.mode) {
      StrategyGoalModeDBO.lose =>
        'Lose ${strategy.targetRatePctPerWeek.toStringAsFixed(2)}%/week',
      StrategyGoalModeDBO.gain =>
        'Gain ${strategy.targetRatePctPerWeek.toStringAsFixed(2)}%/week',
      StrategyGoalModeDBO.maintain => strategy.targetWeightKg != null
          ? 'Maintain ${strategy.targetWeightKg!.toStringAsFixed(1)} kg'
          : 'Maintain weight',
    };
  }

  String _goalAdjustmentDetail() {
    final strategy = _strategy;
    if (strategy == null) {
      return 'based on your goal';
    }

    return switch (strategy.mode) {
      StrategyGoalModeDBO.lose =>
        'cut for ${strategy.targetRatePctPerWeek.toStringAsFixed(2)}%/week',
      StrategyGoalModeDBO.gain =>
        'surplus for ${strategy.targetRatePctPerWeek.toStringAsFixed(2)}%/week',
      StrategyGoalModeDBO.maintain => strategy.targetWeightKg != null
          ? 'keeping you near ${strategy.targetWeightKg!.toStringAsFixed(1)} kg'
          : 'keeping you near maintenance',
    };
  }

  String _formatKcal(double? value) {
    if (value == null) {
      return '-';
    }

    return '${value.toInt()} kcal/day';
  }

  String _formatSignedKcal(double value) {
    final sign = value > 0
        ? '+'
        : value < 0
            ? '-'
            : '';
    return '$sign${value.abs().toInt()} kcal/day';
  }

  Widget _buildInfoChip(
    BuildContext context,
    String label,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(
    BuildContext context,
    String label,
    String value,
    String? subtitle, {
    bool emphasize = false,
  }) {
    final valueStyle = emphasize
        ? Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: valueStyle),
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
