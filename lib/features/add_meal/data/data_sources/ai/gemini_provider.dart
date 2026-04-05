import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/ai/ai_provider.dart';
import 'package:opennutritracker/features/add_meal/data/dto/ai/ai_nutrition_dto.dart';

class GeminiProvider implements AiProvider {
  static const _baseUrl = 'generativelanguage.googleapis.com';
  static const _model = 'gemini-2.0-flash';
  static const _timeout = Duration(seconds: 30);

  final _log = Logger('GeminiProvider');
  final String _apiKey;

  GeminiProvider(this._apiKey);

  @override
  Future<AiNutritionResponseDTO> estimateFromPhoto(
    Uint8List imageBytes,
    String mimeType, {
    String? clarificationAnswer,
  }) async {
    return _sendRequest(
      imageBytes,
      mimeType,
      _buildEstimationPrompt(clarificationAnswer: clarificationAnswer),
    );
  }

  @override
  Future<AiNutritionResponseDTO> extractFromLabel(
    Uint8List imageBytes,
    String mimeType, {
    String? clarificationAnswer,
  }) async {
    return _sendRequest(
      imageBytes,
      mimeType,
      _buildLabelExtractionPrompt(clarificationAnswer: clarificationAnswer),
    );
  }

  Future<AiNutritionResponseDTO> _sendRequest(
    Uint8List imageBytes,
    String mimeType,
    String prompt,
  ) async {
    final uri = Uri.https(
      _baseUrl,
      '/v1beta/models/$_model:generateContent',
      {'key': _apiKey},
    );

    final base64Image = base64Encode(imageBytes);

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image,
              }
            },
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
      },
    });

    _log.fine('Sending request to Gemini API');

    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(_timeout);

    if (response.statusCode != 200) {
      _log.severe('Gemini API error: ${response.statusCode} ${response.body}');
      throw Exception('Gemini API error: ${response.statusCode}');
    }

    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = responseJson['candidates'] as List<dynamic>;
    final content = candidates[0]['content'] as Map<String, dynamic>;
    final parts = content['parts'] as List<dynamic>;
    final text = parts[0]['text'] as String;

    final nutritionJson = jsonDecode(text) as Map<String, dynamic>;
    return AiNutritionResponseDTO.fromJson(nutritionJson);
  }

  String _buildEstimationPrompt({String? clarificationAnswer}) {
    final clarificationContext = clarificationAnswer != null
        ? '\n\nThe user previously answered a clarification question with: "$clarificationAnswer". Use this to refine your estimate.'
        : '';

    return '''Analyze this food photo and estimate the nutritional content of each food item visible.
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
  "source": "estimation"
}

If you cannot clearly identify a food item or need more information to give an accurate estimate, instead return:
{
  "items": [],
  "source": "estimation",
  "clarification": {
    "question": "Your question here",
    "suggested_answers": ["Option A", "Option B"]
  }
}

Rules:
- All nutrition values must be per 100g
- estimated_weight_g is your best estimate of the portion size in the photo
- confidence is "high", "medium", or "low"
- Include all items visible in the photo as separate entries
- Be accurate with portions — use visual cues like plate size, utensils, etc.''';
  }

  String _buildLabelExtractionPrompt({String? clarificationAnswer}) {
    final clarificationContext = clarificationAnswer != null
        ? '\n\nThe user previously answered a clarification question with: "$clarificationAnswer". Use this to refine your extraction.'
        : '';

    return '''Extract the nutritional information from this nutrition label photo.
$clarificationContext
Return a JSON object with this exact structure:
{
  "items": [
    {
      "name": "Product name (from label if visible)",
      "estimated_weight_g": 100,
      "confidence": "high",
      "per_100g": {
        "energy_kcal": 0,
        "protein_g": 0,
        "carbohydrates_g": 0,
        "fat_g": 0,
        "saturated_fat_g": 0,
        "sugars_g": 0,
        "fiber_g": 0,
        "sodium_mg": 0
      }
    }
  ],
  "source": "label_extraction"
}

If the label shows values per serving, convert them to per 100g.
If you cannot read the label clearly, return a clarification request:
{
  "items": [],
  "source": "label_extraction",
  "clarification": {
    "question": "Your question here",
    "suggested_answers": []
  }
}

Rules:
- All values must be normalized to per 100g
- If the label shows values per serving, use the serving size to convert
- estimated_weight_g should be the serving size from the label
- Extract all available nutrients''';
  }
}
