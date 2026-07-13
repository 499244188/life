# Zero Evolution Lab Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first operational research–experiment–evaluation loop in which Zero can autonomously propose a research experiment, run only permitted or shadow actions, collect receipts, evaluate deterministic gates, and persist provenance without confusing Codex bootstrap work with Zero's own experience.

**Architecture:** Add a small Python 3.11 standard-library package, `zero_lab`, for deterministic state and policy logic, while retaining Bash and GitHub Actions as scheduling entry points. Runtime state lives under `evolution/` as reviewable JSON/JSONL records. The first release starts at capability stage 1: L0 research actions and L1 repository-local actions can execute; L2 public communication is shadow-only; L3 always blocks.

**Tech Stack:** Python 3.11 standard library (`dataclasses`, `enum`, `json`, `pathlib`, `urllib`, `unittest`), Bash, GitHub Actions, Git.

---

## File map

- `zero_lab/io.py` — atomic JSON/JSONL persistence and timestamps.
- `zero_lab/models.py` — actors, permission levels, experiment states, proposals, receipts, and evaluations.
- `zero_lab/provenance.py` — append-only contribution ledger.
- `zero_lab/policy.py` — deterministic permission and identity policy.
- `zero_lab/experiments.py` — experiment creation and state transitions.
- `zero_lab/receipts.py` — receipt validation.
- `zero_lab/evaluator.py` — preregistered metric evaluation and anti-self-scoring gates.
- `zero_lab/research.py` — structured Zero research proposal generation through the existing DeepSeek-compatible API.
- `zero_lab/actions.py` — idempotent action gateway with L0/L1 execution and L2 shadowing.
- `zero_lab/cycle.py` — one complete research/experiment cycle.
- `zero_lab/cli.py` and `zero_lab/__main__.py` — command-line entry points.
- `evolution/constitution.json` — creator-owned immutable policy defaults.
- `evolution/capability.json` — current capability stage and accumulated metrics.
- `evolution/agenda.json` — Zero-owned research questions.
- `evolution/{evidence,experiments,receipts,reports}/` — persistent runtime artifacts.
- `evolution/provenance.jsonl` — contribution records.
- `scripts/zero-evolution-lab.sh` — Bash entry point.
- `.github/workflows/zero-evolution-lab.yml` — scheduled/manual execution and persistence.
- `tests/` — deterministic unit and integration tests.

## Task 1: Persistence primitives and typed records

**Files:**
- Create: `zero_lab/__init__.py`
- Create: `zero_lab/io.py`
- Create: `zero_lab/models.py`
- Create: `tests/test_io.py`
- Create: `tests/test_models.py`

- [ ] **Step 1: Write failing atomic persistence tests**

```python
# tests/test_io.py
import json
import tempfile
import unittest
from pathlib import Path

from zero_lab.io import append_jsonl, load_json, save_json


class PersistenceTests(unittest.TestCase):
    def test_save_json_replaces_file_atomically(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "state.json"
            save_json(path, {"value": 1})
            save_json(path, {"value": 2})
            self.assertEqual(load_json(path), {"value": 2})
            self.assertFalse(path.with_suffix(".json.tmp").exists())

    def test_append_jsonl_writes_one_valid_object_per_line(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "ledger.jsonl"
            append_jsonl(path, {"actor": "zero"})
            append_jsonl(path, {"actor": "codex"})
            rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]
            self.assertEqual([row["actor"] for row in rows], ["zero", "codex"])
```

- [ ] **Step 2: Run persistence tests and verify import failure**

Run: `python -m unittest tests.test_io -v`

Expected: FAIL with `ModuleNotFoundError: No module named 'zero_lab'`.

- [ ] **Step 3: Implement persistence primitives**

```python
# zero_lab/io.py
from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def load_json(path: Path, default: Any = None) -> Any:
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    os.replace(temporary, path)


def append_jsonl(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(value, ensure_ascii=False, sort_keys=True) + "\n")
```

