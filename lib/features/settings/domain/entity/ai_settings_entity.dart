import 'package:opennutritracker/features/add_meal/data/data_sources/ai/gemini_provider.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/ai/openai_provider.dart';

enum AiTaskType { foodEstimation, labelExtraction }

enum AiProviderType { gemini, openai }

extension AiProviderTypeX on AiProviderType {
  String get storageValue => switch (this) {
        AiProviderType.gemini => 'gemini',
        AiProviderType.openai => 'openai',
      };

  String get label => switch (this) {
        AiProviderType.gemini => 'Gemini',
        AiProviderType.openai => 'OpenAI',
      };

  List<String> get models => switch (this) {
        AiProviderType.gemini => GeminiProvider.availableModels,
        AiProviderType.openai => OpenAiProvider.availableModels,
      };

  String get defaultModel => switch (this) {
        AiProviderType.gemini => GeminiProvider.defaultModel,
        AiProviderType.openai => OpenAiProvider.defaultModel,
      };

  static AiProviderType fromStorage(String? value) {
    return switch (value) {
      'gemini' => AiProviderType.gemini,
      'openai' => AiProviderType.openai,
      _ => AiProviderType.openai,
    };
  }
}

extension AiTaskTypeX on AiTaskType {
  String get label => switch (this) {
        AiTaskType.foodEstimation => 'Food estimation',
        AiTaskType.labelExtraction => 'Label extraction',
      };

  String get description => switch (this) {
        AiTaskType.foodEstimation =>
          'Used by Magic and AI meal editing.',
        AiTaskType.labelExtraction =>
          'Used when reading nutrition labels from camera or gallery.',
      };
}

class AiTaskSettings {
  final AiProviderType provider;
  final String model;

  const AiTaskSettings({
    required this.provider,
    required this.model,
  });

  factory AiTaskSettings.defaultsFor(AiTaskType task) {
    final provider = switch (task) {
      AiTaskType.foodEstimation => AiProviderType.openai,
      AiTaskType.labelExtraction => AiProviderType.gemini,
    };
    return AiTaskSettings(
      provider: provider,
      model: provider.defaultModel,
    );
  }

  AiTaskSettings copyWith({
    AiProviderType? provider,
    String? model,
  }) {
    return AiTaskSettings(
      provider: provider ?? this.provider,
      model: model ?? this.model,
    );
  }
}

class AiSettingsSnapshot {
  final String geminiApiKey;
  final String openAiApiKey;
  final AiTaskSettings foodEstimation;
  final AiTaskSettings labelExtraction;

  const AiSettingsSnapshot({
    required this.geminiApiKey,
    required this.openAiApiKey,
    required this.foodEstimation,
    required this.labelExtraction,
  });

  bool get hasGeminiKey => geminiApiKey.trim().isNotEmpty;
  bool get hasOpenAiKey => openAiApiKey.trim().isNotEmpty;
  bool get hasAnyApiKey => hasGeminiKey || hasOpenAiKey;

  AiTaskSettings configForTask(AiTaskType task) => switch (task) {
        AiTaskType.foodEstimation => foodEstimation,
        AiTaskType.labelExtraction => labelExtraction,
      };
}
