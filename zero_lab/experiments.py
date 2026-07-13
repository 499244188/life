from __future__ import annotations

from pathlib import Path
from typing import Any
from uuid import uuid4

from zero_lab.io import load_json, save_json, utc_now
from zero_lab.models import Actor, ExperimentStatus, PermissionLevel


class InvalidTransition(ValueError):
    pass


class InvalidExperiment(ValueError):
    pass


LEGAL_TRANSITIONS = {
    ExperimentStatus.PROPOSED: {
        ExperimentStatus.APPROVED,
        ExperimentStatus.AUTO_ALLOWED,
    },
    ExperimentStatus.APPROVED: {ExperimentStatus.RUNNING},
    ExperimentStatus.AUTO_ALLOWED: {ExperimentStatus.RUNNING},
    ExperimentStatus.RUNNING: {
        ExperimentStatus.OBSERVING,
        ExperimentStatus.REJECTED,
    },
    ExperimentStatus.OBSERVING: {
        ExperimentStatus.EVALUATED,
        ExperimentStatus.INCONCLUSIVE,
    },
    ExperimentStatus.EVALUATED: {
        ExperimentStatus.MERGED,
        ExperimentStatus.REJECTED,
    },
}


class ExperimentStore:
    def __init__(self, directory: Path):
        self.directory = directory

    def _path(self, experiment_id: str) -> Path:
        return self.directory / f"{experiment_id}.json"

    def create(
        self,
        *,
        actor: Actor,
        question: str,
        hypothesis: str,
        metric: dict[str, Any],
        failure_condition: str,
        permission: PermissionLevel,
        action: dict[str, Any],
    ) -> dict[str, Any]:
        required_text = {
            "question": question,
            "hypothesis": hypothesis,
            "failure_condition": failure_condition,
        }
        empty = [name for name, value in required_text.items() if not value.strip()]
        if empty or not metric or not action:
            raise InvalidExperiment(f"missing required fields: {', '.join(empty)}")

        now = utc_now()
        experiment = {
            "id": uuid4().hex[:12],
            "actor": actor.value,
            "question": question,
            "hypothesis": hypothesis,
            "metric": metric,
            "failure_condition": failure_condition,
            "permission": int(permission),
            "action": action,
            "status": ExperimentStatus.PROPOSED.value,
            "created_at": now,
            "updated_at": now,
            "history": [],
        }
        save_json(self._path(experiment["id"]), experiment)
        return experiment

    def load(self, experiment_id: str) -> dict[str, Any]:
        value = load_json(self._path(experiment_id))
        if value is None:
            raise FileNotFoundError(experiment_id)
        return value

    def transition(
        self, experiment_id: str, target: ExperimentStatus
    ) -> dict[str, Any]:
        experiment = self.load(experiment_id)
        current = ExperimentStatus(experiment["status"])
        if target not in LEGAL_TRANSITIONS.get(current, set()):
            raise InvalidTransition(f"{current.value} -> {target.value}")

        now = utc_now()
        experiment["history"].append(
            {"from": current.value, "to": target.value, "timestamp": now}
        )
        experiment["status"] = target.value
        experiment["updated_at"] = now
        save_json(self._path(experiment_id), experiment)
        return experiment

    def attach(self, experiment_id: str, **fields: Any) -> dict[str, Any]:
        experiment = self.load(experiment_id)
        experiment.update(fields)
        experiment["updated_at"] = utc_now()
        save_json(self._path(experiment_id), experiment)
        return experiment