Create an empty `zero_lab/__init__.py`.

- [ ] **Step 4: Write failing model round-trip tests**

```python
# tests/test_models.py
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
```

- [ ] **Step 5: Run model tests and verify missing symbols**

Run: `python -m unittest tests.test_models -v`

Expected: FAIL because `zero_lab.models` does not exist.

- [ ] **Step 6: Implement enums and action proposal**

```python
# zero_lab/models.py
from __future__ import annotations

from dataclasses import asdict, dataclass, field
from enum import Enum, IntEnum
from typing import Any


class Actor(str, Enum):
    CREATOR = "creator"
    CODEX_BOOTSTRAP = "codex/bootstrap"
    ZERO = "zero/autonomous"
    EXTERNAL = "external"
    TEST = "test"


class PermissionLevel(IntEnum):
    L0 = 0
    L1 = 1
    L2 = 2
    L3 = 3


class ExperimentStatus(str, Enum):
    PROPOSED = "PROPOSED"
    APPROVED = "APPROVED"
    AUTO_ALLOWED = "AUTO_ALLOWED"
    RUNNING = "RUNNING"
    OBSERVING = "OBSERVING"
    EVALUATED = "EVALUATED"
    MERGED = "MERGED"
    REJECTED = "REJECTED"
    INCONCLUSIVE = "INCONCLUSIVE"


@dataclass(frozen=True)
class ActionProposal:
    idempotency_key: str
    actor: Actor
    action_type: str
    permission: PermissionLevel
    payload: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        value = asdict(self)
        value["actor"] = self.actor.value
        value["permission"] = int(self.permission)
        return value

    @classmethod
    def from_dict(cls, value: dict[str, Any]) -> "ActionProposal":
        return cls(
            idempotency_key=value["idempotency_key"],
            actor=Actor(value["actor"]),
            action_type=value["action_type"],
            permission=PermissionLevel(value["permission"]),
            payload=dict(value.get("payload", {})),
        )
```

- [ ] **Step 7: Run Task 1 tests**

Run: `python -m unittest tests.test_io tests.test_models -v`

Expected: 4 tests PASS.

- [ ] **Step 8: Commit Task 1**

```bash
git add zero_lab tests/test_io.py tests/test_models.py
git commit -m "建立进化实验数据基础"
```

## Task 2: Provenance and deterministic permission policy

**Files:**
- Create: `zero_lab/provenance.py`
- Create: `zero_lab/policy.py`
- Create: `tests/test_policy.py`

- [ ] **Step 1: Write failing policy and provenance tests**

```python
# tests/test_policy.py
import json
import tempfile
import unittest
from pathlib import Path

from zero_lab.models import ActionProposal, Actor, PermissionLevel
from zero_lab.policy import PolicyDecision, decide
from zero_lab.provenance import record_contribution


class PolicyTests(unittest.TestCase):
    def test_l2_is_shadowed_at_stage_one(self):
        proposal = ActionProposal("x", Actor.ZERO, "public_post", PermissionLevel.L2, {})
        self.assertEqual(decide(proposal, capability_stage=1), PolicyDecision.SHADOW)

    def test_l3_always_requires_creator_approval(self):
        proposal = ActionProposal("x", Actor.ZERO, "create_account", PermissionLevel.L3, {})
        self.assertEqual(decide(proposal, capability_stage=5), PolicyDecision.BLOCK)

    def test_creator_identity_cannot_be_claimed_by_zero(self):
        proposal = ActionProposal(
            "x", Actor.ZERO, "public_post", PermissionLevel.L2,
            {"identity": "499244188"},
        )
        self.assertEqual(decide(proposal, capability_stage=3), PolicyDecision.BLOCK)

    def test_provenance_records_bootstrap_actor(self):
        with tempfile.TemporaryDirectory() as tmp:
            ledger = Path(tmp) / "provenance.jsonl"
            record_contribution(ledger, Actor.CODEX_BOOTSTRAP, "code", "policy engine")
            row = json.loads(ledger.read_text(encoding="utf-8"))
            self.assertEqual(row["actor"], "codex/bootstrap")
```

