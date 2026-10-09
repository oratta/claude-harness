#!/usr/bin/env bats
# hook が呼ぶ python3 の隔離と、CLAUDE_PLUGIN_ROOT が空のときの探索先（issue #847）
#
# 何を固定するか:
#   1. hooks.json に登録されたスクリプト（と、そこから呼ばれる usage-probe.sh）の python3 が、
#      -I（隔離モード）か、隣のモジュールを読む 3 本だけ -E -s で起動される。
#   2. 作業ディレクトリと PYTHONPATH に置いた偽の json.py・re.py・usage_view.py を hook の python3 が読まない。
#   3. CLAUDE_PLUGIN_ROOT が空のとき、ファイルシステムのルート直下（/scripts/…・/templates/…）を
#      探しも実行もしない。
#
# 3 はルート直下にスタブを置いて確かめるのが直接だが、テストから / には書けない（macOS は読み取り専用、
# CI でも他のテストと共有する場所を汚す）。代わりに bash -x の実行記録に /scripts/ と /templates/ で始まる
# パスが 1 つも現れないことを検査する（存在確認の [ -x … ] も実行も、パスを組み立てた時点で記録に出る）。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  DW="${REPO_ROOT}/plugins/dev-workflow"
  WORK="$(mktemp -d)"
  # 実環境の ~/.claude と実 API を読まない（subagent-start-context.bats の setup と同じ隔離）
  export CLAUDE_ACCOUNTS_FILE="${WORK}/accounts.json"
  export USAGE_SESSIONS_DIR="${WORK}/.usage-sessions"
  export USAGE_PROBE_STATE="${WORK}/.usage-probe-state"
  export USAGE_PROBE_LOCK="${WORK}/.usage-probe.lock"
  export USAGE_SNAPSHOT="${WORK}/snapshot.json"
  export USAGE_PROBE_RESPONSE_FILE="${WORK}/nonexistent.json"
  unset CLAUDE_SECURESTORAGE_CONFIG_DIR FABLE_BUDGET_MODE SHARED_BUDGET_MODE TRIPWIRES_SCOPE
  unset DEV_WORKFLOW_CONTEXT_CAP DEV_WORKFLOW_CONTEXT_HARD_CAP DEV_WORKFLOW_CONTEXT_TRIPWIRE
  unset PYTHONPATH

  # 偽のモジュール: 読み込まれたら FAKE_MARKER に 1 行足す（読まれたことを出力の差に頼らず検出する）
  FAKE="${WORK}/fake"
  mkdir -p "$FAKE"
  export FAKE_MARKER="${WORK}/fake-loaded"
  local m
  for m in json re usage_view; do
    printf 'import os\nopen(os.environ["FAKE_MARKER"], "a").write("%s\\n")\nraise ImportError("fake %s")\n' "$m" "$m" \
      > "${FAKE}/${m}.py"
  done
  printf '{"hook_event_name":"SubagentStart","session_id":"s1","agent_id":"a1","agent_type":"dev-workflow:worker"}' \
    > "${WORK}/worker.json"
}

teardown() {
  rm -rf "$WORK"
}

# in_fake <コマンド…> — 偽のモジュールを置いたディレクトリをカレントにし、PYTHONPATH にも入れて実行する
in_fake() {
  ( cd "$FAKE" && PYTHONPATH="$FAKE" "$@" )
}

# no_root_level_path <実行記録> — /scripts/ か /templates/ で始まるパスが現れない
no_root_level_path() {
  if grep -n -E "(^|[[:space:]='\"])/(scripts|templates)/" "$1"; then
    echo "ルート直下のパスが実行記録に現れた" >&2
    return 1
  fi
}

