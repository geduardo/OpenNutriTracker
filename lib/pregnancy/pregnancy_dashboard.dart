import 'package:opennutritracker/core/presentation/widgets/app_text.dart';
import 'package:flutter/material.dart';
import '../core/domain/entity/intake_entity.dart';
import '../core/utils/locator.dart';
import 'pregnancy_controller.dart';
import 'pregnancy_targets.dart';
import 'pregnancy_hub.dart';

class PregnancyDashboard extends StatelessWidget {
  final List<IntakeEntity> intakes;
  final DateTime day;
  const PregnancyDashboard(
      {super.key, required this.intakes, required this.day});
  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(
        context); // Rebuild non-Text labels when language changes.

    final controller = locator<PregnancyController>();
    return ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final targets = PregnancyTargets(controller.data.profile, day);
          final days = controller.data.profile?.gestationDays(day);
          return Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                            targets.inPregnancy
                                ? 'Week ${days! ~/ 7} + ${days % 7} • Trimester ${targets.trimester}'
                                : 'Your food diary',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        const AppText(
                            'Logged food totals • AI entries are estimates'),
                        const SizedBox(height: 16),
                        _row(
                            context,
                            NutrientReference('energy', 'Energy', 'kcal',
                                targets.energy ?? 0, 'plan'),
                            noTarget: targets.energy == null),
                        if (targets.energy == null)
                          TextButton(
                              onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const PregnancyHub())),
                              child: const AppText(
                                  'Set your pregnancy energy plan')),
                        _row(
                            context,
                            NutrientReference(
                                'protein',
                                'Protein',
                                'g',
                                targets.protein,
                                targets.energy == null
                                    ? 'RDA reference'
                                    : 'plan')),
                        _row(
                            context,
                            NutrientReference(
                                'carbs',
                                'Carbohydrates',
                                'g',
                                targets.carbs,
                                targets.energy == null
                                    ? 'RDA reference'
                                    : 'plan')),
                        _row(
                            context,
                            NutrientReference(
                                'fat', 'Fat', 'g', targets.fat ?? 0, 'plan'),
                            noTarget: targets.fat == null),
                        ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const AppText('Pregnancy nutrients'),
                            subtitle: const AppText(
                                'Daily totals, targets & data coverage'),
                            children: [
                              _row(
                                  context,
                                  const NutrientReference(
                                      'fiber', 'Fiber', 'g', 28, 'AI')),
                              for (final ref in pregnancyMicroReferences)
                                _row(context, ref),
                              _row(
                                  context,
                                  const NutrientReference('caffeine',
                                      'Caffeine', 'mg', 200, 'limit'),
                                  isLimit: true),
                              const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: AppText(
                                      'Adult pregnancy references (19–50). Food totals are only what you log; unlogged food and supplements are not included. Missing values are unknown. AI estimates and partial totals cannot establish a deficiency or a need for supplements.')),
                              TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const PregnancyHub())),
                                  child: const AppText(
                                      'Targets, pregnancy profile & evidence')),
                            ]),
                      ])));
        });
  }

  Widget _row(BuildContext context, NutrientReference ref,
      {bool noTarget = false, bool isLimit = false}) {
    final total = NutrientTotal.fromIntakes(intakes, ref.key);
    final goal = ref.target;
    final value = total.known == 0
        ? 'Unknown'
        : '${total.amount.toStringAsFixed(ref.target < 10 ? 1 : 0)} ${ref.unit}';
    final description = noTarget
        ? 'No target set'
        : '${isLimit ? tr("Below ") : ""}${goal.toStringAsFixed(goal < 10 ? 1 : 0)} ${ref.unit} • ${tr(ref.kind)}';
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: AppText(ref.name,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            AppText(value),
          ]),
          AppText(description, style: Theme.of(context).textTheme.bodySmall),
          if (total.known > 0 && !noTarget && goal > 0)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(
                    value: (total.amount / goal).clamp(0, 1),
                    color: isLimit && total.amount >= goal
                        ? Theme.of(context).colorScheme.error
                        : null,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(8))),
          if ((total.missing > 0 || total.estimated > 0) &&
              !const ['energy', 'protein', 'carbs', 'fat'].contains(ref.key))
            AppText(
                '${total.missing > 0 ? tr("Partial • ${total.missing} entries missing data") : tr("All logged entries have data")}${total.estimated > 0 ? tr(" • includes AI estimates") : ""}',
                style: Theme.of(context).textTheme.bodySmall),
        ]));
  }
}
