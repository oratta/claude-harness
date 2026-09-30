#!/usr/bin/env python3
"""Compare a review Markdown hit table with repository-wide git-grep results.

With --head, also run the row-3 second stage of pr-review-gate (residual HEAD hits
vs not-applicable rows, the rewritten not-applicable rows table, mixed groups).
"""

import argparse
from collections import Counter
from pathlib import Path
import re
import shlex
import subprocess
import sys


SHA_RE = re.compile(r"^[0-9a-fA-F]{40}$")
HEADER = ("ファイル", "行（修正前 SHA）", "ヒットした行の本文", "扱い")
REWRITTEN_HEADING = "### 書き換えた該当しない行"
REWRITTEN_HEADER = ("ファイル", "行（修正前 SHA）", "修正後の本文")
FIXED = "直した"
NOT_APPLICABLE_RE = re.compile(r"該当しない: \S.*")
SAFE_FLAGS = {"-F", "--fixed-strings", "-E", "--extended-regexp", "-G",
              "--basic-regexp", "-P", "--perl-regexp", "-i", "--ignore-case",
              "-w", "--word-regexp", "-I", "--text", "--and", "--or", "--not",
              "(", ")"}


class ContractError(ValueError):
    pass


def field(lines, prefix):
    matches = [line[len(prefix):].strip() for line in lines if line.startswith(prefix)]
    if len(matches) != 1 or not matches[0]:
        raise ContractError(f"{prefix.rstrip()} must appear exactly once")
    return matches[0]


def split_markdown_row(line):
    cells = []
    current = []
    escaped = False
    for char in line.strip()[1:-1]:
        if escaped:
            current.append(char)
            escaped = False
        elif char == "\\":
            escaped = True
            current.append(char)
        elif char == "|":
            cells.append("".join(current))
            current = []
        else:
            current.append(char)
    if escaped:
        current.append("\\")
    cells.append("".join(current))
    return cells


def decode_cell(cell, *, preserve=False):
    value = cell.strip()
    if not preserve:
        return value.replace("\\|", "|")

    fence_length = len(value) - len(value.lstrip("`"))
    fence = "`" * fence_length
    if not fence or len(value) < fence_length * 2 or not value.endswith(fence):
        raise ContractError("hit row body must be enclosed by a backtick fence")
    encoded = value[fence_length:-fence_length]
    if fence in encoded:
        raise ContractError("hit row body backtick fence must exceed inner runs")

    decoded = []
    index = 0
    while index < len(encoded):
        char = encoded[index]
        if char == "`":
            raise ContractError("backticks in hit row body must be escaped")
        if char != "\\":
            decoded.append(char)
            index += 1
            continue
        index += 1
        if index >= len(encoded) or encoded[index] not in ("\\", "|", "`"):
            raise ContractError("hit row body has an invalid escape")
        decoded.append(encoded[index])
        index += 1
    return "".join(decoded)


def table_rows(lines, header, start=0):
    """Return the raw cells of the rows under the first table whose header is `header`."""
    header_index = None
    for index in range(start, len(lines)):
        line = lines[index]
        if not line.strip().startswith("|") or not line.strip().endswith("|"):
            continue
        cells = tuple(decode_cell(cell) for cell in split_markdown_row(line))
        if cells == header:
            header_index = index
            break
    if header_index is None:
        return None

    rows = []
    for line in lines[header_index + 1:]:
        if not line.lstrip().startswith("|"):
            if rows:
                break
            continue
        cells = split_markdown_row(line)
        if len(cells) != len(header):
            raise ContractError(f"every row must have {len(header)} columns")
        if all(re.fullmatch(r":?-+:?", cell.strip()) for cell in cells):
            continue
        rows.append(cells)
    return rows


def row_key(cells):
    path = decode_cell(cells[0])
    line_number = decode_cell(cells[1])
    if not path or not line_number.isdigit():
        raise ContractError("rows require path and numeric line")
    return path, int(line_number)


def parse_table(lines):
    """Parse the main hit table into (path, line, body, handling) rows."""
    raw = table_rows(lines, HEADER)
    if raw is None:
        raise ContractError("four-column hit table header is required")
    rows = []
    for cells in raw:
        path, line_number = row_key(cells)
        body = decode_cell(cells[2], preserve=True)
        if not body:
            raise ContractError("hit rows require path, numeric line, and body")
        rows.append((path, line_number, body, decode_cell(cells[3])))
    return rows


def parse_rewritten(lines, rows):
    """Parse the rewritten not-applicable rows table into ({(path, line): new body}, violations).

    Structural errors (missing header) still raise immediately. The three per-row content
    checks (duplicate key, wrong target, unchanged body) accumulate into `violations` instead
    so the rest of the table keeps being checked; a violating row is not added to `rewritten`.
    """
    start = next((index for index, line in enumerate(lines)
                  if line.strip() == REWRITTEN_HEADING), None)
    if start is None:
        return {}, []
    raw = table_rows(lines, REWRITTEN_HEADER, start + 1)
    if raw is None:
        raise ContractError("rewritten-rows table header is required under its heading")
    by_key = {(path, number): (body, handling) for path, number, body, handling in rows}
    rewritten = {}
    violations = []
    seen = set()
    for cells in raw:
        key = row_key(cells)
        new_body = decode_cell(cells[2], preserve=True)
        if key in seen:
            violations.append(f"rewritten row is duplicated: {key[0]}:{key[1]}")
            continue
        seen.add(key)
        if key not in by_key or not NOT_APPLICABLE_RE.fullmatch(by_key[key][1]):
            violations.append(
                f"rewritten row must point at one not-applicable row: {key[0]}:{key[1]}")
            continue
        if new_body == by_key[key][0]:
            violations.append(f"rewritten row body is unchanged: {key[0]}:{key[1]}")
            continue
        rewritten[key] = new_body
    return rewritten, violations


