import 'package:flutter/material.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/settings/domain/entity/ai_settings_entity.dart';
import 'package:opennutritracker/features/settings/domain/service/ai_settings_service.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  final _geminiController = TextEditingController();
  final _openAiController = TextEditingController();
  final _service = locator<AiSettingsService>();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _showGeminiKey = false;
  bool _showOpenAiKey = false;
  AiTaskSettings _foodEstimation =
      AiTaskSettings.defaultsFor(AiTaskType.foodEstimation);
  AiTaskSettings _labelExtraction =
      AiTaskSettings.defaultsFor(AiTaskType.labelExtraction);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _geminiController.dispose();
    _openAiController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final snapshot = await _service.loadSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _geminiController.text = snapshot.geminiApiKey;
      _openAiController.text = snapshot.openAiApiKey;
      _foodEstimation = snapshot.foodEstimation;
      _labelExtraction = snapshot.labelExtraction;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _service.saveSettings(
        geminiApiKey: _geminiController.text,
        openAiApiKey: _openAiController.text,
        foodEstimation: _foodEstimation,
        labelExtraction: _labelExtraction,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI settings saved')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save AI settings: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI settings'),
        actions: [
          TextButton(
            onPressed: _isLoading || _isSaving ? null : _save,
            child: Text(
              _isSaving ? 'Saving...' : 'Save',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Keys are stored securely on this device. They are not bundled into app backups.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                _buildApiKeyField(
                  label: 'OpenAI API key',
                  controller: _openAiController,
                  showValue: _showOpenAiKey,
                  onToggleVisibility: () {
                    setState(() => _showOpenAiKey = !_showOpenAiKey);
                  },
                ),
                const SizedBox(height: 12),
                _buildApiKeyField(
                  label: 'Gemini API key',
                  controller: _geminiController,
                  showValue: _showGeminiKey,
                  onToggleVisibility: () {
                    setState(() => _showGeminiKey = !_showGeminiKey);
                  },
                ),
                const SizedBox(height: 24),
                _buildTaskCard(
                  task: AiTaskType.foodEstimation,
                  settings: _foodEstimation,
                  onChanged: (updated) {
                    setState(() => _foodEstimation = updated);
                  },
                ),
                const SizedBox(height: 12),
                _buildTaskCard(
                  task: AiTaskType.labelExtraction,
                  settings: _labelExtraction,
                  onChanged: (updated) {
                    setState(() => _labelExtraction = updated);
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildApiKeyField({
    required String label,
    required TextEditingController controller,
    required bool showValue,
    required VoidCallback onToggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: !showValue,
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onToggleVisibility,
              icon: Icon(showValue ? Icons.visibility_off : Icons.visibility),
            ),
            if (controller.text.isNotEmpty)
              IconButton(
                onPressed: () {
                  controller.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.clear),
              ),
          ],
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildTaskCard({
    required AiTaskType task,
    required AiTaskSettings settings,
    required ValueChanged<AiTaskSettings> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(task.description, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            DropdownButtonFormField<AiProviderType>(
              initialValue: settings.provider,
              decoration: const InputDecoration(
                labelText: 'Provider',
                border: OutlineInputBorder(),
              ),
              items: AiProviderType.values
                  .map((provider) => DropdownMenuItem(
                        value: provider,
                        child: Text(provider.label),
                      ))
                  .toList(),
              onChanged: (provider) {
                if (provider == null) {
                  return;
                }
                onChanged(
                  settings.copyWith(
                    provider: provider,
                    model: provider.defaultModel,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('${task.name}-${settings.provider.storageValue}'),
              initialValue: settings.model,
              decoration: const InputDecoration(
                labelText: 'Model',
                border: OutlineInputBorder(),
              ),
              items: settings.provider.models
                  .map((model) => DropdownMenuItem(
                        value: model,
                        child: Text(
                          model,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (model) {
                if (model == null) {
                  return;
                }
                onChanged(settings.copyWith(model: model));
              },
            ),
          ],
        ),
      ),
    );
  }
}
