#!/usr/bin/env python3
"""Collect a single, passive observation. Exit 0 means saved, never live acceptance."""
import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


class CollectionError(Exception):
    """Only fixed messages may reach the caller."""


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise CollectionError("invalid-arguments")


# These are the only operator assertions that may be copied into a result.
ENUMS = {
    "role": ("parent", "child", "standalone"),
    "kind": ("idle", "config", "normal-compact"),
    "effective_idle": ("on", "off", "unknown"),
    "config_method": ("config", "live-inspection", "disk-only", "unknown"),
    "parent_before": ("on", "off", "unknown"),
    "parent_after": ("on", "off", "unknown"),
    "parent_application": ("live", "restart", "unknown"),
    "child_idle_argument": ("off", "on", "absent", "unknown"),
    "last_request_source": ("request-log", "external-record", "unknown"),
    "threshold_source": ("version-default", "explicit-setting", "unknown"),
    "sleep": ("yes", "no", "unknown"),
    "extra_requests": ("yes", "no", "unknown"),
    "compact_kind": ("none", "automatic", "manual", "unknown"),
    "compact_source": ("session-observation", "external-record", "unknown"),
    "hook_notice": ("yes", "no", "unknown", "not-performed"),
    "skill_read": ("yes", "no", "unknown", "not-performed"),
}
TIMES = ("start_time", "end_time", "last_request_time")
NUMBERS = ("start_line", "end_line", "idle_threshold")


