import 'package:opennutritracker/core/presentation/widgets/app_text.dart';
import 'package:flutter/material.dart';
import '../features/settings/presentation/pages/ai_settings_page.dart';
import '../features/settings/presentation/widgets/export_import_dialog.dart';
import 'pregnancy_hub.dart';

class PregnancySettings extends StatelessWidget {
  final bool embedded;
  const PregnancySettings({super.key, this.embedded = false});
  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(
        context); // Rebuild non-Text labels when language changes.

    final body = ListView(padding: const EdgeInsets.all(16), children: [
      const LanguageSetting(),
      ListTile(
          leading: const Icon(Icons.auto_awesome),
          title: const AppText('AI food logging'),
          subtitle:
              const AppText('Provider keys and models for meals and labels'),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AiSettingsPage()))),
      const Padding(
          padding: EdgeInsets.all(16),
          child: AppText(
              'Your pregnancy profile and weight stay on this device. AI logging sends the food photo or description you choose to your configured provider. Configure a provider key here; the separate app cannot read your OpenNutriTracker key.')),
      ListTile(
          leading: const Icon(Icons.favorite_outline),
          title: const AppText('Pregnancy & targets'),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PregnancyHub()))),
      ListTile(
          leading: const Icon(Icons.import_export),
          title: const AppText('Backup & restore'),
          subtitle: const AppText(
              'Meals, diary, pregnancy profile and weight journal'),
          onTap: () => showDialog(
              context: context, builder: (_) => ExportImportDialog())),
      const Padding(
          padding: EdgeInsets.all(16),
          child: AppText(
              'Pregnancy Nutrition • 1.3.0\nAdapted from OpenNutriTracker • GPL-3.0')),
    ]);
    return embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: const AppText('Settings')), body: body);
  }
}
