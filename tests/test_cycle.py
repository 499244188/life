import tempfile
import unittest
from pathlib import Path

from zero_lab.cycle import initialize, run_cycle, verify_root


class CycleTests(unittest.TestCase):
    def test_cycle_persists_experiment_receipt_evaluation_and_provenance(self):
        proposal = {
            "question": "反例是否会进入研究证据？",
            "hypothesis": "读取外部资料可产生至少一条反例证据",
            "metric": {"name": "receipt_count", "operator": ">=", "target": 1},
            "failure_condition": "没有有效读取凭证",
            "permission": 0,
            "action": {"type": "public_read", "url": "https://example.com"},
            "reason": "验证最小闭环",
        }
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            initialize(root, public_read_hosts=["example.com"])
            result = run_cycle(
                root,
                proposal=proposal,
                fetcher=lambda url: b"external evidence",
            )
            self.assertEqual(result["evaluation"]["outcome"], "PASS")
            self.assertEqual(len(list((root / "experiments").glob("*.json"))), 1)
            self.assertEqual(len(list((root / "receipts").glob("*.json"))), 1)
            self.assertTrue((root / "provenance.jsonl").exists())
            self.assertEqual(verify_root(root), [])

    def test_shadow_action_is_not_mistaken_for_success(self):
        proposal = {
            "question": "公开互动是否可执行？",
            "hypothesis": "发布会得到外部反馈",
            "metric": {"name": "receipt_count", "operator": ">=", "target": 1},
            "failure_condition": "没有外部反馈",
            "permission": 2,
            "action": {"type": "public_post", "body": "test"},
            "reason": "验证权限边界",
        }
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            initialize(root)
            result = run_cycle(root, proposal=proposal)
            self.assertEqual(result["evaluation"]["outcome"], "INCONCLUSIVE")
            self.assertEqual(result["receipt"]["kind"], "shadow")


if __name__ == "__main__":
    unittest.main()
