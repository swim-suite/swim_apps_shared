#!/usr/bin/env python3
"""
Export area -> allowed domain objects mapping.

Combines:
- swim_apps_shared_domain.json
- swim_apps_shared_areas.json

Outputs:
- swim_apps_shared_area_domain_map.json
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]  # swim_apps_shared/
AI_CONTEXT = ROOT / ".ai_context"

DOMAIN_FILE = AI_CONTEXT / "swim_apps_shared_domain.json"
AREAS_FILE = AI_CONTEXT / "swim_apps_shared_areas.json"
OUT_FILE = AI_CONTEXT / "swim_apps_shared_area_domain_map.json"

if not DOMAIN_FILE.exists():
    raise RuntimeError(f"❌ Domain file not found: {DOMAIN_FILE}")

if not AREAS_FILE.exists():
    raise RuntimeError(f"❌ Areas file not found: {AREAS_FILE}")

domain = json.loads(DOMAIN_FILE.read_text(encoding="utf-8"))
areas = json.loads(AREAS_FILE.read_text(encoding="utf-8"))

classes = domain.get("classes", {})
enums = domain.get("enums", {})

area_map = {}

# --------------------------------------------------
# Build reverse lookup: lib-relative path -> classes/enums
# --------------------------------------------------
path_to_classes: dict[str, list[str]] = {}
for class_name, meta in classes.items():
    path = meta["path"].lstrip("/")  # ensure no leading slash
    path_to_classes.setdefault(path, []).append(class_name)

path_to_enums: dict[str, list[str]] = {}
for enum_name, meta in enums.items():
    path = meta["path"].lstrip("/")
    path_to_enums.setdefault(path, []).append(enum_name)


def normalize_area_path(p: str) -> str:
    """
    Convert:
      lib/objects/  -> objects/
    """
    if p.startswith("lib/"):
        return p[len("lib/"):]
    return p


def path_matches(area_paths: list[str], file_path: str) -> bool:
    file_path = file_path.lstrip("/")
    for area_path in area_paths:
        area_path = normalize_area_path(area_path)
        if file_path.startswith(area_path):
            return True
    return False


# --------------------------------------------------
# Build area → domain map
# --------------------------------------------------
for area_name, area_paths in areas.items():
    allowed_classes = set()
    allowed_enums = set()

    for file_path, class_list in path_to_classes.items():
        if path_matches(area_paths, file_path):
            allowed_classes.update(class_list)

    for file_path, enum_list in path_to_enums.items():
        if path_matches(area_paths, file_path):
            allowed_enums.update(enum_list)

    area_map[area_name] = {
        "paths": area_paths,
        "allowed_classes": sorted(allowed_classes),
        "allowed_enums": sorted(allowed_enums),
    }

OUT_FILE.write_text(json.dumps(area_map, indent=2), encoding="utf-8")

print(f"✅ Area-domain map exported to {OUT_FILE}")
print(f"   Areas: {len(area_map)}")

for area, data in area_map.items():
    print(f"   - {area}: {len(data['allowed_classes'])} classes, {len(data['allowed_enums'])} enums")
