import 'package:opennutritracker/core/presentation/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'pregnancy_evidence.dart';
import 'pregnancy_model.dart';
import 'pregnancy_store.dart';
import 'pregnancy_weight_page.dart';
import 'pregnancy_profile_form.dart';
import 'pregnancy_theme.dart';

class PregnancyApp extends StatelessWidget {
  final PregnancyStore store;
  const PregnancyApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Pregnancy Nutrition',
        debugShowCheckedModeBanner: false,
        theme: pregnancyTheme(),
        home: PregnancyHome(store: store),
      );
}

class PregnancyHome extends StatefulWidget {
  final PregnancyStore store;
  const PregnancyHome({super.key, required this.store});
  @override
  State<PregnancyHome> createState() => _PregnancyHomeState();
}

class _PregnancyHomeState extends State<PregnancyHome> {
  PregnancyData? _data;
  bool _loadFailed = false;
  bool _saving = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadFailed = false);
    try {
      final data = await widget.store.read();
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _save(PregnancyData data) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.store.write(data);
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: AppText(
                'Could not save. Your previous data is unchanged. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _profile() async {
    final result = await Navigator.of(context).push<PregnancySetupResult>(
        MaterialPageRoute(
            builder: (_) => PregnancyProfileForm(profile: _data!.profile)));
    if (result != null && mounted) {
      var updated = _data!.withProfile(result.profile);
      if (result.firstReading != null) {
        updated = updated.withWeight(result.firstReading!);
      }
      await _save(updated);
    }
  }

  Future<void> _deleteData() async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const AppText('Delete this pregnancy journal?'),
              content: const AppText(
                  'This removes the profile and all saved weights from this app. This cannot be undone.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const AppText('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const AppText('Delete')),
              ],
            ));
    if (confirm != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.store.clear();
      if (mounted) setState(() => _data = PregnancyData());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                AppText('Could not delete the journal. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(
        context); // Rebuild non-Text labels when language changes.

    if (_loadFailed) {
      return Scaffold(
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppText(
                          'Your saved journal could not be opened. It has not been replaced.'),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: _load, child: const AppText('Try again'))
                    ],
                  ))));
    }
    final data = _data;
    if (data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
          leadingWidth: 66,
          leading: const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 0, 14),
              child: SoftIcon(Icons.favorite_outline_rounded)),
          titleSpacing: 12,
          title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText('Pregnancy',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                AppText('NUTRITION & YOU',
                    style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        color: PregnancyPalette.muted)),
              ]),
          actions: [
            IconButton(
                onPressed: _saving ? null : _profile,
                tooltip: trOptional('Pregnancy profile'),
                icon: const Icon(Icons.tune)),
            PopupMenuButton<String>(
                enabled: !_saving,
                onSelected: (_) => _deleteData(),
                itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'delete', child: AppText('Delete journal')),
                    ]),
          ]),
      body: AbsorbPointer(
          absorbing: _saving,
          child: Column(children: [
            if (_saving) const LinearProgressIndicator(),
            Expanded(
                child: IndexedStack(index: _tab, children: [
              _overview(data),
              const PregnancyNutritionPage(),
              PregnancyWeightPage(data: data, onSave: _save, onSetup: _profile),
              const PregnancySourcesPage(),
            ])),
          ])),
      bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Align(
                heightFactor: 1,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 580),
                    child: Container(
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: PregnancyPalette.border),
                          boxShadow: [
                            BoxShadow(
                                color: PregnancyPalette.plum
                                    .withValues(alpha: 0.05),
                                blurRadius: 24,
                                offset: const Offset(0, 4))
                          ]),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: NavigationBar(
                              selectedIndex: _tab,
                              onDestinationSelected: (value) =>
                                  setState(() => _tab = value),
                              destinations: [
                                NavigationDestination(
                                    icon: Icon(Icons.spa_outlined),
                                    label: tr('Today')),
                                NavigationDestination(
                                    icon: Icon(Icons.restaurant_outlined),
                                    label: tr('Nutrition')),
                                NavigationDestination(
                                    icon: Icon(Icons.show_chart),
                                    label: tr('Weight')),
                                NavigationDestination(
                                    icon: Icon(Icons.menu_book_outlined),
                                    label: tr('Evidence')),
                              ])),
                    ))),
          )),
    );
  }

  Widget _overview(PregnancyData data) {
    final profile = data.profile;
    final days = profile?.gestationDays(DateTime.now()) ?? 0;
    final active =
        profile != null && PregnancyDating.supports(profile, DateTime.now());
    return ReadingList(children: [
      PregnancyHero(
        title: active
            ? 'Week ${days ~/ 7} + ${days % 7} days'
            : 'Nourish your\npregnancy.',
        subtitle: profile == null
            ? 'Nutrition made clearer. A gentle space to follow your pregnancy, one day at a time.'
            : 'A little nourishment, a little perspective. Your pregnancy journey, at your own pace.',
        action: profile == null
            ? FilledButton.icon(
                onPressed: _profile,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const AppText('Set up pregnancy'))
            : null,
      ),
      const SizedBox(height: 26),
      AppText('Your daily companions',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6),
      const AppText('Simple tools. Thoughtful guidance.'),
      const SizedBox(height: 18),
      LayoutBuilder(builder: (context, constraints) {
        final cards = [
          PregnancyShortcut(
              icon: Icons.restaurant_rounded,
              title: 'Nourish yourself',
              description:
                  'Key nutrients, everyday food ideas and the evidence behind them.',
              actionLabel: 'Explore nutrition',
              onTap: () => setState(() => _tab = 1)),
          PregnancyShortcut(
              icon: Icons.show_chart_rounded,
              title: 'Your weight, in context',
              description:
                  'A gentle view of your readings alongside pregnancy references.',
              tint: PregnancyPalette.lavender,
              actionLabel: 'Open weight journal',
              onTap: () => setState(() => _tab = 2)),
        ];
        return constraints.maxWidth >= 640
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 16),
                Expanded(child: cards[1])
              ])
            : Column(
                children: [cards[0], const SizedBox(height: 14), cards[1]]);
      }),
      const SizedBox(height: 20),
      if (profile != null && !active)
        InfoCard(
            title: 'Check your due date',
            body:
                'The saved date is outside this app’s 0–42 week pregnancy view. Your entries are preserved.',
            action: TextButton(
                onPressed: _profile, child: const AppText('Edit profile'))),
      const InfoCard(
          icon: Icons.eco_outlined,
          title: 'Build variety across the week',
          body:
              'Include vegetables and fruit, whole grains, protein foods and pasteurized dairy or fortified alternatives. Your care team can help adapt choices for nausea, allergies or a vegetarian diet.'),
      const InfoCard(
          icon: Icons.menu_book_outlined,
          title: 'A guide to discuss with your care team',
          body:
              'This first version uses US adult pregnancy nutrient references (ages 19–50), with UK caffeine guidance clearly labelled. Medical conditions, multiple pregnancies and local guidance can change your plan. No calorie restriction or supplement prescription is generated.'),
      const SizedBox(height: 16),
      const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.lock_outline_rounded,
            size: 18, color: PregnancyPalette.muted),
        SizedBox(width: 10),
        Expanded(
            child: AppText(
                'A space just for you. Your journal stays on this device.',
                style: TextStyle(fontSize: 12, color: PregnancyPalette.muted))),
      ]),
    ]);
  }
}

