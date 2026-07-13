from __future__ import annotations

import argparse
import json
from pathlib import Path

from zero_lab.cycle import initialize, run_cycle, verify_root
from zero_lab.io import load_json


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="zero_lab")
    subparsers = parser.add_subparsers(dest="command", required=True)
    for name in ("init", "cycle", "status", "verify"):
        command = subparsers.add_parser(name)
        command.add_argument("--root", type=Path, default=Path("evolution"))
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "init":
        initialize(args.root)
        print(json.dumps({"initialized": str(args.root)}, ensure_ascii=False))
        return 0
    if args.command == "cycle":
        print(json.dumps(run_cycle(args.root), ensure_ascii=False, indent=2))
        return 0
    if args.command == "status":
        initialize(args.root)
        status = load_json(args.root / "capability.json")
        status["active_experiments"] = sum(
            1
            for path in (args.root / "experiments").glob("*.json")
            if load_json(path).get("status")
            not in {"MERGED", "REJECTED", "INCONCLUSIVE"}
        )
        print(json.dumps(status, ensure_ascii=False, indent=2))
        return 0
    errors = verify_root(args.root)
    print(json.dumps({"valid": not errors, "errors": errors}, ensure_ascii=False, indent=2))
    return 0 if not errors else 1
