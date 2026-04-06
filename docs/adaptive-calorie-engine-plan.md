# Adaptive Calorie Engine Plan

This document is a handoff for implementing a MacroFactor-style adaptive calorie target system in OpenNutriTracker.

It focuses on calorie estimation and control, not full feature parity.

For the control-theory framing behind this plan, see [adaptive-calorie-control-theory.md](./adaptive-calorie-control-theory.md).

The target behavior is:

1. Use logged nutrition plus smoothed body weight to estimate energy expenditure.
2. Update calorie recommendations weekly, not continuously.
3. Smooth changes so the app does not overreact to water weight noise, missed logs, or short stalls.
4. Preserve a manual fallback path while the adaptive engine matures.

This is intentionally not a reverse-engineering attempt of MacroFactor's private implementation. It is a pragmatic, explicit design based on their publicly described product behavior and adapted to this repo.

## Design Summary

Treat the app as a closed-loop controller:

- Input signals:
  - daily calorie intake
  - body weight entries
  - user goal and target rate
  - day quality flags
- State estimation:
  - smoothed trend weight
  - estimated expenditure
  - estimation confidence / status
- Controller:
  - compute proposed next-week calorie target from estimated expenditure and desired rate of change
  - apply smoothing and limits before publishing the new target
- Output:
  - daily calorie goal
  - macro goals derived from calorie goal and macro program
  - weekly check-in recommendation

## Current Repo Constraints

The current app uses:

- static TDEE from [lib/core/utils/calc/tdee_calc.dart](../lib/core/utils/calc/tdee_calc.dart)
- fixed lose / maintain / gain offsets in [lib/core/utils/calc/calorie_goal_calc.dart](../lib/core/utils/calc/calorie_goal_calc.dart)
- fixed macro percentages in [lib/core/utils/calc/macro_calc.dart](../lib/core/utils/calc/macro_calc.dart)
- a single current weight on [lib/core/domain/entity/user_entity.dart](../lib/core/domain/entity/user_entity.dart)
- day aggregates in [lib/core/data/dbo/tracked_day_dbo.dart](../lib/core/data/dbo/tracked_day_dbo.dart)
- DI in [lib/core/utils/locator.dart](../lib/core/utils/locator.dart)
- schema migration entrypoint in [lib/core/utils/migration_runner.dart](../lib/core/utils/migration_runner.dart)

The current code does not have:

- weight history
- trend-weight smoothing
- day quality states for partial logging
- expenditure history
- weekly strategy/check-in logic
- a strategy feature area

## Recommended Scope

Implement the calorie engine in five pieces:

1. Weight history and trend estimator
2. Logging quality states
3. Adaptive expenditure estimator
4. Weekly calorie controller
5. Strategy integration and check-in flow

These correspond to canvas tasks `AS-01` through `AS-05`.

## Product Rules

These rules are the intended product behavior:

1. Static TDEE is only a startup seed and manual fallback.
2. The adaptive system is driven by intake plus body weight, not wearable calorie burn.
3. Partial logging must never be treated as a trustworthy intake day.
4. The controller updates weekly and should be directionally correct, not aggressively reactive.
5. The controller should not "catch up" for prior weeks. Each week is treated as a new control step.
6. Missing data should move the estimator into `holding`, not produce confident targets from poor inputs.

## Proposed Data Model

### 1. Weight Entry

Create a new dated weight model.

Suggested files:

- `lib/features/strategy/data/dbo/weight_entry_dbo.dart`
- `lib/features/strategy/domain/entity/weight_entry_entity.dart`
- `lib/features/strategy/data/data_source/weight_entry_data_source.dart`
- `lib/features/strategy/data/repository/weight_entry_repository.dart`

Suggested fields:

```dart
class WeightEntryDBO {
  DateTime day;
  double weightKg;
  String? note;
  WeightEntrySourceDBO source; // manual, migratedProfileWeight
}
```

Notes:

- Keep `UserEntity.weightKG` for compatibility in profile and onboarding.
- Treat it as the latest known scale weight, not the full source of truth for the estimator.
- On migration, create one `WeightEntry` from the current user weight if no history exists.

### 2. Day Log Quality

Add an explicit day quality flag.

Suggested enum:

```dart
enum DayLogQuality {
  complete,
  partial,
  unlogged,
  fasted,
}
```

Add to `TrackedDayDBO`:

```dart
DayLogQualityDBO logQuality;
bool manuallyMarked;
```

Semantics:

