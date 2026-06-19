import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  static String get supabaseUrl => _require(
        key: 'SUPABASE_URL',
        dartDefine: 'SUPABASE_URL',
      );

  static String get supabaseAnonKey => _require(
        key: 'SUPABASE_ANON_KEY',
        dartDefine: 'SUPABASE_ANON_KEY',
      );

  static String _require({
    required String key,
    required String dartDefine,
  }) {
    final fromDefine = String.fromEnvironment(dartDefine);
    if (fromDefine.isNotEmpty) return fromDefine;

    final fromDotenv = dotenv.env[key];
    if (fromDotenv != null && fromDotenv.isNotEmpty) return fromDotenv;

    throw StateError(
      '$key is not set. Add it to .env or pass --dart-define=$dartDefine=... at build time.',
    );
  }
}