import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1?target=deno';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import {
  normalizePhone,
  phoneToAuthEmail,
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
    const apiKey = Deno.env.get('TERMII_API_KEY')?.trim();
    const baseUrl =
      Deno.env.get('TERMII_BASE_URL')?.trim() ?? 'https://api.ng.termii.com';
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

    const email = phoneToAuthEmail(normalized);
    await ensureAuthUser(admin, normalized, email);

    const session = await createSessionForEmail(admin, email);
    const userId = session.user?.id;

    if (!userId) {
      return jsonResponse({ error: 'Could not start session' }, 500);
    }

    await admin.from('profiles').update({
      phone: normalized,
      updated_at: new Date().toISOString(),
    }).eq('id', userId);

    return jsonResponse({
      access_token: session.access_token,
      refresh_token: session.refresh_token,
      expires_in: session.expires_in,
      token_type: session.token_type,
      user: session.user,
    });
  } catch (error) {
    console.error('verify-otp error', error);
    const message = error instanceof Error ? error.message : 'Could not verify code';
    return jsonResponse({ error: message }, 500);
  }
});

async function ensureAuthUser(
  admin: ReturnType<typeof createClient>,
  normalizedPhone: string,
  email: string,
): Promise<string> {
  const existingId = await findUserIdByEmail(admin, email);
  if (existingId) {
    return existingId;
  }

  const { data: profile } = await admin
    .from('profiles')
    .select('id')
    .eq('phone', normalizedPhone)
    .maybeSingle();

  if (profile?.id) {
    return profile.id;
  }

  const { data: created, error: createError } =
    await admin.auth.admin.createUser({
      email,
      email_confirm: true,
      user_metadata: {
        phone: normalizedPhone,
        display_name: 'Family Member',
      },
    });

  if (!createError && created.user?.id) {
    return created.user.id;
  }

  const message = createError?.message?.toLowerCase() ?? '';
  if (
    message.includes('already') ||
    message.includes('registered') ||
    message.includes('exists')
  ) {
    const retryId = await findUserIdByEmail(admin, email);
    if (retryId) {
      return retryId;
    }
  }

  throw createError ?? new Error('Could not create user');
}

async function findUserIdByEmail(
  admin: ReturnType<typeof createClient>,
  email: string,
): Promise<string | null> {
  let page = 1;
  const perPage = 200;

  while (page <= 10) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage });
    if (error) {
      throw error;
    }

    const users = data.users ?? [];
    const match = users.find(
      (user) => user.email?.toLowerCase() === email.toLowerCase(),
    );
    if (match?.id) {
      return match.id;
    }

    if (users.length < perPage) {
      break;
    }

    page += 1;
  }

  return null;
}

async function createSessionForEmail(
  admin: ReturnType<typeof createClient>,
  email: string,
) {
  const { data: linkData, error: linkError } =
    await admin.auth.admin.generateLink({
      type: 'magiclink',
      email,
    });

  if (linkError) {
    throw linkError;
  }

  const tokenHash = linkData?.properties?.hashed_token;
  if (!tokenHash) {
    throw new Error('Auth link did not include a token hash');
  }

  const { data: otpData, error: otpError } = await admin.auth.verifyOtp({
    type: 'magiclink',
    token_hash: tokenHash,
  });

  if (otpError) {
    throw otpError;
  }

  if (!otpData?.session) {
    throw new Error('Auth verification did not return a session');
  }

  return otpData.session;
}