def metadata(path):
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        raise CollectionError("unreadable-metadata") from None
    if not isinstance(raw, dict):
        raise CollectionError("invalid-metadata")
    clean = {}
    for key, allowed in ENUMS.items():
        value = raw.get(key, "unknown")
        if not isinstance(value, str) or value not in allowed:
            raise CollectionError("invalid-metadata")
        clean[key] = value
    if clean["role"] == "unknown" or clean["kind"] == "unknown":
        raise CollectionError("invalid-metadata")
    for key in NUMBERS:
        value = raw.get(key)
        if value is not None and (type(value) is not int or value < 0):
            raise CollectionError("invalid-metadata")
        clean[key] = value
    patterns = {"version": r"[0-9]+\.[0-9]+\.[0-9]+", "plugin_commit": r"[0-9a-f]{40}"}
    for key, pattern in patterns.items():
        value = raw.get(key)
        if value is not None and (not isinstance(value, str) or not re.fullmatch(pattern, value)):
            raise CollectionError("invalid-metadata")
        clean[key] = value
    for key in TIMES:
        value = raw.get(key)
        # Keep invalid calendar dates as unknown, but never copy arbitrary text.
        if value is not None and (not isinstance(value, str) or not re.fullmatch(
                r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:Z|[+-]\d{2}:\d{2})", value)):
            raise CollectionError("invalid-metadata")
        clean[key] = value if instant(value) is not None else None
    return clean


def instant(value):
    if value is None:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def repo_root(path):
    proc = subprocess.run(["git", "-C", str(path), "rev-parse", "--show-toplevel"],
                          capture_output=True, text=True, check=False)
    return Path(proc.stdout.strip()).resolve() if proc.returncode == 0 else None


def is_inside(path, root):
    return root is not None and (path == root or root in path.parents)


def locations(args):
    value = os.environ.get("LLM_LOG_DIR", "")
    if not value.strip():
        raise CollectionError("主に保存先を確認し LLM_LOG_DIR を設定して再実行")
    roots = (repo_root(Path.cwd()), repo_root(Path(__file__).resolve().parent))
    dest = Path(value).resolve()
    transcript = Path(args.transcript).resolve()
    meta = Path(args.metadata).resolve()
    if any(is_inside(p, root) for p in (dest, transcript, meta) for root in roots):
        raise CollectionError("repository-path-forbidden")
    return dest, transcript, meta


def measure(transcript, meta, dest):
    """Validate through E, measure only the prefix through S, ignore later appends."""
    start, end = meta["start_line"], meta["end_line"]
    if start is None or end is None or start > end:
        return None, None, ["invalid-line-range"]
    prefix = []
    count = 0
    try:
        with transcript.open("rb") as source:
            for number in range(1, end + 1):
                line = source.readline()
                if not line:
                    return None, None, ["truncated-transcript"]
                if not line.endswith(b"\n"):
                    return None, None, ["incomplete-transcript"]
                try:
                    record = json.loads(line)
                except (ValueError, UnicodeError):
                    return None, None, ["invalid-transcript"]
                if not isinstance(record, dict):
                    return None, None, ["invalid-transcript"]
                if number <= start:
                    prefix.append(line)
                elif record.get("type") == "system" and record.get("subtype") == "compact_boundary":
                    count += 1
    except OSError:
        return None, None, ["unreadable-transcript"]
    # Same approved external directory as results; never inherit a repo-local TMPDIR.
    with tempfile.TemporaryDirectory(prefix="observation-prefix-", dir=dest) as work:
        path = Path(work) / "prefix.jsonl"
        path.write_bytes(b"".join(prefix))
        proc = subprocess.run(["bash", str(Path(__file__).with_name("subagent-context.sh")),
                               "--file", str(path)], capture_output=True, check=False)
    tokens = None
    if proc.returncode in (0, 2):
        try:
            value = json.loads(proc.stdout).get("context_tokens")
            if type(value) is int and value >= 0:
                tokens = value
        except (ValueError, AttributeError):
            pass
    return tokens, count, [] if tokens is not None else ["context-unavailable"]


def classify(meta, transcript, dest):
    result = {"metadata": meta, "context_tokens": None, "boundary_count": None,
              "elapsed_seconds": None, "result": "unverified", "reasons": []}
    reasons = result["reasons"]
    for key in ("version", "plugin_commit"):
        if meta[key] is None:
            reasons.append("missing-" + key.replace("_", "-"))
    if meta["kind"] == "config":
        if meta["effective_idle"] == "unknown" or meta["config_method"] not in ("config", "live-inspection"):
            reasons.append("effective-config-unconfirmed")
    else:
        tokens, count, errors = measure(transcript, meta, dest)
        result.update(context_tokens=tokens, boundary_count=count)
        reasons.extend(errors)
        start, end = instant(meta["start_time"]), instant(meta["end_time"])
        if start is None or end is None or end < start:
            reasons.append("invalid-observation-times")
        if meta["kind"] == "idle":
            last = instant(meta["last_request_time"])
            if last is None or start is None or end is None or last > start or end < start:
                reasons.append("invalid-request-time")
            else:
                result["elapsed_seconds"] = (end - last).total_seconds()
                if result["elapsed_seconds"] < 3600:
                    reasons.append("idle-too-short")
            if meta["last_request_source"] == "unknown":
                reasons.append("request-source-unknown")
            if meta["role"] not in ("parent", "child"):
                reasons.append("idle-role-ineligible")
            if meta["effective_idle"] != "off" or meta["config_method"] not in ("config", "live-inspection"):
                reasons.append("effective-off-unconfirmed")
            threshold = meta["idle_threshold"]
            if threshold is None or threshold <= 0 or meta["threshold_source"] == "unknown":
                reasons.append("threshold-unconfirmed")
            elif tokens is not None and tokens < threshold:
                reasons.append("context-below-threshold")
            for key in ("sleep", "extra_requests"):
                if meta[key] != "no":
                    reasons.append(key.replace("_", "-") + "-unconfirmed")
            if meta["compact_kind"] != "none":
                reasons.append("compact-mixed-or-unknown")
        else:
            if start is not None and end is not None and end >= start:
                result["elapsed_seconds"] = (end - start).total_seconds()
            if meta["compact_kind"] != "automatic" or meta["compact_source"] == "unknown" or not count:
                reasons.append("automatic-compact-unconfirmed")
            for key in ("hook_notice", "skill_read"):
                if meta[key] != "yes":
                    reasons.append(key.replace("_", "-") + "-unconfirmed")
    if not reasons:
        result["result"] = ("unexpected-boundary" if meta["kind"] == "idle" and
                            result["boundary_count"] else "observed")
    return result


def main():
    parser = Parser(description=__doc__)
    parser.add_argument("--transcript", required=True)
    parser.add_argument("--metadata", required=True)
    args = parser.parse_args()
    dest, transcript, meta_path = locations(args)
    meta = metadata(meta_path)
    dest.mkdir(parents=True, exist_ok=True)
    result = classify(meta, transcript, dest)
    # Exclusive creation prevents replacing a prior observation or the original inputs.
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", prefix="idle-observation-",
                                     suffix=".json", dir=dest, delete=False) as output:
        json.dump(result, output, ensure_ascii=False, indent=2)
        output.write("\n")
    print("saved " + result["result"])
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except CollectionError as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
    except (OSError, ValueError, subprocess.SubprocessError):
        print("collection-failed", file=sys.stderr)
        sys.exit(1)
