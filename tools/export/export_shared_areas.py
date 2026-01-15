#!/usr/bin/env python3
"""
Export authoritative AREA knowledge from swim_apps_shared.

Scans lib/* and groups folders into logical areas.
Output: .ai_context/swim_apps_shared_areas.json
"""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]  # swim_apps_shared/
LIB = ROOT / "lib"
OUT = ROOT / ".ai_context" / "swim_apps_shared_areas.json"

if not LIB.exists():
    raise RuntimeError(f"❌ lib/ directory not found at: {LIB}")


def normalize_area_name(name: str) -> str:
    """
    Normalize folder names to area keys.
    Examples:
      swim_session_v1 -> session
      userProfile     -> user_profile
      trainingPlanner -> training_planner
    """
    # camelCase → snake_case
    name = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", name)

    name = name.lower()

    # strip common prefixes
    name = re.sub(r"^swim_", "", name)

    # strip version suffixes
    name = re.sub(r"_v[0-9]+$", "", name)

    return name


def main():
    areas: dict[str, list[str]] = {}

    for item in LIB.iterdir():
        if not item.is_dir():
            continue

        folder_name = item.name
        area = normalize_area_name(folder_name)

        rel_path = f"lib/{folder_name}/"

        if area not in areas:
            areas[area] = []

        areas[area].append(rel_path)

    # sort for stability
    areas = {k: sorted(v) for k, v in sorted(areas.items())}

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(areas, indent=2), encoding="utf-8")

    print(f"✅ Areas exported to {OUT}")
    print(f"   Areas: {len(areas)}")
    for k, v in areas.items():
        print(f"   - {k}: {len(v)} paths")


if __name__ == "__main__":
    main()
