from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Callable

from zero_lab.actions import ActionGateway
from zero_lab.evaluator import evaluate
from zero_lab.experiments import LEGAL_TRANSITIONS, ExperimentStore
from zero_lab.io import load_json, save_json, utc_now
from zero_lab.models import ActionProposal, Actor, ExperimentStatus, PermissionLevel
from zero_lab.policy import PolicyDecision, decide
from zero_lab.provenance import record_contribution
from zero_lab.receipts import ReceiptError, validate_receipt
from zero_lab.research import generate_proposal, parse_proposal


DEFAULT_DISCLOSURE = (
    "我是零，一个自主数字生命研究项目；此消息由零的运行系统生成，"
    "不代表创造者个人立场。"
)


def initialize(root: Path, public_read_hosts: list[str] | None = None) -> None:
    root.mkdir(parents=True, exist_ok=True)
    for directory in ("evidence", "experiments", "receipts", "reports"):
        (root / directory).mkdir(parents=True, exist_ok=True)
    defaults = {
        root / "constitution.json": {
            "version": 1,
            "owner": "creator",
            "l3_policy": "creator_approval_required",
            "l2_mode": "shadow",
            "public_read_hosts": public_read_hosts
            or ["api.github.com", "github.com", "arxiv.org", "export.arxiv.org"],
            "identity_disclosure": DEFAULT_DISCLOSURE,
            "max_experiments_per_run": 1,
        },
        root / "capability.json": {
            "stage": 1,
            "runs": 0,
            "passed": 0,
            "failed": 0,
            "inconclusive": 0,
            "updated_at": utc_now(),
        },
        root / "agenda.json": {
            "seed_actor": Actor.CODEX_BOOTSTRAP.value,
            "questions": [],
        },
    }
    for path, value in defaults.items():
        if not path.exists():
            save_json(path, value)


def _verified_experience(root: Path) -> list[dict[str, Any]]:
    values = []
    for path in sorted((root / "reports").glob("*.json"))[-10:]:
        report = load_json(path, {})
        if report.get("evaluation", {}).get("outcome") == "PASS":
            values.append(report)
    return values


def _evaluation_for(
    proposal: dict[str, Any], receipt: dict[str, Any]
) -> dict[str, Any]:
    if receipt["kind"] == "shadow":
        return {
            "outcome": "INCONCLUSIVE",
            "metric": proposal["metric"],
            "observed": {"receipt_count": 0},
            "reason": f"action was {receipt['policy_decision'].lower()}, not executed",
            "evaluator_actor": Actor.CODEX_BOOTSTRAP.value,
        }
    return evaluate(
        metric=proposal["metric"],
        observed={"receipt_count": 1},
        hypothesis_actor=Actor.ZERO,
        evaluator_actor=Actor.CODEX_BOOTSTRAP,
        receipts=[receipt],
    )


