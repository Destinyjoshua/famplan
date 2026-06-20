-- ============================================================================
-- FAMPLAN COMPLETE SETUP — run this ONCE in Supabase SQL Editor
-- Cleans up prior attempts, creates schema, enables realtime
-- ============================================================================

-- PART 1: CLEANUP (safe for dev / empty projects)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

DO $$ DECLARE r RECORD; BEGIN
  FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
    EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;

DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS set_updated_at() CASCADE;
DROP FUNCTION IF EXISTS is_family_member(UUID) CASCADE;
DROP FUNCTION IF EXISTS is_family_admin(UUID) CASCADE;
DROP FUNCTION IF EXISTS generate_invite_code() CASCADE;
DROP FUNCTION IF EXISTS enforce_announcement_pin_limit() CASCADE;
DROP FUNCTION IF EXISTS create_family(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS join_family(TEXT) CASCADE;
DROP FUNCTION IF EXISTS get_dashboard(UUID, DATE) CASCADE;
DROP FUNCTION IF EXISTS generate_grocery_list(UUID) CASCADE;

DROP TYPE IF EXISTS member_role CASCADE;
DROP TYPE IF EXISTS member_status CASCADE;
DROP TYPE IF EXISTS task_status CASCADE;
DROP TYPE IF EXISTS meal_type CASCADE;
DROP TYPE IF EXISTS rsvp_status CASCADE;
DROP TYPE IF EXISTS event_status CASCADE;


-- PART 2: CREATE SCHEMA
-- FamPlan initial schema v1 (aligned with Flutter app)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TYPE member_role AS ENUM ('admin', 'member', 'child');
CREATE TYPE member_status AS ENUM ('active', 'invited', 'left');
CREATE TYPE task_status AS ENUM ('pending', 'completed', 'archived');
CREATE TYPE meal_type AS ENUM ('breakfast', 'lunch', 'dinner');
CREATE TYPE rsvp_status AS ENUM ('pending', 'yes', 'no');
CREATE TYPE event_status AS ENUM ('active', 'cancelled');

CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL DEFAULT '',
  avatar_url TEXT,
  phone TEXT,
  timezone TEXT NOT NULL DEFAULT 'UTC',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE families (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  timezone TEXT NOT NULL DEFAULT 'UTC',
  invite_code TEXT NOT NULL UNIQUE,
  invite_code_expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '7 days'),
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE family_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role member_role NOT NULL DEFAULT 'member',
  status member_status NOT NULL DEFAULT 'active',
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  notification_preferences JSONB NOT NULL DEFAULT '{}',
  UNIQUE (family_id, user_id)
);

CREATE INDEX idx_family_members_user ON family_members(user_id);
CREATE INDEX idx_family_members_family ON family_members(family_id);

CREATE TABLE family_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  invited_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  email TEXT,
  token TEXT NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(16), 'hex'),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '7 days'),
  accepted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  notes TEXT,
  assignee_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  due_at TIMESTAMPTZ,
  status task_status NOT NULL DEFAULT 'pending',
  completed_at TIMESTAMPTZ,
  completed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  recurrence_rule TEXT,
  recurrence_parent_id UUID REFERENCES tasks(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_tasks_family_due ON tasks(family_id, due_at);

CREATE TABLE events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  location TEXT,
  notes TEXT,
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  all_day BOOLEAN NOT NULL DEFAULT false,
  recurrence_rule TEXT,
  recurrence_parent_id UUID REFERENCES events(id) ON DELETE SET NULL,
  status event_status NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_events_family_starts ON events(family_id, starts_at);

CREATE TABLE event_attendees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  rsvp rsvp_status NOT NULL DEFAULT 'pending',
  invited_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (event_id, user_id)
);

CREATE TABLE announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  author_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  body TEXT NOT NULL,
  photo_url TEXT,
  is_pinned BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE announcement_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  announcement_id UUID NOT NULL REFERENCES announcements(id) ON DELETE CASCADE,
  author_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE announcement_reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  announcement_id UUID NOT NULL REFERENCES announcements(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL,
  UNIQUE (announcement_id, user_id, emoji)
);

