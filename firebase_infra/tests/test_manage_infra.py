import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools import manage_infra


class ManageInfraTests(unittest.TestCase):
    def _create_app(
        self,
        root: Path,
        app: str,
        rules_paths: list[str],
        index_groups: list[str],
        storage_paths: list[str],
        rules_part: str,
        indexes_part: dict,
        storage_part: str,
    ) -> None:
        app_dir = root / "apps" / app
        app_dir.mkdir(parents=True, exist_ok=True)

        manifest_lines = [
            f"app: {app}",
            "rules_paths:",
            *[f"  - \"{path}\"" for path in rules_paths],
            "index_collection_groups:",
            *[f"  - \"{group}\"" for group in index_groups],
            "storage_paths:",
            *[f"  - \"{path}\"" for path in storage_paths],
            "",
        ]
        (app_dir / "ownership.yaml").write_text("\n".join(manifest_lines), encoding="utf-8")
        (app_dir / "firestore.rules.part").write_text(rules_part, encoding="utf-8")
        (app_dir / "firestore.indexes.part.json").write_text(
            json.dumps(indexes_part, indent=2) + "\n", encoding="utf-8"
        )
        (app_dir / "storage.rules.part").write_text(storage_part, encoding="utf-8")

    def test_validate_detects_rules_ownership_conflict(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir) / "firebase_infra"
            (root / "apps").mkdir(parents=True, exist_ok=True)
            (root / "generated").mkdir(parents=True, exist_ok=True)

            self._create_app(
                root,
                app="swimify",
                rules_paths=["/users/{userId}"],
                index_groups=["users"],
                storage_paths=["/clubs/{clubId}/branding/logo.png"],
                rules_part='    match /users/{userId} {\\n      allow read: if true;\\n    }\\n',
                indexes_part={"indexes": [{"collectionGroup": "users", "queryScope": "COLLECTION", "fields": [{"fieldPath": "clubId", "order": "ASCENDING"}]}], "fieldOverrides": []},
                storage_part='    match /clubs/{clubId}/branding/logo.png {\\n      allow read: if true;\\n    }\\n',
            )
            self._create_app(
                root,
                app="swim_analyzer",
                rules_paths=["/users/{userId}"],
                index_groups=["analysis_requests"],
                storage_paths=[],
                rules_part='    match /users/{userId} {\\n      allow read: if false;\\n    }\\n',
                indexes_part={"indexes": [{"collectionGroup": "analysis_requests", "queryScope": "COLLECTION", "fields": [{"fieldPath": "createdAt", "order": "DESCENDING"}]}], "fieldOverrides": []},
                storage_part="",
            )

            errors = manage_infra.validate(root)
            self.assertTrue(any("Ownership collision for rules_paths" in error for error in errors))

    def test_validate_detects_index_collection_group_conflict(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir) / "firebase_infra"
            (root / "apps").mkdir(parents=True, exist_ok=True)
            (root / "generated").mkdir(parents=True, exist_ok=True)

            shared_index = {
                "collectionGroup": "analysis_requests",
                "queryScope": "COLLECTION",
                "fields": [{"fieldPath": "createdAt", "order": "DESCENDING"}],
            }

            self._create_app(
                root,
                app="swimify",
                rules_paths=["/support_requests/{id}"],
                index_groups=["analysis_requests"],
                storage_paths=[],
                rules_part='    match /support_requests/{id} {\\n      allow read: if true;\\n    }\\n',
                indexes_part={"indexes": [shared_index], "fieldOverrides": []},
                storage_part="",
            )
            self._create_app(
                root,
                app="swim_analyzer",
                rules_paths=["/analysis_requests/{id}"],
                index_groups=["analysis_requests"],
                storage_paths=[],
                rules_part='    match /analysis_requests/{id} {\\n      allow read: if true;\\n    }\\n',
                indexes_part={"indexes": [shared_index], "fieldOverrides": []},
                storage_part="",
            )

            errors = manage_infra.validate(root)
            self.assertTrue(
                any("Ownership collision for index_collection_groups" in error for error in errors)
            )

    def test_compose_writes_generated_files(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir) / "firebase_infra"
            (root / "apps").mkdir(parents=True, exist_ok=True)
            (root / "generated").mkdir(parents=True, exist_ok=True)

            self._create_app(
                root,
                app="swimify",
                rules_paths=["/users/{userId}"],
                index_groups=["users"],
                storage_paths=["/clubs/{clubId}/branding/logo.png"],
                rules_part='    match /users/{userId} {\\n      allow read: if true;\\n    }\\n',
                indexes_part={"indexes": [{"collectionGroup": "users", "queryScope": "COLLECTION", "fields": [{"fieldPath": "clubId", "order": "ASCENDING"}]}], "fieldOverrides": []},
                storage_part='    match /clubs/{clubId}/branding/logo.png {\\n      allow read: if true;\\n    }\\n',
            )
            self._create_app(
                root,
                app="aquis",
                rules_paths=["/dailyTrainingRecords/{id}"],
                index_groups=["dailyTrainingRecords"],
                storage_paths=[],
                rules_part='    match /dailyTrainingRecords/{id} {\\n      allow read: if true;\\n    }\\n',
                indexes_part={"indexes": [{"collectionGroup": "dailyTrainingRecords", "queryScope": "COLLECTION", "fields": [{"fieldPath": "userId", "order": "ASCENDING"}]}], "fieldOverrides": []},
                storage_part="",
            )

            validation_errors = manage_infra.validate(root)
            self.assertEqual([], validation_errors)

            compose_errors = manage_infra.compose(root, check=False)
            self.assertEqual([], compose_errors)

            firestore_rules = (root / "generated" / "firestore.rules").read_text(encoding="utf-8")
            self.assertIn("match /users/{userId}", firestore_rules)
            self.assertIn("match /dailyTrainingRecords/{id}", firestore_rules)

            indexes = json.loads((root / "generated" / "firestore.indexes.json").read_text(encoding="utf-8"))
            groups = {index["collectionGroup"] for index in indexes["indexes"]}
            self.assertEqual({"users", "dailyTrainingRecords"}, groups)


if __name__ == "__main__":
    unittest.main()
