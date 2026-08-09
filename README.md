# Focus Flow

Focus Flow is an offline-first Flutter app for daily planning, local reminders,
GitHub AI project digests, and a personal Markdown knowledge base.

The product plan is in [docs/PROJECT_PLAN.md](docs/PROJECT_PLAN.md).
The accepted platform decisions are in
[docs/adr/0001-platform-and-data-architecture.md](docs/adr/0001-platform-and-data-architecture.md),
and release coverage is tracked in [docs/DEVICE_MATRIX.md](docs/DEVICE_MATRIX.md).

## Current status

The local mobile MVP contains the responsive Flutter shell, Drift/SQLite task
and note repositories, local notification scheduling, account-scoped local
data, and tombstone-aware sync. The project currently passes `flutter analyze`
and 40 Flutter tests. Verified debug artifacts are available for Android and
Windows; the Windows debug shell intentionally uses in-memory repositories and
omits mobile-only native plugins during its build.

The current delivery status and remaining release blockers are tracked in
[docs/PROJECT_STATUS_2026-08-09.md](docs/PROJECT_STATUS_2026-08-09.md).

## Next setup

1. Keep `scripts/bootstrap_flutter.py` and `scripts/bootstrap_android_sdk.py` as
   the reproducible bootstrap path for new machines.
2. Verify iOS/macOS release paths on the appropriate host if you want those
   stores covered.
3. Apply `supabase/migrations/0002_release_hardening.sql`, deploy both Edge
   Functions, and run the cloud integration matrix.
4. Complete server-side sync conflict control, push gateway integration,
   platform credentials, release signing, and real-device QA.