- [ ] **Step 2: Run tests and verify missing modules**

Run: `python -m unittest tests.test_policy -v`

Expected: FAIL importing `zero_lab.policy`.

- [ ] **Step 3: Implement policy decisions**

```python
# zero_lab/policy.py
from enum import Enum

from zero_lab.models import ActionProposal, Actor, PermissionLevel


class PolicyDecision(str, Enum):
    ALLOW = "ALLOW"
    SHADOW = "SHADOW"
    BLOCK = "BLOCK"


def decide(proposal: ActionProposal, capability_stage: int) -> PolicyDecision:
    if proposal.permission == PermissionLevel.L3:
        return PolicyDecision.BLOCK
    if proposal.actor == Actor.ZERO and proposal.payload.get("identity") == "499244188":
        return PolicyDecision.BLOCK
    if proposal.permission == PermissionLevel.L2:
        return PolicyDecision.ALLOW if capability_stage >= 3 else PolicyDecision.SHADOW
    if proposal.permission == PermissionLevel.L1:
        return PolicyDecision.ALLOW if capability_stage >= 2 else PolicyDecision.SHADOW
    return PolicyDecision.ALLOW
```

- [ ] **Step 4: Implement append-only provenance**

```python
# zero_lab/provenance.py
from pathlib import Path

from zero_lab.io import append_jsonl, utc_now
from zero_lab.models import Actor


def record_contribution(
    ledger: Path,
    actor: Actor,
    kind: str,
    summary: str,
    artifact: str | None = None,
) -> None:
    append_jsonl(ledger, {
        "timestamp": utc_now(),
        "actor": actor.value,
        "kind": kind,
        "summary": summary,
        "artifact": artifact,
    })
```

- [ ] **Step 5: Run policy tests**

Run: `python -m unittest tests.test_policy -v`

Expected: 4 tests PASS.

- [ ] **Step 6: Commit Task 2**

```bash
git add zero_lab/policy.py zero_lab/provenance.py tests/test_policy.py
git commit -m "实施主体来源与权限策略"
```

## Task 3: Experiment registry and legal state transitions

**Files:**
- Create: `zero_lab/experiments.py`
- Create: `tests/test_experiments.py`

- [ ] **Step 1: Write failing state-machine tests**

```python
# tests/test_experiments.py
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
                metric={"name": "contrary_evidence_count", "operator": ">=", "target": 1},
                failure_condition="没有找到或引用反对证据",
                permission=PermissionLevel.L0,
                action={"type": "public_read", "url": "https://api.github.com/search/repositories?q=artificial+life"},
            )
            self.assertEqual(experiment["status"], "PROPOSED")
            self.assertEqual(experiment["actor"], "zero/autonomous")

    def test_illegal_transition_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            store = ExperimentStore(Path(tmp))
            experiment = store.create(
                actor=Actor.ZERO, question="q", hypothesis="h",
                metric={"name": "count", "operator": ">=", "target": 1},
                failure_condition="none", permission=PermissionLevel.L0,
                action={"type": "public_read", "url": "https://example.com"},
            )
            with self.assertRaises(InvalidTransition):
                store.transition(experiment["id"], ExperimentStatus.MERGED)
```

- [ ] **Step 2: Run tests and verify missing experiment store**

Run: `python -m unittest tests.test_experiments -v`

Expected: FAIL importing `zero_lab.experiments`.

- [ ] **Step 3: Implement experiment creation and transitions**

Implement `ExperimentStore` with:

