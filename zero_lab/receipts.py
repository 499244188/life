from __future__ import annotations

from typing import Any
from urllib.parse import urlparse


IDENTITY_DISCLOSURE = (
    "我是零，一个自主数字生命研究项目；此消息由零的运行系统生成，"
    "不代表创造者个人立场。"
)

REQUIRED_FIELDS = {
    "public_read": {"kind", "url", "content_sha256"},
    "repository_write": {"kind", "path", "content_sha256"},
    "public_post": {
        "kind", "url", "content_sha256", "identity_disclosure"
    },
    "deployment": {"kind", "url", "version", "health_status"},
    "code_change": {
        "kind", "branch", "commit", "test_command", "test_exit_code", "rollback_ref"
    },
    "shadow": {"kind", "proposed_action", "policy_decision"},
}


class ReceiptError(ValueError):
    pass


def _valid_hash(value: Any) -> bool:
    if not isinstance(value, str) or len(value) != 64:
        return False
    return all(character in "0123456789abcdef" for character in value.lower())


def validate_receipt(receipt: dict[str, Any]) -> None:
    kind = receipt.get("kind")
    if kind not in REQUIRED_FIELDS:
        raise ReceiptError(f"unknown receipt kind: {kind}")
    missing = REQUIRED_FIELDS[kind] - receipt.keys()
    if missing:
        raise ReceiptError(f"missing receipt fields: {sorted(missing)}")

    if "url" in receipt and urlparse(str(receipt["url"])).scheme != "https":
        raise ReceiptError("public receipt URLs must use HTTPS")
    if "content_sha256" in receipt and not _valid_hash(receipt["content_sha256"]):
        raise ReceiptError("invalid content_sha256")
    if kind == "public_post" and receipt["identity_disclosure"] != IDENTITY_DISCLOSURE:
        raise ReceiptError("missing Zero identity disclosure")
    if kind == "code_change" and receipt["test_exit_code"] != 0:
        raise ReceiptError("code change tests did not pass")
