import 'pregnancy/pregnancy_gate.dart';
import 'core/utils/app_language.dart';
import 'pregnancy/pregnancy_theme.dart';
import 'pregnancy/pregnancy_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:opennutritracker/core/domain/entity/app_theme_entity.dart';
import 'package:opennutritracker/core/presentation/widgets/image_full_screen.dart';

import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/logger_config.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/core/utils/theme_mode_provider.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/ai_result_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/magic_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/meal_entry_screen.dart';
import 'package:opennutritracker/features/add_meal/presentation/presets_screen.dart';
import 'package:opennutritracker/features/edit_meal/presentation/edit_meal_screen.dart';
import 'package:opennutritracker/features/scanner/scanner_screen.dart';
import 'package:opennutritracker/features/meal_detail/meal_detail_screen.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LoggerConfig.intiLogger();
  await initLocator();
  await AppLanguage.instance.load();
  runApp(const IntegratedPregnancyApp());
}

class IntegratedPregnancyApp extends StatelessWidget {
  final AppLanguage? language;
  const IntegratedPregnancyApp({super.key, this.language});
  @override
  Widget build(BuildContext context) => AppLanguageScope(
      language: language ?? AppLanguage.instance,
      child: ChangeNotifierProvider(
          create: (_) => ThemeModeProvider(appTheme: AppThemeEntity.system),
          child: const OpenNutriTrackerApp(userInitialized: true)));
}

class OpenNutriTrackerApp extends StatelessWidget {
  final bool userInitialized;

  const OpenNutriTrackerApp({super.key, required this.userInitialized});

  @override
  Widget build(BuildContext context) {
    final language = AppLanguageScope.of(context);
    return MaterialApp(
      title: 'Pregnancy Nutrition',
      debugShowCheckedModeBanner: false,
      theme: pregnancyTheme(),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      locale: language.locale,
      supportedLocales: const [Locale('en'), Locale('es')],
      localeListResolutionCallback: resolveAppLocale,
      initialRoute: NavigationOptions.mainRoute,
      routes: {
        NavigationOptions.mainRoute: (context) => const PregnancyGate(),
        NavigationOptions.onboardingRoute: (context) => const PregnancyGate(),
        NavigationOptions.settingsRoute: (context) => const PregnancySettings(),
        NavigationOptions.mealEntryRoute: (context) => const MealEntryScreen(),
        NavigationOptions.addMealRoute: (context) => const AddMealScreen(),
        NavigationOptions.magicRoute: (context) => const MagicScreen(),
        NavigationOptions.aiResultRoute: (context) => const AiResultScreen(),
        NavigationOptions.presetsRoute: (context) => const PresetsScreen(),
        NavigationOptions.scannerRoute: (context) => const ScannerScreen(),
        NavigationOptions.mealDetailRoute: (context) =>
            const MealDetailScreen(),
        NavigationOptions.editMealRoute: (context) => const EditMealScreen(),
        NavigationOptions.imageFullScreenRoute: (context) =>
            const ImageFullScreen(),
      },
    );
  }
}
