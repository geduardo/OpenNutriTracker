import 'package:opennutritracker/core/presentation/widgets/app_text.dart';
import 'package:flutter/material.dart';
import '../core/presentation/main_screen.dart';
import '../core/utils/locator.dart';
import 'pregnancy_controller.dart';
import 'pregnancy_store.dart';
import 'pregnancy_profile_form.dart';
import 'pregnancy_model.dart';

/// Loads existing pregnancy journal data before opening the original food diary.
/// No fabricated user age or weight is needed to use the logging app.
class PregnancyGate extends StatefulWidget {
  const PregnancyGate({super.key});
  @override
  State<PregnancyGate> createState() => _PregnancyGateState();
}

class _PregnancyGateState extends State<PregnancyGate> {
  PregnancyController? _controller;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      if (!locator.isRegistered<PregnancyController>()) {
        final store = SecurePregnancyStore();
        locator
            .registerSingleton(PregnancyController(store, await store.read()));
      }
      if (mounted) setState(() => _controller = locator<PregnancyController>());
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _setup() async {
    final result = await Navigator.of(context).push<PregnancySetupResult>(
        MaterialPageRoute(builder: (_) => const PregnancyProfileForm()));
    if (result == null) return;
    var next = _controller!.data.withProfile(result.profile);
    if (result.firstReading != null) {
      next = next.withWeight(result.firstReading!);
    }
    try {
      await _controller!.save(next);
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: AppText('Could not save setup. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(
        context); // Rebuild non-Text labels when language changes.

    if (_failed) {
      return Scaffold(
          body: Center(
              child: FilledButton(
                  onPressed: _load,
                  child: const AppText('Retry opening saved data'))));
    }
    if (_controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_controller!.data.profile != null) return const MainScreen();
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const LanguageSetting(),
                      const Icon(Icons.restaurant_rounded, size: 64),
                      const SizedBox(height: 24),
                      AppText('Your food diary, for pregnancy',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 16),
                      const AppText(
                          'Snap a meal, describe what you ate, scan a label or reuse a saved meal. Track your food against pregnancy nutrition references and follow your weight through pregnancy.'),
                      const SizedBox(height: 16),
                      const AppText(
                          'Start at any pregnancy week. No earlier logs are required. AI uses your own provider key, configured in Settings.'),
                      const SizedBox(height: 24),
                      FilledButton(
                          onPressed: _setup,
                          child: const AppText(
                              'Set up pregnancy & start logging')),
                    ])))));
  }
}
