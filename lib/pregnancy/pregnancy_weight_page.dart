import 'package:opennutritracker/core/presentation/widgets/app_text.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'pregnancy_app.dart';
import 'pregnancy_model.dart';
import 'pregnancy_theme.dart';
import 'pregnancy_weight_reference.dart';

class PregnancyWeightPage extends StatelessWidget {
  final PregnancyData data;
  final Future<void> Function(PregnancyData) onSave;
  final VoidCallback onSetup;
  final Widget? header;
  final Future<void> Function(WeightEntry entry, WeightEntry? previous)?
      onWeightSave;
  final Future<void> Function(WeightEntry entry)? onWeightDelete;
  const PregnancyWeightPage(
      {super.key,
      required this.data,
      required this.onSave,
      required this.onSetup,
      this.header,
      this.onWeightSave,
      this.onWeightDelete});

  Future<void> _edit(BuildContext context, [WeightEntry? entry]) async {
    final result = await showDialog<WeightEntry>(
        context: context,
        builder: (_) =>
            WeightEntryDialog(profile: data.profile!, entry: entry));
    if (result == null) return;
    var updated = entry == null ? data : data.withoutWeight(entry);
    // A date is a unique reading: edits and repeat entries replace that day.
    updated = updated.withWeight(result);
    try {
      if (onWeightSave != null) {
        await onWeightSave!(result, entry);
      } else {
        await onSave(updated);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: AppText('Could not save. Your reading has not changed.')));
      }
    }
  }

  Future<void> _delete(BuildContext context, WeightEntry entry) async {
    final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const AppText('Delete this reading?'),
              content: AppText(
                  '${entry.date.toIso8601String().substring(0, 10)} • ${entry.kg.toStringAsFixed(1)} kg${entry.source == 'healthConnect' ? tr('\nThis hides imports for this date. The source record in Health Connect is kept.') : ''}'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const AppText('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const AppText('Delete'))
              ],
            ));
    if (result == true) {
      try {
        if (onWeightDelete != null) {
          await onWeightDelete!(entry);
        } else {
          await onSave(data.withoutWeight(entry));
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: AppText('Could not delete. Please try again.')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(
        context); // Rebuild non-Text labels when language changes.

    final profile = data.profile;
    if (profile == null) {
      return ReadingList(children: [
        InfoCard(
            title: 'Your weight journal',
            body:
                'Set up your pregnancy to record weights by date. You can leave your starting weight unknown.',
            action: FilledButton(
                onPressed: onSetup, child: const AppText('Set up pregnancy')))
      ]);
    }
    final total = PregnancyReference.totalGain(profile);
    final baseline = profile.prePregnancyKg;
    final weeks = profile.gestationWeeks(DateTime.now());
    final studyBaseline =
        PregnancyWeightReference.baseline(profile, data.weights);
    final centiles =
        studyBaseline == null ? null : PregnancyWeightReference.atWeek(weeks);
    final rate = PregnancyReference.weeklyRate(profile);
    return ReadingList(children: [
      const PregnancyHero(
          title: 'Your weight over time',
          subtitle: 'Follow your journey with curiosity and kindness.'),
      const SizedBox(height: 12),
      const AppText(
          'Use similar weighing conditions when possible. A reading outside a reference band does not diagnose a problem or call for weight loss.'),
      const SizedBox(height: 16),
      if (header != null) header!,
      FilledButton.icon(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.add),
          label: const AppText('Log weight')),
      const SizedBox(height: 16),
      if (baseline != null && data.weights.isNotEmpty)
        InfoCard(
            title:
                '${(data.weights.last.kg - baseline).toStringAsFixed(1)} kg since before pregnancy',
            body:
                'Latest reading: ${data.weights.last.kg.toStringAsFixed(1)} kg on ${data.weights.last.date.toIso8601String().substring(0, 10)}. The chart uses the gestational age on each reading’s date.'),
      if (total != null)
        InfoCard(
            title: '${total.low}–${total.high} kg total reference gain',
            body:
                'Singleton guidance selected using pre-pregnancy BMI ${profile.prePregnancyBmi!.toStringAsFixed(1)}. This is the whole-pregnancy range, not a target for today.',
            action: const SourceLink(sourceId: 'cdc')),
      if (rate != null && weeks >= 14 && weeks <= 40)
        InfoCard(
            title:
                '${rate.low.toStringAsFixed(2)}–${rate.high.toStringAsFixed(2)} kg/week guideline',
            body:
                'Published average rate for the second and third trimesters, selected using pre-pregnancy BMI. Individual weeks can vary; this is not a weekly pass/fail threshold.',
            action: const SourceLink(sourceId: 'iom')),
      if (centiles != null)
        InfoCard(
            title: 'Week ${weeks.toStringAsFixed(1)} study comparison',
            body:
                '10th–90th centiles: ${centiles[0].toStringAsFixed(1)}–${centiles[2].toStringAsFixed(1)} kg gain; median ${centiles[1].toStringAsFixed(1)} kg. Measured from your first-trimester reading of ${studyBaseline!.kg.toStringAsFixed(1)} kg on ${PregnancyData.dayKey(studyBaseline.date)}. These centiles describe a study population, not a recommended target range.',
            action: const SourceLink(sourceId: 'intergrowth')),
      if (profile.type != PregnancyType.singleton)
        const InfoCard(
            title: 'An individual plan for multiples',
            body:
                'Your readings are shown without a singleton band. Discuss a suitable range with your maternity team; CDC provides separate twin-pregnancy guidance.',
            action: SourceLink(sourceId: 'cdc')),
      if (baseline == null || profile.heightCm == null)
        InfoCard(
            title: 'Comparison needs a starting point',
            body:
                'Add your known pre-pregnancy weight and height to enable the singleton reference. Your current weight is not a substitute.',
            action: TextButton(
                onPressed: onSetup, child: const AppText('Edit profile'))),
      if (studyBaseline == null)
        const InfoCard(
            title: 'Weekly research comparison needs an early reading',
            body:
                'INTERGROWTH applies to singleton pregnancies with BMI 18.5–24.9 at the first-trimester visit. Add a known weight from weeks 9–13 and your height to compare with this study. Pre-pregnancy weight cannot replace that reading. Other BMI groups still have their published total-gain and weekly-rate guidance.'),
      if (studyBaseline != null && (weeks < 15 || weeks > 40))
        const InfoCard(
            title: 'Study centiles cover weeks 15–40',
            body:
                'No study range is extrapolated for today. Your readings remain available.'),
      PregnancyWeightChart(profile: profile, entries: data.weights),
      const SizedBox(height: 12),
      AppText(studyBaseline == null
          ? 'Points and line show your readings. No invented week-specific band is drawn.'
          : 'Shading: published INTERGROWTH 10th–90th centiles; dashed line: median. Study of healthy, well-nourished women with normal first-trimester BMI and singleton pregnancies. This comparison does not establish what is healthy for you. Daily positions interpolate adjacent published weeks.'),
      const SizedBox(height: 20),
      AppText('Readings', style: Theme.of(context).textTheme.titleLarge),
      if (data.weights.isEmpty)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: AppText(
                'No readings yet. Log a weight to begin your journal.')),
      for (final entry in data.weights.reversed)
        Card(
            child: ListTile(
                title: AppText('${entry.kg.toStringAsFixed(1)} kg'),
                subtitle: AppText(
                    '${entry.date.toIso8601String().substring(0, 10)} • ${profile.gestationWeeks(entry.date).toStringAsFixed(1)} weeks • ${entry.source == 'healthConnect' ? 'Health Connect' : tr('Manual')}'),
                onTap: () => _edit(context, entry),
                trailing: IconButton(
                    tooltip: trOptional('Delete reading'),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(context, entry)))),
      const SizedBox(height: 12),
      const AppText(
          'Tap a reading to edit it. One reading is stored per calendar day; saving the same date replaces its reading. Changing the due date preserves all entries.'),
    ]);
  }
}

