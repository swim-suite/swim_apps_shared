#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path
from typing import Callable


_ALLOWED_FILES = {
    "python/swim_apps_shared/firestore/compat.py",
    "python/swim_apps_shared/firestore/guards.py",
    "python/tests/test_compat.py",
    "python/tests/test_guards.py",
    "scripts/check_no_alias_paths.py",
}


def _load_scanner() -> Callable[[str], list[tuple[str, int]]]:
    try:
        from swim_apps_shared.firestore.guards import scan_repo_for_alias_paths

        return scan_repo_for_alias_paths
    except Exception:
        repo_root = Path(__file__).resolve().parents[1]
        local_python = repo_root / "python"
        if local_python.exists():
            sys.path.insert(0, str(local_python))
            from swim_apps_shared.firestore.guards import scan_repo_for_alias_paths

            return scan_repo_for_alias_paths
        raise


def _to_rel_path(root: Path, file_path: str) -> str:
    return Path(file_path).resolve().relative_to(root).as_posix()


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    scanner = _load_scanner()
    findings = scanner(str(root))

    blocked: list[tuple[str, int]] = []
    for file_path, line in findings:
        rel = _to_rel_path(root, file_path)
        if rel in _ALLOWED_FILES:
            continue
        blocked.append((rel, line))

    if blocked:
        print("Forbidden legacy alias path usage detected:")
        for rel, line in sorted(blocked):
            print(f"{rel}:{line}")
        return 1

    print("No forbidden alias paths detected.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
