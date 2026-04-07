import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

/// Compact horizontal strip of macro indicators shown on the home dashboard.
///
/// Layout: a single Row with one column per macro (Carbs / Fat / Protein /
/// Sodium). Each column shows a circular ring, the consumed/goal value, the
/// remaining amount, and the macro label. The Carbs ring is dual-coloured —
/// the outer green arc is the consumed carbs, with a purple sub-arc overlay
/// showing how many of those carbs were sugars.
///
/// When intake exceeds goal, the macro-coloured ring stays filled at 100%
/// and a red sub-arc is overlaid showing the *amount over goal* as a fraction
/// of the goal (clamped to 100%). This is more informative than recolouring
/// the entire ring red, which loses the "you met your goal" signal.
class MacroNutrientsView extends StatelessWidget {
  final double totalCarbsIntake;
  final double totalFatsIntake;
  final double totalProteinsIntake;
  final double totalSugarsIntake;
  final double totalSodiumIntake;
  final double totalCarbsGoal;
  final double totalFatsGoal;
  final double totalProteinsGoal;
  final double totalSodiumGoal;

  const MacroNutrientsView({
    super.key,
    required this.totalCarbsIntake,
    required this.totalFatsIntake,
    required this.totalProteinsIntake,
    required this.totalSugarsIntake,
    required this.totalSodiumIntake,
    required this.totalCarbsGoal,
    required this.totalFatsGoal,
    required this.totalProteinsGoal,
    required this.totalSodiumGoal,
  });

  // Per-macro colors. These are tuned to be friendly on both light and dark
  // themes — saturated enough to read at small sizes, not so saturated they
  // clash with the surface.
  static const _carbsColor = Color(0xFF4CAF50); // green
  static const _sugarsColor = Color(0xFFAB47BC); // purple (matches green)
  static const _fatColor = Color(0xFFFFB300); // amber
  // Deep orange (not red): distinct from the amber fat ring above and from
  // the red over-goal overlay, so an over-protein day is still readable.
  static const _proteinColor = Color(0xFFFF7043); // deep orange
  static const _sodiumColor = Color(0xFF42A5F5); // blue

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _CarbsIndicator(
            carbsIntake: totalCarbsIntake,
            sugarsIntake: totalSugarsIntake,
            carbsGoal: totalCarbsGoal,
            carbsColor: _carbsColor,
            sugarsColor: _sugarsColor,
          ),
        ),
        Expanded(
          child: _MacroIndicator(
            intake: totalFatsIntake,
            goal: totalFatsGoal,
            label: 'Fat',
            color: _fatColor,
          ),
        ),
        Expanded(
          child: _MacroIndicator(
            intake: totalProteinsIntake,
            goal: totalProteinsGoal,
            label: 'Protein',
            color: _proteinColor,
          ),
        ),
        Expanded(
          child: _MacroIndicator(
            intake: totalSodiumIntake,
            goal: totalSodiumGoal,
            label: 'Sodium',
            color: _sodiumColor,
          ),
        ),
      ],
    );
  }
}

/// Single-color macro indicator (fat / protein / sodium).
class _MacroIndicator extends StatelessWidget {
  final double intake;
  final double goal;
  final String label;
  final Color color;

  const _MacroIndicator({
    required this.intake,
    required this.goal,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final hasGoal = goal > 0;
    final isOver = hasGoal && intake > goal;
    final remaining = hasGoal ? (goal - intake) : 0;
    final percent = _percent(intake, goal);
    final overPercent =
        isOver ? ((intake - goal) / goal).clamp(0.0, 1.0) : 0.0;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final errorColor = Theme.of(context).colorScheme.error;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularPercentIndicator(
                radius: 22.0,
                lineWidth: 5.0,
                animation: true,
                animationDuration: 600,
                percent: percent,
                progressColor: color,
                backgroundColor: color.withValues(alpha: 0.18),
                circularStrokeCap: CircularStrokeCap.round,
              ),
              if (isOver)
                CircularPercentIndicator(
                  radius: 22.0,
                  lineWidth: 5.0,
                  animation: true,
                  animationDuration: 600,
                  percent: overPercent,
                  progressColor: errorColor,
                  backgroundColor: Colors.transparent,
                  circularStrokeCap: CircularStrokeCap.round,
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${intake.toInt()}/${goal.toInt()}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isOver ? errorColor : onSurface,
                  fontWeight: FontWeight.w600,
                ),
            maxLines: 1,
            softWrap: false,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            isOver
                ? '+${(intake - goal).toInt()} over'
                : '${remaining.toInt()} left',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: onSurface.withValues(alpha: 0.6),
                ),
            maxLines: 1,
            softWrap: false,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: onSurface.withValues(alpha: 0.7),
              ),
        ),
      ],
    );
  }
}

