import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Breakpoint where the app switches to a sidebar management layout.
const double kDesktopBreakpoint = 900;

bool isWebPlatform() => kIsWeb;

bool useDesktopLayout(BuildContext context) {
  return MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
}

double pageMaxWidth(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1400) return 1200;
  if (width >= kDesktopBreakpoint) return width - 280;
  return width;
}