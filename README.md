# Pregnancy Nutrition

A pregnancy adaptation of geduardo/OpenNutriTracker. The existing AI food logger and diary are the core of the app.

## Food logging retained

Original photo/text AI entry, label extraction, barcode scanning, food search, portions, food library, saved meals, copying, editing and diary. Configure your own Gemini/OpenAI key in Settings > AI food logging. This separate app cannot read the original app's keys.

Micronutrients now pass through the same food, intake, preset, Hive and JSON backup pipeline as macros. AI review, food details and manual editing support folate (DFE), iron, calcium, iodine, choline, vitamin D and B12. Home and diary days display progress against pregnancy references, plus fiber and caffeine. Unknown values remain unknown, partial coverage is shown, and AI estimates are identified.

Without private Supabase configuration, food search uses USDA FoodData Central directly. The bundled public DEMO_KEY is rate limited; supply FDC_API_KEY at build time for regular use.

## Pregnancy integration

- Two-screen onboarding at any day of weeks 0–42: stage, then ready-to-use nutrient references. Weight and height are optional; no target weight or calorie target is required. Start logging opens the food diary directly.
- Pregnancy profile, weight log, gain chart and evidence replace the fitness strategy screen. Pregnancy gain never feeds the adaptive deficit engine.
- Adult pregnancy nutrient references (ages 19–50). Protein/carbohydrate RDA references remain available without an energy plan.
- Enter a care-team energy target, or known pre-pregnancy maintenance intake. The latter uses ACOG singleton trimester additions: 0 / 340 / 450 kcal. No target is invented from missing information; multiples need a care-team energy target.
- A practical 50/20/30 carbohydrate/protein/fat split is used when energy is supplied, preserving pregnancy carbohydrate/protein reference minima. This split is an app default, not a unique pregnancy guideline.
- Existing pregnancy profile and weight data from 1.0.0 are retained. Backups now include pregnancy data and food logs. Older food-only backups preserve the pregnancy journal.

Targets describe total daily intake, not supplement doses. The dashboard counts logged food, not unlogged supplements. AI estimates and incomplete labels cannot establish deficiency or clinical adequacy. The research chart uses published INTERGROWTH-21st 10th/50th/90th centiles for weeks 15–40, relative to the earliest saved weight at weeks 9+0–13+6 (singleton and early BMI 18.5–24.9). It is a study comparison, not an individual normal/abnormal judgment. Other profiles retain IOM total-gain and weekly-rate guidance without invented centiles. Health Connect weight imports are restored to the pregnancy journal; enable them from Pregnancy > Automatic weight imports. Sync runs at app startup, resume, entering Pregnancy, or Sync now, not as a background job. Manual entries take priority; source-deleted records remain local copies until deleted here. Evidence links and methods are available within Pregnancy > Evidence.

## Language

English and Spanish are supported throughout the pregnancy UI and the original food logger. On first launch the primary phone language is used (Spanish in any region, including es-CH); unsupported primary languages use English rather than a secondary German fallback. Settings > Language (Ajustes > Idioma) offers Follow phone, Español and English. The selection is stored securely across restarts and is also available before onboarding.

AI requests ask for food names and clarification text in the selected language while preserving the JSON schema. Open Food Facts Spanish names are requested when available. Existing user-entered food names, brands and external database content are not machine-translated; USDA names may remain English. Language choice does not change nutrient guidance, storage keys, units, saved food data or Health Connect permissions.

Spanish UI catalogues live in lib/l10n/intl_es.arb and lib/l10n/pregnancy_es.json. Regenerate the Dart catalogues with `python tool/generate_spanish.py`. The legacy S API remains compatible; additional screens use explicit AppText/tr UI boundaries. Do not apply UI translation to protocol values or saved food names.

Tests include es-CH with a secondary de-CH locale, preference persistence, live language switching, catalogue placeholders, Spanish product names, and the real onboarding → weight import → AI food logging → backup workflow in Spanish at phone width. AI network calls and physical Android language settings are not device-tested.

## Build and validation

Flutter 3.35.7 / Dart 3.9.2, JDK 17, Android SDK.

    flutter pub get
    dart run build_runner build --delete-conflicting-outputs
    dart analyze lib test/pregnancy
    flutter test test
    flutter build apk --release

Version 1.3.0 (76), Android 8.0+. Package org.geduardo.pregnancynutrition updates the earlier pregnancy APK using the same signing key. It installs separately from com.opennutritracker.ont.opennutritracker.

86 tests passed. The integration test opens the real app, follows food-entry routes, saves a synthetic AI result, verifies persisted micronutrients and historical trimester targets, and round-trips a combined backup. Static analysis is clean; APK signature and alignment checks passed. Live AI calls, camera/barcode hardware and physical-phone Health Connect behavior remain unverified. Automated tests cover foreground lifecycle imports, duplicates, denial, partial history permission, persistence failure, concurrent edits, legacy storage and published centile checkpoints.

Keep android/pregnancy-release.jks and android/key.properties private and backed up; they are Git-ignored. Windows builds used JAVA_TOOL_OPTIONS with -Djdk.net.unixdomain.tmpdir pointing to the workspace work/java-tmp folder.

Local branch pregnancy-foundation, based on source commit 01b7bc4721a9be7f617eed85f263dea98f7d1c3a. Original documentation and attribution: UPSTREAM_README.md.

## License

GPL-3.0, inherited from OpenNutriTracker; see LICENSE.
