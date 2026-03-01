from __future__ import annotations

from typing import Any

USERS_COLLECTION = "users"
CLUBS_COLLECTION = "clubs"
MEMBERS_SUBCOLLECTION = "members"
GROUPS_SUBCOLLECTION = "groups"



def _required_id(value: str, field_name: str) -> str:
    normalized = str(value or "").strip()
    if not normalized:
        raise ValueError(f"{field_name} must be a non-empty string")
    if "/" in normalized:
        raise ValueError(f"{field_name} must not contain '/'")
    return normalized



def user_doc(uid: str) -> str:
    return f"{USERS_COLLECTION}/{_required_id(uid, 'uid')}"



def club_doc(club_id: str) -> str:
    return f"{CLUBS_COLLECTION}/{_required_id(club_id, 'club_id')}"



def club_members_col(club_id: str) -> str:
    return f"{club_doc(club_id)}/{MEMBERS_SUBCOLLECTION}"



def club_member_doc(club_id: str, uid: str) -> str:
    return f"{club_members_col(club_id)}/{_required_id(uid, 'uid')}"



def groups_col(club_id: str) -> str:
    return f"{club_doc(club_id)}/{GROUPS_SUBCOLLECTION}"



def group_doc(club_id: str, group_id: str) -> str:
    return f"{groups_col(club_id)}/{_required_id(group_id, 'group_id')}"



def user_ref(db: Any, uid: str):
    return db.collection(USERS_COLLECTION).document(_required_id(uid, "uid"))



def club_members_ref(db: Any, club_id: str):
    return db.collection(CLUBS_COLLECTION).document(_required_id(club_id, "club_id")).collection(MEMBERS_SUBCOLLECTION)



def club_member_ref(db: Any, club_id: str, uid: str):
    return club_members_ref(db, club_id).document(_required_id(uid, "uid"))



def groups_ref(db: Any, club_id: str):
    return db.collection(CLUBS_COLLECTION).document(_required_id(club_id, "club_id")).collection(GROUPS_SUBCOLLECTION)



def group_ref(db: Any, club_id: str, group_id: str):
    return groups_ref(db, club_id).document(_required_id(group_id, "group_id"))