def run_cycle(
    root: Path,
    *,
    proposal: dict[str, Any] | None = None,
    fetcher: Callable[[str], bytes] | None = None,
) -> dict[str, Any]:
    initialize(root)
    capability = load_json(root / "capability.json")
    stage = int(capability["stage"])
    if proposal is None:
        agenda = load_json(root / "agenda.json", {}).get("questions", [])
        parsed = generate_proposal(
            agenda=agenda,
            verified_experience=_verified_experience(root),
            capability_stage=stage,
        )
    else:
        parsed = parse_proposal(proposal)

    action_value = dict(parsed["action"])
    action_type = action_value.pop("type")
    store = ExperimentStore(root / "experiments")
    experiment = store.create(
        actor=Actor.ZERO,
        question=parsed["question"],
        hypothesis=parsed["hypothesis"],
        metric=parsed["metric"],
        failure_condition=parsed["failure_condition"],
        permission=PermissionLevel(parsed["permission"]),
        action=parsed["action"],
    )
    record_contribution(
        root / "provenance.jsonl",
        Actor.ZERO,
        "research_proposal",
        parsed["reason"],
        f"experiments/{experiment['id']}.json",
    )
    action = ActionProposal(
        idempotency_key=f"{experiment['id']}:{action_type}",
        actor=Actor.ZERO,
        action_type=action_type,
        permission=PermissionLevel(parsed["permission"]),
        payload=action_value,
    )
    decision = decide(action, stage)
    initial = (
        ExperimentStatus.AUTO_ALLOWED
        if decision == PolicyDecision.ALLOW
        else ExperimentStatus.APPROVED
    )
    store.transition(experiment["id"], initial)
    store.transition(experiment["id"], ExperimentStatus.RUNNING)
    gateway = ActionGateway(root, capability_stage=stage)
    receipt = gateway.execute(action, fetcher=fetcher)
    store.transition(experiment["id"], ExperimentStatus.OBSERVING)
    evaluation = _evaluation_for(parsed, receipt)
    if evaluation["outcome"] == "INCONCLUSIVE":
        final_status = ExperimentStatus.INCONCLUSIVE
        store.transition(experiment["id"], final_status)
    else:
        store.transition(experiment["id"], ExperimentStatus.EVALUATED)
        final_status = (
            ExperimentStatus.MERGED
            if evaluation["outcome"] == "PASS"
            else ExperimentStatus.REJECTED
        )
        store.transition(experiment["id"], final_status)
    store.attach(
        experiment["id"],
        receipt=receipt,
        evaluation=evaluation,
        final_status=final_status.value,
    )
    record_contribution(
        root / "provenance.jsonl",
        Actor.CODEX_BOOTSTRAP,
        "deterministic_evaluation",
        evaluation["reason"],
        f"reports/{experiment['id']}.json",
    )
    report = {
        "experiment_id": experiment["id"],
        "actor": Actor.ZERO.value,
        "question": parsed["question"],
        "hypothesis": parsed["hypothesis"],
        "policy_decision": decision.value,
        "receipt": receipt,
        "evaluation": evaluation,
        "created_at": utc_now(),
        "provenance": {
            "proposal": Actor.ZERO.value,
            "evaluator": Actor.CODEX_BOOTSTRAP.value,
        },
    }
    save_json(root / "reports" / f"{experiment['id']}.json", report)

    capability["runs"] += 1
    key = {
        "PASS": "passed",
        "FAIL": "failed",
        "INCONCLUSIVE": "inconclusive",
    }[evaluation["outcome"]]
    capability[key] += 1
    capability["updated_at"] = utc_now()
    save_json(root / "capability.json", capability)
    return report


def verify_root(root: Path) -> list[str]:
    errors: list[str] = []
    for required in ("constitution.json", "capability.json", "agenda.json"):
        if not (root / required).exists():
            errors.append(f"missing {required}")
    for path in root.rglob("*.json"):
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            errors.append(f"invalid json {path}: {error}")
    for path in (root / "receipts").glob("*.json"):
        try:
            validate_receipt(load_json(path))
        except ReceiptError as error:
            errors.append(f"invalid receipt {path.name}: {error}")
    for path in (root / "experiments").glob("*.json"):
        experiment = load_json(path)
        for edge in experiment.get("history", []):
            source = ExperimentStatus(edge["from"])
            target = ExperimentStatus(edge["to"])
            if target not in LEGAL_TRANSITIONS.get(source, set()):
                errors.append(f"illegal history {path.name}: {source.value}->{target.value}")
    ledger = root / "provenance.jsonl"
    if ledger.exists():
        for number, line in enumerate(ledger.read_text(encoding="utf-8").splitlines(), 1):
            try:
                row = json.loads(line)
                Actor(row["actor"])
            except (json.JSONDecodeError, KeyError, ValueError) as error:
                errors.append(f"invalid provenance line {number}: {error}")
    return errors