class PregnancyWeightChart extends StatelessWidget {
  final PregnancyProfile profile;
  final List<WeightEntry> entries;
  const PregnancyWeightChart(
      {super.key, required this.profile, required this.entries});

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(
        context); // Rebuild non-Text labels when language changes.

    final studyBaseline = PregnancyWeightReference.baseline(profile, entries);
    final baseline = studyBaseline?.kg ?? profile.prePregnancyKg;
    final points = entries
        .map((entry) => FlSpot(
            profile.gestationWeeks(entry.date), entry.kg - (baseline ?? 0)))
        .toList();
    final lower = <FlSpot>[];
    final upper = <FlSpot>[];
    final median = <FlSpot>[];
    if (studyBaseline != null) {
      for (var week = 15; week <= 40; week++) {
        final row = PregnancyWeightReference.atWeek(week.toDouble())!;
        lower.add(FlSpot(week.toDouble(), row[0]));
        median.add(FlSpot(week.toDouble(), row[1]));
        upper.add(FlSpot(week.toDouble(), row[2]));
      }
    }
    final values = [...points, ...lower, ...upper];
    if (values.isEmpty) return const SizedBox.shrink();
    final minY = values.map((p) => p.y).reduce(math.min) - 2;
    final maxY = values.map((p) => p.y).reduce(math.max) + 2;
    final minX = math.min(0.0, values.map((p) => p.x).reduce(math.min));
    final maxX = math.max(42.0, values.map((p) => p.x).reduce(math.max));
    final color = Theme.of(context).colorScheme.primary;
    final lines = <LineChartBarData>[
      if (studyBaseline != null) ...[
        LineChartBarData(
            spots: lower,
            color: PregnancyPalette.muted,
            dashArray: [4, 5],
            barWidth: 1,
            dotData: const FlDotData(show: false)),
        LineChartBarData(
            spots: upper,
            color: PregnancyPalette.muted,
            dashArray: [4, 5],
            barWidth: 1,
            dotData: const FlDotData(show: false)),
      ],
      if (median.isNotEmpty)
        LineChartBarData(
            spots: median,
            color: PregnancyPalette.muted,
            dashArray: [5, 5],
            barWidth: 1.5,
            dotData: const FlDotData(show: false)),
      if (points.isNotEmpty)
        LineChartBarData(
            spots: points,
            color: color,
            barWidth: 3,
            dotData: const FlDotData(show: true)),
    ];
    return Semantics(
        label: tr(baseline == null
            ? 'Recorded weight in kilograms by pregnancy week. Readings are listed below.'
            : 'Weight gain in kilograms by pregnancy week. Readings and reference details are provided as text.'),
        child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(studyBaseline != null
                          ? 'Gain since first-trimester reading (kg)'
                          : baseline == null
                              ? 'Weight (kg)'
                              : 'Gain from pre-pregnancy weight (kg)'),
                      const SizedBox(height: 12),
                      SizedBox(
                          height: 270,
                          child: LineChart(LineChartData(
                            minX: minX,
                            maxX: maxX,
                            minY: minY,
                            maxY: maxY,
                            clipData: const FlClipData.all(),
                            lineBarsData: lines,
                            betweenBarsData: studyBaseline == null
                                ? []
                                : [
                                    BetweenBarsData(
                                        fromIndex: 0,
                                        toIndex: 1,
                                        color: PregnancyPalette.blush
                                            .withValues(alpha: 0.8))
                                  ],
                            gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) => const FlLine(
                                    color: PregnancyPalette.border,
                                    strokeWidth: 1)),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(
                                      showTitles: true, reservedSize: 44)),
                              bottomTitles: const AxisTitles(
                                  axisNameWidget: AppText('Pregnancy week'),
                                  sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: 7,
                                      reservedSize: 28)),
                            ),
                          ))),
                      const SizedBox(height: 16),
                      Wrap(spacing: 20, runSpacing: 8, children: [
                        if (points.isNotEmpty)
                          const AppText('Your readings',
                              style: TextStyle(
                                  color: PregnancyPalette.berry,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        if (studyBaseline != null)
                          const AppText('10th–90th centiles · dashed median',
                              style: TextStyle(
                                  color: PregnancyPalette.muted, fontSize: 12)),
                      ]),
                    ]))));
  }
}

