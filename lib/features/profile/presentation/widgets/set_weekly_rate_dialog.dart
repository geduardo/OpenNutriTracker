import 'package:flutter/material.dart';
import 'package:opennutritracker/features/strategy/data/dbo/goal_strategy_dbo.dart';
import 'package:opennutritracker/features/strategy/domain/service/strategy_rate_policy.dart';

class SetWeeklyRateDialog extends StatefulWidget {
  final StrategyGoalModeDBO mode;
  final double initialRatePctPerWeek;
  final double bodyWeightKg;
  final bool usesImperialUnits;

  const SetWeeklyRateDialog({
    super.key,
    required this.mode,
    required this.initialRatePctPerWeek,
    required this.bodyWeightKg,
    required this.usesImperialUnits,
  });

  @override
  State<SetWeeklyRateDialog> createState() => _SetWeeklyRateDialogState();
}

class _SetWeeklyRateDialogState extends State<SetWeeklyRateDialog> {
  late double _selectedPct;

  @override
  void initState() {
    super.initState();
    _selectedPct = StrategyRatePolicy.clampRateForMode(
      widget.mode,
      widget.initialRatePctPerWeek,
    );
  }

  @override
  Widget build(BuildContext context) {
    final signedKgPerWeek = StrategyRatePolicy.signedKgPerWeek(
      mode: widget.mode,
      pctPerWeek: _selectedPct,
      bodyWeightKg: widget.bodyWeightKg,
    );

    return AlertDialog(
      title: const Text('Desired Weekly Change'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatRate(signedKgPerWeek),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${_selectedPct.toStringAsFixed(2)}% of body weight per week',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Slider(
              value: _selectedPct,
              min: StrategyRatePolicy.minRateForMode(widget.mode),
              max: StrategyRatePolicy.maxRateForMode(widget.mode),
              divisions: widget.mode == StrategyGoalModeDBO.lose ? 15 : 20,
              label: _formatRate(signedKgPerWeek),
              onChanged: (value) {
                setState(() {
                  _selectedPct = value;
                });
              },
            ),
            Row(
              children: [
                Text(
                  _formatRate(
                    StrategyRatePolicy.signedKgPerWeek(
                      mode: widget.mode,
                      pctPerWeek:
                          StrategyRatePolicy.minRateForMode(widget.mode),
                      bodyWeightKg: widget.bodyWeightKg,
                    ),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  _formatRate(
                    StrategyRatePolicy.signedKgPerWeek(
                      mode: widget.mode,
                      pctPerWeek:
                          StrategyRatePolicy.maxRateForMode(widget.mode),
                      bodyWeightKg: widget.bodyWeightKg,
                    ),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This rate sets the weekly target the calorie controller tries to achieve.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selectedPct),
          child: const Text('Save'),
        ),
      ],
    );
  }

  String _formatRate(double signedKgPerWeek) {
    final sign = signedKgPerWeek > 0
        ? '+'
        : signedKgPerWeek < 0
            ? '-'
            : '';
    final magnitude = widget.usesImperialUnits
        ? signedKgPerWeek.abs() * 2.20462
        : signedKgPerWeek.abs();
    final unit = widget.usesImperialUnits ? 'lbs/week' : 'kg/week';

    return '$sign${magnitude.toStringAsFixed(2)} $unit';
  }
}
