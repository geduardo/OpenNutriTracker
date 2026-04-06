import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/ai/ai_provider.dart';
import 'package:opennutritracker/features/add_meal/data/dto/ai/ai_nutrition_dto.dart';

class OpenAiProvider implements AiProvider {
  static const _baseUrl = 'api.openai.com';
  static const defaultModel = 'gpt-5.4-mini';
  static const availableModels = [
    'gpt-5.4-nano',
    'gpt-5.4-mini',
    'gpt-5.4',
    'o4-mini',
    'o3',
  ];
  static const _timeout = Duration(seconds: 45);

  final _log = Logger('OpenAiProvider');
  final String _apiKey;
  final String _model;

  OpenAiProvider(this._apiKey, {String model = defaultModel}) : _model = model;

  /// JSON Schema for OpenAI structured outputs (strict mode).
  static final _nutritionResponseSchema = {
    'name': 'nutrition_response',
    'strict': true,
    'schema': {
      'type': 'object',
      'properties': {
        'items': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
              'estimated_weight_g': {'type': 'number'},
              'confidence': {
                'type': 'string',
                'enum': ['high', 'medium', 'low']
              },
              'per_100g': {
                'type': 'object',
                'properties': {
                  'energy_kcal': {'type': 'number'},
                  'protein_g': {'type': 'number'},
                  'carbohydrates_g': {'type': 'number'},
                  'fat_g': {'type': 'number'},
                  'saturated_fat_g': {'type': 'number'},
                  'sugars_g': {'type': 'number'},
                  'fiber_g': {'type': 'number'},
                  'sodium_mg': {'type': 'number'},
                },
                'required': [
                  'energy_kcal', 'protein_g', 'carbohydrates_g', 'fat_g',
                  'saturated_fat_g', 'sugars_g', 'fiber_g', 'sodium_mg'
                ],
                'additionalProperties': false,
              },
            },
            'required': [
              'name', 'estimated_weight_g', 'confidence', 'per_100g'
            ],
            'additionalProperties': false,
          },
        },
        'source': {
          'type': 'string',
          'enum': ['estimation', 'label_extraction']
        },
        'meal_name': {
          'anyOf': [
            {'type': 'string'},
            {'type': 'null'},
          ],
        },
        'clarification': {
          'anyOf': [
            {
              'type': 'object',
              'properties': {
                'question': {'type': 'string'},
                'suggested_answers': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
              },
              'required': ['question', 'suggested_answers'],
              'additionalProperties': false,
            },
            {'type': 'null'},
          ],
        },
      },
      'required': ['items', 'source', 'meal_name', 'clarification'],
      'additionalProperties': false,
    },
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
      _buildPrompt(isLabel: false, clarificationAnswer: clarificationAnswer),
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
      _buildPrompt(isLabel: true, clarificationAnswer: clarificationAnswer),
    );
  }

  Future<AiNutritionResponseDTO> _sendRequest(
    Uint8List imageBytes,
    String mimeType,
    String prompt,
  ) async {
    final uri = Uri.https(_baseUrl, '/v1/chat/completions');

    // Build message content — text always, image optional
    final contentParts = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
    ];

    if (imageBytes.isNotEmpty) {
      final base64Image = base64Encode(imageBytes);
      contentParts.add({
        'type': 'image_url',
        'image_url': {
          'url': 'data:$mimeType;base64,$base64Image',
        }
      });
    }

    final body = jsonEncode({
      'model': _model,
      'messages': [
        {
          'role': 'user',
          'content': contentParts,
        }
      ],
      'response_format': {
        'type': 'json_schema',
        'json_schema': _nutritionResponseSchema,
      },
      'max_tokens': 2000,
    });

    _log.fine('Sending request to OpenAI API');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: body,
    ).timeout(_timeout);

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

  String _buildPrompt({
    required bool isLabel,
    String? clarificationAnswer,
  }) {
    final context = clarificationAnswer != null
        ? '\n\nAdditional context from user: "$clarificationAnswer"'
        : '';

    final task = isLabel
        ? 'Extract the nutritional information from this nutrition label.'
        : 'Analyze this food and estimate the nutritional content of each food item.';

    final rules = isLabel
        ? '''- All values must be normalized to per 100g
- If the label shows values per serving, use the serving size to convert
- estimated_weight_g should be the serving size from the label
- If you cannot read the label, set clarification with your question'''
        : '''- All nutrition values must be per 100g
- estimated_weight_g is your best estimate of the portion size
- confidence is "high", "medium", or "low"
- If multiple items, return each separately
- If you cannot identify the food, set clarification with your question''';

    return '''$task
$context

Rules:
$rules''';
  }
}
