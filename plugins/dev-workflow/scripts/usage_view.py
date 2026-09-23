#!/usr/bin/env python3
"""Effective Claude usage per account slot, from session records and the probe snapshot.

The rules are specified in openspec/specs/usage-session-records ("記録と snapshot から実効値を
求める"). Every dev-workflow reader (select-account.sh, session-tripwires.sh,
agent-model-guard.sh, codex-develop.py) uses this one implementation.

  usage_view.py --json [--now EPOCH]   print {"now", "active", "accounts"} as one JSON line

Inputs: CLAUDE_ACCOUNTS_FILE (default ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json),
USAGE_SESSIONS_DIR (default ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.usage-sessions),
USAGE_SNAPSHOT (default ~/.claude/.usage-snapshot) and CLAUDE_SECURESTORAGE_CONFIG_DIR.
"""
import hashlib
import json
import math
import os
import re
import sys
import time
import unicodedata

ID_RE = re.compile(r"[A-Za-z0-9-]{1,32}\Z")
CTRL_RE = re.compile(r"[\x00-\x1f\x7f]")
WEEK_SECONDS = 7 * 24 * 60 * 60
SAME_WINDOW_SECONDS = 3600


def config_dir():
    return os.environ.get("CLAUDE_CONFIG_DIR") or os.path.join(os.path.expanduser("~"), ".claude")


def default_paths():
    base = config_dir()
    return {
        "accounts_file": os.environ.get("CLAUDE_ACCOUNTS_FILE") or os.path.join(base, "accounts.json"),
        "sessions_dir": os.environ.get("USAGE_SESSIONS_DIR") or os.path.join(base, ".usage-sessions"),
        "snapshot_path": os.environ.get("USAGE_SNAPSHOT")
        or os.path.join(os.path.expanduser("~"), ".claude", ".usage-snapshot"),
    }


def service_name(securestorage):
    if not securestorage:
        return "Claude Code-credentials"
    return "Claude Code-credentials-" + session_key(securestorage)


def session_key(securestorage):
    """The record file name the statusline writes for this CLAUDE_SECURESTORAGE_CONFIG_DIR."""
    if not securestorage:
        return "default"
    value = unicodedata.normalize("NFC", securestorage).encode("utf-8")
    return hashlib.sha256(value).hexdigest()[:8]


def read_registry(path):
    """Same resolution as select-account.sh: [(id, securestorage)], default slot on failure."""
    slots = []
    try:
        with open(path, encoding="utf-8") as handle:
            document = json.load(handle)
        entries = document.get("accounts") if isinstance(document, dict) else None
        if isinstance(entries, list):
            seen = set()
            for entry in entries:
                if len(slots) >= 8:
                    break
                if not isinstance(entry, dict):
                    continue
                slot_id = entry.get("id")
                if not isinstance(slot_id, str) or not ID_RE.fullmatch(slot_id) or slot_id in seen:
                    continue
                label = entry.get("label", slot_id)
                if not isinstance(label, str) or not label:
                    label = slot_id
                secure = entry.get("securestorage")
                if secure is None:
                    secure = ""
                if not isinstance(secure, str) or CTRL_RE.search(label) or CTRL_RE.search(secure):
                    continue
                seen.add(slot_id)
                slots.append((slot_id, secure))
    except Exception:
        pass
    return slots or [("default", "")]


def _read_json(path):
    try:
        with open(path, encoding="utf-8") as handle:
            document = json.load(handle)
        return document if isinstance(document, dict) else None
    except Exception:
        return None


def read_snapshot(path):
    document = _read_json(path)
    if document is None or document.get("schema") != 2:
        return {}
    return document


def finite_number(value):
    return (isinstance(value, (int, float)) and not isinstance(value, bool)
            and math.isfinite(float(value)))


def _source(pct, resets, observed, *, five_hour):
    """Rule 1: a (pct, resets, observed) triple, or None when the window is absent."""
    if not finite_number(pct) or not 0 <= pct <= 100:
        return None
    if resets is None and five_hour:
        resets_ok = True
    else:
        resets_ok = finite_number(resets)
    if not resets_ok:
        return None
    return {"pct": pct, "resets": resets, "observed": observed if finite_number(observed) else None,
            "rolled": False}


def _normalize(value, now, *, five_hour):
    """Rules 2 and 3: past the reset reads as 0%; before it the value is a lower bound."""
    if value is None or value["resets"] is None or now < value["resets"]:
        return value
    if five_hour:
        resets = None
    else:
        weeks = (now - value["resets"]) // WEEK_SECONDS + 1
        resets = value["resets"] + weeks * WEEK_SECONDS
    return {"pct": 0, "resets": resets, "observed": value["observed"], "rolled": True}


def _newer(first, second):
    return max((first, second), key=lambda v: v["observed"] if v["observed"] is not None else -math.inf)


