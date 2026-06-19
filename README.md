# FamPlan

A family coordination app built with Flutter and Supabase. Plan meals, manage tasks, share a calendar, and post announcements — all in one place.

> Nigerian phone sign-in (`080...` or `+234...`) with password. No SMS required for MVP.

## Features

- **Phone + password auth** — sign in with your mobile number
- **Family setup** — create a family or join with an invite code
- **Dashboard** — today's tasks, events, meals, and announcements
- **Tasks** — create, assign, complete; filter All / Mine / Overdue
- **Calendar** — month view with event creation
- **Meals** — weekly Mon–Sun grid, assign cooks, generate grocery list
- **Announcements** — family feed with pin and comments
- **Realtime** — tasks sync live across devices

## Prerequisites

- [Flutter 3.x](https://docs.flutter.dev/get-started/install) (SDK ^3.7)
- A [Supabase](https://supabase.com) project
- iOS Simulator, Android Emulator, or physical device

## Setup

### 1. Clone and install dependencies

```bash
cd famplan
flutter pub get
```

### 2. Create a Supabase project

1. Go to [supabase.com/dashboard](https://supabase.com/dashboard) and create a new project.
2. Note your **Project URL** and **anon public** key under **Settings → API**.

### 3. Run database setup (one copy-paste)

Open **`supabase/complete_setup.sql`** on your Mac, copy the entire file, paste into **Supabase → SQL Editor**, and click **Run once**.

This script cleans up prior attempts, creates all tables/RLS/functions, enables realtime, and shows a table list at the end (you should see ~15 rows).

Alternative: `supabase/migrations/20250618000001_initial_schema.sql` (same schema, no cleanup).

This creates:

- Tables: `profiles`, `families`, `family_members`, `tasks`, `events`, `announcements`, `announcement_comments`, `meal_plans`, `meal_slots`
- RLS policies on all family-scoped tables
- RPC functions: `create_family`, `join_family`, `get_dashboard`, `generate_grocery_list`

Run the migration SQL in the Supabase SQL Editor.

### 4. Configure environment

```bash
cp .env.example .env
```

Edit `.env` with your Supabase credentials:

```
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOi...
```

### 5. Auth (phone UI, works out of the box)

Users enter a Nigerian number: `08012345678` or `+2348012345678`.

The app maps that to an internal auth email (`2348012345678@famplan.auth`) so sign-up works **without SMS** — no Twilio setup needed for MVP.

**Supabase settings (recommended):**

1. **Authentication → Providers → Email** — enabled (default)
2. **Authentication → Providers → Email** — turn **OFF** "Confirm email" for dev/testing
3. Optional later: enable **Phone** provider + SMS for real OTP

Run `supabase/migrations/20250620000001_phone_email_auth.sql` in SQL Editor if profiles are missing phone numbers after sign-up.

### 6. Run the app

```bash
flutter run
```

## Project structure

```
lib/
├── config/          # Env and Supabase init
├── core/theme/      # App theme
├── data/
│   ├── models/      # Data classes
│   └── repositories/# Supabase data layer
├── providers/       # Riverpod state
├── features/        # UI screens by feature
├── shared/widgets/  # Reusable widgets
└── router/          # go_router config
```

## Development

```bash
flutter analyze   # Lint / static analysis
```

## Publishing (App Store / Play Store)

### 1. Supabase production checklist

- Turn **OFF** "Confirm email" under Authentication → Email (or configure SMTP)
- Run all SQL in `supabase/migrations/` on your production project
- Use a dedicated Supabase project for production (not dev keys)

### 2. Build with environment variables

Ensure `.env` exists locally before building (it is bundled as an asset), **or** pass defines:

```bash
flutter build ipa --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key

flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

### 3. iOS (TestFlight / App Store)

1. Open `ios/Runner.xcworkspace` in Xcode
2. Set your **Team** and **Bundle ID** (`com.famplan.famplan` or your own)
3. Configure **Signing & Capabilities** for Release
4. Archive → Distribute to App Store Connect
5. App Store Connect: name **FamPlan**, category Lifestyle, age 4+

### 4. Android (Play Store)

1. Create a release keystore:
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Copy `android/key.properties.example` → `android/key.properties` and fill in paths/passwords
3. Build: `flutter build appbundle --release` (uses release signing when `key.properties` exists)
4. Upload the `.aab` from `build/app/outputs/bundle/release/`
5. Play Console: name **FamPlan**, category Lifestyle

### 5. Store listing copy (starter)

**Subtitle:** Organize your family in one place  
**Description:** FamPlan helps families manage tasks, shared calendars, meal plans, and announcements. Create a family, invite members with a code, and stay coordinated every day.

## Tech stack

- **Flutter** — iOS & Android
- **Supabase** — Postgres, Auth, Realtime
- **Riverpod** — state management
- **go_router** — navigation
- **flutter_dotenv** — environment config

## License

Private — not for publication.
