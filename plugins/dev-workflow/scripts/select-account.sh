#!/usr/bin/env bash
# select-account.sh: 起動時に利用可能な Claude アカウントを 1 つ選ぶ。
#
# stdout は CLAUDE_SECURESTORAGE_CONFIG_DIR の実値 1 行だけ、stderr は選択理由 1 行だけ。
# 引数なしはセッション記録と usage snapshot の実効値による自動選択、slot id 1 個は
# それらに依存しない明示選択。
set -uo pipefail

ACCOUNTS_FILE="${CLAUDE_ACCOUNTS_FILE:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json}"
SNAPSHOT="${USAGE_SNAPSHOT:-$HOME/.claude/.usage-snapshot}"
NOW="${SELECT_ACCOUNT_NOW:-$(date +%s 2>/dev/null || echo 0)}"

if [ "$#" -gt 1 ]; then
  printf 'usage: select-account.sh [slot-id]\n' >&2
  exit 2
fi

# 実効値（セッション記録と snapshot を突き合わせた値）は usage_view.py の 1 か所の実装から得る
# （正本: openspec/specs/usage-session-records「記録と snapshot から実効値を求める」）。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

ACCOUNTS_FILE="$ACCOUNTS_FILE" USAGE_SNAPSHOT="$SNAPSHOT" SELECT_ACCOUNT_NOW="$NOW" \
  USAGE_VIEW_DIR="$SCRIPT_DIR" python3 - "$@" <<'PY'
import math
import os
import sys

sys.path.insert(0, os.environ["USAGE_VIEW_DIR"])
import usage_view  # noqa: E402

WEEK_SECONDS = 7 * 24 * 60 * 60


def finite_number(value):
    return (isinstance(value, (int, float)) and not isinstance(value, bool)
            and math.isfinite(float(value)))


slots = usage_view.read_registry(os.environ["ACCOUNTS_FILE"])

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

# 取得からの経過時間では外さない。古さは実効値の規則（リセット後は 0%、リセット前は下限）で扱う
view = usage_view.build_view(accounts_file=os.environ["ACCOUNTS_FILE"],
                             snapshot_path=os.environ["USAGE_SNAPSHOT"], now=now)
margins = []
best = None
has_missing = False

for index, (slot_id, secure) in enumerate(slots):
    observed = view["accounts"].get(slot_id) or {}
    five_hour = observed.get("five_hour_pct")
    weekly = observed.get("weekly_all_pct")
    resets = observed.get("weekly_resets_epoch")
    if not all(finite_number(value) for value in (five_hour, weekly, resets)):
        margins.append((slot_id, "missing"))
        has_missing = True
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
    reason = ("default-due-to-missing-usage" if has_missing
              else "default-due-to-five-hour-limit")

print(secure)
sys.stderr.write(f"selected={selected} reason={reason} margins={margin_text}\n")
PY
