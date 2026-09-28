import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Only fully translated UI languages are offered. Region never selects a language.
Locale resolveAppLocale(List<Locale>? preferred, Iterable<Locale> supported) =>
    preferred?.isNotEmpty == true && preferred!.first.languageCode == 'es'
        ? const Locale('es')
        : const Locale('en');

class AppLanguage extends ChangeNotifier {
  static final instance = AppLanguage();
  static const storageKey = 'pregnancy_ui_language';
  final FlutterSecureStorage storage;
  String? _code;
  String? get code => _code;
  Locale? get locale => _code == null ? null : Locale(_code!);

  AppLanguage({this.storage = const FlutterSecureStorage()});

  Future<void> load() async {
    try {
      final saved = await storage.read(key: storageKey);
      _code = saved == 'es' || saved == 'en' ? saved : null;
    } catch (_) {
      _code = null; // Follow the phone if secure storage is unavailable.
    }
    notifyListeners();
  }

  Future<void> select(String? code) async {
    if (code != null && code != 'en' && code != 'es') {
      throw ArgumentError.value(code, 'code');
    }
    if (code == null) {
      await storage.delete(key: storageKey);
    } else {
      await storage.write(key: storageKey, value: code);
    }
    _code = code;
    notifyListeners();
  }
}

class AppLanguageScope extends InheritedNotifier<AppLanguage> {
  const AppLanguageScope(
      {super.key, required AppLanguage language, required super.child})
      : super(notifier: language);
  static AppLanguage of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppLanguageScope>()
          ?.notifier ??
      AppLanguage.instance;
}
