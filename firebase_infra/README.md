# Shared Firebase Infra

This directory is the central source of truth for shared Firebase resources used by:
- Swim Suite (`swimify`)
- Swim Analyzer (`swim_analyzer`)
- Aquis (`aquis`)

## Layout

- `apps/<app>/ownership.yaml` declares ownership boundaries.
- `apps/<app>/firestore.rules.part` contains app-owned Firestore rules fragments.
- `apps/<app>/firestore.indexes.part.json` contains app-owned Firestore index fragments.
- `apps/<app>/storage.rules.part` contains app-owned Storage rules fragments.
- `generated/` contains deploy-ready composed artifacts.
- `tools/manage_infra.py` validates ownership and composes artifacts.

## Commands

```bash
cd /Users/johannes/company/swim_suite/swim_apps_shared
python3 firebase_infra/tools/manage_infra.py validate
python3 firebase_infra/tools/manage_infra.py compose
python3 firebase_infra/tools/manage_infra.py all --check
```

## Ownership rules

- One app may own a Firestore match path.
- One app may own a Firestore `collectionGroup`.
- One app may own a Storage match path.

Validation fails on ownership collisions.

## CI prerequisites

- In each app repo (`swimify`, `swim_analyzer`, `aquis`), define `SHARED_INFRA_REPO_TOKEN` with permission to:
  - push branches and open PRs in `swim_apps_shared`
  - post commit statuses in the source app repo
- In `swim_apps_shared`, define `SHARED_INFRA_STATUS_TOKEN` with permission to post commit statuses in all three app repos.

Status contexts used by gates:
- `shared-infra/synced`
- `shared-infra/deployed-dev`
