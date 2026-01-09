import os
import json

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LIB_DIR = os.path.join(ROOT, "lib")
OUT_DIR = os.path.join(ROOT, ".ai_context")
OUT_FILE = os.path.join(OUT_DIR, "swim_apps_shared_index.json")


def build_index():
    index = {}

    for root, _, files in os.walk(LIB_DIR):
        for file in files:
            if not file.endswith(".dart"):
                continue

            abs_path = os.path.join(root, file)
            rel_path = os.path.relpath(abs_path, ROOT).replace("\\", "/")

            # Convert to canonical package import
            pkg_path = rel_path.replace("lib/", "package:swim_apps_shared/")

            index[pkg_path] = rel_path

    return index


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    index = build_index()

    with open(OUT_FILE, "w", encoding="utf-8") as f:
        json.dump(index, f, indent=2, sort_keys=True)

    print(f"✅ Shared index exported: {OUT_FILE}")
    print(f"   Entries: {len(index)}")


if __name__ == "__main__":
    main()