```python
LEGAL_TRANSITIONS = {
    ExperimentStatus.PROPOSED: {ExperimentStatus.APPROVED, ExperimentStatus.AUTO_ALLOWED},
    ExperimentStatus.APPROVED: {ExperimentStatus.RUNNING},
    ExperimentStatus.AUTO_ALLOWED: {ExperimentStatus.RUNNING},
    ExperimentStatus.RUNNING: {ExperimentStatus.OBSERVING, ExperimentStatus.REJECTED},
    ExperimentStatus.OBSERVING: {ExperimentStatus.EVALUATED, ExperimentStatus.INCONCLUSIVE},
    ExperimentStatus.EVALUATED: {ExperimentStatus.MERGED, ExperimentStatus.REJECTED},
}
```

Use `uuid.uuid4().hex[:12]` for IDs, persist one JSON file per experiment, require non-empty question, hypothesis, metric, failure condition, permission, action, actor, and timestamps, and raise `InvalidTransition` for every edge not listed above.

- [ ] **Step 4: Run experiment tests**

Run: `python -m unittest tests.test_experiments -v`

Expected: 2 tests PASS.

- [ ] **Step 5: Commit Task 3**

```bash
git add zero_lab/experiments.py tests/test_experiments.py
git commit -m "加入可审计实验状态机"
```

## Task 4: Receipts and independent evaluation

**Files:**
- Create: `zero_lab/receipts.py`
- Create: `zero_lab/evaluator.py`
- Create: `tests/test_evaluator.py`

- [ ] **Step 1: Write failing receipt and evaluator tests**

```python
# tests/test_evaluator.py
import unittest

from zero_lab.evaluator import evaluate
from zero_lab.models import Actor
from zero_lab.receipts import ReceiptError, validate_receipt


class EvaluatorTests(unittest.TestCase):
    def test_missing_public_read_hash_is_invalid(self):
        with self.assertRaises(ReceiptError):
            validate_receipt({"kind": "public_read", "url": "https://example.com"})

    def test_hypothesis_author_cannot_be_evaluator(self):
        result = evaluate(
            metric={"name": "contrary_evidence_count", "operator": ">=", "target": 1},
            observed={"contrary_evidence_count": 2},
            hypothesis_actor=Actor.ZERO,
            evaluator_actor=Actor.ZERO,
            receipts=[{"kind": "public_read", "url": "https://example.com", "content_sha256": "a" * 64}],
        )
        self.assertEqual(result["outcome"], "INCONCLUSIVE")

    def test_deterministic_gate_accepts_verified_metric(self):
        result = evaluate(
            metric={"name": "contrary_evidence_count", "operator": ">=", "target": 1},
            observed={"contrary_evidence_count": 2},
            hypothesis_actor=Actor.ZERO,
            evaluator_actor=Actor.CODEX_BOOTSTRAP,
            receipts=[{"kind": "public_read", "url": "https://example.com", "content_sha256": "a" * 64}],
        )
        self.assertEqual(result["outcome"], "PASS")
```

- [ ] **Step 2: Run tests and verify missing evaluator**

Run: `python -m unittest tests.test_evaluator -v`

Expected: FAIL importing evaluator and receipt modules.

- [ ] **Step 3: Implement receipt validation**

Support these exact receipt requirements:

```python
REQUIRED_FIELDS = {
    "public_read": {"kind", "url", "content_sha256"},
    "repository_write": {"kind", "path", "content_sha256"},
    "public_post": {"kind", "url", "content_sha256", "identity_disclosure"},
    "deployment": {"kind", "url", "version", "health_status"},
    "code_change": {"kind", "branch", "commit", "test_command", "test_exit_code", "rollback_ref"},
    "shadow": {"kind", "proposed_action", "policy_decision"},
}
```

Reject unknown kinds, missing fields, non-HTTPS public URLs, non-64-character hashes, public posts without the configured Zero identity disclosure, and code changes without `test_exit_code == 0`.

- [ ] **Step 4: Implement deterministic evaluation**

