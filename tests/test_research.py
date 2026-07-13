import unittest

from zero_lab.models import Actor
from zero_lab.research import ProposalError, parse_proposal


VALID_PROPOSAL = {
    "question": "网络环境能否形成行动闭环？",
    "hypothesis": "保存外部反例会改变后续选择",
    "metric": {
        "name": "contrary_evidence_count",
        "operator": ">=",
        "target": 1,
    },
    "failure_condition": "没有保存反例",
    "permission": 0,
    "action": {
        "type": "public_read",
        "url": "https://api.github.com/search/repositories?q=artificial+life",
    },
    "reason": "当前记忆偏向支持性材料",
}


class ResearchTests(unittest.TestCase):
    def test_proposal_is_attributed_to_zero(self):
        value = parse_proposal(VALID_PROPOSAL)
        self.assertEqual(value["actor"], Actor.ZERO.value)

    def test_proposal_without_failure_condition_is_rejected(self):
        with self.assertRaises(ProposalError):
            parse_proposal({"question": "q", "hypothesis": "h"})

    def test_proposal_cannot_choose_its_actor(self):
        value = dict(VALID_PROPOSAL)
        value["actor"] = "creator"
        with self.assertRaises(ProposalError):
            parse_proposal(value)

    def test_unsupported_action_is_rejected(self):
        value = dict(VALID_PROPOSAL)
        value["action"] = {"type": "delete_repository"}
        with self.assertRaises(ProposalError):
            parse_proposal(value)


if __name__ == "__main__":
    unittest.main()
