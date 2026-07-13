from __future__ import annotations

import operator
from typing import Any, Callable

from zero_lab.models import Actor
from zero_lab.receipts import ReceiptError, validate_receipt


OPERATORS: dict[str, Callable[[Any, Any], bool]] = {
    ">=": operator.ge,
    ">": operator.gt,
    "==": operator.eq,
    "<=": operator.le,
    "<": operator.lt,
}


def evaluate(
    *,
    metric: dict[str, Any],
    observed: dict[str, Any],
    hypothesis_actor: Actor,
    evaluator_actor: Actor,
    receipts: list[dict[str, Any]],
) -> dict[str, Any]:
    base = {
        "metric": metric,
        "observed": observed,
        "evaluator_actor": evaluator_actor.value,
    }
    if hypothesis_actor == evaluator_actor:
        return {**base, "outcome": "INCONCLUSIVE", "reason": "self evaluation forbidden"}
    try:
        for receipt in receipts:
            validate_receipt(receipt)
    except ReceiptError as error:
        return {**base, "outcome": "INCONCLUSIVE", "reason": str(error)}

    name = metric.get("name")
    operation = OPERATORS.get(metric.get("operator"))
    if operation is None or name not in observed or "target" not in metric:
        return {**base, "outcome": "INCONCLUSIVE", "reason": "metric is not evaluable"}
    passed = operation(observed[name], metric["target"])
    return {
        **base,
        "outcome": "PASS" if passed else "FAIL",
        "reason": "preregistered metric satisfied" if passed else "preregistered metric failed",
    }
