import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/utils/secure_app_storage_provider.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/ai/ai_provider.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/ai/gemini_provider.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/ai/openai_provider.dart';
import 'package:opennutritracker/features/settings/domain/entity/ai_settings_entity.dart';

class AiSettingsService {
  static const _geminiApiKeyKey = 'AiGeminiApiKey';
  static const _openAiApiKeyKey = 'AiOpenAiApiKey';

  final ConfigDataSource _configDataSource;
  final SecureAppStorageProvider _secureStorage;

  AiSettingsService(this._configDataSource, this._secureStorage);

  Future<AiSettingsSnapshot> loadSettings() async {
    final config = await _configDataSource.getConfig();
    final geminiApiKey =
        (await _secureStorage.readString(_geminiApiKeyKey)) ?? '';
    final openAiApiKey =
        (await _secureStorage.readString(_openAiApiKeyKey)) ?? '';

    return AiSettingsSnapshot(
      geminiApiKey: geminiApiKey,
      openAiApiKey: openAiApiKey,
      foodEstimation: _buildTaskSettings(
        AiTaskType.foodEstimation,
        providerValue: config.aiFoodEstimationProvider,
        modelValue: config.aiFoodEstimationModel,
      ),
      labelExtraction: _buildTaskSettings(
        AiTaskType.labelExtraction,
        providerValue: config.aiLabelExtractionProvider,
        modelValue: config.aiLabelExtractionModel,
      ),
    );
  }

  Future<void> saveSettings({
    required String geminiApiKey,
    required String openAiApiKey,
    required AiTaskSettings foodEstimation,
    required AiTaskSettings labelExtraction,
  }) async {
    await _writeSecret(_geminiApiKeyKey, geminiApiKey);
    await _writeSecret(_openAiApiKeyKey, openAiApiKey);
    await _configDataSource.setAiTaskConfig(
      foodEstimationProvider: foodEstimation.provider.storageValue,
      foodEstimationModel: _sanitizeModel(
        foodEstimation.provider,
        foodEstimation.model,
      ),
      labelExtractionProvider: labelExtraction.provider.storageValue,
      labelExtractionModel: _sanitizeModel(
        labelExtraction.provider,
        labelExtraction.model,
      ),
    );
  }

  Future<AiProvider> buildProviderForTask(AiTaskType task) async {
    final snapshot = await loadSettings();
    final preferred = snapshot.configForTask(task);
    final resolvedProvider = await _resolveProvider(preferred, snapshot);
    final apiKey = await _readApiKey(resolvedProvider.provider);
    return _buildProvider(
      resolvedProvider.provider,
      apiKey,
      resolvedProvider.model,
    );
  }

  Future<void> _writeSecret(String key, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _secureStorage.delete(key);
      return;
    }
    await _secureStorage.writeString(key, trimmed);
  }

  Future<String> _readApiKey(AiProviderType provider) async {
    return switch (provider) {
      AiProviderType.gemini =>
        (await _secureStorage.readString(_geminiApiKeyKey)) ?? '',
      AiProviderType.openai =>
        (await _secureStorage.readString(_openAiApiKeyKey)) ?? '',
    };
  }

  Future<AiTaskSettings> _resolveProvider(
    AiTaskSettings preferred,
    AiSettingsSnapshot snapshot,
  ) async {
    final preferredKey = await _readApiKey(preferred.provider);
    if (preferredKey.trim().isNotEmpty) {
      return preferred.copyWith(
        model: _sanitizeModel(preferred.provider, preferred.model),
      );
    }

    if (snapshot.hasOpenAiKey) {
      return AiTaskSettings(
        provider: AiProviderType.openai,
        model: AiProviderType.openai.defaultModel,
      );
    }
    if (snapshot.hasGeminiKey) {
      return AiTaskSettings(
        provider: AiProviderType.gemini,
        model: AiProviderType.gemini.defaultModel,
      );
    }

    throw StateError(
      'No AI API key configured. Add one in Settings > AI settings.',
    );
  }

  AiProvider _buildProvider(
    AiProviderType provider,
    String apiKey,
    String model,
  ) {
    return switch (provider) {
      AiProviderType.gemini => GeminiProvider(apiKey, model: model),
      AiProviderType.openai => OpenAiProvider(apiKey, model: model),
    };
  }

  AiTaskSettings _buildTaskSettings(
    AiTaskType task, {
    required String? providerValue,
    required String? modelValue,
  }) {
    final defaults = AiTaskSettings.defaultsFor(task);
    final provider = providerValue == null
        ? defaults.provider
        : AiProviderTypeX.fromStorage(providerValue);
    return AiTaskSettings(
      provider: provider,
      model: _sanitizeModel(provider, modelValue ?? defaults.model),
    );
  }

  String _sanitizeModel(AiProviderType provider, String? model) {
    final candidate = model?.trim() ?? '';
    if (candidate.isNotEmpty && provider.models.contains(candidate)) {
      return candidate;
    }
    return provider.defaultModel;
  }
}