- `complete`: intake is trusted
- `partial`: intake exists but is known incomplete; do not use for estimation
- `unlogged`: not enough information; do not use for estimation
- `fasted`: trusted zero or near-zero intake; can be used for estimation

### 3. Expenditure State

Create a persistent daily or weekly expenditure state.

Suggested files:

- `lib/features/strategy/data/dbo/expenditure_state_dbo.dart`
- `lib/features/strategy/domain/entity/expenditure_state_entity.dart`
- `lib/features/strategy/data/data_source/expenditure_state_data_source.dart`
- `lib/features/strategy/data/repository/expenditure_state_repository.dart`

Suggested fields:

```dart
enum ExpenditureStatus {
  seeded,
  holding,
  updating,
}

class ExpenditureStateDBO {
  DateTime day;
  double estimatedExpenditureKcal;
  double rawExpenditureKcal;
  double confidence; // 0..1
  ExpenditureStatusDBO status;
  int validNutritionDays;
  int recentWeighInCount;
}
```

### 4. Goal Strategy

Create a strategy model instead of only lose / maintain / gain.

Suggested fields:

```dart
enum StrategyGoalMode {
  lose,
  maintain,
  gain,
}

enum MacroProgramStyle {
  balanced,
  highCarbLowFat,
  lowCarbHighFat,
  manual,
}

class GoalStrategyDBO {
  StrategyGoalMode mode;
  double? targetWeightKg; // required for maintain and optional for lose/gain
  double targetRatePctPerWeek; // e.g. 0.5 means 0.5% BW / week
  MacroProgramStyleDBO macroStyle;
  bool adaptiveEnabled;
}
```

### 5. Check-In Record

Persist the weekly recommendation and whether the user accepted it.

Suggested fields:

```dart
class CheckInRecordDBO {
  DateTime weekStart;
  double previousCalorieTarget;
  double proposedCalorieTarget;
  double appliedCalorieTarget;
  bool dismissed;
  double expenditureAtCheckIn;
  double trendWeightAtCheckIn;
  double confidenceAtCheckIn;
}
```

## Recommended Algorithms

## 1. Trend Weight

Use a daily trend-weight series.

### Why

Scale weight is noisy. Daily water shifts can easily mask or exaggerate tissue change for several days.

### Recommended implementation

1. Build a daily series from weigh-ins.
2. For dates between two actual weigh-ins, linearly interpolate scale weight.
3. For dates after the latest weigh-in, carry the last weigh-in forward for up to 7 days.
4. If the latest weigh-in is older than 7 days, estimator confidence should degrade and can enter `holding`.
5. Run an EMA over the daily scale-weight series.

### Formula

Use EMA with half-life of 7 days:

```text
alpha = 1 - exp(-ln(2) / halfLifeDays)
trend[d] = alpha * scale[d] + (1 - alpha) * trend[d - 1]
halfLifeDays = 7
```

Initialization:

```text
trend[firstDay] = scale[firstDay]
```

This is simple, stable, and good enough for MVP.

## 2. Intake Validity

Valid nutrition days for the estimator:

- `complete`
- `fasted`

Invalid nutrition days:

- `partial`
- `unlogged`

### Startup heuristic

Until UI exists for manual marking:

- existing tracked days with calories logged can default to `complete`
- missing tracked days are `unlogged`
- add UI later to change a day to `partial`

### Important rule

Never interpret a partially logged day as a low-calorie day. It is unknown input, not negative evidence about expenditure.

## 3. Expenditure Estimator

This is the core calorie-estimation algorithm.

### Model

Use energy balance over a rolling window:

```text
expenditure ~= intake - change_in_body_energy
```

Where:

```text
change_in_body_energy_per_day ~= 7700 * deltaTrendWeightKg / deltaDays
rawExpenditure ~= avgIntakeKcalPerDay - change_in_body_energy_per_day
```

Sign behavior:

- if trend weight is dropping, `deltaTrendWeightKg < 0`
- then `change_in_body_energy_per_day < 0`
- so expenditure becomes greater than intake, which is correct

### Reference implementation

Use the most recent 21-day lookback window.

Parameters:

- `windowDays = 21`
- `minValidNutritionDays = 14`
- `idealValidNutritionDays = 21`
- `minRecentWeighIns = 1`
- `idealRecentWeighIns = 3`

Suggested process:

