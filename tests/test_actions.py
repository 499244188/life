import tempfile
import unittest
from pathlib import Path

from zero_lab.actions import ActionGateway
from zero_lab.models import ActionProposal, Actor, PermissionLevel


class ActionGatewayTests(unittest.TestCase):
    def test_l2_action_at_stage_one_only_creates_shadow_receipt(self):
        with tempfile.TemporaryDirectory() as tmp:
            gateway = ActionGateway(Path(tmp), capability_stage=1)
            receipt = gateway.execute(
                ActionProposal(
                    "exp:post",
                    Actor.ZERO,
                    "public_post",
                    PermissionLevel.L2,
                    {"body": "hello"},
                )
            )
            self.assertEqual(receipt["kind"], "shadow")
            self.assertEqual(receipt["policy_decision"], "SHADOW")

    def test_same_idempotency_key_reuses_receipt(self):
        with tempfile.TemporaryDirectory() as tmp:
            gateway = ActionGateway(Path(tmp), capability_stage=1)
            proposal = ActionProposal(
                "exp:read",
                Actor.ZERO,
                "public_read",
                PermissionLevel.L0,
                {"url": "https://example.com"},
            )
            first = gateway.execute(proposal, fetcher=lambda url: b"evidence")
            second = gateway.execute(proposal, fetcher=lambda url: b"different")
            self.assertEqual(first, second)

    def test_l3_action_is_blocked_without_execution(self):
        with tempfile.TemporaryDirectory() as tmp:
            gateway = ActionGateway(Path(tmp), capability_stage=5)
            receipt = gateway.execute(
                ActionProposal(
                    "exp:account",
                    Actor.ZERO,
                    "create_account",
                    PermissionLevel.L3,
                    {},
                )
            )
            self.assertEqual(receipt["policy_decision"], "BLOCK")

    def test_non_allowlisted_host_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            gateway = ActionGateway(
                Path(tmp), capability_stage=1, public_read_hosts={"example.com"}
            )
            proposal = ActionProposal(
                "exp:read",
                Actor.ZERO,
                "public_read",
                PermissionLevel.L0,
                {"url": "https://not-allowed.invalid/data"},
            )
            with self.assertRaises(PermissionError):
                gateway.execute(proposal, fetcher=lambda url: b"evidence")


if __name__ == "__main__":
    unittest.main()
