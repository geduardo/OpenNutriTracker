import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/features/home/presentation/widgets/macro_nutriments_widget.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:opennutritracker/generated/l10n.dart';

class DashboardWidget extends StatefulWidget {
  final double totalKcalDaily;
  final double totalKcalLeft;
  final double totalKcalSupplied;
  final double totalCarbsIntake;
  final double totalFatsIntake;
  final double totalProteinsIntake;
  final double totalCarbsGoal;
  final double totalFatsGoal;
  final double totalProteinsGoal;

  const DashboardWidget(
      {super.key,
      required this.totalKcalSupplied,
      required this.totalKcalDaily,
      required this.totalKcalLeft,
      required this.totalCarbsIntake,
      required this.totalFatsIntake,
      required this.totalProteinsIntake,
      required this.totalCarbsGoal,
      required this.totalFatsGoal,
      required this.totalProteinsGoal});

  @override
  State<DashboardWidget> createState() => _DashboardWidgetState();
}

class _DashboardWidgetState extends State<DashboardWidget> {
  @override
  Widget build(BuildContext context) {
    final bool isOver = widget.totalKcalLeft < 0;
    double gaugeValue = 0;
    if (widget.totalKcalLeft > widget.totalKcalDaily) {
      gaugeValue = 0;
    } else if (widget.totalKcalLeft <= 0) {
      gaugeValue = 1;
    } else {
      gaugeValue = (widget.totalKcalDaily - widget.totalKcalLeft) /
          widget.totalKcalDaily;
    }

    final progressColor = isOver
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    final centerColor = isOver
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    final centerLabel = isOver
        ? S.of(context).kcalLeftLabel // "kcal left" but value is negative
        : S.of(context).kcalLeftLabel;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Icon(
                        Icons.keyboard_arrow_up_outlined,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      Text('${widget.totalKcalSupplied.toInt()}',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface)),
                      Text(S.of(context).suppliedLabel,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface)),
                    ],
                  ),
                  CircularPercentIndicator(
                    radius: 90.0,
                    lineWidth: 13.0,
                    animation: true,
                    percent: gaugeValue,
                    arcType: ArcType.FULL,
                    progressColor: progressColor,
                    arcBackgroundColor: progressColor.withAlpha(50),
                    center: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedFlipCounter(
                            duration: const Duration(milliseconds: 1000),
                            value: widget.totalKcalLeft.toInt(),
                            textStyle: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                    color: centerColor,
                                    letterSpacing: -1)),
                        Text(
                          centerLabel,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  color: centerColor),
                        )
                      ],
                    ),
                    circularStrokeCap: CircularStrokeCap.round,
                  ),
                ],
              ),
              MacroNutrientsView(
                  totalCarbsIntake: widget.totalCarbsIntake,
                  totalFatsIntake: widget.totalFatsIntake,
                  totalProteinsIntake: widget.totalProteinsIntake,
                  totalCarbsGoal: widget.totalCarbsGoal,
                  totalFatsGoal: widget.totalFatsGoal,
                  totalProteinsGoal: widget.totalProteinsGoal),
            ],
          ),
        ),
      ),
    );
  }
}