1. Take the last 21 calendar days.
2. Count valid intake days.
3. Count weigh-ins in the last 7 days.
4. If valid intake days < 14, set status to `holding`.
5. If weigh-ins in last 7 days == 0, set status to `holding`.
6. Otherwise:
   - compute `avgIntakeKcalPerDay` using only valid intake days
   - compute `deltaTrendWeightKg = trend[today] - trend[today - 21]`
   - compute `rawExpenditure`
   - smooth `rawExpenditure` into `estimatedExpenditure`

### Expenditure smoothing

Add a second EMA so the estimate itself does not jerk around:

```text
estimatedExp[d] =
  beta * rawExp[d] + (1 - beta) * estimatedExp[d - 1]
```

Recommended half-life:

```text
beta = 1 - exp(-ln(2) / 14)
```

This creates a slower expenditure signal than raw weight change.

### Seed behavior

Before the estimator has enough data:

- seed `estimatedExpenditure` with the current IOM TDEE result
- status = `seeded`
- after one week of enough data, move to `updating`

Do not remove the old TDEE calculator immediately. Reuse it as:

- onboarding estimate
- migration seed
- fallback when adaptive mode is disabled

### Confidence score

Use confidence to control both UI messaging and weekly adjustment size.

Suggested formula:

```text
nutritionConfidence = clamp(validNutritionDays / 21, 0, 1)
weightConfidence = clamp(recentWeighInCount / 3, 0, 1)
confidence = 0.65 * nutritionConfidence + 0.35 * weightConfidence
```

Recommended statuses:

- `seeded`: not enough data yet, using startup prior
- `holding`: insufficient recent valid data to safely update
- `updating`: enough valid data to update normally

## 4. Weekly Calorie Controller

The controller turns estimated expenditure into a recommendation.

### Goal rates

Use target rate as percent of body weight per week:

- weight loss: `0.25%` to `1.0%` / week
- weight gain: `0.1%` to `0.5%` / week
- maintenance: `0%`, plus maintenance-band nudges

### Energy balance target

Given current trend weight:

```text
targetDeltaKgPerWeek = trendWeightKg * targetRatePctPerWeek / 100
targetEnergyBalancePerDay = 7700 * targetDeltaKgPerWeek / 7
```

Apply sign by mode:

- lose: negative
- gain: positive
- maintain: normally zero

### Maintenance mode

For maintain, use a target band instead of demanding exact zero drift.

Recommended band:

```text
maintenanceBandKg = 0.68
```

Behavior:

- if trend weight is within `targetWeightKg +/- 0.68`, target balance = `0`
- if above band, use small loss rate `0.15% / week`
- if below band, use small gain rate `0.15% / week`

### Proposed target

```text
proposedCalories = estimatedExpenditure + targetEnergyBalancePerDay
```

### Controller smoothing

Do not apply the full delta immediately.

Use:

```text
delta = proposedCalories - previousCalorieTarget
maxWeeklyStep = lerp(75, 150, confidence)
appliedDelta = clamp(delta, -maxWeeklyStep, maxWeeklyStep)
newCalorieTarget = previousCalorieTarget + appliedDelta
```

Recommended constraints:

- low confidence: cap at `75 kcal/week`
- high confidence: cap at `150 kcal/week`

This is the practical "intelligent smoothing" layer.

### No catch-up logic

Do not increase deficit or surplus because the user is behind plan over prior weeks.

The controller should answer only:

"Given the latest expenditure estimate, what should next week's intake be to target this week's desired rate?"

## 5. Macro Allocation

Calories should be determined first. Macros should be derived second.

Do not continue treating macro percentages as the primary calorie driver in adaptive mode.

### Recommended order

1. Set calorie target from controller.
2. Set protein floor from current body weight and training profile.
3. Set fat floor.
4. Allocate remaining calories according to macro style.

### MVP macro rules

To avoid blocking the calorie engine, start with a simpler rule set:

#### Protein

```text
proteinG = clamp(1.6 * bodyWeightKg, min=110, max=220)
```

This is intentionally simple. Replace later with lean-mass/body-composition logic if desired.

#### Fat

```text
fatG = max(0.6 * bodyWeightKg, calorieTarget * 0.20 / 9)
```

#### Carbs

```text
remainingCalories = calorieTarget - (proteinG * 4 + fatG * 9)
carbsG = max(remainingCalories / 4, 0)
```

#### Macro styles

Adjust only the carb/fat split of remaining calories:

- `balanced`: 50/50 split of remaining calories
- `highCarbLowFat`: 70/30 carbs/fat
- `lowCarbHighFat`: 30/70 carbs/fat
- `manual`: preserve current user percentages