def _combine(record, snapshot, *, weekly_all):
    """Rule 4: pick between the session record and the snapshot after normalizing."""
    if record is None or snapshot is None:
        return record or snapshot
    if record["resets"] is None or snapshot["resets"] is None:
        if record["resets"] is None and snapshot["resets"] is None:
            return _larger(record, snapshot, resets=None)
        return record if record["resets"] is not None else snapshot
    gap = abs(record["resets"] - snapshot["resets"])
    if gap <= SAME_WINDOW_SECONDS:
        return _larger(record, snapshot, resets=_newer(record, snapshot)["resets"])
    if weekly_all and not record["rolled"]:
        return record
    return record if record["resets"] > snapshot["resets"] else snapshot


def _larger(first, second, *, resets):
    if first["pct"] != second["pct"]:
        taken = first if first["pct"] > second["pct"] else second
    else:
        taken = _newer(first, second)
    return dict(taken, resets=resets)


def _window(record, snapshot, now, *, five_hour=False, weekly_all=False):
    return _combine(_normalize(record, now, five_hour=five_hour),
                    _normalize(snapshot, now, five_hour=five_hour), weekly_all=weekly_all)


def slot_view(record, entry, now):
    """Effective values of one slot from its session record and snapshot entry (dicts or None)."""
    record = record if isinstance(record, dict) else {}
    entry = entry if isinstance(entry, dict) else {}
    observed, fetched = record.get("observed_at"), entry.get("fetched_at")

    def source(document, pct_key, resets_key, stamp, five_hour=False):
        if not document:
            return None
        return _source(document.get(pct_key), document.get(resets_key), stamp,
                       five_hour=five_hour)

    five = _window(source(record, "five_hour_pct", "five_hour_resets_epoch", observed, True),
                   source(entry, "five_hour_pct", "five_hour_resets_epoch", fetched, True),
                   now, five_hour=True)
    weekly = _window(source(record, "weekly_all_pct", "weekly_resets_epoch", observed),
                     source(entry, "weekly_all_pct", "weekly_resets_epoch", fetched),
                     now, weekly_all=True)
    fable = _window(None, source(entry, "fable_weekly_pct", "weekly_resets_epoch", fetched), now)

    def pick(value, field):
        return value[field] if value is not None else None

    return {
        "five_hour_pct": pick(five, "pct"),
        "five_hour_resets_epoch": pick(five, "resets"),
        "five_hour_observed_at": pick(five, "observed"),
        "weekly_all_pct": pick(weekly, "pct"),
        "weekly_resets_epoch": pick(weekly, "resets"),
        "weekly_observed_at": pick(weekly, "observed"),
        "fable_weekly_pct": pick(fable, "pct"),
        "fable_resets_epoch": pick(fable, "resets"),
        "fable_observed_at": pick(fable, "observed"),
        "observed_at": pick(weekly, "observed"),
        "session_observed_at": observed if finite_number(observed) else None,
        "probe_fetched_at": fetched if finite_number(fetched) else None,
    }


def active_slot(slots, snapshot, active_secure):
    """usage-account-registry: launch environment, then the snapshot's active, then the first."""
    wanted = service_name(active_secure)
    for slot_id, secure in slots:
        if service_name(secure) == wanted:
            return slot_id
    ids = [slot_id for slot_id, _ in slots]
    if snapshot.get("active") in ids:
        return snapshot["active"]
    return ids[0]


def build_view(accounts_file=None, sessions_dir=None, snapshot_path=None, now=None,
               active_secure=None):
    paths = default_paths()
    accounts_file = accounts_file or paths["accounts_file"]
    sessions_dir = sessions_dir or paths["sessions_dir"]
    snapshot_path = snapshot_path or paths["snapshot_path"]
    now = int(time.time()) if now is None else now
    if active_secure is None:
        active_secure = os.environ.get("CLAUDE_SECURESTORAGE_CONFIG_DIR", "")
    slots = read_registry(accounts_file)
    snapshot = read_snapshot(snapshot_path)
    entries = snapshot.get("accounts") if isinstance(snapshot.get("accounts"), dict) else {}
    accounts = {}
    for slot_id, secure in slots:
        record = _read_json(os.path.join(sessions_dir, session_key(secure) + ".json"))
        accounts[slot_id] = slot_view(record, entries.get(slot_id), now)
    return {"now": now, "active": active_slot(slots, snapshot, active_secure),
            "accounts": accounts}


def main(argv):
    now = None
    if "--now" in argv:
        index = argv.index("--now")
        try:
            now = int(argv[index + 1])
        except (IndexError, ValueError):
            sys.stderr.write("usage: usage_view.py --json [--now EPOCH]\n")
            return 2
        argv = argv[:index] + argv[index + 2:]
    if argv != ["--json"]:
        sys.stderr.write("usage: usage_view.py --json [--now EPOCH]\n")
        return 2
    print(json.dumps(build_view(now=now), ensure_ascii=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
