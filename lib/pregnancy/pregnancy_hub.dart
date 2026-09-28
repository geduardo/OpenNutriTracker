import 'package:opennutritracker/core/presentation/widgets/app_text.dart';
import 'package:flutter/material.dart';
import '../core/utils/locator.dart';
import '../features/home/presentation/bloc/home_bloc.dart';
import 'pregnancy_controller.dart';
import 'pregnancy_model.dart';
import 'pregnancy_profile_form.dart';
import 'pregnancy_weight_page.dart';
import 'pregnancy_app.dart' show PregnancySourcesPage, PregnancyNutritionPage;
import 'pregnancy_targets.dart';
import 'pregnancy_health_card.dart';

class PregnancyHub extends StatefulWidget {
  final bool embedded;
  const PregnancyHub({super.key, this.embedded = false});
  @override
  State<PregnancyHub> createState() => _PregnancyHubState();
}

class _PregnancyHubState extends State<PregnancyHub> {
  final controller = locator<PregnancyController>();
  Future<void> _save(PregnancyData next) async {
    try {
      await controller.save(next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                AppText('Could not save. Your previous data is unchanged.')));
      }
    }
  }

  Future<void> _profile() async {
    final result = await Navigator.of(context).push<PregnancySetupResult>(
        MaterialPageRoute(
            builder: (_) =>
                PregnancyProfileForm(profile: controller.data.profile)));
    if (result == null) return;
    try {
      await controller.update((data) {
        var next = data.withProfile(result.profile);
        if (result.firstReading != null) {
          next = next.withWeight(result.firstReading!);
        }
        return next;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: AppText('Could not save pregnancy profile.')));
      }
    }
    locator<HomeBloc>().add(const LoadItemsEvent());
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(
        context); // Rebuild non-Text labels when language changes.

    final body = ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(children: [
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(
                        onPressed: _profile,
                        icon: const Icon(Icons.edit_calendar),
                        label: const AppText('Pregnancy profile')),
                    OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const PregnancyEnergyForm()));
                          locator<HomeBloc>().add(const LoadItemsEvent());
                        },
                        icon: const Icon(Icons.tune),
                        label: const AppText('Energy & macro plan')),
                    TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => Scaffold(
                                    appBar: AppBar(
                                        title: const AppText(
                                            'Nutrition references')),
                                    body: const PregnancyNutritionPage()))),
                        child: const AppText('Nutrients')),
                    TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => Scaffold(
                                    appBar: AppBar(
                                        title: const AppText(
                                            'Evidence & methods')),
                                    body: const PregnancySourcesPage()))),
                        child: const AppText('Evidence')),
                  ])),
              Expanded(
                  child: PregnancyWeightPage(
                      data: controller.data,
                      onSave: _save,
                      onSetup: _profile,
                      header: PregnancyHealthCard(controller: controller),
                      onWeightSave: (entry, old) => controller.update((d) =>
                          (old == null ? d : d.withoutWeight(old))
                              .withWeight(entry)),
                      onWeightDelete: (entry) =>
                          controller.update((d) => d.withoutWeight(entry)))),
            ]));
    return widget.embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: const AppText('Your pregnancy')), body: body);
  }
}

class PregnancyEnergyForm extends StatefulWidget {
  const PregnancyEnergyForm({super.key});
  @override
  State<PregnancyEnergyForm> createState() => _PregnancyEnergyFormState();
}

class _PregnancyEnergyFormState extends State<PregnancyEnergyForm> {
  final controller = locator<PregnancyController>();
  final form = GlobalKey<FormState>();
  late final maintenance = TextEditingController(
      text: controller.data.profile?.maintenanceKcal?.toStringAsFixed(0) ?? '');
  late final clinician = TextEditingController(
      text: controller.data.profile?.clinicianEnergyKcal?.toStringAsFixed(0) ??
          '');
  bool saving = false;
  @override
  void dispose() {
    maintenance.dispose();
    clinician.dispose();
    super.dispose();
  }

  double? number(String s) => double.tryParse(s.trim().replaceAll(',', '.'));
  String? validate(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final value = number(s);
    return value == null || !value.isFinite || value < 1200 || value > 6000
        ? 'Enter 1,200–6,000 kcal or leave blank.'
        : null;
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final p = controller.data.profile!;
    setState(() => saving = true);
    try {
      await controller.update((data) => data.withProfile(PregnancyProfile(
          dueDate: p.dueDate,
          prePregnancyKg: p.prePregnancyKg,
          heightCm: p.heightCm,
          type: p.type,
          maintenanceKcal: number(maintenance.text),
          clinicianEnergyKcal: number(clinician.text))));
      locator<HomeBloc>().add(const LoadItemsEvent());
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: AppText('Could not save energy plan.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(
        context); // Rebuild non-Text labels when language changes.

    final target = PregnancyTargets(controller.data.profile, DateTime.now());
    return Scaffold(
        appBar: AppBar(title: const AppText('Energy & macro plan')),
        body: Form(
            key: form,
            child: ListView(padding: const EdgeInsets.all(24), children: [
              const AppText(
                  'Use a pregnancy energy target from your maternity team, or a known pre-pregnancy maintenance intake. Both fields are optional. Food logging and nutrient references work without them.'),
              const SizedBox(height: 20),
              TextFormField(
                  controller: clinician,
                  validator: (value) => trOptional((validate)(value)),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: tr('Care-team daily energy target (kcal)'),
                      helperText: trOptional(
                          'If entered, this takes priority. No extra calories are added.'))),
              const SizedBox(height: 20),
              TextFormField(
                  controller: maintenance,
                  validator: (value) => trOptional((validate)(value)),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: tr('Pre-pregnancy maintenance (kcal/day)'),
                      helperText: trOptional(
                          'An intake that maintained weight before pregnancy, not a weight-loss target.'))),
              const SizedBox(height: 20),
              AppText(
                  'For a singleton pregnancy, the ACOG guideline adds 0 kcal in trimester 1, 340 in trimester 2 and 450 in trimester 3. Your current trimester: ${target.trimester}. Multiples require a care-team energy target.'),
              const SizedBox(height: 12),
              const AppText(
                  'With an energy target, the app uses a practical 50% carbohydrate / 20% protein / 30% fat plan, keeping at least the adult pregnancy reference amounts of 175 g carbohydrate and 71 g protein. This split is an app default within adult macronutrient ranges, not a uniquely recommended pregnancy ratio.'),
              const SizedBox(height: 12),
              const AppText(
                  'Without an energy target, protein and carbohydrate show the pregnancy RDA references and fat has no gram target. The app does not infer calorie needs from pregnancy weight gain. For gestational diabetes or another tailored diet, agree the plan with your care team.'),
              const SizedBox(height: 24),
              FilledButton(
                  onPressed: saving ? null : save,
                  child: AppText(saving ? 'Saving…' : 'Save plan')),
              TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const AppText('Keep current plan')),
            ])));
  }
}