/// Dual-color carbs indicator: outer green ring shows consumed carbs as a
/// fraction of the carbs goal; a purple sub-arc starts at the same angle and
/// covers the slice of those consumed carbs that came from sugars.
class _CarbsIndicator extends StatelessWidget {
  final double carbsIntake;
  final double sugarsIntake;
  final double carbsGoal;
  final Color carbsColor;
  final Color sugarsColor;

  const _CarbsIndicator({
    required this.carbsIntake,
    required this.sugarsIntake,
    required this.carbsGoal,
    required this.carbsColor,
    required this.sugarsColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasGoal = carbsGoal > 0;
    final isOver = hasGoal && carbsIntake > carbsGoal;
    final remaining = hasGoal ? (carbsGoal - carbsIntake) : 0;
    // Sugars arc is scaled against the carbs goal (not the sugar daily limit)
    // so it lines up with the carbs ring as a true sub-segment.
    final sugarsPercent = _percent(sugarsIntake, carbsGoal);
    final carbsPercent = _percent(carbsIntake, carbsGoal);
    final overPercent =
        isOver ? ((carbsIntake - carbsGoal) / carbsGoal).clamp(0.0, 1.0) : 0.0;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final errorColor = Theme.of(context).colorScheme.error;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer arc: total carbs (green).
              CircularPercentIndicator(
                radius: 22.0,
                lineWidth: 5.0,
                animation: true,
                animationDuration: 600,
                percent: carbsPercent,
                progressColor: carbsColor,
                backgroundColor: carbsColor.withValues(alpha: 0.18),
                circularStrokeCap: CircularStrokeCap.butt,
              ),
              // Overlay arc: sugars portion (purple), drawn on top so it
              // visually subtracts from the start of the green arc.
              if (sugarsIntake > 0)
                CircularPercentIndicator(
                  radius: 22.0,
                  lineWidth: 5.0,
                  animation: true,
                  animationDuration: 600,
                  percent: sugarsPercent,
                  progressColor: sugarsColor,
                  backgroundColor: Colors.transparent,
                  circularStrokeCap: CircularStrokeCap.butt,
                ),
              // Over-goal overlay: red arc shows how much over (capped at 1x).
              if (isOver)
                CircularPercentIndicator(
                  radius: 22.0,
                  lineWidth: 5.0,
                  animation: true,
                  animationDuration: 600,
                  percent: overPercent,
                  progressColor: errorColor,
                  backgroundColor: Colors.transparent,
                  circularStrokeCap: CircularStrokeCap.butt,
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${carbsIntake.toInt()}/${carbsGoal.toInt()}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isOver ? errorColor : onSurface,
                  fontWeight: FontWeight.w600,
                ),
            maxLines: 1,
            softWrap: false,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            isOver
                ? '+${(carbsIntake - carbsGoal).toInt()} over'
                : '${remaining.toInt()} left',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: onSurface.withValues(alpha: 0.6),
                ),
            maxLines: 1,
            softWrap: false,
          ),
        ),
        Text(
          'Carbs',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: onSurface.withValues(alpha: 0.7),
              ),
        ),
        Text(
          'sugars ${sugarsIntake.toInt()}g',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: sugarsColor,
                fontSize: 10,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

double _percent(double supplied, double goal) {
  if (goal <= 0) return supplied > 0 ? 1 : 0;
  if (supplied <= 0) return 0;
  if (supplied >= goal) return 1;
  return supplied / goal;
}
