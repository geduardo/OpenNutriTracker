import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/ai/ai_provider.dart';
import 'package:opennutritracker/features/add_meal/data/dto/ai/ai_nutrition_dto.dart';
import 'package:opennutritracker/features/add_meal/presentation/add_meal_type.dart';
import 'package:opennutritracker/features/add_meal/presentation/ai_result_screen.dart';

enum MagicMode { singleItem, mealBreakdown }

class MagicScreen extends StatefulWidget {
  const MagicScreen({super.key});

  @override
  State<MagicScreen> createState() => _MagicScreenState();
}

class _MagicScreenState extends State<MagicScreen> {
  final _textController = TextEditingController();
  final _imagePicker = ImagePicker();

  Uint8List? _imageBytes;
  String? _imageMimeType;
  MagicMode _mode = MagicMode.singleItem;
  bool _isLoading = false;
  String? _errorMessage;

  late AddMealType _mealType;
  late DateTime _day;

  @override
  void didChangeDependencies() {
    final args =
        ModalRoute.of(context)?.settings.arguments as MagicScreenArguments;
    _mealType = args.mealType;
    _day = args.day;
    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Magic')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image preview or placeholder
            _buildImageSection(),
            const SizedBox(height: 16),

            // Camera / Gallery buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Text input
            TextField(
              controller: _textController,
              enabled: !_isLoading,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                hintText: 'Describe your food (optional with photo)...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_note),
              ),
            ),
            const SizedBox(height: 20),

            // Single item vs Meal breakdown toggle
            SegmentedButton<MagicMode>(
              segments: const [
                ButtonSegment(
                  value: MagicMode.singleItem,
                  label: Text('Single item'),
                  icon: Icon(Icons.restaurant),
                ),
                ButtonSegment(
                  value: MagicMode.mealBreakdown,
                  label: Text('Meal breakdown'),
                  icon: Icon(Icons.list_alt),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: _isLoading
                  ? null
                  : (selection) => setState(() => _mode = selection.first),
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),

            // Submit button
            FilledButton.icon(
              onPressed: _canSubmit && !_isLoading ? _submit : null,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_isLoading ? 'Analyzing...' : 'Analyze'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    if (_imageBytes != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _imageBytes!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          IconButton(
            onPressed: _isLoading
                ? null
                : () => setState(() {
                      _imageBytes = null;
                      _imageMimeType = null;
                    }),
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }

    return Container(
      height: 150,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo,
                size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 8),
            Text('Add a photo',
                style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      ),
    );
  }

  bool get _canSubmit =>
      _imageBytes != null || _textController.text.trim().isNotEmpty;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageMimeType = picked.mimeType ?? 'image/jpeg';
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to pick image: $e');
    }
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final aiProvider = locator<AiProvider>();
      final userText = _textController.text.trim();

      // Build context string with mode instruction + user text
      final modeInstruction = _mode == MagicMode.singleItem
          ? 'Treat this as a SINGLE food item. Return exactly 1 item with combined nutrition.'
          : 'Break this down into INDIVIDUAL ingredients. Return each ingredient separately.';
      final aiContext = userText.isNotEmpty
          ? '$modeInstruction\n\nUser says: $userText'
          : modeInstruction;

      AiNutritionResponseDTO response;

      if (_imageBytes != null) {
        response = await aiProvider.estimateFromPhoto(
          _imageBytes!,
          _imageMimeType ?? 'image/jpeg',
          clarificationAnswer: aiContext,
        );
      } else {
        // Text only
        response = await aiProvider.estimateFromPhoto(
          Uint8List(0),
          'text/plain',
          clarificationAnswer: aiContext,
        );
      }

      if (!mounted) return;

      if (response.needsClarification) {
        // Show clarification dialog and re-submit
        final answer = await _showClarificationDialog(response.clarification!);
        if (answer != null && mounted) {
          _textController.text = answer;
          await _submit();
          return;
        }
      } else if (response.items.isNotEmpty) {
        Navigator.of(context).pushNamed(
          NavigationOptions.aiResultRoute,
          arguments: AiResultScreenArguments(
            response: response,
            mealType: _mealType,
            day: _day,
            mode: _mode,
          ),
        );
      } else {
        setState(() => _errorMessage = 'Could not identify any food items.');
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _errorMessage = 'Request timed out. Check your internet connection.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().contains('SocketException') || e.toString().contains('HandshakeException')
            ? 'No internet connection.'
            : 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _showClarificationDialog(
      AiClarificationRequest clarification) {
    return showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Quick question'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(clarification.question),
              if (clarification.suggestedAnswers != null &&
                  clarification.suggestedAnswers!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: clarification.suggestedAnswers!
                      .map((answer) => ActionChip(
                            label: Text(answer),
                            onPressed: () => Navigator.of(context).pop(answer),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Or type your answer...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }
}

class MagicScreenArguments {
  final DateTime day;
  final AddMealType mealType;

  MagicScreenArguments(this.day, this.mealType);
}
