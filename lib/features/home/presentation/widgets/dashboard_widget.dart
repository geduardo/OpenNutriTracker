import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  final double totalSugarsIntake;
  final double totalSodiumIntake;
  final double totalCarbsGoal;
  final double totalFatsGoal;
  final double totalProteinsGoal;
  final double totalSodiumGoal;

  /// When true (default) the card includes a date header showing today's
  /// date. The diary uses this widget under its own day-navigation bar so it
  /// passes false to avoid duplicating the date.
  final bool showDateHeader;

  const DashboardWidget(
      {super.key,
      required this.totalKcalSupplied,
      required this.totalKcalDaily,
      required this.totalKcalLeft,
      required this.totalCarbsIntake,
      required this.totalFatsIntake,
      required this.totalProteinsIntake,
      required this.totalSugarsIntake,
      required this.totalSodiumIntake,
      required this.totalCarbsGoal,
      required this.totalFatsGoal,
      required this.totalProteinsGoal,
      required this.totalSodiumGoal,
      this.showDateHeader = true});

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
    // When over goal, the base ring stays full at primary color and a red
    // overlay arc shows how much over the goal as a fraction of the goal
    // (clamped to 100% so a 2× overshoot doesn't look like 2 full red rings).
    final overPercent = (isOver && widget.totalKcalDaily > 0)
        ? ((-widget.totalKcalLeft) / widget.totalKcalDaily).clamp(0.0, 1.0)
        : 0.0;

    final primaryColor = Theme.of(context).colorScheme.primary;
    final errorColor = Theme.of(context).colorScheme.error;
    final centerColor =
        isOver ? errorColor : Theme.of(context).colorScheme.onSurface;
    final centerLabel = S.of(context).kcalLeftLabel;

    final onSurface = Theme.of(context).colorScheme.onSurface;

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
              if (widget.showDateHeader) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 16, color: onSurface.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat.yMMMMEEEEd().format(DateTime.now()),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: onSurface.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_up_outlined,
                        color: onSurface,
                      ),
                      Text('${widget.totalKcalSupplied.toInt()}',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: onSurface)),
                      Text(S.of(context).suppliedLabel,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: onSurface)),
                    ],
                  ),
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularPercentIndicator(
                          radius: 90.0,
                          lineWidth: 13.0,
                          animation: true,
                          percent: gaugeValue,
                          arcType: ArcType.FULL,
                          progressColor: primaryColor,
                          arcBackgroundColor: primaryColor.withAlpha(50),
                          center: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedFlipCounter(
                                  duration:
                                      const Duration(milliseconds: 1000),
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
                                    ?.copyWith(color: centerColor),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '/ ${widget.totalKcalDaily.toInt()} kcal',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                        color:
                                            onSurface.withValues(alpha: 0.6)),
                              ),
                            ],
                          ),
                          circularStrokeCap: CircularStrokeCap.round,
                        ),
                        if (isOver)
                          IgnorePointer(
                            child: CircularPercentIndicator(
                              radius: 90.0,
                              lineWidth: 13.0,
                              animation: true,
                              percent: overPercent,
                              arcType: ArcType.FULL,
                              progressColor: errorColor,
                              arcBackgroundColor: Colors.transparent,
                              backgroundColor: Colors.transparent,
                              circularStrokeCap: CircularStrokeCap.round,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        color: onSurface,
                      ),
                      Text('${widget.totalKcalDaily.toInt()}',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: onSurface)),
                      Text('Goal',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: onSurface)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              MacroNutrientsView(
                  totalCarbsIntake: widget.totalCarbsIntake,
                  totalFatsIntake: widget.totalFatsIntake,
                  totalProteinsIntake: widget.totalProteinsIntake,
                  totalSugarsIntake: widget.totalSugarsIntake,
                  totalSodiumIntake: widget.totalSodiumIntake,
                  totalCarbsGoal: widget.totalCarbsGoal,
                  totalFatsGoal: widget.totalFatsGoal,
                  totalProteinsGoal: widget.totalProteinsGoal,
                  totalSodiumGoal: widget.totalSodiumGoal),
            ],
          ),
        ),
      ),
    );
  }
}
