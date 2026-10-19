# Trail

An MVP walk-tracking app: a Flutter iOS app records your GPS route and uploads it to Supabase; a Next.js website lets you browse past walks on a map.

## Structure

- `supabase/` — SQL schema + setup instructions for the shared Postgres database (do this first).
- `mobile/` — Flutter app (targets iOS). Build/run this on a Mac with Xcode installed.
- `web/` — Next.js website for viewing walk history and routes on a map.

## Getting started

1. Follow [`supabase/README.md`](supabase/README.md) to create your Supabase project and run the schema.
2. **Mobile**: copy `mobile/.env.example` to `mobile/.env`, fill in your Supabase URL/key, then on a Mac: `cd mobile && flutter pub get && flutter run` (pick a physical iPhone as the target to test real GPS/background tracking).
3. **Web**: copy `web/.env.local.example` to `web/.env.local`, fill in the same two values, then `cd web && npm install && npm run dev`.

## Deployment

- **Website**: deployed to Vercel at https://trail-kappa-sand.vercel.app, auto-deploys on push to `master` via the connected [github.com/moneppo/trail](https://github.com/moneppo/trail) repo.
- **Mobile**: not deployed anywhere (dev-only) — build and run locally on a Mac per above.

## Status

Mobile app: auth + start/stop walk tracking + history list implemented (`flutter analyze` clean). Not yet run on a real device — needs a Mac.

Website: auth + walk list + walk detail with map (MapLibre + OpenStreetMap tiles, no API key needed) implemented, build-verified, and confirmed working end-to-end against the real Supabase backend in a browser (signup/login/RLS/map rendering all verified). Live on Vercel.

Still open: end-to-end test with a real walk (see plan Phase 6) once you have a Mac available for the iOS build.
