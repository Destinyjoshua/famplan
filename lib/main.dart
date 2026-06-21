import 'package:famplan/app.dart';
import 'package:famplan/config/supabase.dart';
import 'package:famplan/shared/widgets/bootstrap_error_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Web/release builds can use --dart-define instead of a bundled .env file.
  }

  try {
    await SupabaseConfig.initialize();
    runApp(
      const ProviderScope(
        child: FamPlanApp(),
      ),
    );
  } catch (error) {
    runApp(BootstrapErrorApp(message: error.toString()));
  }
}