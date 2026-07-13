import json
import tempfile
import unittest
from pathlib import Path

from zero_lab.io import append_jsonl, load_json, save_json


class PersistenceTests(unittest.TestCase):
    def test_save_json_replaces_file_atomically(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "state.json"
            save_json(path, {"value": 1})
            save_json(path, {"value": 2})
            self.assertEqual(load_json(path), {"value": 2})
            self.assertFalse(path.with_suffix(".json.tmp").exists())

    def test_append_jsonl_writes_one_valid_object_per_line(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "ledger.jsonl"
            append_jsonl(path, {"actor": "zero"})
            append_jsonl(path, {"actor": "codex"})
            rows = [
                json.loads(line)
                for line in path.read_text(encoding="utf-8").splitlines()
            ]
            self.assertEqual([row["actor"] for row in rows], ["zero", "codex"])


if __name__ == "__main__":
    unittest.main()
