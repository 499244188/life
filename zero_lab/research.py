from __future__ import annotations

import json
import os
from typing import Any
from urllib.request import Request, urlopen

from zero_lab.models import Actor, PermissionLevel


REQUIRED_FIELDS = {
    "question",
    "hypothesis",
    "metric",
    "failure_condition",
    "permission",
    "action",
    "reason",
}
ALLOWED_ACTIONS = {"public_read", "repository_write", "public_post"}
ALLOWED_OPERATORS = {">=", ">", "==", "<=", "<"}


class ProposalError(ValueError):
    pass


def parse_proposal(value: dict[str, Any]) -> dict[str, Any]:
    fields = set(value)
    if fields != REQUIRED_FIELDS:
        missing = REQUIRED_FIELDS - fields
        extra = fields - REQUIRED_FIELDS
        raise ProposalError(f"invalid fields; missing={sorted(missing)} extra={sorted(extra)}")
    for field in ("question", "hypothesis", "failure_condition", "reason"):
        if not isinstance(value[field], str) or not value[field].strip():
            raise ProposalError(f"{field} must be non-empty text")
    try:
        permission = PermissionLevel(value["permission"])
    except (TypeError, ValueError) as error:
        raise ProposalError("permission must be 0..3") from error

    metric = value["metric"]
    if not isinstance(metric, dict) or set(metric) != {"name", "operator", "target"}:
        raise ProposalError("metric requires name, operator, and target")
    if metric["operator"] not in ALLOWED_OPERATORS:
        raise ProposalError("unsupported metric operator")
    action = value["action"]
    if not isinstance(action, dict) or action.get("type") not in ALLOWED_ACTIONS:
        raise ProposalError("unsupported action")
    if action["type"] == "public_read" and not action.get("url"):
        raise ProposalError("public_read requires url")

    parsed = dict(value)
    parsed["permission"] = int(permission)
    parsed["actor"] = Actor.ZERO.value
    return parsed


def _extract_json(content: str) -> dict[str, Any]:
    start = content.find("{")
    end = content.rfind("}")
    if start < 0 or end <= start:
        raise ProposalError("model response contains no JSON object")
    try:
        value = json.loads(content[start : end + 1])
    except json.JSONDecodeError as error:
        raise ProposalError("model response is not valid JSON") from error
    if not isinstance(value, dict):
        raise ProposalError("proposal must be a JSON object")
    return value


def generate_proposal(
    *,
    agenda: list[dict[str, Any]],
    verified_experience: list[dict[str, Any]],
    capability_stage: int,
    timeout: int = 60,
) -> dict[str, Any]:
    api_key = os.environ.get("DEEPSEEK_API_KEY", "")
    if not api_key:
        raise ProposalError("DEEPSEEK_API_KEY is missing")
    api_url = os.environ.get(
        "ZERO_API_URL", "https://api.deepseek.com/v1/chat/completions"
    )
    system = (
        "你是零的研究推理组件。你代表零选择一个研究问题，但不能声称动作已经完成。"
        "只输出一个JSON对象，提出一个可证伪假设、预登记指标、失败条件和单一行动。"
        "不得提供actor或evaluator字段，不得冒充创造者。"
    )
    prompt = json.dumps(
        {
            "agenda": agenda,
            "verified_experience": verified_experience,
            "capability_stage": capability_stage,
            "allowed_actions": sorted(ALLOWED_ACTIONS),
            "required_fields": sorted(REQUIRED_FIELDS),
        },
        ensure_ascii=False,
    )
    body = json.dumps(
        {
            "model": "deepseek-chat",
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": prompt},
            ],
            "max_tokens": 1400,
            "temperature": 0.4,
            "response_format": {"type": "json_object"},
        },
        ensure_ascii=False,
    ).encode("utf-8")
    request = Request(
        api_url,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
            "User-Agent": "zero-evolution-lab/1",
        },
        method="POST",
    )
    try:
        with urlopen(request, timeout=timeout) as response:
            response_value = json.loads(response.read().decode("utf-8"))
        content = response_value["choices"][0]["message"]["content"]
    except (OSError, KeyError, IndexError, json.JSONDecodeError) as error:
        raise ProposalError(f"research backend failure: {type(error).__name__}") from error
    return parse_proposal(_extract_json(content))