class PregnancyNutritionPage extends StatelessWidget {
  const PregnancyNutritionPage({super.key});
  @override
  Widget build(BuildContext context) => ReadingList(children: [
        const PregnancyHero(
            title: 'Nutrients for pregnancy',
            subtitle: 'Small everyday choices. Nourishment for both of you.'),
        const SizedBox(height: 20),
        const AppText(
            'US references for ages 19–50 • Total daily intake from food and supplements combined. These are general reference values, not a personalized prescription or measured intake.'),
        const SizedBox(height: 12),
        const Card(
            child: ExpansionTile(
          leading:
              Icon(Icons.info_outline_rounded, color: PregnancyPalette.berry),
          title: AppText('How to read these references'),
          childrenPadding: EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            AppText(
                'RDA: meets the needs of nearly all healthy people in a group. AI: an intake reference used when evidence is insufficient to set an RDA. More is not necessarily better.')
          ],
        )),
        const SizedBox(height: 12),
        for (final nutrient in pregnancyNutrients)
          Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ExpansionTile(
                leading: SoftIcon(_nutrientIcon(nutrient.name)),
                title: AppText(nutrient.name),
                subtitle: AppText(
                    '${tr(nutrient.amount)} / day • ${tr(nutrient.kind)}'),
                childrenPadding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: PregnancyPalette.border),
                  const SizedBox(height: 10),
                  const AppText('ON YOUR PLATE',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w600,
                          color: PregnancyPalette.berry)),
                  const SizedBox(height: 8),
                  AppText(nutrient.foods),
                  const SizedBox(height: 8),
                  AppText(nutrient.note),
                  const SourceLink(sourceId: 'nih')
                ],
              )),
        const InfoCard(
            title: 'Caffeine • UK guidance',
            body:
                'Keep caffeine to no more than 200 mg a day from all sources. Drink sizes and preparation change the amount. Unknown caffeine content is not zero.',
            action: SourceLink(sourceId: 'nhs')),
        const InfoCard(
            title: 'Fish • US FDA/EPA guidance',
            body:
                'Choose 2–3 servings a week from the lower-mercury “Best Choices” list: 8–12 oz (about 225–340 g) total. Use the source list for species and choose cooked fish.',
            action: SourceLink(sourceId: 'fda')),
        const InfoCard(
            title: 'Prenatal supplements',
            body:
                'Review your current prenatal product with your midwife or obstetrician before adding another supplement. Intake reference values are not amounts to add on top of your food or prenatal vitamin.',
            action: SourceLink(sourceId: 'nih')),
        const InfoCard(
            title: 'Food preparation matters',
            body:
                'Use pregnancy-specific guidance on pasteurization, cooking and storage. A food photo or barcode alone cannot establish whether a food is safe.',
            action: SourceLink(sourceId: 'nhs')),
      ]);

  static IconData _nutrientIcon(String name) => switch (name) {
        'Folate' => Icons.eco_outlined,
        'Iron' => Icons.water_drop_outlined,
        'Calcium' => Icons.local_drink_outlined,
        'Iodine' => Icons.waves_rounded,
        'Choline' => Icons.egg_outlined,
        'Vitamin D' => Icons.wb_sunny_outlined,
        _ => Icons.grain_rounded,
      };
}

