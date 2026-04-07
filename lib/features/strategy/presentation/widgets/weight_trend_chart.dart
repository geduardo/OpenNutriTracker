import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/features/strategy/domain/entity/weight_entry_entity.dart';
import 'package:opennutritracker/features/strategy/domain/service/trend_weight_service.dart';

enum ChartRange {
  oneWeek('1W', 7),
  oneMonth('1M', 30),
  threeMonths('3M', 90),
  sixMonths('6M', 180),
  oneYear('1Y', 365),
  twoYears('2Y', 730);

  final String label;
  final int days;
  const ChartRange(this.label, this.days);
}

class WeightTrendChart extends StatefulWidget {
  final List<WeightEntryEntity> entries;

  const WeightTrendChart({super.key, required this.entries});

  @override
  State<WeightTrendChart> createState() => _WeightTrendChartState();
}

class _WeightTrendChartState extends State<WeightTrendChart> {
  ChartRange _range = ChartRange.oneMonth;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final rangeStart = DateUtils.dateOnly(
        DateTime(today.year, today.month, today.day - _range.days));

    // Filter entries in range
    final entriesInRange = widget.entries
        .where((e) => !DateUtils.dateOnly(e.day).isBefore(rangeStart))
        .toList();

    // Compute trend series for this range
    final allTrend = TrendWeightService.computeTrendSeries(widget.entries,
        endDate: today);
    final trendInRange = <DateTime, double>{};
    allTrend.forEach((day, value) {
      if (!day.isBefore(rangeStart)) trendInRange[day] = value;
    });

    // Build chart spots
    final scaleSpots = <FlSpot>[];
    final trendSpots = <FlSpot>[];

    for (final entry in entriesInRange) {
      final x = DateUtils.dateOnly(entry.day)
          .difference(rangeStart)
          .inDays
          .toDouble();
      scaleSpots.add(FlSpot(x, entry.weightKg));
    }

    final sortedTrendDays = trendInRange.keys.toList()..sort();
    for (final day in sortedTrendDays) {
      final x = day.difference(rangeStart).inDays.toDouble();
      trendSpots.add(FlSpot(x, trendInRange[day]!));
    }

    // Y axis range
    final allWeights = [
      ...entriesInRange.map((e) => e.weightKg),
      ...trendInRange.values,
    ];
    if (allWeights.isEmpty) {
      return _buildEmpty(context);
    }

    final minY = (allWeights.reduce((a, b) => a < b ? a : b) - 1)
        .floorToDouble();
    final maxY = (allWeights.reduce((a, b) => a > b ? a : b) + 1)
        .ceilToDouble();

    return Column(
      children: [
        // Range selector
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ChartRange.values.map((range) {
              final selected = range == _range;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ChoiceChip(
                  label: Text(range.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _range = range),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),

        // Chart
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: _range.days.toDouble(),
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.15),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 45,
                    interval: _yInterval(maxY - minY),
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: _xInterval(_range.days),
                    getTitlesWidget: (value, meta) {
                      final date = DateUtils.dateOnly(DateTime(
                          rangeStart.year,
                          rangeStart.month,
                          rangeStart.day + value.toInt()));
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${date.day}/${date.month}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                // Scale weight dots
                LineChartBarData(
                  spots: scaleSpots,
                  isCurved: false,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.5),
                  barWidth: 1.0,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.6),
                      strokeWidth: 0,
                    ),
                  ),
                ),
                // Trend line
                LineChartBarData(
                  spots: trendSpots,
                  isCurved: true,
                  curveSmoothness: 0.2,
                  color: Theme.of(context).colorScheme.error,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),

        // Legend
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(context,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                  'Scale weight'),
              const SizedBox(width: 16),
              _legendLine(context, Theme.of(context).colorScheme.error,
                  'Trend weight'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Text('No weight data in this range',
            style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  Widget _legendLine(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 2.5, color: color),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  double _yInterval(double range) {
    if (range <= 3) return 0.5;
    if (range <= 6) return 1;
    if (range <= 15) return 2;
    return 5;
  }

  double _xInterval(int totalDays) {
    if (totalDays <= 7) return 1;
    if (totalDays <= 30) return 7;
    if (totalDays <= 90) return 14;
    if (totalDays <= 180) return 30;
    if (totalDays <= 365) return 60;
    return 90;
  }
}
