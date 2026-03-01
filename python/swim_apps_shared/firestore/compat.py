"""Deprecated compatibility helpers for legacy alias membership shape.

Deprecated: use /clubs/{clubId}/members as canonical membership source.
This module exists only for temporary dual-read support during migration.
"""

from __future__ import annotations

import logging
from typing import Any

from swim_apps_shared.domain.models import ClubMember
from swim_apps_shared.firestore.paths import (
    club_doc,
    club_members_ref,
)

DEPRECATION_REMOVE_AFTER = "2026-06-30"

_LOGGER = logging.getLogger(__name__)



def _as_active_status(value: Any) -> str:
    raw = str(value or "").strip().lower()
    if raw in {"inactive", "disabled", "revoked", "pending"}:
        return "inactive"
    return "active"



def _map_alias_doc_to_member(uid: str, payload: dict[str, Any]) -> ClubMember:
    role = str(payload.get("role") or payload.get("userType") or "swimmer").strip().lower()
    if role in {"clubadmin", "owner"}:
        role = "admin"
    if role not in {"swimmer", "coach", "admin"}:
        role = "swimmer"

    normalized_payload = {
        "uid": uid,
        "role": role,
        "groupId": payload.get("groupId") or payload.get("teamId"),
        "status": _as_active_status(payload.get("status") or payload.get("active")),
        "joinedAt": payload.get("joinedAt") or payload.get("registerDate") or payload.get("createdAt"),
    }
    return ClubMember.from_firestore_dict(normalized_payload)



def get_club_members(db: Any, club_id: str) -> list[ClubMember]:
    member_docs = list(club_members_ref(db, club_id).stream())
    if member_docs:
        out: list[ClubMember] = []
        for member_doc in member_docs:
            payload = member_doc.to_dict() or {}
            payload.setdefault("uid", member_doc.id)
            out.append(ClubMember.from_firestore_dict(payload))
        return out

    alias_docs = list(
        db.document(club_doc(club_id))
        .collection("users")
        .stream()
    )

    if alias_docs:
        _LOGGER.warning(
            "Compat fallback to legacy alias membership path /clubs/{clubId}/users",
            extra={"club_id": club_id, "remove_after": DEPRECATION_REMOVE_AFTER},
        )

    fallback_members: list[ClubMember] = []
    for alias_doc in alias_docs:
        payload = alias_doc.to_dict() or {}
        uid = str(payload.get("uid") or payload.get("userId") or alias_doc.id).strip()
        if not uid:
            continue
        fallback_members.append(_map_alias_doc_to_member(uid, payload))
    return fallback_members
