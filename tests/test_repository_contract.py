import json
import unittest
from pathlib import Path


class RepositoryContractTests(unittest.TestCase):
    def test_constitution_enforces_stage_one_boundaries(self):
        value = json.loads(
            Path("evolution/constitution.json").read_text(encoding="utf-8")
        )
        self.assertEqual(value["owner"], "creator")
        self.assertEqual(value["l3_policy"], "creator_approval_required")
        self.assertEqual(value["l2_mode"], "shadow")
        self.assertIn("api.github.com", value["public_read_hosts"])

    def test_workflow_runs_tests_before_cycle(self):
        text = Path(".github/workflows/zero-evolution-lab.yml").read_text(
            encoding="utf-8"
        )
        self.assertLess(
            text.index("python3 -m unittest"),
            text.index("python3 -m zero_lab cycle"),
        )

    def test_workflow_persists_only_evolution_artifacts(self):
        text = Path(".github/workflows/zero-evolution-lab.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("git add evolution/", text)
        self.assertNotIn("git add -A", text)

    def test_bootstrap_agenda_is_not_attributed_to_zero(self):
        value = json.loads(Path("evolution/agenda.json").read_text(encoding="utf-8"))
        self.assertEqual(value["seed_actor"], "codex/bootstrap")


if __name__ == "__main__":
    unittest.main()
