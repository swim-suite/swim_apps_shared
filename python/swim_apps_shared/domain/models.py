from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Literal


MemberRole = Literal["swimmer", "coach", "admin"]
MemberStatus = Literal["active", "inactive"]



def _utc_now() -> datetime:
    return datetime.now(timezone.utc)



def _to_utc_datetime(value: Any, *, default: datetime | None = None) -> datetime:
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)

    if hasattr(value, "to_datetime"):
        try:
            as_dt = value.to_datetime()
            if isinstance(as_dt, datetime):
                return as_dt if as_dt.tzinfo else as_dt.replace(tzinfo=timezone.utc)
        except Exception:
            pass

    if hasattr(value, "timestamp"):
        try:
            ts = value.timestamp()
            if isinstance(ts, datetime):
                return ts if ts.tzinfo else ts.replace(tzinfo=timezone.utc)
            if isinstance(ts, (int, float)):
                return datetime.fromtimestamp(float(ts), tz=timezone.utc)
        except Exception:
            pass

    if isinstance(value, str):
        raw = value.strip()
        if raw:
            normalized = raw[:-1] + "+00:00" if raw.endswith("Z") else raw
            try:
                parsed = datetime.fromisoformat(normalized)
                return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
            except ValueError:
                pass

    return default or _utc_now()



def _as_non_empty_str(value: Any, *, default: str = "") -> str:
    text = str(value or "").strip()
    return text if text else default



def _as_optional_str(value: Any) -> str | None:
    text = str(value or "").strip()
    return text or None



def _as_list_of_str(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    out: list[str] = []
    for item in value:
        text = str(item or "").strip()
        if text:
            out.append(text)
    return out



def _normalize_member_role(value: Any) -> MemberRole:
    role = _as_non_empty_str(value, default="swimmer").lower()
    if role in {"swimmer", "coach", "admin"}:
        return role  # type: ignore[return-value]
    if role in {"clubadmin", "owner"}:
        return "admin"
    return "swimmer"



def _normalize_member_status(value: Any) -> MemberStatus:
    status = _as_non_empty_str(value, default="active").lower()
    if status in {"active", "inactive"}:
        return status  # type: ignore[return-value]
    if status in {"pending", "disabled", "revoked"}:
        return "inactive"
    return "active"


@dataclass(frozen=True)
class User:
    display_name: str
    email: str
    photo_url: str | None
    created_at: datetime
    roles: list[str]

    @staticmethod
    def from_firestore_dict(data: dict[str, Any]) -> "User":
        payload = dict(data or {})
        return User(
            display_name=_as_non_empty_str(payload.get("displayName") or payload.get("name"), default=""),
            email=_as_non_empty_str(payload.get("email"), default=""),
            photo_url=_as_optional_str(payload.get("photoURL")),
            created_at=_to_utc_datetime(payload.get("createdAt")),
            roles=_as_list_of_str(payload.get("roles")),
        )

    def to_firestore_dict(self) -> dict[str, Any]:
        return {
            "displayName": self.display_name,
            "email": self.email,
            "photoURL": self.photo_url,
            "createdAt": self.created_at,
            "roles": list(self.roles),
        }


@dataclass(frozen=True)
class ClubMember:
    uid: str
    role: MemberRole
    group_id: str | None
    status: MemberStatus
    joined_at: datetime

    @staticmethod
    def from_firestore_dict(data: dict[str, Any]) -> "ClubMember":
        payload = dict(data or {})
        uid = _as_non_empty_str(payload.get("uid") or payload.get("userId"), default="")
        return ClubMember(
            uid=uid,
            role=_normalize_member_role(payload.get("role") or payload.get("userType")),
            group_id=_as_optional_str(payload.get("groupId")),
            status=_normalize_member_status(payload.get("status") or payload.get("membershipStatus")),
            joined_at=_to_utc_datetime(payload.get("joinedAt") or payload.get("registerDate") or payload.get("createdAt")),
        )

    def to_firestore_dict(self) -> dict[str, Any]:
        return {
            "uid": self.uid,
            "role": self.role,
            "groupId": self.group_id,
            "status": self.status,
            "joinedAt": self.joined_at,
        }


@dataclass(frozen=True)
class Group:
    name: str
    coach_ids: list[str]
    created_at: datetime

    @staticmethod
    def from_firestore_dict(data: dict[str, Any]) -> "Group":
        payload = dict(data or {})
        return Group(
            name=_as_non_empty_str(payload.get("name"), default=""),
            coach_ids=_as_list_of_str(payload.get("coachIds")),
            created_at=_to_utc_datetime(payload.get("createdAt")),
        )

    def to_firestore_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "coachIds": list(self.coach_ids),
            "createdAt": self.created_at,
        }
