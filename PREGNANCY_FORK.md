# Pregnancy fork: evidence and implementation

## Scope selected

Nutrition recommendations grounded in scientific evidence, plus weight tracking against pregnancy-stage references. This first version implements a standalone pregnancy experience within the cloned Flutter project. It does not expose the inherited weight-loss UI or infer calorie needs from pregnancy weight changes.

## References reviewed 28 September 2026

- [NIH Office of Dietary Supplements: Pregnancy](https://ods.od.nih.gov/factsheets/Pregnancy-HealthProfessional/) summarizes US Dietary Reference Intakes and research. The app shows seven adult (19–50) nutrient references and distinguishes RDA from AI. These refer to total intake, not amounts to add as supplements.
- [National Academies: Weight Gain During Pregnancy, 2009 resource sheet](https://nap.nationalacademies.org/resource/12584/Resource-Page---Weight-Gain-During-Pregnancy.pdf) provides consensus singleton gain ranges based largely on observational evidence and an assumed 0.5–2 kg first-trimester gain. It does not supply diagnostic weekly percentiles.
- [CDC pregnancy weight guidance](https://www.cdc.gov/maternal-infant-health/pregnancy-weight/index.html) continues to use BMI-based recommendations and provides separate twin trackers.
- [Health Canada metric guidance](https://sante.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/prenatal-nutrition/pregnancy-weight-gain-calculator.html?wbdisable=true) provides kilogram ranges.
- [NHS food guidance](https://www.nhs.uk/pregnancy/keeping-well/foods-to-avoid/) is the labelled UK source for caffeine and food preparation.
- [FDA/EPA fish guidance](https://www.fda.gov/food/consumers/advice-about-eating-fish) provides lower-mercury seafood choices and serving guidance.
- [Swiss FSVO pregnancy guidance](https://www.blv.admin.ch/en/recommendations-for-those-who-are-pregnant-or-breastfeeding) is linked for regional context; Swiss-specific nutrient targets have not been implemented.

## Weight chart method

Pre-pregnancy BMI is pre-pregnancy kilograms divided by height in metres squared. Current weight never changes the reference category.

| Pre-pregnancy BMI | Singleton total gain, kg |
| --- | --- |
| Below 18.5 | 12.5–18 |
| 18.5 to below 25 | 11.5–16 |
| 25 to below 30 | 7–11.5 |
| 30 and above | 5–9 |

For weeks 13–40, the chart linearly interpolates from the assumed 0.5–2 kg at week 13 to the table range at week 40. This interpolation is an explicit product approximation, not a research-derived weekly distribution. The UI labels it accordingly. No band is computed before week 13, after week 40, without baseline measurements, or for multiples. It cannot establish whether an individual pregnancy is healthy and never triggers calorie adjustments.

Calendar dates are normalized without local DST-duration arithmetic. Editing the due date preserves all readings and recalculates their gestational positions. One weight per calendar date is stored; the UI explains replacement behavior. No personal dates, weights or medical details were prefilled from the conversation.

## Code

- `lib/pregnancy/pregnancy_model.dart`: calendar calculations, baseline BMI, reference bands and versioned data.
- `lib/pregnancy/pregnancy_evidence.dart`: reference values, context and source links.
- `lib/pregnancy/pregnancy_store.dart`: separate secure-storage key.
- `lib/pregnancy/pregnancy_app.dart`: Today, Nutrition and Evidence views.
- `lib/pregnancy/pregnancy_profile_form.dart`: optional baseline and due-date setup.
- `lib/pregnancy/pregnancy_weight_page.dart`: readings and chart.
- `test/pregnancy/`: focused calculation and widget tests.

## Remaining product work

- Confirm country and language before adapting regional recommendations.
- Physical Android/iOS installation and secure-storage verification; accessibility and clinician review.
- Export/import and optional clinician-provided targets.
- Pregnancy-appropriate integration of the inherited food diary, with unknown nutrient values, nutrient-form/unit handling and data provenance before any adequacy assessment.
- Any validated centile chart would need a suitable published dataset, population eligibility and reproducible implementation; this app makes no centile claim.

The original source is preserved, including its license. This work is local and has not been pushed or published.

## Validation on 28 September 2026

- 12 focused Flutter unit/widget tests passed, including reference boundaries, DST/leap-date arithmetic, missing baselines, exclusion of multiples, persistence behavior, failed storage operations and phone-width layout with larger text.
- `dart analyze lib/pregnancy`: no issues found.
- `flutter build web`: succeeded with Flutter 3.35.7 / Dart 3.9.2 (JavaScript build).
- `git diff --check`: passed.
- Browser preview rendered. Automated browser clicks did not reliably change the view, so browser interaction verification is inconclusive; widget interaction tests passed.
- No physical-device or clinical validation has been performed. An Android release APK was subsequently built and statically verified (see below). The inherited app test suite was not rerun; the changed default entry point uses the new pregnancy feature.

## Joining during pregnancy

Setup now has three steps: pregnancy stage, optional measurements and review.
Enter either a care-team due date or current completed weeks plus additional days (0–6). The input window covers every day of weeks 0–42, including 42+6. The app calculates the equivalent due date using its existing 40-week dating convention and labels a date derived from weeks/days as estimated.

Today’s weight is a separate optional journal reading. It is never substituted for pre-pregnancy weight. All measurements can be skipped; missing baseline values disable the BMI-based band, without blocking nutrition guidance or weight logging. Historical readings are optional and can be entered later. Editing a profile preserves saved readings.

Validation after the onboarding update: all 19 focused tests passed, including full setup at 6+3, 20+3, 38+3 and 42+3, a current-weight-only entry, editing a saved profile and invalid-day validation. Every gestational day from 0 through 300 is covered by the dating calculation test. Static analysis found no issues.

## Android APK

Release APK 1.0.0 (72) built successfully on 28 September 2026. It supports Android API 26+ and ARM64, ARMv7 and x86_64. The final APK has package `org.geduardo.pregnancynutrition`, label Pregnancy Nutrition and a pink heart icon. All provider authorities use the separate pregnancy package, with no shared user ID or debuggable flag. A dedicated local signing key signs the release; `apksigner verify` and `zipalign -c -P 16 4` passed. Installation and runtime behavior on a physical Android phone remain unverified.

## 1.1.0: integration into the existing food tracker

The default entry point now initializes the original encrypted food stores and opens the original food diary. AI photo/text logging, label extraction, barcode/search, library, saved meals, portion editing and historical diary remain available. Pregnancy replaces the fitness strategy page. Goal usecases bypass the adaptive weight-loss engine; historical food entries use their own gestational day when creating target records.

Nutrients use a nullable map with explicit canonical units per 100 g/ml, persisted in appended Hive fields 9 and 10 (map and provenance). Older foods load an empty map; unknown values are not converted to zero. USDA fields use nutrient IDs 1089 (iron), 1087 (calcium), 1190 (folate DFE), 1100 (iodine), 1180 (choline), 1114 (vitamin D in micrograms), 1178 (B12). Open Food Facts gram values are converted to mg or micrograms; its ambiguous folate field is not counted as DFE. AI label extraction requires explicit amounts, and does not derive micronutrients from ingredient lists or percent daily values. Photo/text estimates remain estimates. The pregnancy profile is not included in AI requests.

Targets: adult pregnancy NIH/National Academies DRIs. Carbohydrate 175 g RDA, protein 71 g RDA, fiber 28 g AI; seven micronutrients use the existing NIH evidence source (B12 2.6 micrograms). Caffeine is presented as a limit, never an intake goal. The dashboard reports food totals only and explains coverage and supplement limitations.

Energy requires a supplied care-team target or pre-pregnancy maintenance value. Care-team targets take priority, with no additions. The singleton maintenance route adds ACOG trimester guidance (0, 340, 450 kcal/day), with trimester boundaries at 14 and 28 completed weeks. No maintenance estimate is inferred from pregnancy weight gain. The 50/20/30 macro split is an app planning default within adult AMDRs, not a unique pregnancy prescription; pregnancy RDA minima take priority. Multiples need individualized energy input. More personalized clinical macro targets and supplement tracking are not implemented.

Sources: https://www.acog.org/womens-health/experts-and-stories/ask-acog/how-much-weight-should-i-gain-during-pregnancy ; https://www.ncbi.nlm.nih.gov/books/NBK545442/ ; https://ods.od.nih.gov/factsheets/Pregnancy-HealthProfessional/ ; https://fdc.nal.usda.gov/Foundation_Foods_Documentation/

Verification: 71 tests passed, including the real app entry point, original AI entry navigation, synthetic AI-result saving to the actual encrypted diary, portion/micronutrient persistence, missing-data coverage, historical trimester targets, and combined food/pregnancy backup restore. Static analysis is clean. Android release 1.1.0 (73) built and signature/alignment verified. Provider calls and device hardware have not been exercised. The preview contains an explicitly synthetic test meal, never user data.


## 1.1.1 onboarding correction

Setup now takes two screens: pregnancy stage, then ready-to-use daily references.
The final Start logging button goes directly to the food diary without opening
an energy-target form. Weight/height inputs are collapsed and optional; no target
weight is requested. Known pre-pregnancy measurements calculate the BMI-specific
total gain range automatically. Unknown measurements stay unknown. Protein,
carbohydrate, fiber and seven micronutrient reference values are shown before
starting. These are nutrient references, not a complete meal plan or intake caps.
Calories and fat remain tracked without targets unless a user adds an energy
plan later. Editing a profile preserves existing energy plans and weight history.

This update does not fix the disconnected Health Connect pregnancy flow or replace
the illustrative weekly weight band identified in the 1.1.0 audit.


## 1.2.0 weight tracking and research references

Resolves the disconnected Health Connect and endpoint-interpolated weight band
reported in the 1.1.0 audit. Pregnancy now reads through the original Android
Health Connect service into its own existing journal, preserving its backups and
manual data. Opt-in read permission, foreground startup/resume/tab sync, refresh,
last-success status, provider/settings links and disconnect are visible. History
permission is optional: recent reads still work when history access is denied.
Native coroutine errors return through the channel rather than crashing the app.

Daily imports select the latest available source timestamp in local time and
preserve manual readings/edits. Out-of-pregnancy, future, invalid and user-hidden
readings are ignored. Deleting an imported reading suppresses imports for that
date until the user restores hidden imports. Import provenance, settings, last
sync and hidden dates survive backup and restart. This is a foreground importer,
not background polling or a bidirectional replica; source deletions retain local
copies. Concurrent writes are serialized and imports merge against current data.

The globally linear endpoint band is removed. The chart reads Oxford's published
INTERGROWTH-21st weekly 10th, 50th and 90th centiles (Cheikh Ismail et al., BMJ
2016;352:i555). Exact-week values match the table; intermediate days interpolate
only adjacent published weeks. No extrapolation beyond 15–40 weeks. The reference
uses the earliest saved week 9+0–13+6 weight, first-trimester BMI 18.5–24.9 and a
singleton. Pre-pregnancy and current weights cannot stand in for this baseline.
The UI describes this as a comparison with a healthy study population, not a
normal/abnormal threshold or prescribed gain. If this comparison is unavailable,
IOM 2009 BMI-specific total gain and average second/third-trimester weekly rates
are shown where the baseline is known. No invented band is shown for other BMI
groups, multiples, unknown baseline or unsupported weeks.

Primary sources:
- https://media.tghn.org/medialibrary/2017/05/GROW_GWG-nw-ct_Table.pdf
- https://pmc.ncbi.nlm.nih.gov/articles/PMC4770850/
- https://www.nationalacademies.org/read/12584/chapter/2
- https://developer.android.com/health-and-fitness/health-connect/read-data

Validation: 79 tests passed and Dart analysis clean. The real app widget flow
covers onboarding, foreground auto-import, pregnancy-tab refresh, chart rendering,
AI food logging and combined backup restore using a fake Health Connect provider.
Physical Android Health Connect permission UI and a real scale remain unverified.


## 1.3.0 language fix

Added Spanish throughout food logging and pregnancy screens, primary-language resolution independent of region, and persisted Follow phone / Español / English choices on welcome and Settings. AI output language follows the app while protocol keys stay fixed. Open Food Facts requests Spanish product names; source food names fall back unchanged when unavailable. Existing pregnancy data and app identity are retained. 86 automated tests pass, including the real Spanish app flow, and static analysis is clean.