If fat would drop below the floor, hold fat and take the reduction from carbs.

## Implementation Plan by Repo Layer

## A. Persistence

Update:

- [lib/core/utils/hive_db_provider.dart](../lib/core/utils/hive_db_provider.dart)
- [lib/core/utils/migration_runner.dart](../lib/core/utils/migration_runner.dart)
- [lib/features/settings/domain/usecase/export_data_usecase.dart](../lib/features/settings/domain/usecase/export_data_usecase.dart)
- [lib/features/settings/domain/usecase/import_data_usecase.dart](../lib/features/settings/domain/usecase/import_data_usecase.dart)

Add new boxes:

- `WeightEntryBox`
- `ExpenditureStateBox`
- `GoalStrategyBox`
- `CheckInRecordBox`

Migration target:

1. bump schema version
2. create new boxes / adapters
3. migrate current `UserEntity.weightKG` into a single `WeightEntry`
4. default adaptive mode to disabled for existing users
5. default tracked days with logged calories to `complete`

## B. Domain Services

Create a new feature area:

- `lib/features/strategy/domain/service/trend_weight_service.dart`
- `lib/features/strategy/domain/service/expenditure_estimator_service.dart`
- `lib/features/strategy/domain/service/weekly_calorie_controller.dart`
- `lib/features/strategy/domain/service/macro_program_service.dart`

These should be pure business-logic services with unit tests.

## C. Use Cases

Add:

- `GetStrategyStateUsecase`
- `RecomputeExpenditureUsecase`
- `RunWeeklyCheckInUsecase`
- `GetAdaptiveCalorieGoalUsecase`
- `GetAdaptiveMacroGoalUsecase`
- `AddWeightEntryUsecase`

Then refactor current:

- [lib/core/domain/usecase/get_kcal_goal_usecase.dart](../lib/core/domain/usecase/get_kcal_goal_usecase.dart)
- [lib/core/domain/usecase/get_macro_goal_usecase.dart](../lib/core/domain/usecase/get_macro_goal_usecase.dart)

Recommended behavior:

- if adaptive strategy enabled and estimator has a usable target, return adaptive goal
- otherwise fall back to current static logic

## D. Existing Integration Points

Places currently creating or updating tracked-day goals:

- [lib/features/home/presentation/bloc/home_bloc.dart](../lib/features/home/presentation/bloc/home_bloc.dart)
- [lib/features/profile/presentation/bloc/profile_bloc.dart](../lib/features/profile/presentation/bloc/profile_bloc.dart)
- [lib/features/settings/presentation/bloc/settings_bloc.dart](../lib/features/settings/presentation/bloc/settings_bloc.dart)
- add-meal flows that call `GetKcalGoalUsecase`

Goal:

- these callers should not know whether the goal is static or adaptive
- keep the branch inside the use case layer

## E. UI

Minimum viable UI:

1. Weight history entry screen
2. Day-quality edit action on diary day
3. Strategy screen with:
   - estimated expenditure
   - trend weight
   - estimator status
   - current target calories
   - next check-in summary
4. Weekly check-in sheet:
   - previous target
   - proposed target
   - reason for change
   - accept / dismiss

Do not block the math layer on UI completeness. Build the engine first.

## State Machine

Suggested estimator state transitions:

```text
seeded -> updating
  when valid intake and weight thresholds are met

seeded -> holding
  when startup seed exists but data quality remains too poor

updating -> holding
  when recent nutrition coverage or weigh-ins fall below thresholds

holding -> updating
  when data quality recovers
```

Suggested check-in state transitions:

```text
no_checkin -> proposed
proposed -> accepted
proposed -> dismissed
accepted -> next week's no_checkin
dismissed -> next week's no_checkin
```

## Recommended Thresholds

Use these defaults unless product testing suggests otherwise:

```text
trend EMA half-life: 7 days
expenditure EMA half-life: 14 days
expenditure lookback window: 21 days
minimum valid intake days to update: 14 of 21
minimum weigh-ins in last 7 days: 1
ideal weigh-ins in last 7 days: 3
maintenance band: +/- 0.68 kg
maintenance nudge rate: 0.15% body weight / week
weekly calorie adjustment cap: 75 to 150 kcal depending on confidence
body energy constant: 7700 kcal / kg
```

These are implementation choices, not scientifically perfect truths. Consistency and robustness matter more than false precision.