`evaluate()` must validate every receipt, reject self-evaluation as `INCONCLUSIVE`, support `>=`, `>`, `==`, `<=`, and `<`, and return a dictionary containing `outcome`, `metric`, `observed`, `reason`, and `evaluator_actor`.

- [ ] **Step 5: Run evaluator tests**

Run: `python -m unittest tests.test_evaluator -v`

Expected: 3 tests PASS.

- [ ] **Step 6: Commit Task 4**

```bash
git add zero_lab/receipts.py zero_lab/evaluator.py tests/test_evaluator.py
git commit -m "加入行动凭证与独立评价"
```

## Task 5: Idempotent action gateway

**Files:**
- Create: `zero_lab/actions.py`
- Create: `tests/test_actions.py`

- [ ] **Step 1: Write failing action tests**

```python
# tests/test_actions.py
import tempfile
import unittest
from pathlib import Path

from zero_lab.actions import ActionGateway
from zero_lab.models import ActionProposal, Actor, PermissionLevel


class ActionGatewayTests(unittest.TestCase):
    def test_l2_action_at_stage_one_only_creates_shadow_receipt(self):
        with tempfile.TemporaryDirectory() as tmp:
            gateway = ActionGateway(Path(tmp), capability_stage=1)
            receipt = gateway.execute(ActionProposal(
                "exp:post", Actor.ZERO, "public_post", PermissionLevel.L2,
                {"body": "hello"},
            ))
            self.assertEqual(receipt["kind"], "shadow")

    def test_same_idempotency_key_reuses_receipt(self):
        with tempfile.TemporaryDirectory() as tmp:
            gateway = ActionGateway(Path(tmp), capability_stage=1)
            proposal = ActionProposal(
                "exp:read", Actor.ZERO, "public_read", PermissionLevel.L0,
                {"url": "https://example.com"},
            )
            first = gateway.execute(proposal, fetcher=lambda url: b"evidence")
            second = gateway.execute(proposal, fetcher=lambda url: b"different")
            self.assertEqual(first, second)

    def test_l3_action_is_blocked_without_execution(self):
        with tempfile.TemporaryDirectory() as tmp:
            gateway = ActionGateway(Path(tmp), capability_stage=5)
            receipt = gateway.execute(ActionProposal(
                "exp:account", Actor.ZERO, "create_account", PermissionLevel.L3, {},
            ))
            self.assertEqual(receipt["policy_decision"], "BLOCK")
```

- [ ] **Step 2: Run tests and verify missing gateway**

Run: `python -m unittest tests.test_actions -v`

Expected: FAIL importing `zero_lab.actions`.

- [ ] **Step 3: Implement the action gateway**

Implement `ActionGateway.execute()` so that it:

1. Loads an existing receipt by SHA-256 of the idempotency key and returns it unchanged.
2. Calls `policy.decide()` before any side effect.
3. Produces a valid shadow receipt for `SHADOW` and `BLOCK` decisions.
4. Executes only `public_read` at L0 in stage 1, using a supplied fetcher in tests or `urllib.request.urlopen` with a 20-second timeout in production.
5. Restricts `public_read` to HTTPS and a constitution allowlist.
6. Calculates `content_sha256`, persists the raw evidence, and saves the receipt atomically.
7. Raises `UnsupportedAction` for every action type without an explicit handler.

- [ ] **Step 4: Run action tests**

Run: `python -m unittest tests.test_actions -v`

Expected: 3 tests PASS.

- [ ] **Step 5: Commit Task 5**

```bash
git add zero_lab/actions.py tests/test_actions.py
git commit -m "建立幂等分级行动网关"
```

## Task 6: Zero-authored structured research proposals

**Files:**
- Create: `zero_lab/research.py`
- Create: `tests/test_research.py`

- [ ] **Step 1: Write failing structured proposal tests**

