import 'package:opennutritracker/core/presentation/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'pregnancy_controller.dart';

class PregnancyHealthCard extends StatelessWidget {
  final PregnancyController controller;
  const PregnancyHealthCard({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final enabled = controller.data.healthSyncEnabled;
        final status = controller.healthStatus;
        Future<void> perform(Future<dynamic> Function() action) async {
          try {
            final result = await action();
            if (result == false && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: AppText(
                      'Could not open Health Connect on this device.')));
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: AppText(
                      'Could not update Health Connect. Please try again.')));
            }
          }
        }

        return Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText('Automatic weight imports',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const AppText(
                          'Connect your scale app to Health Connect, then allow this app to read weight. Readings stay in your local journal.'),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const AppText('Import from Health Connect'),
                          value: enabled,
                          onChanged: controller.syncing
                              ? null
                              : (value) => perform(
                                  () => controller.setHealthEnabled(value))),
                      if (controller.syncing) const LinearProgressIndicator(),
                      if (controller.healthMessage != null)
                        AppText(controller.healthMessage!),
                      if (controller.data.lastHealthSync != null)
                        AppText(
                            'Last successful sync: ${MaterialLocalizations.of(context).formatMediumDate(controller.data.lastHealthSync!.toLocal())} ${TimeOfDay.fromDateTime(controller.data.lastHealthSync!.toLocal()).format(context)}'),
                      if (enabled) ...[
                        const AppText(
                            'Syncs when you open or return to the app. No background service.'),
                        if (status?.permissionsGranted == true &&
                            status?.historyPermissionGranted == false)
                          const AppText(
                              'Recent weights only (last 30 days). Older readings need history access where supported, or can be added manually.'),
                        Wrap(spacing: 8, children: [
                          FilledButton.tonal(
                              onPressed: controller.syncing
                                  ? null
                                  : () => controller.syncHealth(
                                      requestPermission: true),
                              child: AppText(status?.permissionsGranted == true
                                  ? 'Sync now'
                                  : 'Connect')),
                          TextButton(
                              onPressed: () => perform(
                                  controller.health.openHealthConnectSettings),
                              child: const AppText('Permissions')),
                          if (status?.available == false)
                            TextButton(
                                onPressed: () => perform(
                                    controller.health.openHealthConnectStore),
                                child: AppText(status?.updateRequired == true
                                    ? 'Update Health Connect'
                                    : 'Get Health Connect')),
                        ]),
                      ],
                      if (controller.data.hiddenHealthDays.isNotEmpty)
                        TextButton(
                            onPressed: controller.syncing
                                ? null
                                : () => perform(() async {
                                      await controller.update((d) =>
                                          d.copyWith(hiddenHealthDays: {}));
                                      await controller.syncHealth();
                                    }),
                            child: const AppText(
                                'Allow deleted imports to sync again')),
                      const AppText(
                          'Manual edits take priority. Imported readings are local copies; changes here do not write to Health Connect.'),
                    ])));
      });
}
