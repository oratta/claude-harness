#!/usr/bin/env bash
# select-account.sh: 起動時に利用可能な Claude アカウントを 1 つ選ぶ。
#
# stdout は CLAUDE_SECURESTORAGE_CONFIG_DIR の実値 1 行だけ、stderr は選択理由 1 行だけ。
# 引数なしは usage snapshot による自動選択、slot id 1 個は snapshot 非依存の明示選択。
set -uo pipefail

ACCOUNTS_FILE="${CLAUDE_ACCOUNTS_FILE:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json}"
SNAPSHOT="${USAGE_SNAPSHOT:-$HOME/.claude/.usage-snapshot}"
NOW="${SELECT_ACCOUNT_NOW:-$(date +%s 2>/dev/null || echo 0)}"

if [ "$#" -gt 1 ]; then
  printf 'usage: select-account.sh [slot-id]\n' >&2
  exit 2
fi

ACCOUNTS_FILE="$ACCOUNTS_FILE" USAGE_SNAPSHOT="$SNAPSHOT" SELECT_ACCOUNT_NOW="$NOW" \
  python3 - "$@" <<'PY'
import json
import math
import os
import re
import sys

ID_RE = re.compile(r"[A-Za-z0-9-]{1,32}\Z")
CTRL_RE = re.compile(r"[\x00-\x1f\x7f]")
WEEK_SECONDS = 7 * 24 * 60 * 60
FRESH_SECONDS = 300


def read_registry(path):
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


def finite_number(value):
    return (isinstance(value, (int, float)) and not isinstance(value, bool)
            and math.isfinite(float(value)))


def read_snapshot(path):
    try:
        with open(path, encoding="utf-8") as handle:
            document = json.load(handle)
        if not isinstance(document, dict) or document.get("schema") != 2:
            return {}
        accounts = document.get("accounts")
        return accounts if isinstance(accounts, dict) else {}
    except Exception:
        return {}


slots = read_registry(os.environ["ACCOUNTS_FILE"])

if len(sys.argv) == 2:
    requested = sys.argv[1]
    for slot_id, secure in slots:
        if slot_id == requested:
            print(secure)
            sys.stderr.write(f"selected={slot_id} reason=explicit margins=-\n")
            raise SystemExit(0)
    sys.stderr.write(f"unknown account id: {requested}\n")
    raise SystemExit(2)

try:
    now = int(os.environ["SELECT_ACCOUNT_NOW"])
except (KeyError, TypeError, ValueError):
    now = 0

snapshot_accounts = read_snapshot(os.environ["USAGE_SNAPSHOT"])
margins = []
best = None
has_missing_or_stale = False

for index, (slot_id, secure) in enumerate(slots):
    observed = snapshot_accounts.get(slot_id)
    if not isinstance(observed, dict):
        margins.append((slot_id, "missing"))
        has_missing_or_stale = True
        continue

    fetched = observed.get("fetched_at")
    if not finite_number(fetched):
        margins.append((slot_id, "missing"))
        has_missing_or_stale = True
        continue
    age = now - float(fetched)
    if age < 0 or age >= FRESH_SECONDS:
        margins.append((slot_id, "stale"))
        has_missing_or_stale = True
        continue

    five_hour = observed.get("five_hour_pct")
    weekly = observed.get("weekly_all_pct")
    resets = observed.get("weekly_resets_epoch")
    if not all(finite_number(value) for value in (five_hour, weekly, resets)):
        margins.append((slot_id, "missing"))
        has_missing_or_stale = True
        continue
    if float(five_hour) >= 90:
        margins.append((slot_id, "five-hour>=90"))
        continue

    elapsed = (WEEK_SECONDS - (float(resets) - now)) / WEEK_SECONDS * 100
    elapsed = min(100.0, max(0.0, elapsed))
    margin = elapsed - float(weekly)
    display_margin = 0.0 if abs(margin) < 0.0005 else margin
    margins.append((slot_id, f"{display_margin:.2f}"))
    if best is None or margin > best[0]:
        best = (margin, index, slot_id, secure)

margin_text = ",".join(f"{slot_id}:{value}" for slot_id, value in margins)
if best is not None:
    _, _, selected, secure = best
    reason = "max-weekly-margin"
else:
    secure = ""
    selected = next((slot_id for slot_id, value in slots if value == ""),
                    "@unregistered-default")
    reason = ("default-due-to-missing-usage" if has_missing_or_stale
              else "default-due-to-five-hour-limit")

print(secure)
sys.stderr.write(f"selected={selected} reason={reason} margins={margin_text}\n")
PY
