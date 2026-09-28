import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(
      varName: 'FDC_API_KEY', obfuscate: true, defaultValue: 'DEMO_KEY')
  static final String fdcApiKey = _Env.fdcApiKey;
  @EnviedField(varName: 'SENTRY_DNS', obfuscate: true, defaultValue: '')
  static final String sentryDns = _Env.sentryDns;
  @EnviedField(
      varName: 'SUPABASE_PROJECT_URL', obfuscate: true, defaultValue: '')
  static final String supabaseProjectUrl = _Env.supabaseProjectUrl;
  @EnviedField(
      varName: 'SUPABASE_PROJECT_ANON_KEY', obfuscate: true, defaultValue: '')
  static final String supabaseProjectAnonKey = _Env.supabaseProjectAnonKey;
}
