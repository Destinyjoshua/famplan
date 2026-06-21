-- Platform operator flag (Taskit / Famplans staff — not family admin role)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS is_platform_admin BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_profiles_platform_admin
  ON profiles (is_platform_admin)
  WHERE is_platform_admin = true;

COMMENT ON COLUMN profiles.is_platform_admin IS
  'When true, user can access the operator admin dashboard API.';