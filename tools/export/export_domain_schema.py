#!/usr/bin/env python3
"""
Export authoritative domain knowledge from swim_apps_shared.

v2 additions:
- Parameter types
- Field types
"""

import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]  # swim_apps_shared/
LIB = ROOT / "lib"
OUT = ROOT / ".ai_context" / "swim_apps_shared_domain.json"

if not LIB.exists():
    raise RuntimeError(f"❌ lib/ directory not found at: {LIB}")

CLASS_RE = re.compile(r"class\s+(\w+)")
ENUM_RE = re.compile(r"enum\s+(\w+)\s*\{([^}]+)\}", re.MULTILINE)

# Fields like: final DateTime startTime;
FIELD_RE = re.compile(
    r"(final|late|const)?\s*([\w<>, ?]+)\s+(\w+)\s*;",
)

# Constructor with named params
CTOR_RE = re.compile(
    r"\b(\w+)\s*\(\s*\{([\s\S]*?)\}\s*\);",
    re.MULTILINE,
)

# Constructor param lines:
# required this.startTime,
# this.assignedIds = const [],
CTOR_PARAM_RE = re.compile(
    r"(required\s+)?this\.(\w+)(\s*=\s*([^,]+))?,?"
)

# Optional typed param (rare but valid):
# required DateTime startTime,
TYPED_PARAM_RE = re.compile(
    r"(required\s+)?([\w<>, ?]+)\s+(\w+)(\s*=\s*([^,]+))?,?"
)


def relpath(p: Path) -> str:
    return str(p.relative_to(LIB)).replace("\\", "/")


def parse_fields(code: str) -> dict:
    fields = {}
    for _, type_, name in FIELD_RE.findall(code):
        fields[name] = type_.strip()
    return fields


def parse_constructor(class_name: str, code: str, fields: dict):
    for match in CTOR_RE.finditer(code):
        ctor_name, body = match.groups()
        if ctor_name != class_name:
            continue

        params = {}

        # this.foo params
        for req, name, _, default in CTOR_PARAM_RE.findall(body):
            params[name] = {
                "required": bool(req),
                "default": default.strip() if default else None,
                "type": fields.get(name),
            }

        # typed params (rare but supported)
        for req, type_, name, _, default in TYPED_PARAM_RE.findall(body):
            if name in params:
                continue
            params[name] = {
                "required": bool(req),
                "default": default.strip() if default else None,
                "type": type_.strip(),
            }

        return params

    return None


def parse_enum(code: str):
    enums = {}
    for name, body in ENUM_RE.findall(code):
        values = [
            v.strip()
            for v in body.split(",")
            if v.strip() and not v.strip().startswith("//")
        ]
        enums[name] = values
    return enums


def main():
    domain = {
        "classes": {},
        "enums": {},
        "generated_from": "swim_apps_shared",
        "schema_version": 2,
    }

    for dart_file in LIB.rglob("*.dart"):
        code = dart_file.read_text(encoding="utf-8", errors="ignore")

        # Enums
        for enum_name, values in parse_enum(code).items():
            domain["enums"][enum_name] = {
                "path": relpath(dart_file),
                "values": values,
            }

        # Classes
        for class_name in CLASS_RE.findall(code):
            fields = parse_fields(code)
            ctor_params = parse_constructor(class_name, code, fields)

            if not ctor_params:
                continue

            domain["classes"][class_name] = {
                "path": relpath(dart_file),
                "fields": fields,
                "constructor": {
                    "params": ctor_params
                },
            }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(domain, indent=2), encoding="utf-8")

    print(f"✅ Domain schema exported to {OUT}")
    print(f"   Classes: {len(domain['classes'])}")
    print(f"   Enums:   {len(domain['enums'])}")
    print("   Schema version: 2")


if __name__ == "__main__":
    main()
