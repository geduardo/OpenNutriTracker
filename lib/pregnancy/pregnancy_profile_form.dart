import 'package:opennutritracker/core/presentation/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'pregnancy_model.dart';
import 'pregnancy_theme.dart';
import 'pregnancy_targets.dart';

enum _DatingInput { dueDate, currentStage }

class PregnancyProfileForm extends StatefulWidget {
  final PregnancyProfile? profile;
  const PregnancyProfileForm({super.key, this.profile});
  @override
  State<PregnancyProfileForm> createState() => _PregnancyProfileFormState();
}

class _PregnancyProfileFormState extends State<PregnancyProfileForm> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  late final DateTime _today;
  late final TextEditingController _weight;
  late final TextEditingController _height;
  final _currentWeight = TextEditingController();
  final _weeks = TextEditingController();
  final _days = TextEditingController(text: '0');
  DateTime? _due;
  _DatingInput _dating = _DatingInput.dueDate;
  PregnancyType _type = PregnancyType.singleton;
  bool _adult = false;
  int _step = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _today = calendarDate(DateTime.now());
    _weight = TextEditingController(
        text: widget.profile?.prePregnancyKg?.toString() ?? '');
    _height =
        TextEditingController(text: widget.profile?.heightCm?.toString() ?? '');
    _due = widget.profile?.dueDate;
    _type = widget.profile?.type ?? PregnancyType.singleton;
    _adult = widget.profile != null;
  }

  @override
  void dispose() {
    for (final controller in [
      _weight,
      _height,
      _currentWeight,
      _weeks,
      _days
    ]) {
      controller.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  double? _number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));
  String _dateLabel(DateTime date) =>
      MaterialLocalizations.of(context).formatMediumDate(date);

  DateTime? get _effectiveDue {
    if (_dating == _DatingInput.dueDate) return _due;
    final weeks = int.tryParse(_weeks.text.trim());
    final days = int.tryParse(_days.text.trim());
    if (weeks == null ||
        days == null ||
        weeks < 0 ||
        weeks > 42 ||
        days < 0 ||
        days > 6) {
      return null;
    }
    return PregnancyDating.dueDateFromStage(
        onDate: _today, weeks: weeks, days: days);
  }

  PregnancyProfile get _profile => PregnancyProfile(
      dueDate: _effectiveDue!,
      prePregnancyKg: _measurementError(_weight.text, 25, 350) == null
          ? _number(_weight.text)
          : null,
      heightCm: _measurementError(_height.text, 100, 230) == null
          ? _number(_height.text)
          : null,
      type: _type,
      maintenanceKcal: widget.profile?.maintenanceKcal,
      clinicianEnergyKcal: widget.profile?.clinicianEnergyKcal);

  Future<void> _pickDate() async {
    final first = _today
        .subtract(const Duration(days: PregnancyDating.maxGestationDays - 280));
    final last = _today.add(const Duration(days: 280));
    final candidate = _due ?? _today;
    final date = await showDatePicker(
        context: context,
        initialDate: candidate.isBefore(first) || candidate.isAfter(last)
            ? _today
            : candidate,
        firstDate: first,
        lastDate: last,
        helpText: tr('Due date from your maternity team'));
    if (date != null && mounted) {
      setState(() {
        _due = calendarDate(date);
        _error = null;
      });
    }
  }

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _error = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _next() {
    if (!_form.currentState!.validate()) return;
    // ListView fields can be unmounted offscreen. Validate the controllers too
    // so an invalid optional baseline cannot bypass Form.validate().
    if (_step == 1) {
      for (final field in [
        (_currentWeight, 25.0, 350.0),
        (_weight, 25.0, 350.0),
        (_height, 100.0, 230.0)
      ]) {
        if (_measurementError(field.$1.text, field.$2, field.$3) != null) {
          setState(() => _error =
              'Check your measurements, or leave unknown values blank.');
          return;
        }
      }
    }
    if (_step == 0) {
      if (_effectiveDue == null) {
        setState(() => _error = _dating == _DatingInput.dueDate
            ? 'Choose your due date to continue.'
            : 'Enter your current weeks and additional days.');
        return;
      }
      final datingProfile = PregnancyProfile(dueDate: _effectiveDue!);
      if (!PregnancyDating.supports(datingProfile, _today)) {
        setState(() => _error =
            'Check your date. This pregnancy view covers weeks 0–42, including the days after week 42 begins.');
        return;
      }
      if (!_adult) {
        setState(() => _error =
            'Confirm the age range for this version’s nutrition references.');
        return;
      }
    }
    if (_step < 1) {
      _goTo(_step + 1);
    } else {
      final current = _number(_currentWeight.text);
      Navigator.of(context).pop(PregnancySetupResult(_profile,
          firstReading: current == null ? null : WeightEntry(_today, current)));
    }
  }

  String? _measurementError(String value, double min, double max) {
    if (value.trim().isEmpty) return null;
    final number = _number(value);
    return number == null || !number.isFinite || number < min || number > max
        ? 'Enter ${min.toInt()}–${max.toInt()}, or leave blank.'
        : null;
  }

  Widget _measurement(TextEditingController controller, String label,
          String hint, IconData icon, double min, double max) =>
      TextFormField(
        controller: controller,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
            labelText: tr(label),
            helperText: trOptional(hint),
            prefixIcon: Icon(icon)),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (value) =>
            trOptional(((value) => _measurementError(value!, min, max))(value)),
      );

  List<Widget> _stageStep() => [
        const PregnancyHero(
            title: 'Start where you are',
            subtitle:
                'First weeks or final stretch: you can join today. No earlier entries needed.'),
        const SizedBox(height: 24),
        AppText('How would you like to add your stage?',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 8, children: [
          ChoiceChip(
              label: const AppText('I know my due date'),
              selected: _dating == _DatingInput.dueDate,
              onSelected: (_) => setState(() {
                    _dating = _DatingInput.dueDate;
                    _error = null;
                  })),
          ChoiceChip(
              label: const AppText('I know my weeks + days'),
              selected: _dating == _DatingInput.currentStage,
              onSelected: (_) => setState(() {
                    _dating = _DatingInput.currentStage;
                    _error = null;
                  })),
        ]),
        const SizedBox(height: 20),
        if (_dating == _DatingInput.dueDate)
          OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month),
              label: AppText(_due == null
                  ? 'Choose due date'
                  : 'Due ${_dateLabel(_due!)}'))
        else ...[
          AppText('How far along are you on ${_dateLabel(_today)}?'),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: TextFormField(
                    controller: _weeks,
                    decoration: InputDecoration(labelText: tr('Weeks')),
                    keyboardType: TextInputType.number,
                    validator: (value) => trOptional(((text) {
                          final value = int.tryParse(text!.trim());
                          return value == null || value < 0 || value > 42
                              ? 'Use 0–42 weeks.'
                              : null;
                        })(value)))),
            const SizedBox(width: 12),
            Expanded(
                child: TextFormField(
                    controller: _days,
                    decoration:
                        InputDecoration(labelText: tr('Additional days')),
                    keyboardType: TextInputType.number,
                    validator: (value) => trOptional(((text) {
                          final value = int.tryParse(text!.trim());
                          return value == null || value < 0 || value > 6
                              ? 'Use 0–6 days.'
                              : null;
                        })(value)))),
          ]),
        ],
        const SizedBox(height: 12),
        const AppText(
            'Use the pregnancy dating given by your care team. Weeks and days are more precise than months. You can update this later.'),
        const SizedBox(height: 24),
        DropdownButtonFormField<PregnancyType>(
            initialValue: _type,
            decoration: InputDecoration(labelText: tr('Pregnancy type')),
            items: const [
              DropdownMenuItem(
                  value: PregnancyType.singleton, child: AppText('One baby')),
              DropdownMenuItem(
                  value: PregnancyType.twins, child: AppText('Twins')),
              DropdownMenuItem(
                  value: PregnancyType.higherOrder,
                  child: AppText('Triplets or more'))
            ],
            onChanged: (value) => setState(() => _type = value!)),
        const SizedBox(height: 12),
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _adult,
            title: const AppText('I am 19–50 years old'),
            subtitle: const AppText(
                'This version’s numeric nutrition references cover this age group.'),
            onChanged: (value) => setState(() => _adult = value!)),
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const AppText('Explore without a profile for now')),
      ];

  List<Widget> _measurementsStep() => [
        const PregnancyHero(
            title: 'Add what you know',
            subtitle:
                'Every measurement here is optional. Leave anything you do not know blank.'),
        const SizedBox(height: 24),
        _measurement(
            _currentWeight,
            'Today’s weight (kg)',
            'Optional — starts your journal today',
            Icons.monitor_weight_outlined,
            25,
            350),
        const SizedBox(height: 24),
        AppText('Before pregnancy',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const AppText(
            'These measurements select the recommended total gain and average weekly rate. Today’s weight will never be used as your pre-pregnancy weight.'),
        const SizedBox(height: 18),
        _measurement(
            _weight,
            'Weight before pregnancy (kg)',
            'Your earlier weight, not a target. Leave blank if unknown.',
            Icons.history_rounded,
            25,
            350),
        const SizedBox(height: 20),
        _measurement(
            _height,
            'Height (cm)',
            'Optional — used with pre-pregnancy weight',
            Icons.straighten_rounded,
            100,
            230),
        const SizedBox(height: 20),
        const AppText(
            'You can still use nutrition guidance and track your weight without a comparison. Earlier readings can be added later if you have them.'),
        if (widget.profile != null)
          const Padding(
              padding: EdgeInsets.only(top: 12),
              child: AppText(
                  'An optional reading for today replaces any reading already saved on this date. Other readings are preserved.')),
      ];

  List<Widget> _reviewStep() {
    final profile = _profile;
    final age = profile.gestationDays(_today);
    final targets = PregnancyTargets(profile, _today);
    final gain = PregnancyReference.totalGain(profile);
    return [
      PregnancyHero(
          title: 'Your defaults are ready',
          subtitle:
              'Week ${age ~/ 7} + ${age % 7} days. Start logging now and adjust your details later.'),
      const SizedBox(height: 20),
      Card(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText('Your daily starting references',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    AppText('Protein: ${targets.protein.toStringAsFixed(0)} g'),
                    AppText(
                        'Carbohydrate: ${targets.carbs.toStringAsFixed(0)} g'),
                    const AppText('Fiber: 28 g'),
                    const SizedBox(height: 8),
                    const AppText(
                        'Pregnancy vitamin and mineral references are included automatically.'),
                    const SizedBox(height: 12),
                    AppText(targets.energy == null
                        ? 'Calories and fat: track now, add personal targets later.'
                        : 'Your saved energy plan is kept: ${targets.energy!.toStringAsFixed(0)} kcal/day.'),
                    const SizedBox(height: 8),
                    const AppText(
                        'These daily nutrient references are not intake limits or a complete meal plan.'),
                    ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const AppText('See vitamin & mineral defaults'),
                        children: [
                          for (final ref in pregnancyMicroReferences)
                            ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: AppText(ref.name),
                                trailing: AppText(
                                    '${ref.target.toStringAsFixed(ref.target < 10 ? 1 : 0)} ${ref.unit}')),
                          const AppText(
                              'Total daily references from food and supplements; these are not supplement doses. The diary currently totals logged food.'),
                        ]),
                  ]))),
      const SizedBox(height: 12),
      ExpansionTile(
          key: const ValueKey('optional-pregnancy-measurements'),
          title: const AppText('Add weight & height (optional)'),
          subtitle: const AppText('You can skip this and start logging now.'),
          children: [
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _measurementsStep())),
          ]),
      const SizedBox(height: 12),
      AppText(gain != null
          ? 'Recommended total pregnancy gain: ${gain.low}–${gain.high} kg, based on your weight before pregnancy and height. This is a guideline range, not a target weight you need to choose.'
          : profile.type != PregnancyType.singleton
              ? 'For twins or more, use a weight-gain and energy plan from your maternity team. You can start your food diary now.'
              : 'No target weight to choose. If you add your weight before pregnancy and height, we will show the recommended total gain range.'),
      const SizedBox(height: 12),
      AppText(
          'Due ${_dateLabel(profile.dueDate)} · You can update your details later.'),
      if (widget.profile != null)
        const Padding(
            padding: EdgeInsets.only(top: 14),
            child: AppText(
                'Your existing readings and energy plan will be kept.')),
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: AppText(
                widget.profile == null ? 'Your pregnancy' : 'Edit pregnancy'),
            leading: IconButton(
                tooltip:
                    trOptional(_step == 0 ? 'Close setup' : 'Previous step'),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _step == 0
                    ? Navigator.of(context).pop()
                    : _goTo(_step - 1))),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                                'Step ${_step + 1} of 2 · ${tr([
                                  'Your stage',
                                  'Ready to log'
                                ][_step])}',
                                style: const TextStyle(
                                    color: PregnancyPalette.berry,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                    value: (_step + 1) / 2,
                                    minHeight: 5,
                                    backgroundColor: PregnancyPalette.blush)),
                          ])),
                  Expanded(
                      child: Form(
                          key: _form,
                          child: ListView(
                              controller: _scroll,
                              padding: const EdgeInsets.all(24),
                              children: [
                                ...switch (_step) {
                                  0 => _stageStep(),
                                  _ => _reviewStep()
                                },
                              ]))),
                  SafeArea(
                      top: false,
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_error != null)
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Semantics(
                                          liveRegion: true,
                                          child: AppText(_error!,
                                              style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .error)))),
                                FilledButton(
                                    onPressed: _next,
                                    child: AppText(_step == 1
                                        ? (widget.profile == null
                                            ? 'Start logging'
                                            : 'Save changes')
                                        : 'Continue')),
                              ]))),
                ]))),
      );
}
