# Shared Firebase Ownership (Central Infra Repo)

This repository is the source of truth for shared Firebase infrastructure used by:
- Swim Suite (`swimify`)
- Swim Analyzer (`swim_analyzer`)
- Aquis (`aquis`)

## What This Repo Owns
- Composed Firestore rules
- Composed Storage rules
- Ownership validation across app fragments
- Shared rules/storage deployment to stage/dev and production

## What This Repo Does Not Own
- Firestore composite index definitions
- Firestore index deployment to stage/prod
- Firestore index file synchronization from app repos

Firestore index source-of-truth is stage Firestore itself. App repos promote live indexes from stage to prod at deploy time.

## Ownership Model
Each app owns its own infra fragments, but shared deploy happens here.

Single-owner rules are enforced for:
- Exact Firestore `match` path ownership
- Firestore `collectionGroup` ownership metadata (used by app-side index promotion filters)

## Directory Contract
- `firebase_infra/apps/<app>/ownership.yaml`
- `firebase_infra/apps/<app>/firestore.rules.part`
- `firebase_infra/apps/<app>/storage.rules.part`
- `firebase_infra/generated/firestore.rules`
- `firebase_infra/generated/storage.rules`
- `firebase_infra/tools/manage_infra.py`

## Workflows In This Repo
- `Validate Shared Firebase Infra`
  - Runs on PRs touching shared infra files.
  - Validates ownership and generated rules/storage artifacts.
- `Deploy Shared Firebase Infra (DEV)`
  - Runs on merge to `master` for shared infra paths.
  - Deploys Firestore rules + Storage to `swim-coach-support-dev`.
- `Deploy Shared Firebase Infra (PROD)`
  - Manual dispatch.
  - Deploys Firestore rules + Storage to `swim-coach-support`.

## Required Secrets
- `SHARED_INFRA_STATUS_TOKEN` (recommended)
  - Used to publish `shared-infra/deployed-dev` status to source app commits.
- `FIREBASE_SERVICE_ACCOUNT` (for prod deploy workflow)

## Required Status Contexts (Cross-Repo)
- `shared-infra/synced`
- `shared-infra/deployed-dev`

## Day-to-Day Flow
1. App repo changes fragment files.
2. App sync workflow opens/updates PR here.
3. Merge sync PR in this repo (rules/storage only).
4. `Deploy Shared Firebase Infra (DEV)` runs and must pass (rules/storage).
5. App backend deploy proceeds (or is rerun if previously gated).

## Production Flow
1. Merge approved shared infra PR(s) to `master`.
2. Run `Deploy Shared Firebase Infra (PROD)` manually with approval (rules/storage).
3. Then run app production deploys.

## Operational Safety Checklist
Before app production deploys when infra changed:
1. Confirm latest shared `validate` run is green.
2. Confirm latest shared `deploy dev` run is green.
3. Confirm intended sync PRs are merged.
4. Run shared prod deploy manually.
5. Then deploy app production jobs.

## Rollback Strategy
If shared infra deploy introduces an issue:
1. Revert the offending commit in this repo.
2. Let `Deploy Shared Firebase Infra (DEV)` run from the revert.
3. Verify stage behavior.
4. For prod, run manual shared prod deploy from known-good commit.

## Known Failure Patterns
- `Unexpected 'return'` / `Unexpected '}'` in Firestore rules:
  - A fragment is syntactically broken.
- `Unexpected '}'` in Storage rules:
  - A fragment has unmatched braces.
- `Invalid username or token` during app sync push:
  - App repo token cannot write to `swim_apps_shared`.
