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
