#!/usr/bin/env python3
"""Prune old artifacts — the other scripting language a server sees."""
from __future__ import annotations

import shutil
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path


@dataclass(frozen=True)
class Rule:
    pattern: str
    keep: timedelta

    def expired(self, path: Path, now: datetime) -> bool:
        age = now - datetime.fromtimestamp(path.stat().st_mtime)
        return age > self.keep


RULES = [
    Rule("*.log", timedelta(days=30)),
    Rule("*.sql.gz", timedelta(days=14)),
]


def sweep(root: Path, *, dry_run: bool = True) -> int:
    now, removed = datetime.now(), 0
    for rule in RULES:
        for path in root.rglob(rule.pattern):
            if not rule.expired(path, now):
                continue
            print(f"{'would remove' if dry_run else 'removing'} {path}")
            if not dry_run:
                shutil.rmtree(path, ignore_errors=True) if path.is_dir() else path.unlink()
            removed += 1
    return removed


if __name__ == "__main__":
    sweep(Path("/var/log"), dry_run=True)