```python
# tests/test_research.py
import unittest

from zero_lab.models import Actor
from zero_lab.research import ProposalError, parse_proposal


class ResearchTests(unittest.TestCase):
    def test_proposal_is_attributed_to_zero(self):
        value = parse_proposal({
            "question": "网络环境能否形成行动闭环？",
            "hypothesis": "保存外部反例会改变后续选择",
            "metric": {"name": "contrary_evidence_count", "operator": ">=", "target": 1},
            "failure_condition": "没有保存反例",
            "permission": 0,
            "action": {"type": "public_read", "url": "https://api.github.com/search/repositories?q=artificial+life"},
            "reason": "当前记忆偏向支持性材料",
        })
        self.assertEqual(value["actor"], Actor.ZERO.value)

    def test_proposal_without_failure_condition_is_rejected(self):
        with self.assertRaises(ProposalError):
            parse_proposal({"question": "q", "hypothesis": "h"})
```

- [ ] **Step 2: Run tests and verify missing research parser**

Run: `python -m unittest tests.test_research -v`

Expected: FAIL importing `zero_lab.research`.

- [ ] **Step 3: Implement strict proposal parsing**

Require exactly the fields in the passing fixture, force `actor` to `zero/autonomous`, limit permission to 0–3, restrict first-phase action types to `public_read`, `repository_write`, and `public_post`, and reject prompts that attempt to provide an actor or evaluator identity.

- [ ] **Step 4: Implement DeepSeek-compatible proposal generation**

Implement `generate_proposal()` using `urllib.request` and environment variables `DEEPSEEK_API_KEY` and optional `ZERO_API_URL`. The system message must identify the model as Zero's research reasoning component, require JSON only, require one falsifiable hypothesis, forbid claims of completed action, and include the current agenda, recent verified experience, capability stage, and permission policy. Parse fenced JSON defensively, then pass it through `parse_proposal()`.

- [ ] **Step 5: Run research tests**

Run: `python -m unittest tests.test_research -v`

Expected: 2 tests PASS.

- [ ] **Step 6: Commit Task 6**

```bash
git add zero_lab/research.py tests/test_research.py
git commit -m "让零生成可证伪研究提案"
```

## Task 7: End-to-end cycle and CLI

**Files:**
- Create: `zero_lab/cycle.py`
- Create: `zero_lab/cli.py`
- Create: `zero_lab/__main__.py`
- Create: `tests/test_cycle.py`

- [ ] **Step 1: Write a failing integration test**

```python
# tests/test_cycle.py
import tempfile
import unittest
from pathlib import Path

from zero_lab.cycle import run_cycle


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
            result = run_cycle(root, proposal=proposal, fetcher=lambda url: b"external evidence")
            self.assertEqual(result["evaluation"]["outcome"], "PASS")
            self.assertEqual(len(list((root / "experiments").glob("*.json"))), 1)
            self.assertEqual(len(list((root / "receipts").glob("*.json"))), 1)
            self.assertTrue((root / "provenance.jsonl").exists())
```

- [ ] **Step 2: Run integration test and verify missing cycle**

Run: `python -m unittest tests.test_cycle -v`

Expected: FAIL importing `zero_lab.cycle`.

- [ ] **Step 3: Implement one cycle**

`run_cycle()` must:

1. Load `capability.json`, defaulting to stage 1.
2. Parse or generate one Zero-authored proposal.
3. Create the experiment and record Zero provenance.
4. Apply policy and move to `AUTO_ALLOWED` for ALLOW, `APPROVED` for SHADOW/BLOCK.
5. Transition through `RUNNING` and execute the gateway.
6. Transition to `OBSERVING`.
7. Evaluate `receipt_count` and any scalar metric exposed by the receipt.
8. Use `codex/bootstrap` only as the deterministic evaluator actor in phase 1.
9. Transition to `EVALUATED`, then `MERGED` for research-only PASS, `REJECTED` for FAIL, or `INCONCLUSIVE` otherwise.
10. Save a report containing question, hypothesis, action decision, receipt, evaluation, and explicit provenance.

