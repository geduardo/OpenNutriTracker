# Friction Log

Collected friction points from real usage. Each one becomes a task.

---

## 1. Unknown barcode → dead end
**Current behavior:** Scanning a barcode not in OFF/FDC shows "Error while fetching product data" and stops.
**Desired behavior:** Prompt to take a photo of the nutrition label → send to LLM → LLM extracts nutrition fields → save to local database as a new food item → proceed with logging the intake.

## 1a. Add meal entry point needs redesign
**Current behavior:** Tapping "Add to Lunch" goes straight to a search screen with 3 tabs (Products, Food, Recent).
**Desired behavior:** Show a 4-option entry screen first: Camera (AI photo), Gallery (AI photo), Search/Barcode (existing flow), Recent/Presets (frequency-sorted one-tap logging). This is the main gateway to all food logging.

## 1b. Photo source: camera OR gallery upload
**Current behavior:** (not yet implemented)
**Desired behavior:** When triggering photo-based AI flows, present choice: take photo with camera OR pick from gallery. Use `image_picker` with `ImageSource.camera` / `ImageSource.gallery`.

## 1c. Single item vs full meal choice before LLM
**Current behavior:** (not yet implemented)
**Desired behavior:** After taking/selecting a photo, ask: "Single food item" or "Full meal". This changes the LLM prompt and the result handling:
- Single item → 1 result → normal MealDetailScreen flow
- Full meal → multiple items → review list with quantities → confirm all as separate intakes

## 2. Wrong data from public database → no way to correct it
**Current behavior:** If OFF/FDC returns incorrect nutrition data for a product, you're stuck with it.
**Desired behavior:** Option to override/correct a pulled product by taking a photo of the actual label → LLM extracts the real values → saves corrected version locally. Future scans of that barcode should use the local override instead of the public database.

## 3. Recently added items don't remember my usual quantity
**Current behavior:** When re-logging a recently added item, quantity defaults to the product's default serving size, not what you last used.
**Desired behavior:** Remember the last-used quantity per food item. When re-logging, pre-fill with that quantity. Most people eat consistent portions of the same foods.

## 4. No meal presets / food groups (like MacroFactor "quick add")
**Current behavior:** Each food item must be logged individually. No way to save a combination of items as a reusable meal.
**Desired behavior:** Ability to save a group of food items + their quantities as a "meal preset" (e.g. "My usual breakfast" = oats 80g + milk 200ml + banana 120g). One tap to log the whole group. Should be editable — adjust quantities or swap items before confirming.

## 5. No sodium tracking
**Current behavior:** Only tracks macros + sugar/saturated fat/fiber. No sodium.
**Desired behavior:** Add sodium (mg) to `MealNutrimentsDBO` and display it. Both OFF and FDC APIs already provide sodium data — it's just not being pulled. The LLM label extraction should also capture it. Full micronutrient support isn't needed, but sodium is essential for health tracking.

## 6. No search debouncing — fires on every keystroke
**Current behavior:** Typing "banana" fires 6 network requests ("b", "ba", "ban"...). No debounce in `meal_search_bar.dart`.
**Desired behavior:** 300-400ms debounce. Simple fix.

## 7. Too many taps to log — forced through detail screen
**Current behavior:** Search → tap item → full detail screen with nutrients/images/disclaimers → bottom sheet for quantity → confirm. 6-7 taps minimum.
**Desired behavior:** Allow setting quantity directly from search results. Tap item → quick quantity picker → done. Detail screen should be optional (long-press or info button).

## 8. Recent items are recent-only, not frequency-based
**Current behavior:** "Recently added" shows last-used items sorted by date. No frequency tracking, no favorites.
**Desired behavior:** Sort by frequency (most-logged first). The items you eat every day should be at the top, always.

## 9. Onboarding is 6 mandatory pages — no skip
**Current behavior:** 6 full-screen pages, all mandatory, before you can use the app.
**Desired behavior:** Minimal onboarding — just ask the essentials (goal + weight maybe), let the rest be set later in profile. Get to logging ASAP.

## 10. Custom meal entry requires 9 fields
**Current behavior:** Creating a custom meal needs name, brands, quantity, serving, unit, base qty, kcal, carbs, fat, protein.
**Desired behavior:** Name + kcal is the minimum. Everything else optional. For quick "I ate ~500kcal of pasta" moments.
