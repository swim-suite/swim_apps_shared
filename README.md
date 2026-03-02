# swim_apps_shared

Shared package and central Firebase infra repository for:
- `swimify`
- `swim_analyzer`
- `aquis`

See [SHARED_FIREBASE_OWNERSHIP.md](SHARED_FIREBASE_OWNERSHIP.md) for ownership and deploy flow.

## Local Firebase Emulators

Emulator startup enforces shared artifact freshness. If generated artifacts are stale,
the launcher exits and tells you to re-compose.

You can still compose manually first:

```bash
cd /Users/johannes/company/swim_suite/swim_apps_shared
python3 firebase_infra/tools/manage_infra.py compose
```

Start emulators:

```bash
./scripts/local-emulators.sh start
```

Useful commands:

```bash
# Firestore only (no auto-seed)
./scripts/local-emulators.sh firestore

# Force deterministic reseed
./scripts/local-emulators.sh seed

# Delete local emulator data
./scripts/local-emulators.sh clean
```

Behavior notes:
- Emulators use shared generated rules/indexes/storage from this repo.
- Both `swimify` and `swim_analyzer` functions codebases are loaded.
- Mock data auto-seeds once when the selected data dir has no export metadata.
- Seeded demo users: `stage_owner_demo`, `stage_swimmer_01`, `stage_staff_demo`.

Optional overrides:

```bash
FIREBASE_PROJECT_ID=swim-coach-support-dev ./scripts/local-emulators.sh start
FIREBASE_EMULATOR_DATA_DIR=/tmp/swim-apps-shared-emulators ./scripts/local-emulators.sh start
LOCAL_EMULATOR_DEMO_PASSWORD='LocalDemoPassword#123' ./scripts/local-emulators.sh seed
```
