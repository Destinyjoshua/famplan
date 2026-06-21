import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1?target=deno';
import { jsonResponse } from './cors.ts';

export async function requirePlatformAdmin(
  req: Request,
  serviceClient: SupabaseClient,
): Promise<{ id: string; email?: string }> {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    throw new AdminAuthError('Missing authorization', 401);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  if (!supabaseUrl || !anonKey) {
    throw new AdminAuthError('Server auth is not configured', 500);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    throw new AdminAuthError('Invalid or expired session', 401);
  }

  const { data: profile, error: profileError } = await serviceClient
    .from('profiles')
    .select('is_platform_admin')
    .eq('id', userData.user.id)
    .maybeSingle();

  if (profileError) {
    console.error('admin profile lookup', profileError);
    throw new AdminAuthError('Could not verify admin access', 500);
  }

  if (!profile?.is_platform_admin) {
    throw new AdminAuthError('You do not have operator admin access', 403);
  }

  return {
    id: userData.user.id,
    email: userData.user.email,
  };
}

export class AdminAuthError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
    this.name = 'AdminAuthError';
  }
}

export function adminErrorResponse(error: unknown) {
  if (error instanceof AdminAuthError) {
    return jsonResponse({ error: error.message }, error.status);
  }
  console.error('admin-data error', error);
  return jsonResponse({ error: 'Request failed' }, 500);
}