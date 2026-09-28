import 'dart:typed_data';

import 'package:opennutritracker/features/add_meal/data/dto/ai/ai_nutrition_dto.dart';

/// Prompt rules shared by all providers. EU/UK labels print salt, which is
/// 2.5 Ã— sodium; the app converts it, so the model must never do it.
const aiLabelSaltRules =
    '''- EU/UK labels list "Salt" (Salz, Sel, Sale, Sal) in grams, not sodium. Copy that number into salt_g, normalized per 100g, and do not convert it.
- Set sodium_mg only if the label explicitly lists "Sodium" (Natrium). Otherwise set sodium_mg to null.
- Never put a salt value into sodium_mg.''';

const aiEstimationSaltRules =
    '''- sodium_mg is sodium (not salt) in milligrams per 100g. Set salt_g to null.''';

/// Abstract interface for AI-powered food nutrition estimation.
/// Implementations: GeminiProvider, OpenAiProvider.
abstract class AiProvider {
  /// Estimate macros from a photo of food on a plate.
  /// [imageBytes] is the raw image data (JPEG/PNG).
  /// [mimeType] is the MIME type (e.g., "image/jpeg").
  /// [clarificationAnswer] is the user's response to a previous clarification request.
  Future<AiNutritionResponseDTO> estimateFromPhoto(
    Uint8List imageBytes,
    String mimeType, {
    String? clarificationAnswer,
  });

  /// Extract exact nutrition values from a photo of a nutrition label.
  /// [imageBytes] is the raw image data (JPEG/PNG).
  /// [mimeType] is the MIME type (e.g., "image/jpeg").
  /// [clarificationAnswer] is the user's response to a previous clarification request.
  Future<AiNutritionResponseDTO> extractFromLabel(
    Uint8List imageBytes,
    String mimeType, {
    String? clarificationAnswer,
  });
}

// Only food data is requested; pregnancy profile and weight are never sent.
const aiPregnancyEstimateRules = '''
- Estimate iron_mg, calcium_mg, folate_dfe_ug, iodine_ug, choline_mg, vitamin_d_ug and vitamin_b12_ug per 100g only when reasonably supported by the identified ingredients. Otherwise return null, never a fabricated zero.
- These are uncertain food-composition estimates, not measurements or dietary advice. Do not recommend supplement doses.
- folate_dfe_ug must be dietary folate equivalents (DFE), not unconverted folic acid. If fortification or folate form is unclear return null.
- Vitamin D must be in micrograms, not IU (1 microgram = 40 IU).''';
const aiPregnancyLabelRules = '''
- For iron_mg, calcium_mg, folate_dfe_ug, iodine_ug, choline_mg, vitamin_d_ug and vitamin_b12_ug, copy only explicit amounts visible on the label, normalized per 100g. Missing or unclear values must be null. Do not infer micronutrients from ingredients or percent daily values.
- folate_dfe_ug requires an explicit DFE value. Folic acid without DFE is not interchangeable: return null.
- Convert vitamin D from IU to micrograms only if needed (divide IU by 40).''';
