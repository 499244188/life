from __future__ import annotations

import hashlib
import logging
from pathlib import Path
from typing import Callable
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen

from zero_lab.io import load_json, save_json, utc_now
from zero_lab.models import ActionProposal
from zero_lab.policy import PolicyDecision, decide
from zero_lab.receipts import validate_receipt

logger = logging.getLogger(__name__)


class UnsupportedAction(ValueError):
    pass


class FetchError(RuntimeError):
    """网络读取失败——非致命，应被记录为实验失败而非整体崩溃"""

    def __init__(self, url: str, code: int | None, message: str):
        self.url = url
        self.code = code
        self.message = message
        super().__init__(f"fetch {url}: {message}" + (f" (HTTP {code})" if code else ""))


class ActionGateway:
    def __init__(
        self,
        root: Path,
        capability_stage: int,
        public_read_hosts: set[str] | None = None,
    ):
        self.root = root
        self.capability_stage = capability_stage
        constitution = load_json(root / "constitution.json", {}) or {}
        configured = constitution.get("public_read_hosts", [])
        self.public_read_hosts = public_read_hosts or set(configured) or {"example.com"}

    def _receipt_path(self, key: str) -> Path:
        digest = hashlib.sha256(key.encode("utf-8")).hexdigest()
        return self.root / "receipts" / f"{digest}.json"

    @staticmethod
    def _fetch(url: str) -> bytes:
        request = Request(url, headers={"User-Agent": "zero-evolution-lab/1"})
        try:
            with urlopen(request, timeout=20) as response:
                return response.read()
        except HTTPError as exc:
            raise FetchError(url, exc.code, exc.reason) from exc
        except URLError as exc:
            raise FetchError(url, None, str(exc.reason)) from exc

    def execute(
        self,
        proposal: ActionProposal,
        fetcher: Callable[[str], bytes] | None = None,
    ) -> dict:
        receipt_path = self._receipt_path(proposal.idempotency_key)
        existing = load_json(receipt_path)
        if existing is not None:
            return existing

        decision = decide(proposal, self.capability_stage)
        if decision in {PolicyDecision.SHADOW, PolicyDecision.BLOCK}:
            receipt = {
                "kind": "shadow",
                "proposed_action": proposal.to_dict(),
                "policy_decision": decision.value,
                "created_at": utc_now(),
            }
            validate_receipt(receipt)
            save_json(receipt_path, receipt)
            return receipt

        if proposal.action_type != "public_read":
            raise UnsupportedAction(proposal.action_type)

        url = str(proposal.payload.get("url", ""))
        parsed = urlparse(url)
        if parsed.scheme != "https" or parsed.hostname not in self.public_read_hosts:
            raise PermissionError(f"public_read host not allowed: {parsed.hostname}")

        try:
            content = (fetcher or self._fetch)(url)
        except FetchError as exc:
            logger.warning("fetch failed, recording as error receipt: %s", exc)
            receipt = {
                "kind": "fetch_error",
                "url": url,
                "error_code": exc.code,
                "error_message": exc.message,
                "created_at": utc_now(),
            }
            save_json(receipt_path, receipt)
            return receipt

        content_hash = hashlib.sha256(content).hexdigest()
        evidence_path = self.root / "evidence" / f"{content_hash}.bin"
        evidence_path.parent.mkdir(parents=True, exist_ok=True)
        if not evidence_path.exists():
            evidence_path.write_bytes(content)
        receipt = {
            "kind": "public_read",
            "url": url,
            "content_sha256": content_hash,
            "created_at": utc_now(),
        }
        validate_receipt(receipt)
        save_json(receipt_path, receipt)
        return receipt
