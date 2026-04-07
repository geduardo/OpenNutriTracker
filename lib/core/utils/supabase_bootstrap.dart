import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:opennutritracker/core/utils/env.dart';

class SupabaseBootstrap {
  static SupabaseClient? _client;
  static Future<SupabaseClient>? _pendingInitialization;

  static Future<SupabaseClient> getClient() async {
    final existing = _client;
    if (existing != null) {
      return existing;
    }

    final pending = _pendingInitialization;
    if (pending != null) {
      return pending;
    }

    _pendingInitialization = _initialize();
    return _pendingInitialization!;
  }

  static Future<SupabaseClient> _initialize() async {
    await Supabase.initialize(
      url: Env.supabaseProjectUrl,
      anonKey: Env.supabaseProjectAnonKey,
    );
    final client = Supabase.instance.client;
    _client = client;
    return client;
  }
}
