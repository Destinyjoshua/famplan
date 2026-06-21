-- Real contact email on profiles (separate from internal auth.users email)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS contact_email TEXT;

-- Never derive display_name from the internal @famplan.auth login email
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  meta_display_name TEXT;
  email_local_part TEXT;
BEGIN
  meta_display_name := NULLIF(trim(NEW.raw_user_meta_data->>'display_name'), '');
  email_local_part := split_part(NEW.email, '@', 1);

  INSERT INTO profiles (id, display_name, phone)
  VALUES (
    NEW.id,
    COALESCE(
      meta_display_name,
      CASE
        WHEN NEW.email LIKE '%@famplan.auth' THEN 'Family Member'
        ELSE NULLIF(email_local_part, '')
      END,
      'Family Member'
    ),
    COALESCE(NEW.raw_user_meta_data->>'phone', NEW.phone)
  );
  RETURN NEW;
END;
$$;

-- Clean up profiles that were named after phone digits or auth aliases
UPDATE profiles
SET display_name = 'Family Member',
    updated_at = now()
WHERE display_name ~ '^(234|0)\d{10}$'
   OR display_name ~ '^\+\d{10,}$'
   OR display_name LIKE '%@famplan.auth';