import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1?target=deno';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import {
  normalizePhone,
  phoneToAuthEmail,
  phoneToTermiiFormat,
} from '../_shared/phone.ts';

interface VerifyOtpRequest {
  phone?: string;
  pin_id?: string;
  pin?: string;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  try {
    const apiKey = Deno.env.get('TERMII_API_KEY');
    const baseUrl = Deno.env.get('TERMII_BASE_URL') ?? 'https://api.ng.termii.com';
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!apiKey || !supabaseUrl || !serviceRoleKey) {
      return jsonResponse(
        { error: 'Auth service is not configured. Contact support.' },
        500,
      );
    }

    const body = (await req.json()) as VerifyOtpRequest;
    const normalized = normalizePhone(body.phone ?? '');
    const pinId = body.pin_id?.trim();
    const pin = body.pin?.trim();

    if (!normalized || !pinId || !pin) {
      return jsonResponse({ error: 'Phone, pin id, and code are required' }, 400);
    }

    const termiiResponse = await fetch(`${baseUrl}/api/sms/otp/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        api_key: apiKey,
        pin_id: pinId,
        pin,
      }),
    });

    const termiiData = await termiiResponse.json();
    const verified =
      `${termiiData.verified}`.toLowerCase() === 'true' ||
      termiiData.verified === true;

    if (!termiiResponse.ok || !verified) {
      return jsonResponse({ error: 'Invalid or expired verification code' }, 401);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const userId = await resolveUserId(admin, normalized);
    const { data: sessionData, error: sessionError } =
      await admin.auth.admin.createSession(userId);

    if (sessionError || !sessionData.session) {
      console.error('createSession error', sessionError);
      return jsonResponse({ error: 'Could not start session' }, 500);
    }

    await admin.from('profiles').update({
      phone: normalized,
      updated_at: new Date().toISOString(),
    }).eq('id', userId);

    const session = sessionData.session;

    return jsonResponse({
      access_token: session.access_token,
      refresh_token: session.refresh_token,
      expires_in: session.expires_in,
      token_type: session.token_type,
      user: session.user,
    });
  } catch (error) {
    console.error('verify-otp error', error);
    return jsonResponse({ error: 'Could not verify code' }, 500);
  }
});

async function resolveUserId(
  admin: ReturnType<typeof createClient>,
  normalizedPhone: string,
): Promise<string> {
  const { data: profile } = await admin
    .from('profiles')
    .select('id')
    .eq('phone', normalizedPhone)
    .maybeSingle();

  if (profile?.id) {
    return profile.id;
  }

  const email = phoneToAuthEmail(normalizedPhone);

  const { data: created, error: createError } =
    await admin.auth.admin.createUser({
      email,
      email_confirm: true,
      user_metadata: {
        phone: normalizedPhone,
        display_name: normalizedPhone,
      },
    });

  if (!createError && created.user) {
    return created.user.id;
  }

  const message = createError?.message?.toLowerCase() ?? '';
  if (
    message.includes('already') ||
    message.includes('registered') ||
    message.includes('exists')
  ) {
    const { data: existing, error: lookupError } =
      await admin.auth.admin.getUserByEmail(email);

    if (lookupError || !existing.user) {
      throw lookupError ?? new Error('Existing user could not be loaded');
    }

    return existing.user.id;
  }

  throw createError ?? new Error('Could not create user');
}