CREATE TABLE meal_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  ingredients JSONB NOT NULL DEFAULT '[]',
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE meal_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  week_start_date DATE NOT NULL,
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (family_id, week_start_date)
);

CREATE TABLE meal_slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  meal_plan_id UUID NOT NULL REFERENCES meal_plans(id) ON DELETE CASCADE,
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  meal_type meal_type NOT NULL,
  meal_name TEXT NOT NULL DEFAULT '',
  cook_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  ingredients JSONB NOT NULL DEFAULT '[]',
  UNIQUE (meal_plan_id, day_of_week, meal_type)
);

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}',
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE user_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, fcm_token)
);

CREATE OR REPLACE FUNCTION is_family_member(fid UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = fid AND user_id = auth.uid() AND status = 'active'
  );
$$;

CREATE OR REPLACE FUNCTION is_family_admin(fid UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = fid AND user_id = auth.uid() AND status = 'active' AND role = 'admin'
  );
$$;

CREATE OR REPLACE FUNCTION generate_invite_code()
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE code TEXT; exists_already BOOLEAN;
BEGIN
  LOOP
    code := upper(substr(md5(random()::text), 1, 8));
    SELECT EXISTS(SELECT 1 FROM families WHERE invite_code = code) INTO exists_already;
    EXIT WHEN NOT exists_already;
  END LOOP;
  RETURN code;
END; $$;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO profiles (id, display_name, phone)
  VALUES (
    NEW.id,
    COALESCE(
      NEW.raw_user_meta_data->>'display_name',
      NEW.phone,
      NULLIF(split_part(NEW.email, '@', 1), ''),
      'Family Member'
    ),
    COALESCE(NEW.raw_user_meta_data->>'phone', NEW.phone)
  );
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

DROP TRIGGER IF EXISTS profiles_updated_at ON profiles;
CREATE TRIGGER profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS tasks_updated_at ON tasks;
CREATE TRIGGER tasks_updated_at BEFORE UPDATE ON tasks FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS events_updated_at ON events;
CREATE TRIGGER events_updated_at BEFORE UPDATE ON events FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS announcements_updated_at ON announcements;
CREATE TRIGGER announcements_updated_at BEFORE UPDATE ON announcements FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE FUNCTION enforce_announcement_pin_limit()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE pin_count INT;
BEGIN
  IF NEW.is_pinned = true THEN
    SELECT COUNT(*) INTO pin_count FROM announcements
    WHERE family_id = NEW.family_id AND is_pinned = true AND id != NEW.id;
    IF pin_count >= 3 THEN RAISE EXCEPTION 'Maximum 3 pinned announcements allowed'; END IF;
  END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS check_announcement_pin_limit ON announcements;
CREATE TRIGGER check_announcement_pin_limit
  BEFORE INSERT OR UPDATE ON announcements FOR EACH ROW EXECUTE FUNCTION enforce_announcement_pin_limit();

CREATE OR REPLACE FUNCTION create_family(family_name TEXT, p_timezone TEXT DEFAULT 'UTC')
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_family_id UUID; v_code TEXT; v_family families%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  v_code := generate_invite_code();
  INSERT INTO families (name, timezone, invite_code, invite_code_expires_at, created_by)
  VALUES (trim(family_name), p_timezone, v_code, now() + INTERVAL '7 days', auth.uid())
  RETURNING id INTO v_family_id;
  INSERT INTO family_members (family_id, user_id, role, status) VALUES (v_family_id, auth.uid(), 'admin', 'active');
  SELECT * INTO v_family FROM families WHERE id = v_family_id;
  RETURN row_to_json(v_family);
END; $$;