def deleted_lines(repo, before, after, path):
    """Count deleted line bodies in `git diff before after -- path`."""
    result = subprocess.run(
        ["git", "diff", "--no-color", "--no-ext-diff", "--no-renames", "-U0",
         before, after, "--", path],
        cwd=repo, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "git diff failed")
    counts = Counter()
    in_hunk = False
    for line in result.stdout.splitlines():
        if line.startswith("@@"):
            in_hunk = True
        elif line.startswith("diff --git"):
            in_hunk = False
        elif in_hunk and line.startswith("-"):
            counts[line[1:]] += 1
    return counts


def second_stage(repo, rows, rewritten, head_hits, sha, head):
    """Row-3 second stage: HEAD residual hits vs not-applicable rows, and mixed groups."""
    report = []
    allowed = Counter()
    for path, number, body, handling in rows:
        if NOT_APPLICABLE_RE.fullmatch(handling):
            allowed[(path, rewritten.get((path, number), body))] += 1

    residual = {}
    for path, number, body in sorted(head_hits):
        residual.setdefault((path, body), []).append(number)
    for (path, body), numbers in sorted(residual.items()):
        for number in numbers[allowed[(path, body)]:]:
            report.append(f"unmatched: {path}:{number}")

    groups = {}
    for path, number, body, handling in rows:
        groups.setdefault((path, body), []).append((number, handling))
    diffs = {}
    for (path, body), members in sorted(groups.items()):
        fixed = [number for number, handling in members if handling == FIXED]
        not_applicable = [number for number, handling in members if handling != FIXED]
        if not fixed or not not_applicable:
            continue
        required = len(fixed) + sum((path, number) in rewritten for number in not_applicable)
        if path not in diffs:
            diffs[path] = deleted_lines(repo, sha, head, path)
        if diffs[path][body] < required:
            report.extend(f"not-removed: {path}:{number}" for number in sorted(fixed))
    return report


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
    has_pattern = False
    index = 0
    while index < len(search):
        token = search[index]
        if token in ("-e", "--regexp"):
            index += 1
            if index >= len(search) or not search[index]:
                raise ContractError("-e/--regexp requires a pattern")
            has_pattern = True
        elif token in SAFE_FLAGS:
            pass
        elif token.startswith("-"):
            raise ContractError(f"search option is not allowed: {token}")
        else:
            has_pattern = True
        index += 1
    if not has_pattern:
        raise ContractError("search term is required")
    return ["git", "grep", "-n", *search, sha, "--", "."]


def repository_root(repo):
    result = subprocess.run(["git", "-C", str(repo), "rev-parse", "--show-toplevel"],
                            text=True, capture_output=True)
    if result.returncode:
        raise ContractError("--repo must be a Git repository root")
    root = Path(result.stdout.strip()).resolve()
    if root != repo.resolve():
        raise ContractError("--repo must be the repository root")
    return root


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
    parser.add_argument("--head", help="post-fix HEAD (40-digit SHA); runs the row-3 second stage")
    args = parser.parse_args()
    lines = args.table.read_text().splitlines()
    sha = field(lines, "修正前 SHA:")
    if not SHA_RE.fullmatch(sha):
        raise ContractError("修正前 SHA must be a full 40-digit SHA")
    if args.head is not None and not SHA_RE.fullmatch(args.head):
        raise ContractError("--head must be a full 40-digit SHA")
    search = field(lines, "検索コマンド:")
    command = parse_command(search, sha)
    rows = parse_table(lines)
    rewritten = {}
    violations = []
    if args.head is not None:
        for path, number, _body, handling in rows:
            if handling != FIXED and not NOT_APPLICABLE_RE.fullmatch(handling):
                violations.append(
                    f"row-3 handling must be 直した or 該当しない: <理由>: {path}:{number}")
        rewritten, rewritten_violations = parse_rewritten(lines, rows)
        violations += rewritten_violations
    expected = {(path, number, body) for path, number, body, _handling in rows}
    repo = repository_root(args.repo)
    actual = actual_hits(repo, command)
    report = [f"missing: {path}:{number}" for path, number, _body in sorted(actual - expected)]
    report += [f"extra: {path}:{number}" for path, number, _body in sorted(expected - actual)]
    # A row-level contract violation makes the not-applicable/rewritten bookkeeping
    # unreliable, so the second stage (unmatched:/not-removed:) only runs when clean.
    if args.head is not None and not violations:
        head_hits = actual_hits(repo, parse_command(search, args.head))
        report += second_stage(repo, rows, rewritten, head_hits, sha, args.head)
    report += [f"contract: {message}" for message in violations]
    for line in report:
        print(line)
    return int(bool(report))


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ContractError, OSError, RuntimeError, ValueError) as exc:
        print(f"contract: {exc}", file=sys.stderr)
        sys.exit(1)
