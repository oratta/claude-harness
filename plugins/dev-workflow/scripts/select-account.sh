#!/usr/bin/env bash
# select-account.sh: 起動時に利用可能な Claude アカウントを 1 つ選ぶ。
#
# stdout は CLAUDE_SECURESTORAGE_CONFIG_DIR の実値 1 行だけ、stderr は選択理由 1 行だけ。
# 引数なしは headroom.compute(now) の best_by_provider.claude（Claude で一番余っている
# スロット）による自動選択、slot id 1 個はそれに依存しない明示選択。余りと候補の外し方は
# headroom.py の 1 か所で数え、ここでは数え直さない。
# accounts.json で enabled が false のスロット（オフ）は自動選択の候補にせず（margins には
# <id>:off と出す）、明示選択は exit 2 で拒否する。全スロットがオフなら既定アカウントへ縮退し、
# 理由は default-due-to-all-off。
set -uo pipefail

ACCOUNTS_FILE="${CLAUDE_ACCOUNTS_FILE:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json}"
SNAPSHOT="${USAGE_SNAPSHOT:-$HOME/.claude/.usage-snapshot}"
NOW="${SELECT_ACCOUNT_NOW:-$(date +%s 2>/dev/null || echo 0)}"

if [ "$#" -gt 1 ]; then
  printf 'usage: select-account.sh [slot-id]\n' >&2
  exit 2
fi

# 余り・margin・各スロットの status は headroom.py の 1 か所の実装から得る（正本:
# openspec/specs/dev-workflow-headroom。実効値は usage_view.py が記録と snapshot から求める）。
# headroom は usage_view.default_paths で CLAUDE_ACCOUNTS_FILE と USAGE_SNAPSHOT を読む。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

CLAUDE_ACCOUNTS_FILE="$ACCOUNTS_FILE" USAGE_SNAPSHOT="$SNAPSHOT" \
  SELECT_ACCOUNT_NOW="$NOW" USAGE_VIEW_DIR="$SCRIPT_DIR" python3 - "$@" <<'PY'
import os
import shlex
import sys

sys.path.insert(0, os.environ["USAGE_VIEW_DIR"])
import usage_view  # noqa: E402
import headroom  # noqa: E402

slots = usage_view.read_slots(os.environ["CLAUDE_ACCOUNTS_FILE"])

if len(sys.argv) == 2:
    requested = sys.argv[1]
    for slot_id, secure, enabled in slots:
        if slot_id == requested:
            if not enabled:
                sys.stderr.write(
                    f"account {requested} is off (enabled is false in {os.environ['CLAUDE_ACCOUNTS_FILE']}): "
                    f"run {shlex.quote(os.path.join(os.environ['USAGE_VIEW_DIR'], 'accounts.sh'))} on {requested}\n")
                raise SystemExit(2)
            print(secure)
            sys.stderr.write(f"selected={slot_id} reason=explicit margins=-\n")
            raise SystemExit(0)
    sys.stderr.write(f"unknown account id: {requested}\n")
    raise SystemExit(2)

try:
    now = int(os.environ["SELECT_ACCOUNT_NOW"])
except (KeyError, TypeError, ValueError):
    now = 0


def default_slot():
    # 縮退先は常に既定アカウントなので、selected は enabled を見ずに決める
    return next((slot_id for slot_id, value, _ in slots if value == ""), "@unregistered-default")


# 取得からの経過時間では外さない。古さは実効値の規則（リセット後は 0%、リセット前は下限）で扱い、
# 候補の外し方（off・missing・stale・5 時間 90% 以上）と同点の宣言順は headroom の best に従う
try:
    result = headroom.compute(now)
except headroom.ConfigError:
    print("")
    sys.stderr.write(f"selected={default_slot()} reason=default-due-to-invalid-headroom-setting margins=-\n")
    raise SystemExit(0)

rows = [row for row in result["accounts"] if row["provider"] == "claude"]
margins = []
for row in rows:
    if row["status"] != "ok":
        margins.append((row["account"], row["status"]))
    elif row["five_hour_pct"] is not None and row["five_hour_pct"] >= headroom.FIVE_HOUR_LIMIT:
        margins.append((row["account"], "five-hour>=90"))
    else:
        margin = row["margin"]
        display_margin = 0.0 if abs(margin) < 0.0005 else margin
        margins.append((row["account"], f"{display_margin:.2f}"))

margin_text = ",".join(f"{slot_id}:{value}" for slot_id, value in margins)
best = result["best_by_provider"]["claude"]
if best is not None:
    selected = best["account"]
    secure = next(value for slot_id, value, _ in slots if slot_id == selected)
    reason = "max-surplus"
else:
    secure = ""
    selected = default_slot()
    statuses = [row["status"] for row in rows]
    if all(status == "off" for status in statuses):
        reason = "default-due-to-all-off"
    elif any(status in ("missing", "stale") for status in statuses):
        reason = "default-due-to-missing-usage"
    else:
        reason = "default-due-to-five-hour-limit"

print(secure)
sys.stderr.write(f"selected={selected} reason={reason} margins={margin_text}\n")
PY
