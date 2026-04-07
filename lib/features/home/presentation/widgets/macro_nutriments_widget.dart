import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:opennutritracker/generated/l10n.dart';

class MacroNutrientsView extends StatefulWidget {
  final double totalCarbsIntake;
  final double totalFatsIntake;
  final double totalProteinsIntake;
  final double totalCarbsGoal;
  final double totalFatsGoal;
  final double totalProteinsGoal;

  const MacroNutrientsView(
      {super.key,
      required this.totalCarbsIntake,
      required this.totalFatsIntake,
      required this.totalProteinsIntake,
      required this.totalCarbsGoal,
      required this.totalFatsGoal,
      required this.totalProteinsGoal});

  @override
  State<MacroNutrientsView> createState() => _MacroNutrientsViewState();
}

class _MacroNutrientsViewState extends State<MacroNutrientsView> {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceAround,
      spacing: 12,
      runSpacing: 8,
      children: [
        _macroIndicator(
          context,
          intake: widget.totalCarbsIntake,
          goal: widget.totalCarbsGoal,
          label: S.of(context).carbsLabel,
        ),
        _macroIndicator(
          context,
          intake: widget.totalFatsIntake,
          goal: widget.totalFatsGoal,
          label: S.of(context).fatLabel,
        ),
        _macroIndicator(
          context,
          intake: widget.totalProteinsIntake,
          goal: widget.totalProteinsGoal,
          label: S.of(context).proteinLabel,
        ),
      ],
    );
  }

  Widget _macroIndicator(
    BuildContext context, {
    required double intake,
    double? goal,
    required String label,
  }) {
    final hasGoal = goal != null && goal > 0;
    final isOver = hasGoal && intake > goal;
    final color = isOver
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    final diffText = hasGoal
        ? isOver
            ? '+${(intake - goal).toInt()}'
            : '${intake.toInt()}/${goal.toInt()}'
        : '${intake.toInt()}';

    return Row(
      children: [
        CircularPercentIndicator(
          radius: 15.0,
          lineWidth: 6.0,
          animation: true,
          percent: _goalPercentage(goal, intake),
          progressColor: color,
          backgroundColor: color.withAlpha(50),
          circularStrokeCap: CircularStrokeCap.round,
        ),
        Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            children: [
              Text(
                '$diffText g',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isOver
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurface),
              ),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _goalPercentage(double? goal, double supplied) {
    if (goal == null || goal <= 0) {
      return supplied > 0 ? 1 : 0;
    }
    if (supplied <= 0) {
      return 0;
    } else if (supplied > goal) {
      return 1;
    } else {
      return supplied / goal;
    }
  }
}
