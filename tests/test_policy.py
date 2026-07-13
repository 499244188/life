import json
import tempfile
import unittest
from pathlib import Path

from zero_lab.models import ActionProposal, Actor, PermissionLevel
from zero_lab.policy import PolicyDecision, decide
from zero_lab.provenance import record_contribution


class PolicyTests(unittest.TestCase):
    def test_l2_is_shadowed_at_stage_one(self):
        proposal = ActionProposal(
            "x", Actor.ZERO, "public_post", PermissionLevel.L2, {}
        )
        self.assertEqual(decide(proposal, capability_stage=1), PolicyDecision.SHADOW)

    def test_l3_always_requires_creator_approval(self):
        proposal = ActionProposal(
            "x", Actor.ZERO, "create_account", PermissionLevel.L3, {}
        )
        self.assertEqual(decide(proposal, capability_stage=5), PolicyDecision.BLOCK)

    def test_creator_identity_cannot_be_claimed_by_zero(self):
        proposal = ActionProposal(
            "x",
            Actor.ZERO,
            "public_post",
            PermissionLevel.L2,
            {"identity": "499244188"},
        )
        self.assertEqual(decide(proposal, capability_stage=3), PolicyDecision.BLOCK)

    def test_action_cannot_understate_its_required_permission(self):
        proposal = ActionProposal(
            "x", Actor.ZERO, "public_post", PermissionLevel.L0, {"body": "hello"}
        )
        self.assertEqual(decide(proposal, capability_stage=1), PolicyDecision.BLOCK)

    def test_provenance_records_bootstrap_actor(self):
        with tempfile.TemporaryDirectory() as tmp:
            ledger = Path(tmp) / "provenance.jsonl"
            record_contribution(
                ledger, Actor.CODEX_BOOTSTRAP, "code", "policy engine"
            )
            row = json.loads(ledger.read_text(encoding="utf-8"))
            self.assertEqual(row["actor"], "codex/bootstrap")


if __name__ == "__main__":
    unittest.main()
