#!/usr/bin/env python3
"""Synchronize Firestore composite indexes with desired JSON spec.

Used as a workflow fallback when `firebase deploy --only firestore:indexes --force`
fails early on an existing-index 409.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib import error, parse, request


def _run(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, text=True).strip()


def _get_access_token() -> str:
    token = _run(["gcloud", "auth", "print-access-token"])
    if not token:
        raise RuntimeError("Failed to obtain access token from gcloud")
    return token


def _api_call(
    *,
    method: str,
    url: str,
    token: str,
    quota_project: str,
    body: dict[str, Any] | None = None,
) -> tuple[int, dict[str, Any] | None]:
    payload = None if body is None else json.dumps(body).encode("utf-8")
    headers = {
        "Authorization": f"Bearer {token}",
        "x-goog-user-project": quota_project,
    }
    if payload is not None:
        headers["Content-Type"] = "application/json"
    req = request.Request(url=url, data=payload, headers=headers, method=method)
    try:
        with request.urlopen(req) as resp:
            data = resp.read().decode("utf-8")
            return resp.status, (json.loads(data) if data else None)
    except error.HTTPError as exc:
        data = exc.read().decode("utf-8")
        try:
            parsed = json.loads(data) if data else None
        except json.JSONDecodeError:
            parsed = {"raw": data}
        return exc.code, parsed


@dataclass(frozen=True)
class IndexSpec:
    collection_group: str
    query_scope: str
    fields: tuple[tuple[tuple[str, Any], ...], ...]
    density: str

    @staticmethod
    def _norm_fields(fields: list[dict[str, Any]]) -> tuple[tuple[tuple[str, Any], ...], ...]:
        normalized: list[tuple[tuple[str, Any], ...]] = []
        for field in fields:
            item: dict[str, Any] = {"fieldPath": field["fieldPath"]}
            for key in ("order", "arrayConfig", "vectorConfig"):
                if key in field:
                    item[key] = field[key]
            normalized.append(tuple(sorted(item.items(), key=lambda kv: kv[0])))
        return tuple(normalized)

    @classmethod
    def from_desired(cls, raw: dict[str, Any]) -> "IndexSpec":
        return cls(
            collection_group=raw["collectionGroup"],
            query_scope=raw.get("queryScope", "COLLECTION"),
            fields=cls._norm_fields(raw.get("fields", [])),
            density=raw.get("density", "SPARSE_ALL"),
        )

    @classmethod
    def from_existing(cls, raw: dict[str, Any]) -> "IndexSpec":
        name = raw.get("name", "")
        if "/collectionGroups/" in name:
            collection_group = name.split("/collectionGroups/", 1)[1].split("/indexes/", 1)[0]
        else:
            collection_group = raw.get("collectionGroup", "")
        return cls(
            collection_group=collection_group,
            query_scope=raw.get("queryScope", "COLLECTION"),
            fields=cls._norm_fields(raw.get("fields", [])),
            density=raw.get("density", "SPARSE_ALL"),
        )

    def to_create_body(self) -> dict[str, Any]:
        fields: list[dict[str, Any]] = [dict(pairs) for pairs in self.fields]
        body: dict[str, Any] = {
            "queryScope": self.query_scope,
            "fields": fields,
        }
        if self.density:
            body["density"] = self.density
        return body


def _load_desired(path: Path) -> dict[IndexSpec, dict[str, Any]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    desired: dict[IndexSpec, dict[str, Any]] = {}
    for raw in payload.get("indexes", []):
        spec = IndexSpec.from_desired(raw)
        desired.setdefault(spec, raw)
    return desired


def _list_existing(project_id: str, token: str) -> dict[IndexSpec, str]:
    base_url = (
        "https://firestore.googleapis.com/v1/"
        f"projects/{project_id}/databases/(default)/collectionGroups/-/indexes"
    )
    url = base_url
    existing: dict[IndexSpec, str] = {}

    while True:
        status, payload = _api_call(
            method="GET",
            url=url,
            token=token,
            quota_project=project_id,
        )
        if status != 200 or payload is None:
            raise RuntimeError(f"Failed to list indexes (HTTP {status}): {payload}")

        for raw in payload.get("indexes", []):
            spec = IndexSpec.from_existing(raw)
            name = raw.get("name", "")
            if spec.collection_group and name:
                existing.setdefault(spec, name)

        next_page = payload.get("nextPageToken", "")
        if not next_page:
            break
        url = f"{base_url}?pageToken={parse.quote(next_page, safe='')}"

    return existing


def sync_indexes(project_id: str, indexes_file: Path, allow_delete: bool) -> None:
    token = _get_access_token()
    desired = _load_desired(indexes_file)
    existing = _list_existing(project_id, token)

    missing_specs = [spec for spec in desired if spec not in existing]
    extra_specs = [spec for spec in existing if spec not in desired]

    print(
        f"Index sync for {project_id}: desired={len(desired)} existing={len(existing)} "
        f"missing={len(missing_specs)} extra={len(extra_specs)}"
    )

    created = 0
    already_exists = 0
    for spec in missing_specs:
        group = parse.quote(spec.collection_group, safe="")
        url = (
            "https://firestore.googleapis.com/v1/"
            f"projects/{project_id}/databases/(default)/collectionGroups/{group}/indexes"
        )
        status, payload = _api_call(
            method="POST",
            url=url,
            token=token,
            quota_project=project_id,
            body=spec.to_create_body(),
        )
        if status in (200, 201):
            created += 1
            continue
        if status == 409:
            already_exists += 1
            continue
        raise RuntimeError(
            f"Failed to create index for {spec.collection_group} (HTTP {status}): {payload}"
        )

    deleted = 0
    if allow_delete:
        for spec in extra_specs:
            name = existing[spec]
            url = f"https://firestore.googleapis.com/v1/{name}"
            status, payload = _api_call(
                method="DELETE",
                url=url,
                token=token,
                quota_project=project_id,
            )
            if status in (200, 204, 404):
                deleted += 1
                continue
            raise RuntimeError(f"Failed to delete index {name} (HTTP {status}): {payload}")

    print(
        f"Index sync complete: created={created} already_exists={already_exists} "
        f"deleted={deleted}"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Sync Firestore composite indexes via API")
    parser.add_argument("--project-id", required=True, help="Firebase/GCP project ID")
    parser.add_argument(
        "--indexes-file",
        default="firebase_infra/generated/firestore.indexes.json",
        help="Path to firestore index spec JSON",
    )
    parser.add_argument(
        "--allow-delete",
        action="store_true",
        help="Delete existing indexes that are not present in the desired spec",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        sync_indexes(
            project_id=args.project_id,
            indexes_file=Path(args.indexes_file),
            allow_delete=args.allow_delete,
        )
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