## Pseudocode

## Daily recompute

```text
for each day d:
  scaleSeries[d] = interpolatedScaleWeight(d)
  trendWeight[d] = ema(scaleSeries[d], trendWeight[d - 1], alphaTrend)

  validDays = last 21 days where logQuality in {complete, fasted}
  recentWeighIns = count(weight entries in last 7 days)

  if validDays.count < 14 or recentWeighIns == 0:
    status[d] = holding if prior state exists else seeded
    estimatedExp[d] = estimatedExp[d - 1] or seedTdee
    continue

  avgIntake = mean(intakeKcal on validDays)
  deltaTrendKg = trendWeight[d] - trendWeight[d - 21]
  bodyEnergyPerDay = 7700 * deltaTrendKg / 21
  rawExp[d] = avgIntake - bodyEnergyPerDay
  estimatedExp[d] = ema(rawExp[d], estimatedExp[d - 1], alphaExp)
  confidence[d] = score(validDays.count, recentWeighIns)
  status[d] = updating
```

## Weekly check-in

```text
trendWeight = latest trend weight
estimatedExp = latest estimated expenditure
previousTarget = current calorie target

if goalMode == maintain:
  targetRate = 0 or +/-0.15 depending on target band breach
else:
  targetRate = configured target rate

targetDeltaKgWeek = trendWeight * targetRate / 100
targetEnergyBalance = 7700 * targetDeltaKgWeek / 7
if goalMode == lose:
  targetEnergyBalance = -abs(targetEnergyBalance)
if goalMode == gain:
  targetEnergyBalance = abs(targetEnergyBalance)

proposedTarget = estimatedExp + targetEnergyBalance
maxStep = interpolate(confidence, 75, 150)
appliedTarget = previousTarget + clamp(proposedTarget - previousTarget, -maxStep, maxStep)

store check-in recommendation
```

## Testing Plan

Add unit tests before broad UI work.

### Trend weight tests

- interpolates between weigh-ins correctly
- carries last weigh-in for short gaps
- confidence degrades after long gap
- EMA smooths noisy daily weights

### Expenditure estimator tests

- stable maintenance with flat trend returns expenditure near intake
- losing weight returns expenditure above intake
- gaining weight returns expenditure below intake
- partial days are excluded
- insufficient data returns `holding`
- startup returns `seeded`

### Controller tests

- maintenance inside band gives near-zero energy balance
- maintenance outside band adds small nudge
- no catch-up behavior
- weekly step cap prevents overreaction
- higher confidence allows larger changes

### Integration tests

- adaptive use case overrides static goal when enabled
- static fallback remains unchanged when disabled
- weight migration creates initial weight history
- export/import preserves new strategy data

## Suggested File Layout

```text
lib/
  features/
    strategy/
      data/
        data_source/
        dbo/
        repository/
      domain/
        entity/
        service/
        usecase/
      presentation/
        bloc/
        pages/
        widgets/
```

## Recommended Delivery Order

1. Add persistence models and migration.
2. Add `WeightEntry` history and trend service.
3. Add `DayLogQuality` to tracked days.
4. Add expenditure estimator and tests.
5. Add weekly controller and tests.
6. Refactor calorie goal use case to branch between static and adaptive.
7. Add minimal Strategy UI and check-in sheet.
8. Add macro-program refinement.

## Non-Goals for First Implementation

Do not try to ship all of these in the first pass:

- exact MacroFactor parity
- wearable integration
- advanced body composition logic
- advanced lean-mass estimation
- complicated coaching modules
- retroactive recalculation of every historical target in the UI

## Source Notes

Research date: 2026-04-06

Primary references used for behavior and constraints:

- Expenditure: <https://help.macrofactorapp.com/en/articles/20-expenditure>
- Dashboard and trend-weight behavior: <https://help.macrofactorapp.com/en/articles/22-get-to-know-your-dashboard>
- Weekly adjustments and smoothing: <https://help.macrofactorapp.com/en/articles/222-how-does-macrofactor-make-adjustments-for-a-weight-gain-or-weight-loss-goal>
- Partial logging behavior: <https://help.macrofactorapp.com/en/articles/241-what-is-partial-logging>
- Dynamic maintenance behavior: <https://help.macrofactorapp.com/en/articles/125-how-does-dynamic-maintenance-work-in-macrofactor>

The exact proprietary internals are not public. This document specifies an explicit implementation that matches the public product philosophy closely enough to build an open-source equivalent.
