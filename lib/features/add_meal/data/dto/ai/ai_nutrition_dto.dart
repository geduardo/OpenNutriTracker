/// Structured response from an AI provider for food nutrition estimation or label extraction.
class AiNutritionResponseDTO {
  final List<AiNutritionItemDTO> items;
  final AiNutritionSource source;
  final AiClarificationRequest? clarification;

  const AiNutritionResponseDTO({
    required this.items,
    required this.source,
    this.clarification,
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
        (e) => e.name == json['source'],
        orElse: () => AiNutritionSource.estimation,
      ),
      clarification: json['clarification'] != null
          ? AiClarificationRequest.fromJson(
              json['clarification'] as Map<String, dynamic>)
          : null,
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

  const AiNutrimentsPer100gDTO({
    required this.energyKcal,
    required this.proteinG,
    required this.carbohydratesG,
    required this.fatG,
    this.saturatedFatG,
    this.sugarsG,
    this.fiberG,
    this.sodiumMg,
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
