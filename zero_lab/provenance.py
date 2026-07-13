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
    append_jsonl(
        ledger,
        {
            "timestamp": utc_now(),
            "actor": actor.value,
            "kind": kind,
            "summary": summary,
            "artifact": artifact,
        },
    )
