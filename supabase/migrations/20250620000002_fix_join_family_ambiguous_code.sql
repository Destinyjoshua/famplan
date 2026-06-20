-- Fix ambiguous invite_code reference in join_family RPC

CREATE OR REPLACE FUNCTION join_family(invite_code TEXT)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_family families%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  SELECT * INTO v_family FROM families
  WHERE upper(families.invite_code) = upper(join_family.invite_code)
    AND families.invite_code_expires_at > now();

  IF v_family.id IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired invite code';
  END IF;

  INSERT INTO family_members (family_id, user_id, role, status)
  VALUES (v_family.id, auth.uid(), 'member', 'active')
  ON CONFLICT (family_id, user_id) DO UPDATE
    SET status = 'active', joined_at = now();

  RETURN row_to_json(v_family);
END; $$;