import 'package:famplan/core/utils/phone_utils.dart';

const syntheticAuthEmailDomain = authEmailDomain;

final _emailPattern = RegExp(
  r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
);

bool isSyntheticAuthEmail(String? email) {
  if (email == null || email.isEmpty) return false;
  return email.toLowerCase().endsWith('@$syntheticAuthEmailDomain');
}

String? normalizeContactEmail(String input) {
  final email = input.trim().toLowerCase();
  if (email.isEmpty) return null;
  if (!_emailPattern.hasMatch(email)) return null;
  if (isSyntheticAuthEmail(email)) return null;
  return email;
}

bool isPlaceholderDisplayName(String? name) {
  if (name == null || name.trim().isEmpty) return true;

  final trimmed = name.trim();
  if (trimmed == 'Family Member') return true;
  if (normalizePhone(trimmed) != null) return true;
  if (RegExp(r'^234\d{10}$').hasMatch(trimmed)) return true;
  if (RegExp(r'^0\d{10}$').hasMatch(trimmed)) return true;
  if (trimmed.contains('@famplan.auth')) return true;

  return false;
}