class WeightEntryDialog extends StatefulWidget {
  final PregnancyProfile profile;
  final WeightEntry? entry;
  const WeightEntryDialog({super.key, required this.profile, this.entry});
  @override
  State<WeightEntryDialog> createState() => _WeightEntryDialogState();
}

class _WeightEntryDialogState extends State<WeightEntryDialog> {
  late final TextEditingController _weight;
  late DateTime _date;
  String? _error;
  @override
  void initState() {
    super.initState();
    _weight = TextEditingController(text: widget.entry?.kg.toString() ?? '');
    _date = widget.entry?.date ?? calendarDate(DateTime.now());
  }

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: AppText(widget.entry == null ? 'Log weight' : 'Edit weight'),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _weight,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: tr('Weight (kg)'), errorText: trOptional(_error))),
          const SizedBox(height: 16),
          TextButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: AppText(_date.toIso8601String().substring(0, 10)),
              onPressed: () async {
                final now = DateUtils.dateOnly(DateTime.now());
                final start = widget.profile.startDate;
                // Existing entries outside a revised pregnancy window remain editable.
                final earliest = _date.isBefore(start) ? _date : start;
                final first =
                    DateTime(earliest.year, earliest.month, earliest.day);
                final initial = DateTime(_date.year, _date.month, _date.day);
                final picked = await showDatePicker(
                    context: context,
                    initialDate: initial.isAfter(now) ? now : initial,
                    firstDate: first.isAfter(now) ? now : first,
                    lastDate: now);
                if (picked != null && mounted) {
                  setState(() => _date = calendarDate(picked));
                }
              }),
          const AppText(
              'One reading per day. An existing reading on this date will be replaced.'),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AppText('Cancel')),
          FilledButton(
              onPressed: () {
                final value =
                    double.tryParse(_weight.text.trim().replaceAll(',', '.'));
                if (value == null ||
                    !value.isFinite ||
                    value < 25 ||
                    value > 350) {
                  setState(
                      () => _error = 'Enter a weight between 25 and 350 kg.');
                  return;
                }
                Navigator.pop(context, WeightEntry(_date, value));
              },
              child: const AppText('Save reading'))
        ],
      );
}
