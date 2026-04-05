# Useful Information for the Refactor

## Architecture Overview

The app follows **clean architecture** with Flutter BLoC for state management, **Hive** (encrypted NoSQL) for local storage, and **GetIt** for dependency injection. Each feature module follows a `data/domain/presentation` pattern.

---

## Data Models & Storage

### Food Items (`lib/core/data/dbo/meal_dbo.dart`)
Each food item (`MealDBO`, Hive Type ID: 1) stores:
- **Identity**: `code`, `name`, `brands`, image URLs, source URL
- **Portions**: `mealQuantity`, `mealUnit`, `servingQuantity`, `servingUnit`, `servingSize`
- **Source**: enum `MealSourceDBO` (Type ID: 14) — `off` (Open Food Facts), `fdc` (USDA), `custom` (user-created)
- **Nutriments**: embedded `MealNutrimentsDBO` object

### Nutrition Values (`lib/core/data/dbo/meal_nutriments_dbo.dart`, Type ID: 3)
All values stored as **doubles, per 100g/100ml**:
- `energyKcal100` (kcal)
- `carbohydrates100`, `fat100`, `proteins100` (grams)
- `sugars100`, `saturatedFat100`, `fiber100` (grams)

**No micronutrients are tracked** — only macros + sugar/sat fat/fiber.

### Food Log Entries (`lib/core/data/dbo/intake_dbo.dart`, Type ID: 0)
Each logged food (`IntakeDBO`) stores:
- `id` — UUID
- `meal` — full `MealDBO` reference (embedded, not relational)
- `amount` — quantity consumed (double)
- `unit` — g, ml, etc.
- `type` — `IntakeTypeDBO` enum (Type ID: 4): `breakfast`, `lunch`, `dinner`, `snack`
- `dateTime` — when consumed

**Calorie calculation**: `amount × (energyKcal100 / 100)` — same pattern for all macros.

### Daily Summaries (`lib/core/data/dbo/tracked_day_dbo.dart`, Type ID: 9)
Keyed by date, each `TrackedDayDBO` aggregates:
- `caloriesTracked` / `calorieGoal`
- `carbsTracked` / `carbsGoal`
- `fatTracked` / `fatGoal`
- `proteinTracked` / `proteinGoal`

### User Profile (`lib/core/data/dbo/user_dbo.dart`, Type ID: 5)
- `birthday`, `heightCM`, `weightKG`
- `gender` (male/female), `goal` (lose/maintain/gain), `pal` (activity level)

### Config (`lib/core/data/dbo/config_dbo.dart`, Type ID: 13)
- Disclaimer/policy flags, theme, imperial/metric toggle
- `userKcalAdjustment`, macro goal percentages (`userCarbGoalPct`, `userProteinGoalPct`, `userFatGoalPct`)

---

## Hive Type ID Registry

| Type | ID | File |
|------|----|------|
| IntakeDBO | 0 | intake_dbo.dart |
| MealDBO | 1 | meal_dbo.dart |
| MealNutrimentsDBO | 3 | meal_nutriments_dbo.dart |
| IntakeTypeDBO | 4 | intake_type_dbo.dart |
| UserDBO | 5 | user_dbo.dart |
| UserGenderDBO | 6 | user_gender_dbo.dart |
| UserWeightGoalDBO | 7 | user_weight_goal_dbo.dart |
| UserPALDBO | 8 | user_pal_dbo.dart |
| TrackedDayDBO | 9 | tracked_day_dbo.dart |
| PhysicalActivityDBO | 11 | physical_activity_dbo.dart |
| PhysicalActivityTypeDBO | 12 | physical_activity_dbo.dart |
| ConfigDBO | 13 | config_dbo.dart |
| MealSourceDBO | 14 | meal_dbo.dart |

---

## Food Data Sources

| Source | API | Use |
|--------|-----|-----|
| Open Food Facts | `world.openfoodfacts.org/api/v0/` | Text search + barcode lookup |
| USDA FDC | `api.nal.usda.gov/fdc/v1/` | Text search (needs API key) |
| Supabase-cached FDC | Custom Supabase backend | Localized FDC search |

Barcode scanning via `mobile_scanner` feeds into the OFF barcode API.

### Key data source files
- OFF: `lib/features/add_meal/data/data_sources/off_data_source.dart`
- FDC: `lib/features/add_meal/data/data_sources/fdc_data_source.dart`
- Supabase FDC: `lib/features/add_meal/data/data_sources/sp_fdc_data_source.dart`
- Products repo (orchestrates all): `lib/features/add_meal/data/repository/products_repository.dart`

---

## Dependency Injection (GetIt)

All wired in `lib/core/utils/locator.dart`:
- Singleton BLoCs: OnboardingBloc, HomeBloc, DiaryBloc, ProfileBloc, SettingsBloc
- Factory BLoCs: ProductsBloc, FoodBloc, ScannerBloc (per-screen)
- Repositories, use cases, data sources all registered as lazy singletons

---

## Key Integration Points for VLLM Feature

1. **No micronutrient support** — extending requires changes to `MealNutrimentsDBO`, its entity, and all DTOs.
2. **Per-100g format** — VLLM responses must output nutrition per 100g to fit the existing calculation pipeline.
3. **`MealSource` enum is extensible** — add `vllm` or `ai` alongside `off`/`fdc`/`custom`.
4. **Simplest integration path**: VLLM estimates nutrition → create `MealEntity` with new AI source → feed into existing intake flow.
5. **Hive embeds full meal objects** in each intake — no foreign keys, data is self-contained per log entry.

---

## Key Dependencies (pubspec.yaml)

- **State**: `flutter_bloc: ^8.1.6`, `provider: ^6.1.2`
- **DI**: `get_it: ^8.0.3`
- **DB**: `hive: ^2.2.3`, `hive_flutter: ^1.1.0`
- **HTTP**: `http: ^1.2.2`
- **Backend**: `supabase_flutter: ^2.8.2`
- **Scanner**: `mobile_scanner: ^6.0.2`
- **Env secrets**: `envied: ^1.0.0`
- **Security**: `flutter_secure_storage: ^9.2.2`
- **Monitoring**: `sentry_flutter: ^8.14.2`