CREATE OR REPLACE FUNCTION join_family(invite_code TEXT)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_family families%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT * INTO v_family FROM families
  WHERE upper(families.invite_code) = upper(join_family.invite_code)
    AND families.invite_code_expires_at > now();
  IF v_family.id IS NULL THEN RAISE EXCEPTION 'Invalid or expired invite code'; END IF;
  INSERT INTO family_members (family_id, user_id, role, status)
  VALUES (v_family.id, auth.uid(), 'member', 'active')
  ON CONFLICT (family_id, user_id) DO UPDATE SET status = 'active', joined_at = now();
  RETURN row_to_json(v_family);
END; $$;

CREATE OR REPLACE FUNCTION get_dashboard(p_family_id UUID, p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSON LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE result JSON; week_start DATE;
BEGIN
  IF NOT is_family_member(p_family_id) THEN RAISE EXCEPTION 'Not a family member'; END IF;
  week_start := date_trunc('week', p_date::timestamptz)::date;
  SELECT json_build_object(
    'date', p_date::text,
    'tasks', COALESCE((SELECT json_agg(t) FROM (
      SELECT id, family_id, created_by, title, notes, assignee_id, due_at, status, completed_at, completed_by, created_at, updated_at
      FROM tasks WHERE family_id = p_family_id AND status = 'pending'
        AND (assignee_id = auth.uid() OR assignee_id IS NULL)
      ORDER BY due_at NULLS LAST LIMIT 3) t), '[]'::json),
    'events', COALESCE((SELECT json_agg(e) FROM (
      SELECT id, family_id, created_by, title, location, notes, starts_at, ends_at, all_day, status, created_at, updated_at
      FROM events WHERE family_id = p_family_id AND status = 'active'
        AND starts_at >= p_date::timestamptz AND starts_at < (p_date + INTERVAL '8 days')::timestamptz
      ORDER BY starts_at LIMIT 3) e), '[]'::json),
    'announcements', COALESCE((SELECT json_agg(a) FROM (
      SELECT id, family_id, author_id, body, photo_url, is_pinned, created_at, updated_at
      FROM announcements WHERE family_id = p_family_id
      ORDER BY is_pinned DESC, created_at DESC LIMIT 3) a), '[]'::json),
    'meals', COALESCE((SELECT json_agg(m) FROM (
      SELECT id, meal_plan_id, family_id, day_of_week, meal_type, meal_name, cook_id, ingredients
      FROM meal_slots ms JOIN meal_plans mp ON mp.id = ms.meal_plan_id
      WHERE mp.family_id = p_family_id AND mp.week_start_date = week_start
        AND ms.day_of_week = CASE WHEN EXTRACT(DOW FROM p_date)::int = 0 THEN 6 ELSE EXTRACT(DOW FROM p_date)::int - 1 END
      ORDER BY meal_type) m), '[]'::json)
  ) INTO result;
  RETURN result;
END; $$;

CREATE OR REPLACE FUNCTION generate_grocery_list(p_meal_plan_id UUID)
RETURNS JSON LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_family_id UUID; result JSON;
BEGIN
  SELECT family_id INTO v_family_id FROM meal_plans WHERE id = p_meal_plan_id;
  IF NOT is_family_member(v_family_id) THEN RAISE EXCEPTION 'Not a family member'; END IF;
  SELECT COALESCE(json_agg(DISTINCT jsonb_build_object('name', ing->>'name', 'qty', ing->>'qty', 'unit', ing->>'unit')), '[]'::json)
  INTO result FROM meal_slots ms, LATERAL jsonb_array_elements(ms.ingredients) ing
  WHERE ms.meal_plan_id = p_meal_plan_id AND ms.meal_name != '';
  RETURN result;
END; $$;

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE families ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_attendees ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcement_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcement_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profiles_select ON profiles;
DROP POLICY IF EXISTS profiles_insert ON profiles;
DROP POLICY IF EXISTS profiles_update ON profiles;
DROP POLICY IF EXISTS families_select ON families;
DROP POLICY IF EXISTS families_insert ON families;
DROP POLICY IF EXISTS families_update ON families;
DROP POLICY IF EXISTS family_members_select ON family_members;
DROP POLICY IF EXISTS family_members_insert ON family_members;
DROP POLICY IF EXISTS family_members_update ON family_members;
DROP POLICY IF EXISTS tasks_all ON tasks;
DROP POLICY IF EXISTS events_all ON events;
DROP POLICY IF EXISTS event_attendees_all ON event_attendees;
DROP POLICY IF EXISTS announcements_all ON announcements;
DROP POLICY IF EXISTS announcement_comments_all ON announcement_comments;
DROP POLICY IF EXISTS meal_templates_all ON meal_templates;
DROP POLICY IF EXISTS meal_plans_all ON meal_plans;
DROP POLICY IF EXISTS meal_slots_all ON meal_slots;
DROP POLICY IF EXISTS notifications_select ON notifications;
DROP POLICY IF EXISTS user_devices_all ON user_devices;

CREATE POLICY profiles_select ON profiles FOR SELECT USING (
  id = auth.uid() OR EXISTS (
    SELECT 1 FROM family_members fm1 JOIN family_members fm2 ON fm1.family_id = fm2.family_id
    WHERE fm1.user_id = auth.uid() AND fm2.user_id = profiles.id AND fm1.status = 'active'));
CREATE POLICY profiles_insert ON profiles FOR INSERT WITH CHECK (id = auth.uid());
CREATE POLICY profiles_update ON profiles FOR UPDATE USING (id = auth.uid());

CREATE POLICY families_select ON families FOR SELECT USING (is_family_member(id));
CREATE POLICY families_insert ON families FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY families_update ON families FOR UPDATE USING (is_family_admin(id));

CREATE POLICY family_members_select ON family_members FOR SELECT USING (is_family_member(family_id));
CREATE POLICY family_members_insert ON family_members FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY family_members_update ON family_members FOR UPDATE USING (is_family_admin(family_id));

CREATE POLICY tasks_all ON tasks FOR ALL USING (is_family_member(family_id)) WITH CHECK (is_family_member(family_id));
CREATE POLICY events_all ON events FOR ALL USING (is_family_member(family_id)) WITH CHECK (is_family_member(family_id));
CREATE POLICY event_attendees_all ON event_attendees FOR ALL USING (
  EXISTS (SELECT 1 FROM events e WHERE e.id = event_id AND is_family_member(e.family_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM events e WHERE e.id = event_id AND is_family_member(e.family_id)));
CREATE POLICY announcements_all ON announcements FOR ALL USING (is_family_member(family_id)) WITH CHECK (is_family_member(family_id));
CREATE POLICY announcement_comments_all ON announcement_comments FOR ALL USING (
  EXISTS (SELECT 1 FROM announcements a WHERE a.id = announcement_id AND is_family_member(a.family_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM announcements a WHERE a.id = announcement_id AND is_family_member(a.family_id)));
CREATE POLICY meal_templates_all ON meal_templates FOR ALL USING (is_family_member(family_id)) WITH CHECK (is_family_member(family_id));
CREATE POLICY meal_plans_all ON meal_plans FOR ALL USING (is_family_member(family_id)) WITH CHECK (is_family_member(family_id));
CREATE POLICY meal_slots_all ON meal_slots FOR ALL USING (is_family_member(family_id)) WITH CHECK (is_family_member(family_id));
CREATE POLICY notifications_select ON notifications FOR SELECT USING (user_id = auth.uid());
CREATE POLICY user_devices_all ON user_devices FOR ALL USING (user_id = auth.uid());

-- PART 3: REALTIME (creates publication if missing)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'tasks'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.tasks;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'events'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.events;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'announcements'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.announcements;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'announcement_comments'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.announcement_comments;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'meal_slots'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.meal_slots;
  END IF;
END $$;

-- PART 4: VERIFY (should return 15 tables)
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
