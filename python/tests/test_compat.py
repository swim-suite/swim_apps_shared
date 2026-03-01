from __future__ import annotations

from datetime import datetime, timezone

from swim_apps_shared.firestore.compat import get_club_members


class _FakeDoc:
    def __init__(self, doc_id: str, data: dict):
        self.id = doc_id
        self._data = data

    def to_dict(self):
        return dict(self._data)


class _FakeCollection:
    def __init__(self, store: dict[str, dict], path: str):
        self._store = store
        self._path = path

    def document(self, doc_id: str):
        return _FakeDocument(self._store, f"{self._path}/{doc_id}")

    def stream(self):
        prefix = f"{self._path}/"
        for key, value in self._store.items():
            if not key.startswith(prefix):
                continue
            suffix = key[len(prefix) :]
            if "/" in suffix:
                continue
            yield _FakeDoc(suffix, value)


class _FakeDocument:
    def __init__(self, store: dict[str, dict], path: str):
        self._store = store
        self._path = path

    def collection(self, name: str):
        return _FakeCollection(self._store, f"{self._path}/{name}")


class _FakeDB:
    def __init__(self, store: dict[str, dict]):
        self._store = store

    def collection(self, name: str):
        return _FakeCollection(self._store, name)


def test_get_club_members_prefers_members_collection(caplog):
    db = _FakeDB(
        {
            "clubs/club1/members/user1": {
                "uid": "user1",
                "role": "coach",
                "status": "active",
                "joinedAt": datetime(2026, 1, 1, tzinfo=timezone.utc),
            },
            "clubs/club1/users/legacy": {
                "uid": "legacy",
                "role": "swimmer",
                "status": "active",
            },
        }
    )

    members = get_club_members(db, "club1")

    assert len(members) == 1
    assert members[0].uid == "user1"
    assert "fallback" not in caplog.text.lower()


def test_get_club_members_falls_back_to_alias_users(caplog):
    db = _FakeDB(
        {
            "clubs/club1/users/legacy1": {
                "uid": "legacy1",
                "role": "clubadmin",
                "status": "pending",
                "groupId": "g1",
                "joinedAt": "2026-01-02T10:00:00Z",
            }
        }
    )

    members = get_club_members(db, "club1")

    assert len(members) == 1
    assert members[0].uid == "legacy1"
    assert members[0].role == "admin"
    assert members[0].status == "inactive"
    assert "legacy alias" in caplog.text.lower()
