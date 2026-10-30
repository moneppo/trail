# Supabase setup (do this once, manually)

This step requires your own Supabase account, so it isn't something I can do for you from here.

1. Go to https://supabase.com, sign in, and click "New project".
   - Pick any name (e.g. `trail`) and a database password (save it somewhere).
2. Once the project finishes provisioning, open the **SQL Editor** in the left sidebar, paste in the contents of [`schema.sql`](./schema.sql), and run it.
   - This creates the `walks` and `walk_points` tables with Row Level Security policies that restrict each user to their own data.
   - Then run each file in [`migrations/`](./migrations) in order. They add the later tables (`snapped_points`, `untracked_trails`), which the app and website need.
3. Go to **Authentication > Providers** and confirm **Email** is enabled (it is by default). For the MVP we're using plain email/password auth — no email confirmation needed if you turn off "Confirm email" under Authentication > Settings, which is convenient while testing.
4. Go to **Project Settings > API Keys** and copy:
   - **Project URL** (looks like `https://xxxxx.supabase.co`)
   - The **Publishable key** (starts with `sb_publishable_...`) — this is the new replacement for the old "anon public" key. Safe to use in client code (mobile app, website): it still respects Row Level Security.
   - Do **not** use the **Secret key** (`sb_secret_...`) anywhere in this project — that's the replacement for the old `service_role` key, bypasses RLS entirely, and should never ship in an app or website.
5. Put the URL and Publishable key into:
   - `mobile/.env` (for the Flutter app)
   - `web/.env.local` (for the Next.js site)

   Both `.env` files are gitignored — never commit real keys. Example files (`.env.example`) are provided in each folder showing the expected variable names.

That's it — both the mobile app and the website talk directly to Supabase's REST API using these two values, no separate backend server needed.
