import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  static const String _supabaseUrlDefine =
      String.fromEnvironment('SUPABASE_URL');
  static const String _supabaseAnonKeyDefine =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get supabaseUrl => _require(
        key: 'SUPABASE_URL',
        fromDefine: _supabaseUrlDefine,
      );

  static String get supabaseAnonKey => _require(
        key: 'SUPABASE_ANON_KEY',
        fromDefine: _supabaseAnonKeyDefine,
      );

  static String _require({
    required String key,
    required String fromDefine,
  }) {
    if (fromDefine.isNotEmpty) return fromDefine;

    final fromDotenv = dotenv.env[key];
    if (fromDotenv != null && fromDotenv.isNotEmpty) return fromDotenv;

    throw StateError(
      '$key is not set. Add it to .env (for local dev) or pass '
      '--dart-define=$key=... when building for web.',
    );
  }
}