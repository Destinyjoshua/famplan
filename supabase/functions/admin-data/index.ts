import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1?target=deno';
import { AdminAuthError, adminErrorResponse, requirePlatformAdmin } from '../_shared/admin.ts';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';

type AdminAction = 'stats' | 'customers' | 'families' | 'family';

interface AdminRequest {
  action?: AdminAction;
  family_id?: string;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: 'Admin service is not configured' }, 500);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  try {
    await requirePlatformAdmin(req, admin);

    const body = (await req.json()) as AdminRequest;
    const action = body.action;

    switch (action) {
      case 'stats':
        return jsonResponse(await loadStats(admin));
      case 'customers':
        return jsonResponse(await loadCustomers(admin));
      case 'families':
        return jsonResponse(await loadFamilies(admin));
      case 'family': {
        const familyId = body.family_id?.trim();
        if (!familyId) {
          return jsonResponse({ error: 'family_id is required' }, 400);
        }
        return jsonResponse(await loadFamilyDetail(admin, familyId));
      }
      default:
        return jsonResponse({ error: 'Unknown action' }, 400);
    }
  } catch (error) {
    if (error instanceof AdminAuthError) {
      return adminErrorResponse(error);
    }
    return adminErrorResponse(error);
  }
});

async function loadStats(admin: ReturnType<typeof createClient>) {
  const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();

  const [
    { count: totalUsers },
    { count: totalFamilies },
    { count: newUsers },
    { count: activeMembers },
  ] = await Promise.all([
    admin.from('profiles').select('*', { count: 'exact', head: true }),
    admin.from('families').select('*', { count: 'exact', head: true }),
    admin
      .from('profiles')
      .select('*', { count: 'exact', head: true })
      .gte('created_at', weekAgo),
    admin
      .from('family_members')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'active'),
  ]);

  return {
    total_users: totalUsers ?? 0,
    total_families: totalFamilies ?? 0,
    new_users_7d: newUsers ?? 0,
    active_members: activeMembers ?? 0,
  };
}

async function loadCustomers(admin: ReturnType<typeof createClient>) {
  const { data: profiles, error } = await admin
    .from('profiles')
    .select('id, display_name, phone, contact_email, created_at, updated_at')
    .order('created_at', { ascending: false });

  if (error) throw error;

  const { data: memberships, error: memberError } = await admin
    .from('family_members')
    .select('user_id, family_id, role, status, joined_at, families(name)')
    .eq('status', 'active');

  if (memberError) throw memberError;

  const familyByUser = new Map<string, Array<Record<string, unknown>>>();
  for (const row of memberships ?? []) {
    const userId = row.user_id as string;
    const family = row.families as { name?: string } | null;
    const list = familyByUser.get(userId) ?? [];
    list.push({
      family_id: row.family_id,
      family_name: family?.name ?? 'Unknown',
      role: row.role,
      joined_at: row.joined_at,
    });
    familyByUser.set(userId, list);
  }

  return {
    customers: (profiles ?? []).map((profile) => ({
      ...profile,
      families: familyByUser.get(profile.id) ?? [],
    })),
  };
}

async function loadFamilies(admin: ReturnType<typeof createClient>) {
  const { data: families, error } = await admin
    .from('families')
    .select(
      'id, name, invite_code, invite_code_expires_at, created_at, created_by',
    )
    .order('created_at', { ascending: false });

  if (error) throw error;

  const { data: members, error: memberError } = await admin
    .from('family_members')
    .select('family_id, user_id, role, status')
    .eq('status', 'active');

  if (memberError) throw memberError;

  const counts = new Map<string, number>();
  const admins = new Map<string, string[]>();

  for (const member of members ?? []) {
    const familyId = member.family_id as string;
    counts.set(familyId, (counts.get(familyId) ?? 0) + 1);
  }

  const { data: profiles } = await admin
    .from('profiles')
    .select('id, display_name')
    .in(
      'id',
      (members ?? [])
        .filter((m) => m.role === 'admin')
        .map((m) => m.user_id as string),
    );

  const nameById = new Map(
    (profiles ?? []).map((p) => [p.id as string, p.display_name as string]),
  );

  for (const member of members ?? []) {
    if (member.role !== 'admin' || member.status !== 'active') continue;
    const familyId = member.family_id as string;
    const list = admins.get(familyId) ?? [];
    list.push(nameById.get(member.user_id as string) ?? 'Admin');
    admins.set(familyId, list);
  }

  return {
    families: (families ?? []).map((family) => ({
      ...family,
      member_count: counts.get(family.id as string) ?? 0,
      admin_names: admins.get(family.id as string) ?? [],
    })),
  };
}

async function loadFamilyDetail(
  admin: ReturnType<typeof createClient>,
  familyId: string,
) {
  const { data: family, error } = await admin
    .from('families')
    .select(
      'id, name, invite_code, invite_code_expires_at, created_at, timezone',
    )
    .eq('id', familyId)
    .maybeSingle();

  if (error) throw error;
  if (!family) {
    throw new AdminAuthError('Family not found', 404);
  }

  const { data: members, error: memberError } = await admin
    .from('family_members')
    .select('user_id, role, status, joined_at, profiles(display_name, phone, contact_email)')
    .eq('family_id', familyId)
    .order('joined_at', { ascending: true });

  if (memberError) throw memberError;

  const { count: taskCount } = await admin
    .from('tasks')
    .select('*', { count: 'exact', head: true })
    .eq('family_id', familyId);

  const { count: eventCount } = await admin
    .from('events')
    .select('*', { count: 'exact', head: true })
    .eq('family_id', familyId);

  return {
    family,
    members: members ?? [],
    task_count: taskCount ?? 0,
    event_count: eventCount ?? 0,
  };
}