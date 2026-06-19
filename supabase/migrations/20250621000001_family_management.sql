-- Family management RPCs: rename, invite refresh, member roles, remove, leave

CREATE OR REPLACE FUNCTION regenerate_family_invite_code(p_family_id UUID)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_family families%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF NOT is_family_admin(p_family_id) THEN RAISE EXCEPTION 'Only admins can regenerate invite codes'; END IF;

  UPDATE families
  SET invite_code = generate_invite_code(),
      invite_code_expires_at = now() + INTERVAL '7 days'
  WHERE id = p_family_id
  RETURNING * INTO v_family;

  RETURN row_to_json(v_family);
END; $$;

CREATE OR REPLACE FUNCTION update_family_name(p_family_id UUID, p_name TEXT)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_family families%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF NOT is_family_admin(p_family_id) THEN RAISE EXCEPTION 'Only admins can rename the family'; END IF;
  IF trim(p_name) = '' THEN RAISE EXCEPTION 'Family name cannot be empty'; END IF;

  UPDATE families
  SET name = trim(p_name)
  WHERE id = p_family_id
  RETURNING * INTO v_family;

  RETURN row_to_json(v_family);
END; $$;

CREATE OR REPLACE FUNCTION update_family_member_role(
  p_family_id UUID,
  p_user_id UUID,
  p_role member_role
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE admin_count INT;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF NOT is_family_admin(p_family_id) THEN RAISE EXCEPTION 'Only admins can change roles'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = p_family_id AND user_id = p_user_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Member not found';
  END IF;

  IF p_role != 'admin' AND p_user_id = auth.uid() THEN
    SELECT COUNT(*) INTO admin_count
    FROM family_members
    WHERE family_id = p_family_id AND status = 'active' AND role = 'admin';
    IF admin_count <= 1 THEN
      RAISE EXCEPTION 'Promote another admin before changing your role';
    END IF;
  END IF;

  IF p_role != 'admin' THEN
    SELECT COUNT(*) INTO admin_count
    FROM family_members
    WHERE family_id = p_family_id AND status = 'active' AND role = 'admin' AND user_id != p_user_id;
    IF admin_count = 0 THEN
      RAISE EXCEPTION 'Family must have at least one admin';
    END IF;
  END IF;

  UPDATE family_members
  SET role = p_role
  WHERE family_id = p_family_id AND user_id = p_user_id AND status = 'active';
END; $$;

CREATE OR REPLACE FUNCTION remove_family_member(p_family_id UUID, p_user_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE admin_count INT;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF NOT is_family_admin(p_family_id) THEN RAISE EXCEPTION 'Only admins can remove members'; END IF;
  IF p_user_id = auth.uid() THEN RAISE EXCEPTION 'Use Leave family to remove yourself'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = p_family_id AND user_id = p_user_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'Member not found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = p_family_id AND user_id = p_user_id AND status = 'active' AND role = 'admin'
  ) THEN
    SELECT COUNT(*) INTO admin_count
    FROM family_members
    WHERE family_id = p_family_id AND status = 'active' AND role = 'admin';
    IF admin_count <= 1 THEN
      RAISE EXCEPTION 'Promote another admin before removing this member';
    END IF;
  END IF;

  UPDATE family_members
  SET status = 'left'
  WHERE family_id = p_family_id AND user_id = p_user_id AND status = 'active';
END; $$;

CREATE OR REPLACE FUNCTION leave_family(p_family_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE admin_count INT;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF NOT is_family_member(p_family_id) THEN RAISE EXCEPTION 'Not a family member'; END IF;

  IF is_family_admin(p_family_id) THEN
    SELECT COUNT(*) INTO admin_count
    FROM family_members
    WHERE family_id = p_family_id AND status = 'active' AND role = 'admin';
    IF admin_count <= 1 THEN
      SELECT COUNT(*) INTO admin_count
      FROM family_members
      WHERE family_id = p_family_id AND status = 'active';
      IF admin_count > 1 THEN
        RAISE EXCEPTION 'Promote another admin before leaving';
      END IF;
    END IF;
  END IF;

  UPDATE family_members
  SET status = 'left'
  WHERE family_id = p_family_id AND user_id = auth.uid() AND status = 'active';
END; $$;