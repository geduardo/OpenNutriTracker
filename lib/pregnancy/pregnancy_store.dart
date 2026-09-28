import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'pregnancy_model.dart';

abstract class PregnancyStore {
  Future<PregnancyData> read();
  Future<void> write(PregnancyData data);
  Future<void> clear();
}

/// Separate key and app identity from the original tracker. Nothing is sent
/// to an AI provider, analytics endpoint, or backend by this feature.
class SecurePregnancyStore implements PregnancyStore {
  static const _key = 'pregnancy_journal_v1';
  final FlutterSecureStorage storage;
  SecurePregnancyStore({this.storage = const FlutterSecureStorage()});

  @override
  Future<PregnancyData> read() async {
    final raw = await storage.read(key: _key);
    return raw == null
        ? PregnancyData()
        : PregnancyData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> write(PregnancyData data) =>
      storage.write(key: _key, value: jsonEncode(data.toJson()));

  @override
  Future<void> clear() => storage.delete(key: _key);
}
