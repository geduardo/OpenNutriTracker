import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/ai/ai_provider.dart';
import 'package:opennutritracker/features/add_meal/data/dto/ai/ai_nutrition_dto.dart';

class OpenAiProvider implements AiProvider {
  static const _baseUrl = 'api.openai.com';
  static const _model = 'gpt-4o-mini';
  static const _timeout = Duration(seconds: 30);

  final _log = Logger('OpenAiProvider');
  final String _apiKey;

  OpenAiProvider(this._apiKey);

  @override
  Future<AiNutritionResponseDTO> estimateFromPhoto(
    Uint8List imageBytes,
    String mimeType, {
    String? clarificationAnswer,
  }) async {
    // Reuse Gemini's prompt logic — same structured output format
    final prompt = _buildPrompt(
      isLabel: false,
      clarificationAnswer: clarificationAnswer,
    );
    return _sendRequest(imageBytes, mimeType, prompt);
  }

  @override
  Future<AiNutritionResponseDTO> extractFromLabel(
    Uint8List imageBytes,
    String mimeType, {
    String? clarificationAnswer,
  }) async {
    final prompt = _buildPrompt(
      isLabel: true,
      clarificationAnswer: clarificationAnswer,
    );
    return _sendRequest(imageBytes, mimeType, prompt);
  }

  Future<AiNutritionResponseDTO> _sendRequest(
    Uint8List imageBytes,
    String mimeType,
    String prompt,
  ) async {
    final uri = Uri.https(_baseUrl, '/v1/chat/completions');
    final base64Image = base64Encode(imageBytes);

    final body = jsonEncode({
      'model': _model,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:$mimeType;base64,$base64Image',
              }
            },
          ]
        }
      ],
      'response_format': {'type': 'json_object'},
      'max_tokens': 2000,
    });

    _log.fine('Sending request to OpenAI API');

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: body,
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      _log.severe('OpenAI API error: ${response.statusCode} ${response.body}');
      throw Exception('OpenAI API error: ${response.statusCode}');
    }

    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = responseJson['choices'] as List<dynamic>;
    final message = choices[0]['message'] as Map<String, dynamic>;
    final content = message['content'] as String;

    final nutritionJson = jsonDecode(content) as Map<String, dynamic>;
    return AiNutritionResponseDTO.fromJson(nutritionJson);
  }

  // Uses the same prompt structure as Gemini for consistent output format.
  // Both providers return the same AiNutritionResponseDTO.
  String _buildPrompt({
    required bool isLabel,
    String? clarificationAnswer,
  }) {
    final clarificationContext = clarificationAnswer != null
        ? '\n\nThe user previously answered a clarification question with: "$clarificationAnswer". Use this to refine your estimate.'
        : '';

    final source = isLabel ? 'label_extraction' : 'estimation';
    final task = isLabel
        ? 'Extract the nutritional information from this nutrition label photo.'
        : 'Analyze this food photo and estimate the nutritional content of each food item visible.';
    final rules = isLabel
        ? '''- All values must be normalized to per 100g
- If the label shows values per serving, use the serving size to convert
- estimated_weight_g should be the serving size from the label
- Extract all available nutrients'''
        : '''- All nutrition values must be per 100g
- estimated_weight_g is your best estimate of the portion size in the photo
- confidence is "high", "medium", or "low"
- Include all items visible in the photo as separate entries
- Be accurate with portions — use visual cues like plate size, utensils, etc.''';

    return '''$task
$clarificationContext
Return a JSON object with this exact structure:
{
  "items": [
    {
      "name": "Food item name",
      "estimated_weight_g": 150,
      "confidence": "high",
      "per_100g": {
        "energy_kcal": 165,
        "protein_g": 31,
        "carbohydrates_g": 0,
        "fat_g": 3.6,
        "saturated_fat_g": 1.0,
        "sugars_g": 0,
        "fiber_g": 0,
        "sodium_mg": 74
      }
    }
  ],
  "source": "$source"
}

If you cannot clearly identify a food item or need more information, instead return:
{
  "items": [],
  "source": "$source",
  "clarification": {
    "question": "Your question here",
    "suggested_answers": ["Option A", "Option B"]
  }
}

Rules:
$rules''';
  }
}