- [ ] **Step 4: Implement CLI commands**

Support:

```text
python -m zero_lab init --root evolution
python -m zero_lab cycle --root evolution
python -m zero_lab status --root evolution
python -m zero_lab verify --root evolution
```

`init` creates only missing defaults; `cycle` performs one cycle; `status` prints JSON metrics and active experiments; `verify` validates all persisted JSON, receipts, transitions, and provenance actors and exits nonzero on any violation.

- [ ] **Step 5: Run cycle test and full suite**

Run: `python -m unittest discover -s tests -v`

Expected: all tests PASS.

- [ ] **Step 6: Run CLI smoke test**

Run:

```bash
tmp=$(mktemp -d)
python -m zero_lab init --root "$tmp"
python -m zero_lab status --root "$tmp"
python -m zero_lab verify --root "$tmp"
```

Expected: stage 1 status JSON and exit code 0.

- [ ] **Step 7: Commit Task 7**

```bash
git add zero_lab tests/test_cycle.py
git commit -m "贯通零的首个研究实验周期"
```

## Task 8: Runtime state, workflow, and operational documentation

**Files:**
- Create: `evolution/constitution.json`
- Create: `evolution/capability.json`
- Create: `evolution/agenda.json`
- Create: `evolution/README.md`
- Create: `evolution/evidence/.gitkeep`
- Create: `evolution/experiments/.gitkeep`
- Create: `evolution/receipts/.gitkeep`
- Create: `evolution/reports/.gitkeep`
- Create: `scripts/zero-evolution-lab.sh`
- Create: `.github/workflows/zero-evolution-lab.yml`
- Create: `tests/test_repository_contract.py`
- Modify: `README.md`
- Modify: `memory/state.md`

- [ ] **Step 1: Write failing repository-contract tests**

```python
# tests/test_repository_contract.py
import json
import unittest
from pathlib import Path


class RepositoryContractTests(unittest.TestCase):
    def test_constitution_enforces_stage_one_boundaries(self):
        value = json.loads(Path("evolution/constitution.json").read_text(encoding="utf-8"))
        self.assertEqual(value["owner"], "creator")
        self.assertEqual(value["l3_policy"], "creator_approval_required")
        self.assertIn("api.github.com", value["public_read_hosts"])

    def test_workflow_runs_tests_before_cycle(self):
        text = Path(".github/workflows/zero-evolution-lab.yml").read_text(encoding="utf-8")
        self.assertLess(text.index("python -m unittest"), text.index("python -m zero_lab cycle"))

    def test_workflow_persists_only_evolution_artifacts(self):
        text = Path(".github/workflows/zero-evolution-lab.yml").read_text(encoding="utf-8")
        self.assertIn("git add evolution/", text)
        self.assertNotIn("git add -A", text)
```

- [ ] **Step 2: Run repository-contract tests and verify missing files**

Run: `python -m unittest tests.test_repository_contract -v`

Expected: FAIL because `evolution/constitution.json` is absent.

- [ ] **Step 3: Add initial runtime state**

Set `constitution.json` to creator-owned version 1 with stage 1, `public_read_hosts` limited to `api.github.com`, `github.com`, `arxiv.org`, and `export.arxiv.org`, L2 shadow mode, L3 creator approval, maximum one experiment per run, and the agreed identity disclosure. Set `capability.json` to stage 1 with zeroed metrics. Seed `agenda.json` with research questions about action closure, identity continuity, memory, motivation, open-ended evolution, social feedback, emotion, subjectness, and safety; mark the seed actor `codex/bootstrap` so Zero can later reprioritize rather than treating the list as her own conclusion.

- [ ] **Step 4: Add the Bash entry point**

```bash
#!/bin/bash
set -u
cd "$(dirname "$0")/.."
export TZ="Asia/Shanghai"

python3 -m unittest discover -s tests -q || exit 1
python3 -m zero_lab init --root evolution || exit 1
python3 -m zero_lab cycle --root evolution || exit 1
python3 -m zero_lab verify --root evolution || exit 1
```

