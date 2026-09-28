import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/app_language.dart';
import 'package:opennutritracker/core/utils/supported_language.dart';
import 'package:opennutritracker/core/utils/off_const.dart';
import 'package:opennutritracker/core/presentation/widgets/app_text.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/ai/ai_output_language.dart';
import 'package:opennutritracker/features/add_meal/data/dto/off/off_product_dto.dart';
import 'package:opennutritracker/pregnancy/pregnancy_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
      'UI language follows primary phone language, never Swiss region or German fallback',
      () {
    expect(resolveAppLocale(const [Locale('es', 'CH'), Locale('de', 'CH')], []),
        const Locale('es'));
    expect(resolveAppLocale(const [Locale('en', 'CH'), Locale('de')], []),
        const Locale('en'));
    expect(resolveAppLocale(const [Locale('fr', 'CH'), Locale('de')], []),
        const Locale('en'));
    expect(resolveAppLocale([], []), const Locale('en'));
  });
  test('manual preference survives restart and Follow phone clears it',
      () async {
    final language = AppLanguage();
    await language.select('es');
    final restarted = AppLanguage();
    await restarted.load();
    expect(restarted.locale, const Locale('es'));
    await restarted.select('en');
    await language.load();
    expect(language.locale, const Locale('en'));
    await restarted.select(null);
    await language.load();
    expect(language.locale, isNull);
  });
  test('Spanish catalog covers legacy keys and preserves placeholders', () {
    final english =
        jsonDecode(File('lib/l10n/intl_en.arb').readAsStringSync()) as Map;
    final spanish =
        jsonDecode(File('lib/l10n/intl_es.arb').readAsStringSync()) as Map;
    for (final key
        in english.keys.where((key) => !key.toString().startsWith('@'))) {
      expect(spanish.containsKey(key), isTrue, reason: '$key');
      final placeholders = RegExp(r'\{\w+\}');
      expect(placeholders.allMatches(spanish[key]).map((m) => m[0]).toSet(),
          placeholders.allMatches(english[key]).map((m) => m[0]).toSet(),
          reason: '$key');
    }
  });
  test(
      'AI output instructions follow app language while preserving the protocol',
      () async {
    await S.load(const Locale('es'));
    expect(aiOutputLanguageInstruction(), contains('in Spanish'));
    expect(aiOutputLanguageInstruction(),
        contains('Do not translate protocol values'));
    expect(S.current.deleteMealGroupContent(3, 'Mi comida'),
        contains('3 alimentos'));
    await S.load(const Locale('en'));
    expect(aiOutputLanguageInstruction(), contains('in English'));
  });
  test(
      'Spanish product name preferred; original name remains when translation is absent',
      () {
    expect(OFFConst.getOffBarcodeSearchUri('123').queryParameters['fields'], contains('product_name_es'));
    expect(OFFConst.getOffWordSearchUrl('leche').queryParameters['fields'], contains('product_name_es'));
    final dto = OFFProductDTO.fromJson({
      'product_name': 'Milch',
      'product_name_es': 'Leche',
      'nutriments': <String, dynamic>{}
    });
    expect(dto.getLocaleName(SupportedLanguage.fromCode('es-CH')), 'Leche');
    final original = OFFProductDTO.fromJson(
        {'product_name': 'Milch', 'nutriments': <String, dynamic>{}});
    expect(original.getLocaleName(SupportedLanguage.es), 'Milch');
  });
  testWidgets(
      'Settings switches open UI, date picker locale and phone override without restart',
      (tester) async {
    tester.platformDispatcher.localesTestValue = const [
      Locale('es', 'CH'),
      Locale('de', 'CH')
    ];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final language = AppLanguage();
    await tester.pumpWidget(AppLanguageScope(
        language: language,
        child: ListenableBuilder(
            listenable: language,
            builder: (context, _) => MaterialApp(
                  locale: language.locale,
                  supportedLocales: const [Locale('en'), Locale('es')],
                  localeListResolutionCallback: resolveAppLocale,
                  localizationsDelegates: const [
                    S.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate
                  ],
                  home: const PregnancySettings(),
                ))));
    await tester.pumpAndSettle();
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Registro de alimentos con IA'), findsOneWidget);
    await tester.tap(find.text('Idioma'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('AI food logging'), findsOneWidget);
    expect(Localizations.localeOf(tester.element(find.byType(LanguageSetting))),
        const Locale('en'));
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();
    expect(find.text('Ajustes'), findsOneWidget);
    expect(Localizations.localeOf(tester.element(find.byType(LanguageSetting))),
        const Locale('es'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    language.dispose();
  });
}
