import 'package:opennutritracker/core/utils/calc/sodium_calc.dart';

/// Structured response from an AI provider for food nutrition estimation or label extraction.
class AiNutritionResponseDTO {
  final List<AiNutritionItemDTO> items;
  final AiNutritionSource source;
  final AiClarificationRequest? clarification;
  final String? mealName;

  const AiNutritionResponseDTO({
    required this.items,
    required this.source,
    this.clarification,
    this.mealName,
  });

  bool get needsClarification => clarification != null;

  factory AiNutritionResponseDTO.fromJson(Map<String, dynamic> json) {
    return AiNutritionResponseDTO(
      items: (json['items'] as List<dynamic>?)
              ?.map((item) =>
                  AiNutritionItemDTO.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      source: AiNutritionSource.values.firstWhere(
        (e) =>
            e.name == json['source'] ||
            (e == AiNutritionSource.labelExtraction &&
                json['source'] == 'label_extraction'),
        orElse: () => AiNutritionSource.estimation,
      ),
      clarification: json['clarification'] != null
          ? AiClarificationRequest.fromJson(
              json['clarification'] as Map<String, dynamic>)
          : null,
      mealName: json['meal_name'] as String?,
    );
  }
}

class AiNutritionItemDTO {
  final String name;
  final double estimatedWeightG;
  final String confidence; // "high", "medium", "low"
  final AiNutrimentsPer100gDTO per100g;

  const AiNutritionItemDTO({
    required this.name,
    required this.estimatedWeightG,
    required this.confidence,
    required this.per100g,
  });

  factory AiNutritionItemDTO.fromJson(Map<String, dynamic> json) {
    return AiNutritionItemDTO(
      name: json['name'] as String,
      estimatedWeightG: (json['estimated_weight_g'] as num).toDouble(),
      confidence: json['confidence'] as String? ?? 'medium',
      per100g: AiNutrimentsPer100gDTO.fromJson(
          json['per_100g'] as Map<String, dynamic>),
    );
  }
}

class AiNutrimentsPer100gDTO {
  final double energyKcal;
  final double proteinG;
  final double carbohydratesG;
  final double fatG;
  final double? saturatedFatG;
  final double? sugarsG;
  final double? fiberG;
  final double? sodiumMg;
  final double? saltG;
  final double? caffeineMg;
  final Map<String, double> micronutrients;

  /// Sodium in mg per 100 g; labels that only list salt are converted here.
  double? get resolvedSodiumMg =>
      sodiumMg ?? (saltG != null ? SodiumCalc.saltGToSodiumMg(saltG!) : null);

  const AiNutrimentsPer100gDTO({
    required this.energyKcal,
    required this.proteinG,
    required this.carbohydratesG,
    required this.fatG,
    this.saturatedFatG,
    this.sugarsG,
    this.fiberG,
    this.sodiumMg,
    this.saltG,
    this.caffeineMg,
    this.micronutrients = const {},
  });

  factory AiNutrimentsPer100gDTO.fromJson(Map<String, dynamic> json) {
    return AiNutrimentsPer100gDTO(
      energyKcal: (json['energy_kcal'] as num).toDouble(),
      proteinG: (json['protein_g'] as num).toDouble(),
      carbohydratesG: (json['carbohydrates_g'] as num).toDouble(),
      fatG: (json['fat_g'] as num).toDouble(),
      saturatedFatG: (json['saturated_fat_g'] as num?)?.toDouble(),
      sugarsG: (json['sugars_g'] as num?)?.toDouble(),
      fiberG: (json['fiber_g'] as num?)?.toDouble(),
      sodiumMg: (json['sodium_mg'] as num?)?.toDouble(),
      saltG: (json['salt_g'] as num?)?.toDouble(),
      caffeineMg: (json['caffeine_mg'] as num?)?.toDouble(),
      micronutrients: {
        for (final key in const [
          'iron_mg',
          'calcium_mg',
          'folate_dfe_ug',
          'iodine_ug',
          'choline_mg',
          'vitamin_d_ug',
          'vitamin_b12_ug'
        ])
          if (json[key] case final num value)
            if (value.isFinite && value >= 0) key: value.toDouble(),
      },
    );
  }
}

/// When the LLM needs more info before providing a final estimate.
class AiClarificationRequest {
  final String question;
  final List<String>? suggestedAnswers;

  const AiClarificationRequest({
    required this.question,
    this.suggestedAnswers,
  });

  factory AiClarificationRequest.fromJson(Map<String, dynamic> json) {
    return AiClarificationRequest(
      question: json['question'] as String,
      suggestedAnswers: (json['suggested_answers'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }
}

enum AiNutritionSource {
  estimation, // photo of food
  labelExtraction, // photo of nutrition label
}
