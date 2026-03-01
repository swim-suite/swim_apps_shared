from __future__ import annotations

import os
import re
from typing import Iterable

_ALIAS_PATTERNS = [
    re.compile(r"/clubs/[^\s'\"`]+/users(?:/|$)"),
    re.compile(r"clubs/\{[^}]+\}/users(?:/|$)"),
    re.compile(
        r"collection\(\s*(?:(['\"])clubs\1|CLUBS_COLLECTION)\s*\)\s*"
        r"\.\s*document\([^)]*\)\s*"
        r"\.\s*collection\(\s*(['\"])users\2\s*\)",
        re.DOTALL,
    ),
    re.compile(
        r"document\(\s*club_doc\([^)]*\)\s*\)\s*"
        r"\.\s*collection\(\s*(['\"])users\1\s*\)",
        re.DOTALL,
    ),
]



def assert_no_alias_paths(path: str) -> None:
    candidate = str(path or "")
    for pattern in _ALIAS_PATTERNS:
        if pattern.search(candidate):
            raise ValueError(f"Forbidden legacy alias path usage detected: {candidate}")



def _iter_text_files(root_dir: str) -> Iterable[str]:
    skip_dirs = {
        ".git",
        "venv",
        ".venv",
        "node_modules",
        "build",
        "__pycache__",
        ".dart_tool",
        ".idea",
        ".firebase",
    }
    allowed_ext = {
        ".py",
        ".pyi",
        ".txt",
        ".md",
        ".rules",
        ".yaml",
        ".yml",
        ".json",
        ".toml",
    }

    for current_root, dirs, files in os.walk(root_dir):
        dirs[:] = [d for d in dirs if d not in skip_dirs]
        for filename in files:
            _, ext = os.path.splitext(filename)
            if ext.lower() not in allowed_ext:
                continue
            yield os.path.join(current_root, filename)



def scan_repo_for_alias_paths(root_dir: str) -> list[tuple[str, int]]:
    findings: list[tuple[str, int]] = []
    for file_path in _iter_text_files(root_dir):
        try:
            with open(file_path, "r", encoding="utf-8") as handle:
                content = handle.read()
                matched_lines: set[int] = set()
                for pattern in _ALIAS_PATTERNS:
                    for match in pattern.finditer(content):
                        line_number = content.count("\n", 0, match.start()) + 1
                        if line_number in matched_lines:
                            continue
                        matched_lines.add(line_number)
                        findings.append((file_path, line_number))
        except (OSError, UnicodeDecodeError):
            continue
    return findings
