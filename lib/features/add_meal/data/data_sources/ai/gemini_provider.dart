import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/ai/ai_provider.dart';
import 'package:opennutritracker/features/add_meal/data/dto/ai/ai_nutrition_dto.dart';

class GeminiProvider implements AiProvider {
  static const _baseUrl = 'generativelanguage.googleapis.com';
  static const defaultModel = 'gemini-3-flash-preview';
  static const availableModels = [
    'gemini-3-flash-preview',
    'gemini-3.1-pro-preview',
    'gemini-2.5-flash',
    'gemini-2.5-pro',
  ];
  static const _timeout = Duration(seconds: 45);

  final _log = Logger('GeminiProvider');
  final String _apiKey;
  final String _model;

  GeminiProvider(this._apiKey, {String model = defaultModel}) : _model = model;

  /// JSON Schema enforced on the Gemini response.
  static final _nutritionResponseSchema = {
    'type': 'OBJECT',
    'properties': {
      'items': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'name': {'type': 'STRING'},
            'estimated_weight_g': {'type': 'NUMBER'},
            'confidence': {
              'type': 'STRING',
              'enum': ['high', 'medium', 'low']
            },
            'per_100g': {
              'type': 'OBJECT',
              'properties': {
                'energy_kcal': {'type': 'NUMBER'},
                'protein_g': {'type': 'NUMBER'},
                'carbohydrates_g': {'type': 'NUMBER'},
                'fat_g': {'type': 'NUMBER'},
                'saturated_fat_g': {'type': 'NUMBER'},
                'sugars_g': {'type': 'NUMBER'},
                'fiber_g': {'type': 'NUMBER'},
                'sodium_mg': {'type': 'NUMBER'},
              },
              'required': [
                'energy_kcal',
                'protein_g',
                'carbohydrates_g',
                'fat_g'
              ],
            },
          },
          'required': ['name', 'estimated_weight_g', 'confidence', 'per_100g'],
        },
      },
      'source': {
        'type': 'STRING',
        'enum': ['estimation', 'label_extraction']
      },
      'meal_name': {
        'type': 'STRING',
        'nullable': true,
      },
      'clarification': {
        'type': 'OBJECT',
        'nullable': true,
        'properties': {
          'question': {'type': 'STRING'},
          'suggested_answers': {
            'type': 'ARRAY',
            'items': {'type': 'STRING'},
          },
        },
        'required': ['question'],
      },
    },
    'required': ['items', 'source'],
  };

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
    );

    final parts = <Map<String, dynamic>>[
      {'text': prompt},
    ];

    if (imageBytes.isNotEmpty) {
      final base64Image = base64Encode(imageBytes);
      parts.add({
        'inline_data': {
          'mime_type': mimeType,
          'data': base64Image,
        }
      });
    }

    final body = jsonEncode({
      'contents': [
        {'parts': parts}
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseJsonSchema': _nutritionResponseSchema,
      },
    });

    _log.fine('Sending request to Gemini API');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': _apiKey,
      },
      body: body,
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      _log.severe('Gemini API error: ${response.statusCode} ${response.body}');
      throw Exception('Gemini API error: ${response.statusCode}');
    }

    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = responseJson['candidates'] as List<dynamic>;
    final content = candidates[0]['content'] as Map<String, dynamic>;
    final responseParts = content['parts'] as List<dynamic>;
    final text = responseParts[0]['text'] as String;

    final nutritionJson = jsonDecode(text) as Map<String, dynamic>;
    return AiNutritionResponseDTO.fromJson(nutritionJson);
  }

  String _buildEstimationPrompt({String? clarificationAnswer}) {
    final context = clarificationAnswer != null
        ? '\n\nAdditional context from user: "$clarificationAnswer"'
        : '';

    return '''Analyze this food and estimate the nutritional content of each food item.
$context

Rules:
- All nutrition values must be per 100g
- estimated_weight_g is your best estimate of the portion size
- confidence is "high", "medium", or "low"
- If multiple items, return each separately
- Be accurate with portions — use visual cues like plate size, utensils, etc.
- If you cannot identify the food or need more info, return empty items with a clarification object
- If there are multiple items, set meal_name to a concise name for the overall meal (e.g. "Spaghetti Bolognese", "Chicken Caesar Salad")''';
  }

  String _buildLabelExtractionPrompt({String? clarificationAnswer}) {
    final context = clarificationAnswer != null
        ? '\n\nAdditional context from user: "$clarificationAnswer"'
        : '';

    return '''Extract the nutritional information from this nutrition label.
$context

Rules:
- All values must be normalized to per 100g
- If the label shows values per serving, use the serving size to convert
- estimated_weight_g should be the serving size from the label
- Extract all available nutrients
- If you cannot read the label clearly, return empty items with a clarification object''';
  }
}
