-- Update profile creation to support phone-based sign-up
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO profiles (id, display_name, phone)
  VALUES (
    NEW.id,
    COALESCE(
      NEW.raw_user_meta_data->>'display_name',
      NEW.phone,
      split_part(NEW.email, '@', 1),
      'Family Member'
    ),
    NEW.phone
  );
  RETURN NEW;
END;
$$;