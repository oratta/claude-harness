#!/usr/bin/env python3
"""Compare a review Markdown hit table with repository-wide git-grep results."""

import argparse
from pathlib import Path
import re
import shlex
import subprocess
import sys


SHA_RE = re.compile(r"^[0-9a-fA-F]{40}$")
HEADER = ("ファイル", "行（修正前 SHA）", "ヒットした行の本文", "扱い")


class ContractError(ValueError):
    pass


def field(lines, prefix):
    matches = [line[len(prefix):].strip() for line in lines if line.startswith(prefix)]
    if len(matches) != 1 or not matches[0]:
        raise ContractError(f"{prefix.rstrip()} must appear exactly once")
    return matches[0]


def parse_table(lines):
    header_index = None
    for index, line in enumerate(lines):
        cells = tuple(cell.strip() for cell in line.strip().strip("|").split("|"))
        if cells == HEADER:
            header_index = index
            break
    if header_index is None:
        raise ContractError("four-column hit table header is required")

    hits = set()
    for line in lines[header_index + 1:]:
        if not line.lstrip().startswith("|"):
            if hits:
                break
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) != 4:
            raise ContractError("every hit row must have four columns")
        if all(re.fullmatch(r":?-+:?", cell) for cell in cells):
            continue
        path, line_number, body, _handling = cells
        if not path or not line_number.isdigit() or not body:
            raise ContractError("hit rows require path, numeric line, and body")
        hits.add((path, int(line_number), body))
    return hits


def parse_command(command, sha):
    try:
        tokens = shlex.split(command)
    except ValueError as exc:
        raise ContractError(f"invalid search command: {exc}") from exc
    if len(tokens) < 7 or tokens[:3] != ["git", "grep", "-n"]:
        raise ContractError("search command must start with: git grep -n")
    if tokens[-3:] != ["<rev>", "--", "."]:
        raise ContractError("search command must end with: <rev> -- .")
    search = tokens[3:-3]
    if not search:
        raise ContractError("search term is required")
    return ["git", "grep", "-n", *search, sha, "--", "."]


def actual_hits(repo, command):
    result = subprocess.run(command, cwd=repo, text=True, capture_output=True)
    if result.returncode not in (0, 1):
        raise RuntimeError(result.stderr.strip() or "git grep failed")
    hits = set()
    for line in result.stdout.splitlines():
        parts = line.split(":", 3)
        if len(parts) == 4 and SHA_RE.fullmatch(parts[0]):
            _revision, path, number, body = parts
        else:
            path, number, body = line.split(":", 2)
        hits.add((path, int(number), body))
    return hits


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("table", type=Path)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    args = parser.parse_args()
    lines = args.table.read_text().splitlines()
    sha = field(lines, "修正前 SHA:")
    if not SHA_RE.fullmatch(sha):
        raise ContractError("修正前 SHA must be a full 40-digit SHA")
    command = parse_command(field(lines, "検索コマンド:"), sha)
    expected = parse_table(lines)
    actual = actual_hits(args.repo.resolve(), command)
    for path, number, _body in sorted(actual - expected):
        print(f"missing: {path}:{number}")
    for path, number, _body in sorted(expected - actual):
        print(f"extra: {path}:{number}")
    return int(actual != expected)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ContractError, OSError, RuntimeError, ValueError) as exc:
        print(f"contract: {exc}", file=sys.stderr)
        sys.exit(1)
