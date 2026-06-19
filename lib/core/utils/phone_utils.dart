const nigeriaCountryCode = '+234';
const authEmailDomain = 'famplan.auth';

/// Normalizes Nigerian phone numbers to E.164 (+234...).
///
/// Accepts:
/// - Local: `08012345678`
/// - International: `+2348012345678` or `2348012345678`
String? normalizePhone(String input) {
  var cleaned = input.trim().replaceAll(RegExp(r'[\s\-().]'), '');

  if (cleaned.isEmpty) return null;

  // Local Nigerian format: 08012345678
  if (cleaned.startsWith('0')) {
    if (!RegExp(r'^0\d{10}$').hasMatch(cleaned)) return null;
    cleaned = '$nigeriaCountryCode${cleaned.substring(1)}';
  }
  // 2348012345678 (without +)
  else if (cleaned.startsWith('234')) {
    if (!RegExp(r'^234\d{10}$').hasMatch(cleaned)) return null;
    cleaned = '+$cleaned';
  }
  // +2348012345678
  else if (cleaned.startsWith('+234')) {
    if (!RegExp(r'^\+234\d{10}$').hasMatch(cleaned)) return null;
  } else {
    return null;
  }

  return cleaned;
}

/// Maps a normalized phone to the internal Supabase auth email.
/// Phone provider is optional; email+password auth uses this alias.
String phoneToAuthEmail(String normalizedPhone) {
  final digits = normalizedPhone.startsWith('+')
      ? normalizedPhone.substring(1)
      : normalizedPhone;
  return '$digits@$authEmailDomain';
}

String formatPhoneHint() => '08012345678';

String formatPhoneHelper() => 'Use 080... or +234...';