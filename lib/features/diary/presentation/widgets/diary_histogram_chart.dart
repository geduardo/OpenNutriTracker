import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/tracked_day_entity.dart';
import 'package:opennutritracker/core/utils/extensions.dart';

enum HistogramRange {
  oneWeek('7D', 7),
  oneMonth('1M', 30),
  threeMonths('3M', 90),
  sixMonths('6M', 180),
  oneYear('1Y', 365);

  final String label;
  final int days;
  const HistogramRange(this.label, this.days);
}

class DiaryHistogramChart extends StatefulWidget {
  final Map<String, TrackedDayEntity> trackedDaysMap;
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const DiaryHistogramChart({
    super.key,
    required this.trackedDaysMap,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<DiaryHistogramChart> createState() => _DiaryHistogramChartState();
}

class _DiaryHistogramChartState extends State<DiaryHistogramChart> {
  HistogramRange _range = HistogramRange.oneMonth;

  double get _barWidth {
    switch (_range) {
      case HistogramRange.oneWeek:
        return 24;
      case HistogramRange.oneMonth:
        return 9;
      case HistogramRange.threeMonths:
        return 3.5;
      case HistogramRange.sixMonths:
        return 2;
      case HistogramRange.oneYear:
        return 1.5;
    }
  }

  int get _xLabelInterval {
    switch (_range) {
      case HistogramRange.oneWeek:
        return 1;
      case HistogramRange.oneMonth:
        return 7;
      case HistogramRange.threeMonths:
        return 14;
      case HistogramRange.sixMonths:
        return 30;
      case HistogramRange.oneYear:
        return 60;
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final rangeStart = DateUtils.dateOnly(
        DateTime(today.year, today.month, today.day - _range.days + 1));

    final days = <DateTime>[];
    var d = rangeStart;
    while (!d.isAfter(today)) {
      days.add(d);
      d = DateUtils.dateOnly(DateTime(d.year, d.month, d.day + 1));
    }

    final dayData = {
      for (final day in days) day: widget.trackedDaysMap[day.toParsedDay()]
    };

    final selectedDay = DateUtils.dateOnly(widget.selectedDate);
    final selectedTracked = dayData[selectedDay];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Range selector
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: HistogramRange.values.map((range) {
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  label: Text(range.label),
                  selected: range == _range,
                  onSelected: (_) => setState(() => _range = range),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),

        // Calories header
        _buildChartHeader(
          context,
          label: 'Calories',
          tracked: selectedTracked?.caloriesTracked ?? 0,
          goal: selectedTracked?.calorieGoal ?? 0,
          unit: 'kcal',
        ),
        const SizedBox(height: 4),

        // Calorie chart
        _buildCalorieChart(context, days, dayData, selectedDay),

        // Calorie legend
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendSquare(context, _carbsColor(context), 'Carbs'),
              const SizedBox(width: 12),
              _legendSquare(context, _fatColor, 'Fat'),
              const SizedBox(width: 12),
              _legendSquare(context, _proteinColor, 'Protein'),
              const SizedBox(width: 12),
              _legendDash(context, 'Goal'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Macro charts
        _buildMacroChart(context, 'Carbs', _carbsColor(context), days,
            dayData, selectedDay, selectedTracked,
            (t) => t.carbsTracked, (t) => t.carbsGoal),
        const SizedBox(height: 12),
        _buildMacroChart(context, 'Fat', _fatColor, days, dayData,
            selectedDay, selectedTracked,
            (t) => t.fatTracked, (t) => t.fatGoal),
        const SizedBox(height: 12),
        _buildMacroChart(context, 'Protein', _proteinColor, days, dayData,
            selectedDay, selectedTracked,
            (t) => t.proteinTracked, (t) => t.proteinGoal),
        const SizedBox(height: 12),
        _buildMacroChart(context, 'Sodium', _sodiumColor, days, dayData,
            selectedDay, selectedTracked,
            (t) => t.sodiumTracked, (t) => t.sodiumGoal,
            unit: 'mg'),
      ],
    );
  }

  // ── Calorie chart ──────────────────────────────────────

  Widget _buildCalorieChart(BuildContext context, List<DateTime> days,
      Map<DateTime, TrackedDayEntity?> dayData, DateTime selectedDay) {
    double calorieGoal = 2000;
    for (final day in days.reversed) {
      final tracked = dayData[day];
      if (tracked != null && tracked.calorieGoal > 0) {
        calorieGoal = tracked.calorieGoal;
        break;
      }
    }

    // Find actual max value in data
    double maxData = 0;
    for (final day in days) {
      final tracked = dayData[day];
      if (tracked != null && tracked.caloriesTracked > maxData) {
        maxData = tracked.caloriesTracked;
      }
    }

    final barGroups = <BarChartGroupData>[
      for (int i = 0; i < days.length; i++)
        _buildCalorieBarGroup(
            context, i, dayData[days[i]], days[i] == selectedDay),
    ];

    final ceiling = max(calorieGoal, maxData);
    final yStep = _niceInterval(ceiling, 4);
    final maxY = (_ceilTo(ceiling * 1.15, yStep)).clamp(yStep, double.infinity);

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          minY: 0,
          barTouchData: _barTouchData(days),
          titlesData: _buildTitlesData(context, days, maxY, yStep),
          gridData: _buildGridData(context, yStep),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [_goalLine(context, calorieGoal)],
          ),
          barGroups: barGroups,
        ),
      ),
    );
  }

  BarChartGroupData _buildCalorieBarGroup(BuildContext context, int index,
      TrackedDayEntity? tracked, bool isSelected) {
    final opacity = isSelected ? 1.0 : 0.55;
    final barW = _barWidth;

    if (tracked == null || tracked.caloriesTracked <= 0) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
              toY: 0, width: barW, color: Colors.transparent),
        ],
      );
    }

    final carbsKcal = (tracked.carbsTracked ?? 0) * 4;
    final fatKcal = (tracked.fatTracked ?? 0) * 9;
    final totalKcal = tracked.caloriesTracked;
    final macroTotal = carbsKcal + fatKcal + (tracked.proteinTracked ?? 0) * 4;

    BarChartRodData rod;
    if (macroTotal > 10) {
      rod = BarChartRodData(
        toY: totalKcal,
        width: barW,
        borderRadius: BorderRadius.circular(2),
        rodStackItems: [
          BarChartRodStackItem(
              0, carbsKcal, _carbsColor(context).withValues(alpha: opacity)),
          BarChartRodStackItem(carbsKcal, carbsKcal + fatKcal,
              _fatColor.withValues(alpha: opacity)),
          BarChartRodStackItem(carbsKcal + fatKcal, totalKcal,
              _proteinColor.withValues(alpha: opacity)),
        ],
        color: Colors.transparent,
      );
    } else {
      rod = BarChartRodData(
        toY: totalKcal,
        width: barW,
        color:
            Theme.of(context).colorScheme.primary.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(2),
      );
    }

    return BarChartGroupData(x: index, barRods: [rod]);
  }

  // ── Macro chart ──────────────────────────────────────

  Widget _buildMacroChart(
    BuildContext context,
    String label,
    Color color,
    List<DateTime> days,
    Map<DateTime, TrackedDayEntity?> dayData,
    DateTime selectedDay,
    TrackedDayEntity? selectedTracked,
    double? Function(TrackedDayEntity) getTracked,
    double? Function(TrackedDayEntity) getGoal, {
    String unit = 'g',
  }) {
    double goal = 0;
    for (final day in days.reversed) {
      final tracked = dayData[day];
      if (tracked != null) {
        final g = getGoal(tracked);
        if (g != null && g > 0) {
          goal = g;
          break;
        }
      }
    }

    double maxValue = 0;
    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < days.length; i++) {
      final tracked = dayData[days[i]];
      double value = 0;
      if (tracked != null) {
        value = (getTracked(tracked) ?? 0).clamp(0, double.infinity);
      }
      if (value > maxValue) maxValue = value;
      barGroups.add(
          _buildSimpleBarGroup(i, value, color, days[i] == selectedDay));
    }

    final selectedValue = selectedTracked != null
        ? (getTracked(selectedTracked) ?? 0)
        : 0.0;
    final selectedGoal = selectedTracked != null
        ? (getGoal(selectedTracked) ?? goal)
        : goal;

    final ceiling = max(goal, maxValue);
    final header = _buildChartHeader(
      context,
      label: label,
      tracked: selectedValue,
      goal: selectedGoal,
      unit: unit,
      color: color,
    );
    if (ceiling <= 0) return header;

    final yStep = _niceInterval(ceiling, 3);
    final maxY = (_ceilTo(ceiling * 1.15, yStep)).clamp(yStep, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 4),
        SizedBox(
          height: 100,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              minY: 0,
              barTouchData: _barTouchData(days),
              titlesData: _buildTitlesData(context, days, maxY, yStep),
              gridData: _buildGridData(context, yStep),
              borderData: FlBorderData(show: false),
              extraLinesData: goal > 0
                  ? ExtraLinesData(
                      horizontalLines: [_goalLine(context, goal)])
                  : const ExtraLinesData(),
              barGroups: barGroups,
            ),
          ),
        ),
      ],
    );
  }

  BarChartGroupData _buildSimpleBarGroup(
      int index, double value, Color color, bool isSelected) {
    final opacity = isSelected ? 1.0 : 0.55;
    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          toY: value,
          width: _barWidth,
          color: value > 0
              ? color.withValues(alpha: opacity)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }

  // ── Chart header: "Carbs  180 / 250 g" ──────────────────

  Widget _buildChartHeader(
    BuildContext context, {
    required String label,
    required double tracked,
    required double goal,
    required String unit,
    Color? color,
  }) {
    final trackedText = tracked.round().toString();
    final goalText = goal > 0 ? ' / ${goal.round()}' : '';

    return Row(
      children: [
        if (color != null) ...[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 6),
        ],
        Text(label,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(
          '$trackedText$goalText $unit',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  // ── Shared helpers ──────────────────────────────────────

  BarTouchData _barTouchData(List<DateTime> days) {
    return BarTouchData(
      touchTooltipData: BarTouchTooltipData(
        getTooltipItem: (_, __, ___, ____) => null,
      ),
      touchCallback: (event, response) {
        if (event is FlTapUpEvent) {
          final index = response?.spot?.touchedBarGroupIndex;
          if (index != null && index >= 0 && index < days.length) {
            widget.onDateSelected(days[index]);
          }
        }
      },
    );
  }

  FlTitlesData _buildTitlesData(BuildContext context, List<DateTime> days,
      double maxY, double yInterval) {
    return FlTitlesData(
      topTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: yInterval,
          getTitlesWidget: (value, meta) {
            // Hide 0 and the maxY ceiling to avoid clutter
            if (value <= 0 || value >= maxY) return const SizedBox();
            // Only show values that land exactly on a tick
            if ((value % yInterval).abs() > 0.01) return const SizedBox();
            return Text(
              _formatYLabel(value),
              style: Theme.of(context).textTheme.labelSmall,
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          getTitlesWidget: (value, meta) {
            final i = value.toInt();
            if (i < 0 || i >= days.length) return const SizedBox();
            if (i != 0 &&
                i != days.length - 1 &&
                i % _xLabelInterval != 0) {
              return const SizedBox();
            }
            final day = days[i];
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _formatDateLabel(day),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            );
          },
        ),
      ),
    );
  }

  /// Format y-axis values: "1.2k" for >= 1000, plain int otherwise.
  static String _formatYLabel(double value) {
    if (value >= 1000) {
      final k = value / 1000;
      return k == k.roundToDouble() ? '${k.toInt()}k' : '${k.toStringAsFixed(1)}k';
    }
    return value.toInt().toString();
  }

  /// Format x-axis date label depending on selected range.
  String _formatDateLabel(DateTime day) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                     'Jul','Aug','Sep','Oct','Nov','Dec'];
    switch (_range) {
      case HistogramRange.oneWeek:
        // "Mon 6" style
        const weekdays = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
        return '${weekdays[day.weekday - 1]} ${day.day}';
      case HistogramRange.oneMonth:
        // Just the day number to avoid overlap
        return '${day.day}';
      case HistogramRange.threeMonths:
      case HistogramRange.sixMonths:
        // "6 Apr"
        return '${day.day} ${months[day.month - 1]}';
      case HistogramRange.oneYear:
        // "Apr '26"
        return "${months[day.month - 1]} '${day.year % 100}";
    }
  }

  /// Pick a "nice" round interval so that ~[targetTicks] labels fit in [range].
  /// Returns values like 5, 10, 25, 50, 100, 250, 500, 1000, ...
  static double _niceInterval(double range, int targetTicks) {
    if (range <= 0) return 1;
    final raw = range / targetTicks;
    final magnitude = pow(10, (log(raw) / ln10).floorToDouble()).toDouble();
    final residual = raw / magnitude;
    // Snap to 1, 2, 2.5, 5, or 10
    final double nice;
    if (residual <= 1.5) {
      nice = 1;
    } else if (residual <= 3) {
      nice = 2.5;
    } else if (residual <= 7) {
      nice = 5;
    } else {
      nice = 10;
    }
    return (nice * magnitude).clamp(1.0, double.infinity);
  }

  /// Ceil [value] to the next multiple of [step].
  static double _ceilTo(double value, double step) {
    return (value / step).ceilToDouble() * step;
  }

  FlGridData _buildGridData(BuildContext context, double yInterval) {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: yInterval,
      getDrawingHorizontalLine: (value) => FlLine(
        color:
            Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
        strokeWidth: 1,
      ),
    );
  }

  HorizontalLine _goalLine(BuildContext context, double y) {
    return HorizontalLine(
      y: y,
      color:
          Theme.of(context).colorScheme.outline.withValues(alpha: 0.7),
      strokeWidth: 1.5,
      dashArray: [6, 4],
    );
  }

  // ── Colors & legend ──────────────────────────────────────

  Color _carbsColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary;
  Color get _fatColor => Colors.amber.shade600;
  Color get _proteinColor => Colors.green.shade400;
  Color get _sodiumColor => Colors.deepPurple.shade300;

  Widget _legendSquare(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  Widget _legendDash(BuildContext context, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 1.5,
          color: Theme.of(context)
              .colorScheme
              .outline
              .withValues(alpha: 0.7),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

