import unittest

from zero_lab.evaluator import evaluate
from zero_lab.models import Actor
from zero_lab.receipts import ReceiptError, validate_receipt


VALID_READ_RECEIPT = {
    "kind": "public_read",
    "url": "https://example.com",
    "content_sha256": "a" * 64,
}


class EvaluatorTests(unittest.TestCase):
    def test_missing_public_read_hash_is_invalid(self):
        with self.assertRaises(ReceiptError):
            validate_receipt({"kind": "public_read", "url": "https://example.com"})

    def test_hypothesis_author_cannot_be_evaluator(self):
        result = evaluate(
            metric={
                "name": "contrary_evidence_count",
                "operator": ">=",
                "target": 1,
            },
            observed={"contrary_evidence_count": 2},
            hypothesis_actor=Actor.ZERO,
            evaluator_actor=Actor.ZERO,
            receipts=[VALID_READ_RECEIPT],
        )
        self.assertEqual(result["outcome"], "INCONCLUSIVE")

    def test_deterministic_gate_accepts_verified_metric(self):
        result = evaluate(
            metric={
                "name": "contrary_evidence_count",
                "operator": ">=",
                "target": 1,
            },
            observed={"contrary_evidence_count": 2},
            hypothesis_actor=Actor.ZERO,
            evaluator_actor=Actor.CODEX_BOOTSTRAP,
            receipts=[VALID_READ_RECEIPT],
        )
        self.assertEqual(result["outcome"], "PASS")

    def test_failed_metric_is_reported_without_rewriting_target(self):
        metric = {"name": "count", "operator": ">=", "target": 3}
        result = evaluate(
            metric=metric,
            observed={"count": 1},
            hypothesis_actor=Actor.ZERO,
            evaluator_actor=Actor.CODEX_BOOTSTRAP,
            receipts=[VALID_READ_RECEIPT],
        )
        self.assertEqual(result["outcome"], "FAIL")
        self.assertEqual(result["metric"], metric)


if __name__ == "__main__":
    unittest.main()
