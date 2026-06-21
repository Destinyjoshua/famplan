import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1?target=deno';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { normalizePhone, phoneToTermiiFormat } from '../_shared/phone.ts';

interface SendOtpRequest {
  phone?: string;
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
    const senderId = Deno.env.get('TERMII_SENDER_ID')?.trim();
    const baseUrl =
      Deno.env.get('TERMII_BASE_URL')?.trim() ?? 'https://api.ng.termii.com';

    if (!apiKey || !senderId) {
      return jsonResponse(
        { error: 'SMS service is not configured. Contact support.' },
        500,
      );
    }

    const body = (await req.json()) as SendOtpRequest;
    const normalized = normalizePhone(body.phone ?? '');
    if (!normalized) {
      return jsonResponse({ error: 'Enter a valid Nigerian phone number' }, 400);
    }

    const termiiResponse = await fetch(`${baseUrl}/api/sms/otp/send`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        api_key: apiKey,
        pin_type: 'NUMERIC',
        to: phoneToTermiiFormat(normalized),
        from: senderId,
        channel: 'generic',
        pin_attempts: 3,
        pin_time_to_live: 10,
        pin_length: 6,
        pin_placeholder: '< 123456 >',
        message_text:
          'Your Famplans verification code is < 123456 >. Valid for 10 minutes.',
      }),
    });

    const termiiData = await termiiResponse.json();

    if (!termiiResponse.ok) {
      const termiiMessage = `${termiiData?.message ?? ''}`.trim();
      console.error('Termii send error', {
        status: termiiResponse.status,
        message: termiiMessage,
        data: termiiData,
      });

      if (/invalid api key/i.test(termiiMessage)) {
        return jsonResponse(
          {
            error:
              'SMS provider credentials are invalid. Update TERMII_API_KEY in Supabase secrets.',
          },
          502,
        );
      }

      return jsonResponse(
        { error: termiiMessage || 'Could not send verification code' },
        502,
      );
    }

    const pinId = termiiData.pin_id ?? termiiData.pinId;
    if (!pinId) {
      return jsonResponse({ error: 'SMS provider did not return a pin id' }, 502);
    }

    return jsonResponse({
      pin_id: pinId,
      phone: normalized,
      message: 'Verification code sent',
    });
  } catch (error) {
    console.error('send-otp error', error);
    return jsonResponse({ error: 'Could not send verification code' }, 500);
  }
});