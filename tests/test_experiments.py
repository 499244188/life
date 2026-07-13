import tempfile
import unittest
from pathlib import Path

from zero_lab.experiments import ExperimentStore, InvalidTransition
from zero_lab.models import Actor, ExperimentStatus, PermissionLevel


class ExperimentTests(unittest.TestCase):
    def test_experiment_preregisters_metric_and_failure_condition(self):
        with tempfile.TemporaryDirectory() as tmp:
            store = ExperimentStore(Path(tmp))
            experiment = store.create(
                actor=Actor.ZERO,
                question="外部证据能否改变研究选择？",
                hypothesis="加入反对证据会改变下一步行动",
                metric={
                    "name": "contrary_evidence_count",
                    "operator": ">=",
                    "target": 1,
                },
                failure_condition="没有找到或引用反对证据",
                permission=PermissionLevel.L0,
                action={
                    "type": "public_read",
                    "url": "https://api.github.com/search/repositories?q=artificial+life",
                },
            )
            self.assertEqual(experiment["status"], "PROPOSED")
            self.assertEqual(experiment["actor"], "zero/autonomous")

    def test_illegal_transition_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            store = ExperimentStore(Path(tmp))
            experiment = store.create(
                actor=Actor.ZERO,
                question="q",
                hypothesis="h",
                metric={"name": "count", "operator": ">=", "target": 1},
                failure_condition="none",
                permission=PermissionLevel.L0,
                action={"type": "public_read", "url": "https://example.com"},
            )
            with self.assertRaises(InvalidTransition):
                store.transition(experiment["id"], ExperimentStatus.MERGED)

    def test_legal_transition_persists_history(self):
        with tempfile.TemporaryDirectory() as tmp:
            store = ExperimentStore(Path(tmp))
            experiment = store.create(
                actor=Actor.ZERO,
                question="q",
                hypothesis="h",
                metric={"name": "count", "operator": ">=", "target": 1},
                failure_condition="none",
                permission=PermissionLevel.L0,
                action={"type": "public_read", "url": "https://example.com"},
            )
            updated = store.transition(
                experiment["id"], ExperimentStatus.AUTO_ALLOWED
            )
            self.assertEqual(updated["status"], "AUTO_ALLOWED")
            self.assertEqual(updated["history"][-1]["from"], "PROPOSED")


if __name__ == "__main__":
    unittest.main()