class PregnancySourcesPage extends StatelessWidget {
  const PregnancySourcesPage({super.key});
  @override
  Widget build(BuildContext context) => ReadingList(children: [
        const PregnancyHero(
            title: 'Evidence & limitations',
            subtitle:
                'Know where your guidance comes from, and what it can tell you.'),
        const SizedBox(height: 12),
        AppText(
            'References checked ${tr(evidenceReviewed)}. Guidelines synthesize studies; they do not predict the outcome of an individual pregnancy.'),
        const InfoCard(
            title: 'How the study comparison is drawn',
            body:
                'The shaded study comparison uses the published INTERGROWTH-21st 10th and 90th centiles for exact weeks 15–40; the dashed line is the median. Days interpolate adjacent published weeks. Gain is measured from the earliest saved weight at weeks 9+0–13+6, with BMI 18.5–24.9 then and a singleton pregnancy. Pre-pregnancy weight is never substituted. The study recruited healthy, well-nourished women; centiles are not treatment targets or diagnostic cutoffs.'),
        const InfoCard(
            title: 'Reading your chart',
            body:
                'Pre-pregnancy BMI selects the IOM total-gain and second/third trimester weekly-rate guidance. The separate research chart uses first-trimester BMI and weight. Fluid changes, measurement conditions and individual circumstances affect readings. Being outside the band does not diagnose a problem or mean you should lose weight. Discuss a persistent change with your care team.'),
        for (final source in evidenceSources)
          InfoCard(
              title: source.title,
              body: source.context,
              action: SourceLink(sourceId: source.id)),
      ]);
}

class SourceLink extends StatelessWidget {
  final String sourceId;
  const SourceLink({super.key, required this.sourceId});
  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(
        context); // Rebuild non-Text labels when language changes.

    final source = evidenceSources.firstWhere((value) => value.id == sourceId);
    return TextButton.icon(
        icon: const Icon(Icons.open_in_new, size: 16),
        label: AppText('Read source • ${source.title.split(' • ').first}'),
        onPressed: () async {
          try {
            if (!await launchUrl(Uri.parse(source.url),
                mode: LaunchMode.externalApplication)) {
              throw StateError('Link unavailable');
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: AppText('Could not open ${source.url}')));
            }
          }
        });
  }
}

class ReadingList extends StatelessWidget {
  final List<Widget> children;
  const ReadingList({super.key, required this.children});
  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: children),
      ));
}

class InfoCard extends StatelessWidget {
  final String title;
  final String body;
  final Widget? action;
  final IconData? icon;
  const InfoCard(
      {super.key,
      required this.title,
      required this.body,
      this.action,
      this.icon});
  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (icon != null) ...[
              Icon(icon, size: 22, color: PregnancyPalette.berry),
              const SizedBox(width: 12)
            ],
            Expanded(
                child: AppText(title,
                    style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 8),
          AppText(body),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ]),
      ));
}