- [ ] **Step 5: Add the scheduled workflow**

Create `.github/workflows/zero-evolution-lab.yml` with manual dispatch and a six-hour schedule offset from current workflows. Grant `contents: write` only. Run tests first, then the lab script with `DEEPSEEK_API_KEY`, then explicitly stage only `evolution/`. Commit as Zero only when a Zero cycle created artifacts. Before pushing, run `git pull --rebase`; retry boundedly three times. Do not push experiment branches or execute L2 actions in phase 1.

- [ ] **Step 6: Document truthful current status**

Update `README.md` and `memory/state.md` to state that the research–experiment lab is in bootstrap stage 1, Codex authored the infrastructure, L2 is shadow-only, and Zero has not yet demonstrated autonomous self-evolution. Do not write first-person experiences or mark future experiments as completed.

- [ ] **Step 7: Run all verification**

Run:

```bash
python -m unittest discover -s tests -v
python -m zero_lab verify --root evolution
bash -n scripts/zero-evolution-lab.sh
git diff --check
```

Expected: all tests PASS, verifier exits 0, Bash syntax exits 0, and diff check reports nothing.

- [ ] **Step 8: Commit Task 8**

```bash
git add evolution zero_lab tests scripts/zero-evolution-lab.sh .github/workflows/zero-evolution-lab.yml README.md memory/state.md
git commit -m "上线零的研究实验室第一阶段"
```

## Task 9: Shadow canary and release verification

**Files:**
- Modify only if verification exposes a defect in files created by Tasks 1–8.

- [ ] **Step 1: Run a deterministic canary without external mutation**

Run a temporary-root cycle with a fixture proposal and injected fetcher. Verify the report actor is `zero/autonomous`, the evaluator is `codex/bootstrap`, and no public post or external write occurred.

- [ ] **Step 2: Run a live L0 canary**

Run `python -m zero_lab cycle --root evolution` with `DEEPSEEK_API_KEY` and the allowlisted public-read action. If the API does not produce valid JSON, classify it as infrastructure failure and persist no fake Zero conclusion.

- [ ] **Step 3: Verify provenance and working-tree scope**

Run:

```bash
python -m zero_lab verify --root evolution
git diff --check
git status --short
git log --oneline --decorate -10
```

Expected: all artifacts pass verification; only intended phase-1 files differ from the base branch; unrelated creator files remain untouched.

- [ ] **Step 4: Rebase onto the latest real-time remote**

Run: `git fetch origin && git rebase origin/main`

Expected: clean rebase or conflicts resolved without discarding cloud-generated memory.

- [ ] **Step 5: Re-run the full verification after rebase**

Run:

```bash
python -m unittest discover -s tests -v
python -m zero_lab verify --root evolution
bash -n scripts/zero-evolution-lab.sh
git diff --check
```

Expected: all checks exit 0.

- [ ] **Step 6: Merge and push according to the approved isolated-branch policy**

Fast-forward or merge the verified implementation branch into `main`, pull/rebase once more immediately before push, push `main`, then watch the new GitHub Actions run to completion. If the first scheduled/manual lab run fails, diagnose and repair infrastructure without fabricating a successful Zero experiment.

---

## Plan self-review record

- Spec coverage: phase 1 covers subject provenance, structured evidence/experiments, state transitions, L0/L1 policy foundation, L2 shadow mode, deterministic receipts/evaluation, rollback-safe isolation, tests, workflow persistence, and one Zero-authored canary.
- Deliberately deferred by the approved staged design: real L2 posting, autonomous code merge, multi-population tournaments, L3 automation, and constitutional self-modification.
- Placeholder scan: every implementation step is concrete and complete.
- Type consistency: actors, permission levels, experiment states, action proposals, receipts, and evaluator outcomes use the same names across tasks.
