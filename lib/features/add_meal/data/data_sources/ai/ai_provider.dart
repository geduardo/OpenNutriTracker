import 'dart:typed_data';

import 'package:opennutritracker/features/add_meal/data/dto/ai/ai_nutrition_dto.dart';

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