@test "#847: python3 in hook scripts starts with -I (or -E -s for the three that import a sibling module)" {
  run python3 -I - "$REPO_ROOT" <<'PY'
import glob, json, os, re, sys
root = sys.argv[1]
# 隣の .py を直接実行し、同じディレクトリのモジュールを import する。-I はそのディレクトリを検索パスから外す
SIBLING = {"plugins/cost-ledger/scripts/backfill.sh", "plugins/cost-ledger/scripts/gate-report.sh",
           "plugins/cost-ledger/scripts/ledger-hook.sh"}
# マージ待ちの別の PR が同じファイルを変えているので、この検査の対象から外す（その PR のマージ後に直す）
PENDING = {"plugins/dev-workflow/scripts/team-mode-warning.sh",   # PR #897 が python3 を外す
           "plugins/worktree/scripts/wt-setup-guard.sh"}          # PR #298 が変更中
targets = {"plugins/dev-workflow/scripts/usage-probe.sh"}         # session-tripwires.sh から呼ばれる
for hj in glob.glob(os.path.join(root, "plugins/*/hooks/hooks.json")):
    plugin = os.path.relpath(os.path.dirname(os.path.dirname(hj)), root)
    for name in re.findall(r"/scripts/([A-Za-z0-9_.-]+\.sh)", open(hj, encoding="utf-8").read()):
        targets.add(plugin + "/scripts/" + name)
assert len(targets) >= 15, sorted(targets)
bad, seen = [], 0
for rel in sorted(targets - PENDING):
    path = os.path.join(root, rel)
    assert os.path.isfile(path), rel
    for no, line in enumerate(open(path, encoding="utf-8"), 1):
        code = re.split(r"(^|\s)#(\s|$)", line, 1)[0]     # コメントを落とす
        if "command -v python3" in code:
            continue
        for m in re.finditer(r"(?<![\w./-])python3\s+(\S+)(?:\s+(\S+))?", code):
            seen += 1
            ok = (m.group(1) == "-E" and m.group(2) == "-s") if rel in SIBLING else m.group(1) == "-I"
            if not ok:
                bad.append("%s:%d: %s" % (rel, no, line.strip()[:120]))
assert seen >= 20, seen
assert not bad, "\n".join(bad)
PY
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "#847: -I cannot be used for the cost-ledger wrappers (the sibling module is not importable under -I)" {
  # -E -s を選んだ理由を実物で固定する。-I で動くようになったら、3 本を -I にそろえる
  run python3 -I -c 'import runpy, sys; runpy.run_path(sys.argv[1], run_name="not_main")' \
    "${REPO_ROOT}/plugins/cost-ledger/scripts/backfill.py"
  [ "$status" -ne 0 ]
  [[ "$output" == *"write_allow"* ]] || return 1
  run python3 -E -s -c 'import sys; sys.path.insert(0, sys.argv[1]); import write_allow' \
    "${REPO_ROOT}/plugins/cost-ledger/scripts"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "#847: cost-ledger ledger-hook hands python3 -E -s and the script next to it" {
  mkdir -p "${WORK}/shim"
  printf '#!/bin/bash\nprintf "%%s\\n" "$@" > "%s"\n' "${WORK}/argv" > "${WORK}/shim/python3"
  chmod +x "${WORK}/shim/python3"
  run env PATH="${WORK}/shim:${PATH}" COST_LEDGER_PATH="${WORK}/ledger.jsonl" \
    /bin/bash "${REPO_ROOT}/plugins/cost-ledger/scripts/ledger-hook.sh" </dev/null
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p "${WORK}/argv")" = "-E" ]
  [ "$(sed -n 2p "${WORK}/argv")" = "-s" ]
  [ "$(sed -n 3p "${WORK}/argv")" = "${REPO_ROOT}/plugins/cost-ledger/scripts/cost_ledger.py" ]
}

@test "#847: subagent-start-context does not load json.py / re.py / usage_view.py from the cwd or PYTHONPATH" {
  export CLAUDE_PLUGIN_ROOT="$DW"
  run bash -c "'${DW}/scripts/subagent-start-context.sh' < '${WORK}/worker.json'"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"additionalContext"'* ]] || return 1
  [[ "$output" == *"Fable 残量モード"* ]] || return 1
  local clean="$output"
  run in_fake bash -c "'${DW}/scripts/subagent-start-context.sh' < '${WORK}/worker.json'"
  [ "$status" -eq 0 ]
  [ ! -e "$FAKE_MARKER" ] || { cat "$FAKE_MARKER"; return 1; }
  [ "$output" = "$clean" ]
}

@test "#847: session-tripwires (session scope, with the probe) does not load fake modules" {
  export CLAUDE_PLUGIN_ROOT="$DW"
  # 比べる側も空のディレクトリで実行する（メモリ索引の検知がカレントディレクトリごとの置き場を読むため）
  mkdir -p "${WORK}/clean"
  run bash -c "cd '${WORK}/clean' && '${DW}/scripts/session-tripwires.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"昇格トリップワイヤー"* ]] || return 1
  local clean="$output"
  run in_fake "${DW}/scripts/session-tripwires.sh"
  [ "$status" -eq 0 ]
  [ ! -e "$FAKE_MARKER" ] || { cat "$FAKE_MARKER"; return 1; }
  [ "$output" = "$clean" ]
}

@test "#847: prompt-tripwires-refresh does not load fake modules" {
  export CLAUDE_PLUGIN_ROOT="$DW"
  export TMPDIR="${WORK}/tmp-a"
  mkdir -p "$TMPDIR"
  run bash -c "printf '{\"session_id\":\"iso-a\"}' | '${DW}/scripts/prompt-tripwires-refresh.sh'"
  [ "$status" -eq 0 ]
  export TMPDIR="${WORK}/tmp-b"
  mkdir -p "$TMPDIR"
  run in_fake bash -c "printf '{\"session_id\":\"iso-a\"}' | '${DW}/scripts/prompt-tripwires-refresh.sh'"
  [ "$status" -eq 0 ]
  [ ! -e "$FAKE_MARKER" ] || { cat "$FAKE_MARKER"; return 1; }
}

@test "#847: capability-registry browser-guard does not load fake modules" {
  local guard="${REPO_ROOT}/plugins/capability-registry/scripts/browser-guard.sh"
  export CLAUDE_PLUGIN_ROOT="${REPO_ROOT}/plugins/capability-registry"
  export TMPDIR="${WORK}/tmp-a"
  mkdir -p "$TMPDIR"
  run bash -c "printf '{\"session_id\":\"iso-b\"}' | '$guard'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"additionalContext"* ]] || return 1
  local clean="$output"
  export TMPDIR="${WORK}/tmp-b"
  mkdir -p "$TMPDIR"
  run in_fake bash -c "printf '{\"session_id\":\"iso-b\"}' | '$guard'"
  [ "$status" -eq 0 ]
  [ ! -e "$FAKE_MARKER" ] || { cat "$FAKE_MARKER"; return 1; }
  [ "$output" = "$clean" ]
}

@test "#847: the fake modules are loaded by an unisolated python3 (control for the tests above)" {
  run in_fake python3 -c 'import json'
  [ "$status" -ne 0 ]
  [ -s "$FAKE_MARKER" ]
}

@test "#847: subagent-start-context with an empty CLAUDE_PLUGIN_ROOT never looks under /scripts" {
  local v
  for v in empty unset; do
    if [ "$v" = "empty" ]; then export CLAUDE_PLUGIN_ROOT=""; else unset CLAUDE_PLUGIN_ROOT; fi
    /bin/bash -x "${DW}/scripts/subagent-start-context.sh" < "${WORK}/worker.json" \
      > "${WORK}/out.$v" 2> "${WORK}/trace.$v"
    [ -s "${WORK}/trace.$v" ]
    no_root_level_path "${WORK}/trace.$v"
    # 残量ブロックは作れないが、閾値の行は出す（budget を空にするだけで、hook は止めない）
    grep -q '"additionalContext"' "${WORK}/out.$v"
    if grep -q 'Fable 残量モード' "${WORK}/out.$v"; then return 1; fi
  done
}

@test "#847: session-tripwires with an empty CLAUDE_PLUGIN_ROOT never forms a root-level path" {
  local scope
  for scope in session subagent-budget; do
    ( cd "$FAKE" && CLAUDE_PLUGIN_ROOT="" TRIPWIRES_SCOPE="$scope" \
        /bin/bash -x "${DW}/scripts/session-tripwires.sh" > "${WORK}/out.$scope" 2> "${WORK}/trace.$scope" )
    [ -s "${WORK}/trace.$scope" ]
    no_root_level_path "${WORK}/trace.$scope"
    # 空の検索先をカレントディレクトリと読んで、そこの usage_view.py を import しない
    [ ! -e "$FAKE_MARKER" ] || { cat "$FAKE_MARKER"; return 1; }
    [ ! -e "$USAGE_PROBE_STATE" ]
  done
  # session の範囲はテンプレートが無いときと同じく何も出さない。subagent-budget は既定の残量ブロックを出す
  [ ! -s "${WORK}/out.session" ]
  grep -q '^## Fable 残量モード' "${WORK}/out.subagent-budget"
}

@test "#847: the xtrace check does catch a root-level path (control for the two tests above)" {
  printf '+ [ -x /scripts/session-tripwires.sh ]\n' > "${WORK}/trace.bad"
  run no_root_level_path "${WORK}/trace.bad"
  [ "$status" -ne 0 ]
  printf "+ TEMPLATE=/templates/escalation-tripwires.md\n" > "${WORK}/trace.bad"
  run no_root_level_path "${WORK}/trace.bad"
  [ "$status" -ne 0 ]
  printf '+ USAGE_VIEW_DIR=/x/plugins/dev-workflow/scripts\n+ [ -x /x/scripts/a.sh ]\n' > "${WORK}/trace.ok"
  run no_root_level_path "${WORK}/trace.ok"
  [ "$status" -eq 0 ]
}
