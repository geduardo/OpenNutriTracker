import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/magic_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/presets_screen.dart';
import 'package:opennutritracker/features/scanner/scanner_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';

class MealEntryScreen extends StatelessWidget {
  const MealEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as MealEntryScreenArguments;

    return Scaffold(
      appBar: AppBar(
        title: Text(args.mealType.getTypeName(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _EntryOption(
              icon: Icons.auto_awesome,
              label: 'Magic',
              subtitle: 'Photo, text, or both',
              color: Theme.of(context).colorScheme.primary,
              onTap: () => Navigator.of(context).pushNamed(
                NavigationOptions.magicRoute,
                arguments:
                    MagicScreenArguments(args.day, args.mealType),
              ),
            ),
            const SizedBox(height: 16),
            _EntryOption(
              icon: Icons.search,
              label: S.of(context).searchLabel,
              subtitle: 'Food database',
              color: Theme.of(context).colorScheme.secondary,
              onTap: () => Navigator.of(context).pushNamed(
                NavigationOptions.addMealRoute,
                arguments:
                    AddMealScreenArguments(args.mealType, args.day),
              ),
            ),
            const SizedBox(height: 16),
            _EntryOption(
              icon: Icons.qr_code_scanner,
              label: S.of(context).scanProductLabel,
              subtitle: 'Barcode',
              color: Theme.of(context).colorScheme.tertiary,
              onTap: () => Navigator.of(context).pushNamed(
                NavigationOptions.scannerRoute,
                arguments: ScannerScreenArguments(
                    args.day, args.mealType.getIntakeType()),
              ),
            ),
            const SizedBox(height: 16),
            _EntryOption(
              icon: Icons.history,
              label: S.of(context).recentlyAddedLabel,
              subtitle: 'Quick re-log',
              color: Theme.of(context).colorScheme.outline,
              onTap: () => Navigator.of(context).pushNamed(
                NavigationOptions.addMealRoute,
                arguments:
                    AddMealScreenArguments(args.mealType, args.day,
                        initialTab: 2),
              ),
            ),
            const SizedBox(height: 16),
            _EntryOption(
              icon: Icons.playlist_play,
              label: 'Saved meals',
              subtitle: 'Reusable meals',
              color: Theme.of(context).colorScheme.inversePrimary,
              onTap: () => Navigator.of(context).pushNamed(
                NavigationOptions.presetsRoute,
                arguments: PresetsScreenArguments(args.mealType, args.day),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _EntryOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Icon(icon, size: 32, color: color),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(subtitle,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MealEntryScreenArguments {
  final AddMealType mealType;
  final DateTime day;

  MealEntryScreenArguments(this.mealType, this.day);
}
