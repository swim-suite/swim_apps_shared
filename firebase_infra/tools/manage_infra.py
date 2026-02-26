#!/usr/bin/env python3
"""Compose and validate shared Firebase infra artifacts."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

MANIFEST_FILE = "ownership.yaml"
RULES_PART_FILE = "firestore.rules.part"
INDEXES_PART_FILE = "firestore.indexes.part.json"
STORAGE_PART_FILE = "storage.rules.part"

LIST_KEYS = ("rules_paths", "index_collection_groups", "storage_paths")
PREFERRED_ORDER = ("swimify", "swim_analyzer", "aquis")
MATCH_RE = re.compile(r"^\s*match\s+([^\s]+)")


def parse_simple_yaml(path: Path) -> dict[str, Any]:
    """Parse constrained YAML used by ownership manifests."""
    parsed: dict[str, Any] = {}
    active_list: str | None = None

    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        if line.startswith("-"):
            if active_list is None:
                raise ValueError(f"{path}:{line_number}: list item without list key")
            item = line[1:].strip().strip('"').strip("'")
            parsed.setdefault(active_list, []).append(item)
            continue

        if line.endswith(":"):
            key = line[:-1].strip()
            parsed.setdefault(key, [])
            active_list = key
            continue

        if ":" in line:
            key, value = line.split(":", 1)
            parsed[key.strip()] = value.strip().strip('"').strip("'")
            active_list = None
            continue

        raise ValueError(f"{path}:{line_number}: unsupported syntax '{raw_line}'")

    return parsed


def discover_apps(apps_dir: Path) -> list[str]:
    return sorted([entry.name for entry in apps_dir.iterdir() if entry.is_dir()])


def ordered_apps(app_names: list[str]) -> list[str]:
    preferred = [name for name in PREFERRED_ORDER if name in app_names]
    remaining = sorted([name for name in app_names if name not in PREFERRED_ORDER])
    return preferred + remaining


def load_manifests(apps_dir: Path, app_names: list[str]) -> tuple[dict[str, dict[str, Any]], list[str]]:
    errors: list[str] = []
    manifests: dict[str, dict[str, Any]] = {}

    for app in app_names:
        manifest_path = apps_dir / app / MANIFEST_FILE
        if not manifest_path.exists():
            errors.append(f"Missing manifest: {manifest_path}")
            continue

        try:
            manifest = parse_simple_yaml(manifest_path)
        except ValueError as exc:
            errors.append(str(exc))
            continue

        manifest.setdefault("app", app)
        for key in LIST_KEYS:
            value = manifest.get(key, [])
            if isinstance(value, list):
                manifest[key] = [str(item) for item in value]
            elif value in (None, ""):
                manifest[key] = []
            else:
                errors.append(f"{manifest_path}: key '{key}' must be a YAML list")
                manifest[key] = []

        if manifest.get("app") != app:
            errors.append(
                f"{manifest_path}: app value '{manifest.get('app')}' does not match directory '{app}'"
            )

        manifests[app] = manifest

    return manifests, errors


def validate_unique_manifest_ownership(manifests: dict[str, dict[str, Any]]) -> list[str]:
    errors: list[str] = []

    for key in LIST_KEYS:
        owners: dict[str, str] = {}
        for app, manifest in manifests.items():
            for item in manifest.get(key, []):
                current = owners.get(item)
                if current and current != app:
                    errors.append(
                        f"Ownership collision for {key}='{item}': {current} and {app}"
                    )
                owners[item] = app

    return errors


def load_json_part(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"indexes": [], "fieldOverrides": []}
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"{path}: part file must be a JSON object")
    payload.setdefault("indexes", [])
    payload.setdefault("fieldOverrides", [])
    if not isinstance(payload["indexes"], list):
        raise ValueError(f"{path}: 'indexes' must be an array")
    if not isinstance(payload["fieldOverrides"], list):
        raise ValueError(f"{path}: 'fieldOverrides' must be an array")
    return payload


def find_match_paths(fragment_text: str) -> set[str]:
    paths: set[str] = set()
    for line in fragment_text.splitlines():
        match = MATCH_RE.match(line)
        if match:
            paths.add(match.group(1).strip())
    return paths


def validate_rules_parts(apps_dir: Path, manifests: dict[str, dict[str, Any]]) -> list[str]:
    errors: list[str] = []
    owners: dict[str, str] = {}

    for app in manifests:
        part_path = apps_dir / app / RULES_PART_FILE
        if not part_path.exists():
            errors.append(f"Missing rules part: {part_path}")
            continue

        fragment = part_path.read_text(encoding="utf-8")
        paths = find_match_paths(fragment)

        for path in paths:
            current = owners.get(path)
            if current and current != app:
                errors.append(f"Rules path '{path}' appears in both {current} and {app} fragments")
            owners[path] = app

        for declared_path in manifests[app].get("rules_paths", []):
            if declared_path not in paths:
                errors.append(
                    f"{part_path}: declared rules path '{declared_path}' not found in fragment"
                )

    return errors


def validate_storage_parts(apps_dir: Path, manifests: dict[str, dict[str, Any]]) -> list[str]:
    errors: list[str] = []
    owners: dict[str, str] = {}

    for app in manifests:
        part_path = apps_dir / app / STORAGE_PART_FILE
        if not part_path.exists():
            errors.append(f"Missing storage part: {part_path}")
            continue

        fragment = part_path.read_text(encoding="utf-8")
        paths = find_match_paths(fragment)

        for path in paths:
            current = owners.get(path)
            if current and current != app:
                errors.append(f"Storage path '{path}' appears in both {current} and {app} fragments")
            owners[path] = app

        for declared_path in manifests[app].get("storage_paths", []):
            if declared_path not in paths:
                errors.append(
                    f"{part_path}: declared storage path '{declared_path}' not found in fragment"
                )

    return errors


def validate_index_parts(apps_dir: Path, manifests: dict[str, dict[str, Any]]) -> list[str]:
    errors: list[str] = []
    owners: dict[str, str] = {}

    for app in manifests:
        part_path = apps_dir / app / INDEXES_PART_FILE
        if not part_path.exists():
            errors.append(f"Missing indexes part: {part_path}")
            continue

        try:
            payload = load_json_part(part_path)
        except ValueError as exc:
            errors.append(str(exc))
            continue

        part_groups: set[str] = set()
        for index in payload["indexes"]:
            group = str(index.get("collectionGroup", "")).strip()
            if not group:
                errors.append(f"{part_path}: index missing non-empty collectionGroup")
                continue

            part_groups.add(group)
            current = owners.get(group)
            if current and current != app:
                errors.append(f"Index collectionGroup '{group}' appears in both {current} and {app}")
            owners[group] = app

        declared_groups = set(manifests[app].get("index_collection_groups", []))
        missing_groups = declared_groups.difference(part_groups)
        if missing_groups:
            errors.append(
                f"{part_path}: declared collection groups missing in fragment: {sorted(missing_groups)}"
            )

    return errors


def validate(root_dir: Path) -> list[str]:
    apps_dir = root_dir / "apps"
    if not apps_dir.exists():
        return [f"Missing apps directory: {apps_dir}"]

    app_names = discover_apps(apps_dir)
    manifests, errors = load_manifests(apps_dir, app_names)
    errors.extend(validate_unique_manifest_ownership(manifests))
    errors.extend(validate_rules_parts(apps_dir, manifests))
    errors.extend(validate_index_parts(apps_dir, manifests))
    errors.extend(validate_storage_parts(apps_dir, manifests))
    return errors


def normalize_fragment_lines(fragment: str) -> list[str]:
    output: list[str] = []
    for line in fragment.rstrip().splitlines():
        if not line.strip():
            output.append("")
            continue
        if line.startswith("    "):
            output.append(line.rstrip())
        else:
            output.append(f"    {line.rstrip()}")
    return output


def compose_firestore_rules(root_dir: Path, app_names: list[str]) -> str:
    apps_dir = root_dir / "apps"
    lines = [
        "rules_version = '2';",
        "",
        "service cloud.firestore {",
        "  match /databases/{database}/documents {",
        "",
    ]

    for app in app_names:
        fragment_path = apps_dir / app / RULES_PART_FILE
        fragment = fragment_path.read_text(encoding="utf-8")
        lines.append(f"    // BEGIN {app}")
        lines.extend(normalize_fragment_lines(fragment))
        lines.append(f"    // END {app}")
        lines.append("")

    lines.extend(["  }", "}"])
    return "\n".join(lines) + "\n"


def compose_storage_rules(root_dir: Path, app_names: list[str]) -> str:
    apps_dir = root_dir / "apps"
    lines = [
        "rules_version = '2';",
        "",
        "service firebase.storage {",
        "  match /b/{bucket}/o {",
        "",
    ]

    for app in app_names:
        fragment_path = apps_dir / app / STORAGE_PART_FILE
        fragment = fragment_path.read_text(encoding="utf-8")
        lines.append(f"    // BEGIN {app}")
        lines.extend(normalize_fragment_lines(fragment))
        lines.append(f"    // END {app}")
        lines.append("")

    lines.extend(["  }", "}"])
    return "\n".join(lines) + "\n"


def canonical_json(item: dict[str, Any]) -> str:
    return json.dumps(item, sort_keys=True, separators=(",", ":"))


def compose_indexes(root_dir: Path, app_names: list[str]) -> dict[str, Any]:
    apps_dir = root_dir / "apps"
    all_indexes: list[dict[str, Any]] = []
    all_overrides: list[dict[str, Any]] = []

    for app in app_names:
        payload = load_json_part(apps_dir / app / INDEXES_PART_FILE)
        for index in payload["indexes"]:
            all_indexes.append(index)
        for override in payload["fieldOverrides"]:
            all_overrides.append(override)

    dedup_indexes: dict[str, dict[str, Any]] = {}
    dedup_overrides: dict[str, dict[str, Any]] = {}

    for index in all_indexes:
        dedup_indexes[canonical_json(index)] = index

    for override in all_overrides:
        dedup_overrides[canonical_json(override)] = override

    indexes_sorted = sorted(
        dedup_indexes.values(),
        key=lambda item: (
            str(item.get("collectionGroup", "")),
            str(item.get("queryScope", "")),
            canonical_json({"fields": item.get("fields", [])}),
            canonical_json(item),
        ),
    )
    overrides_sorted = sorted(
        dedup_overrides.values(),
        key=lambda item: (
            str(item.get("collectionGroup", "")),
            str(item.get("fieldPath", "")),
            canonical_json(item),
        ),
    )

    return {
        "indexes": indexes_sorted,
        "fieldOverrides": overrides_sorted,
    }


def check_or_write(path: Path, content: str, check: bool) -> list[str]:
    errors: list[str] = []
    current = path.read_text(encoding="utf-8") if path.exists() else None

    if check:
        if current != content:
            errors.append(f"Generated file out of date: {path}")
        return errors

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return errors


def compose(root_dir: Path, check: bool = False) -> list[str]:
    apps_dir = root_dir / "apps"
    generated_dir = root_dir / "generated"

    app_names = ordered_apps(discover_apps(apps_dir))

    firestore_rules = compose_firestore_rules(root_dir, app_names)
    storage_rules = compose_storage_rules(root_dir, app_names)
    indexes_payload = compose_indexes(root_dir, app_names)
    indexes_text = json.dumps(indexes_payload, indent=2) + "\n"

    errors: list[str] = []
    errors.extend(check_or_write(generated_dir / "firestore.rules", firestore_rules, check=check))
    errors.extend(check_or_write(generated_dir / "storage.rules", storage_rules, check=check))
    errors.extend(
        check_or_write(generated_dir / "firestore.indexes.json", indexes_text, check=check)
    )

    return errors


def run(validate_only: bool, compose_only: bool, root_dir: Path, check: bool) -> int:
    errors: list[str] = []

    if not compose_only:
        errors.extend(validate(root_dir))

    if not validate_only:
        errors.extend(compose(root_dir, check=check))

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    print("OK")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        default=str(Path(__file__).resolve().parents[1]),
        help="Path to firebase_infra root",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    validate_parser = subparsers.add_parser("validate", help="Validate ownership and fragments")
    validate_parser.set_defaults(validate_only=True, compose_only=False)

    compose_parser = subparsers.add_parser("compose", help="Compose generated artifacts")
    compose_parser.add_argument(
        "--check",
        action="store_true",
        help="Fail if generated files differ from on-disk content",
    )
    compose_parser.set_defaults(validate_only=False, compose_only=True)

    all_parser = subparsers.add_parser("all", help="Validate and compose artifacts")
    all_parser.add_argument(
        "--check",
        action="store_true",
        help="Fail if generated files differ from on-disk content",
    )
    all_parser.set_defaults(validate_only=False, compose_only=False)

    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root_dir = Path(args.root).resolve()
    return run(
        validate_only=getattr(args, "validate_only", False),
        compose_only=getattr(args, "compose_only", False),
        root_dir=root_dir,
        check=getattr(args, "check", False),
    )


if __name__ == "__main__":
    sys.exit(main())
