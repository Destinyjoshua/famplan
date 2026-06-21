import 'package:famplan/core/theme/app_theme.dart';
import 'package:famplan/core/utils/responsive.dart';
import 'package:famplan/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FamPlanApp extends ConsumerWidget {
  const FamPlanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Famplans',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: isWebPlatform()
          ? const MaterialScrollBehavior().copyWith(
              scrollbars: true,
              physics: const ClampingScrollPhysics(),
            )
          : null,
      routerConfig: router,
    );
  }
}
