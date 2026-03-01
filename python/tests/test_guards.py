from __future__ import annotations

import pathlib

import pytest

from swim_apps_shared.firestore.guards import assert_no_alias_paths, scan_repo_for_alias_paths


def test_assert_no_alias_paths_accepts_safe_path():
    assert_no_alias_paths("clubs/club1/members/user1")


def test_assert_no_alias_paths_rejects_alias_path():
    with pytest.raises(ValueError):
        assert_no_alias_paths("clubs/club1/users/alias")


def test_assert_no_alias_paths_rejects_builder_alias_path():
    with pytest.raises(ValueError):
        assert_no_alias_paths(
            'db.collection(CLUBS_COLLECTION).document(club_id).collection("users")'
        )


def test_assert_no_alias_paths_rejects_club_doc_builder_alias_path():
    with pytest.raises(ValueError):
        assert_no_alias_paths('db.document(club_doc(club_id)).collection("users")')


def test_scan_repo_for_alias_paths(tmp_path: pathlib.Path):
    safe = tmp_path / "safe.py"
    unsafe = tmp_path / "unsafe.py"
    unsafe_builder = tmp_path / "unsafe_builder.py"

    safe.write_text('print("clubs/club1/members/user1")\n', encoding="utf-8")
    unsafe.write_text('path = "clubs/club1/users/alias"\n', encoding="utf-8")
    unsafe_builder.write_text(
        (
            "query = (\n"
            "    db.collection(CLUBS_COLLECTION)\n"
            "      .document(club_id)\n"
            "      .collection(\"users\")\n"
            ")\n"
        ),
        encoding="utf-8",
    )

    findings = scan_repo_for_alias_paths(str(tmp_path))
    normalized = sorted((pathlib.Path(path).name, line) for path, line in findings)
    assert normalized == [("unsafe.py", 1), ("unsafe_builder.py", 2)]
