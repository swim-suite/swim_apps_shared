from __future__ import annotations

from datetime import datetime, timezone

from swim_apps_shared.domain.models import ClubMember, Group, User


class _FakeTimestamp:
    def __init__(self, dt: datetime):
        self._dt = dt

    def to_datetime(self) -> datetime:
        return self._dt


def test_user_from_and_to_firestore_dict_roundtrip():
    source = {
        "displayName": "Jane",
        "email": "jane@example.com",
        "photoURL": "https://example.com/jane.png",
        "createdAt": _FakeTimestamp(datetime(2026, 1, 1, tzinfo=timezone.utc)),
        "roles": ["coach", "staff"],
    }

    user = User.from_firestore_dict(source)

    assert user.display_name == "Jane"
    assert user.email == "jane@example.com"
    assert user.roles == ["coach", "staff"]

    payload = user.to_firestore_dict()
    assert payload["displayName"] == "Jane"
    assert payload["email"] == "jane@example.com"
    assert payload["roles"] == ["coach", "staff"]


def test_club_member_normalizes_role_and_status():
    member = ClubMember.from_firestore_dict(
        {
            "uid": "u1",
            "role": "clubadmin",
            "status": "pending",
            "joinedAt": "2026-02-01T10:00:00Z",
            "groupId": "g1",
        }
    )

    assert member.uid == "u1"
    assert member.role == "admin"
    assert member.status == "inactive"
    assert member.group_id == "g1"


def test_group_from_and_to_firestore_dict_roundtrip():
    group = Group.from_firestore_dict(
        {
            "name": "A Group",
            "coachIds": ["c1", "c2"],
            "createdAt": datetime(2026, 2, 2, tzinfo=timezone.utc),
        }
    )

    assert group.name == "A Group"
    assert group.coach_ids == ["c1", "c2"]

    payload = group.to_firestore_dict()
    assert payload["name"] == "A Group"
    assert payload["coachIds"] == ["c1", "c2"]
