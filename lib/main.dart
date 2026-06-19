import 'package:famplan/app.dart';
import 'package:famplan/config/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await SupabaseConfig.initialize();

  runApp(
    const ProviderScope(
      child: FamPlanApp(),
    ),
  );
}
