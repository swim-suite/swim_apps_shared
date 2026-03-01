from __future__ import annotations

import pytest

from swim_apps_shared.firestore.paths import (
    club_doc,
    club_member_doc,
    club_members_col,
    group_doc,
    groups_col,
    user_doc,
)


class _FakeRef:
    def __init__(self, path: str):
        self.path = path

    def collection(self, name: str):
        return _FakeCollectionRef(f"{self.path}/{name}")


class _FakeCollectionRef:
    def __init__(self, path: str):
        self.path = path

    def document(self, doc_id: str):
        return _FakeRef(f"{self.path}/{doc_id}")


class _FakeDB:
    def collection(self, name: str):
        return _FakeCollectionRef(name)


def test_path_builders():
    assert user_doc("u1") == "users/u1"
    assert club_doc("c1") == "clubs/c1"
    assert club_members_col("c1") == "clubs/c1/members"
    assert club_member_doc("c1", "u1") == "clubs/c1/members/u1"
    assert groups_col("c1") == "clubs/c1/groups"
    assert group_doc("c1", "g1") == "clubs/c1/groups/g1"


def test_empty_id_raises():
    with pytest.raises(ValueError):
        user_doc("")

    with pytest.raises(ValueError):
        club_member_doc("club", "")


def test_ref_builders():
    from swim_apps_shared.firestore.paths import (
        club_member_ref,
        club_members_ref,
        group_ref,
        groups_ref,
        user_ref,
    )

    db = _FakeDB()
    assert user_ref(db, "u1").path == "users/u1"
    assert club_members_ref(db, "c1").path == "clubs/c1/members"
    assert club_member_ref(db, "c1", "u1").path == "clubs/c1/members/u1"
    assert groups_ref(db, "c1").path == "clubs/c1/groups"
    assert group_ref(db, "c1", "g1").path == "clubs/c1/groups/g1"
