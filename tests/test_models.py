import unittest

from zero_lab.models import (
    ActionProposal,
    Actor,
    ExperimentStatus,
    PermissionLevel,
)


class ModelTests(unittest.TestCase):
    def test_action_proposal_round_trip_preserves_identity(self):
        proposal = ActionProposal(
            idempotency_key="exp-001:search",
            actor=Actor.ZERO,
            action_type="public_read",
            permission=PermissionLevel.L0,
            payload={"url": "https://api.github.com/repos/openai/openai-python"},
        )
        self.assertEqual(ActionProposal.from_dict(proposal.to_dict()), proposal)

    def test_experiment_status_names_are_stable(self):
        self.assertEqual(ExperimentStatus.INCONCLUSIVE.value, "INCONCLUSIVE")


if __name__ == "__main__":
    unittest.main()
