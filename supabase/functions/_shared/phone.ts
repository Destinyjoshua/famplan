const nigeriaCountryCode = '+234';

export function normalizePhone(input: string): string | null {
  let cleaned = input.trim().replace(/[\s\-().]/g, '');

  if (!cleaned) return null;

  if (cleaned.startsWith('0')) {
    if (!/^0\d{10}$/.test(cleaned)) return null;
    cleaned = `${nigeriaCountryCode}${cleaned.substring(1)}`;
  } else if (cleaned.startsWith('234')) {
    if (!/^234\d{10}$/.test(cleaned)) return null;
    cleaned = `+${cleaned}`;
  } else if (cleaned.startsWith('+234')) {
    if (!/^\+234\d{10}$/.test(cleaned)) return null;
  } else {
    return null;
  }

  return cleaned;
}

/** Termii expects 2348012345678 (no plus sign). */
export function phoneToTermiiFormat(normalizedPhone: string): string {
  return normalizedPhone.startsWith('+')
    ? normalizedPhone.substring(1)
    : normalizedPhone;
}

export function phoneToAuthEmail(normalizedPhone: string): string {
  const digits = normalizedPhone.startsWith('+')
    ? normalizedPhone.substring(1)
    : normalizedPhone;
  return `${digits}@famplan.auth`;
}