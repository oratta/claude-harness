#!/usr/bin/env bats
# hook が呼ぶ python3 の隔離と、CLAUDE_PLUGIN_ROOT が空のときの探索先（issue #847）
#
# 何を固定するか:
#   1. hooks.json に登録されたスクリプト（と、そこから呼ばれる usage-probe.sh）の python3 が、
#      -I（隔離モード）か、隣のモジュールを読む 2 本だけ -E -s で起動される。
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
  # 実環境の ~/.claude に触れない: HOME と、prompt-tripwires-refresh の状態の置き場を作業ディレクトリの下に向ける
  mkdir -p "${WORK}/home"
  export HOME="${WORK}/home"
  export TRIPWIRE_STATE_DIR="${WORK}/tripwire-versions"
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

# unisolated_copy <スクリプト> — python3 の -I を外した複製を作り、そのパスを出す。偽のモジュールを置いた
# ディレクトリで実行すると偽物が読まれる（＝その入力で python3 まで進んでいる）ことを、検査ごとの対照に使う
unisolated_copy() {
  local dst; dst="${WORK}/unisolated/$(basename "$1")"
  mkdir -p "${WORK}/unisolated"
  sed 's/python3 -I /python3 /' "$1" > "$dst"
  if cmp -s "$1" "$dst"; then
    echo "unisolated_copy: $1 に python3 -I が無い" >&2
    return 1
  fi
  chmod +x "$dst"
  printf '%s' "$dst"
}

# no_root_level_path <実行記録> — /scripts/ か /templates/ で始まるパスが現れない
no_root_level_path() {
  if grep -n -E "(^|[[:space:]='\"])/(scripts|templates)/" "$1"; then
    echo "ルート直下のパスが実行記録に現れた" >&2
    return 1
  fi
}

@test "#847: python3 in hook scripts starts with -I (or -E -s for the two that import a sibling module)" {
  run python3 -I - "$REPO_ROOT" <<'PY'
import glob, json, os, re, sys
root = sys.argv[1]
# 隣の .py を直接実行し、同じディレクトリのモジュールを import する。-I はそのディレクトリを検索パスから外す
SIBLING = {"plugins/cost-ledger/scripts/backfill.sh", "plugins/cost-ledger/scripts/gate-report.sh"}
# 別の PR と同じファイルが重なるので、この検査の対象から外す（follow-up で直す）
PENDING = {"plugins/cost-ledger/scripts/ledger-hook.sh",          # PR #909 が変えた直後。-E -s は follow-up
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
  # -E -s を選んだ理由を実物で固定する。-I で動くようになったら、2 本を -I にそろえる
  run python3 -I -c 'import runpy, sys; runpy.run_path(sys.argv[1], run_name="not_main")' \
    "${REPO_ROOT}/plugins/cost-ledger/scripts/backfill.py"
  [ "$status" -ne 0 ]
  [[ "$output" == *"write_allow"* ]] || return 1
  run python3 -E -s -c 'import sys; sys.path.insert(0, sys.argv[1]); import write_allow' \
    "${REPO_ROOT}/plugins/cost-ledger/scripts"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

# cost_ledger_fake_env <コマンド…> — backfill.sh・gate-report.sh が python3 の起動まで進む最小の環境で実行する。
# python3 は「起動された印を残して本物に引き継ぐ」shim、gh は必ず失敗する偽物（GitHub に問い合わせない）。
cost_ledger_fake_env() {
  local real_py; real_py="$(command -v python3)"
  mkdir -p "${WORK}/shim" "${WORK}/home"
  printf '#!/bin/bash\nprintf "%%s\\n" "$*" >> "%s"\nexec "%s" "$@"\n' "${WORK}/py-started" "$real_py" > "${WORK}/shim/python3"
  printf '#!/bin/bash\nexit 1\n' > "${WORK}/shim/gh"
  chmod +x "${WORK}/shim/python3" "${WORK}/shim/gh"
  printf 'example/none\n' > "${WORK}/write-repos"
  env -u CLAUDE_PLUGIN_OPTION_LEDGER_PATH PATH="${WORK}/shim:${PATH}" HOME="${WORK}/home" \
    COST_LEDGER_PATH="${WORK}/ledger.jsonl" COST_LEDGER_WRITE_REPOS_FILE="${WORK}/write-repos" \
    COST_LEDGER_HOOK_FOREGROUND=1 "$@"
}

@test "#847: cost-ledger backfill.sh and gate-report.sh do not load json.py from the cwd or PYTHONPATH" {
  local cl="${REPO_ROOT}/plugins/cost-ledger/scripts"
  # 偽の json.py が効くことの確認: -E -s を付けずに同じ .py を起動すると PYTHONPATH の偽物が読まれる
  run in_fake python3 "${cl}/backfill.py" </dev/null
  [ -s "$FAKE_MARKER" ] || { echo "偽の json.py が読まれない（検査が効いていない）"; return 1; }
  rm -f "$FAKE_MARKER"

  run in_fake cost_ledger_fake_env bash -c "printf '{}' | '${cl}/backfill.sh'"
  [ "$status" -eq 0 ]
  grep -q -- "-E -s ${cl}/backfill.py" "${WORK}/py-started" || { echo "backfill.py が起動されていない"; return 1; }
  [ ! -e "$FAKE_MARKER" ] || { cat "$FAKE_MARKER"; return 1; }

  run in_fake cost_ledger_fake_env bash -c \
    "printf '%s' '{\"tool_input\":{\"command\":\"gh pr comment 1 --body x\"}}' | '${cl}/gate-report.sh'"
  [ "$status" -eq 0 ]
  grep -q -- "-E -s ${cl}/gate_report.py" "${WORK}/py-started" || { echo "gate_report.py が起動されていない"; return 1; }
  [ ! -e "$FAKE_MARKER" ] || { cat "$FAKE_MARKER"; return 1; }
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
  mkdir -p "$TMPDIR" "$TRIPWIRE_STATE_DIR"
  local refresh="${DW}/scripts/prompt-tripwires-refresh.sh" state="${TRIPWIRE_STATE_DIR}/iso-a" copy
  # python3 まで進むのは、状態ファイルに今のプラグインの場所と違う値が入っているとき（プラグイン更新後）だけ。
  # 対照: -I を外した複製は、同じ条件で偽の json.py を読む（＝この条件で python3 まで進んでいる）
  copy="$(unisolated_copy "$refresh")"
  printf 'older-plugin-root\n' > "$state"
  run in_fake bash -c "printf '{\"session_id\":\"iso-a\"}' | '$copy'"
  [ -s "$FAKE_MARKER" ] || { echo "対照で偽のモジュールが読まれない（python3 まで進んでいない）"; return 1; }
  rm -f "$FAKE_MARKER"

  printf 'older-plugin-root\n' > "$state"
  run in_fake bash -c "printf '{\"session_id\":\"iso-a\"}' | '$refresh'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"additionalContext"* ]] || return 1
  [ ! -e "$FAKE_MARKER" ] || { cat "$FAKE_MARKER"; return 1; }
}

# body_hook_payload <hook> — Python 本体を -c で渡す 5 本が python3 の起動まで進む最小の payload
body_hook_payload() {
  case "$1" in
    git-destructive-guard) printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git reset --hard"},"hook_event_name":"PreToolUse","permission_mode":"default"}' ;;
    agent-model-guard) printf '%s' '{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose","prompt":"x"}}' ;;
    context-tripwire) printf '%s' '{"agent_id":"x","hook_event_name":"PostToolUse"}' ;;
    subagent-stop-guard) printf '%s' '{"agent_id":"x","hook_event_name":"SubagentStop"}' ;;
    model-switch-recache-notice) printf '%s' '{"hook_event_name":"PreModelSwitch"}' ;;
  esac
}

@test "#847: the five hooks that pass their body with -c do not load json.py from the cwd or PYTHONPATH" {
  unset DEV_WORKFLOW_GIT_GUARD DEV_WORKFLOW_GIT_GUARD_FORCE DEV_WORKFLOW_MODEL_GUARD
  local h copy
  for h in git-destructive-guard agent-model-guard context-tripwire subagent-stop-guard model-switch-recache-notice; do
    body_hook_payload "$h" > "${WORK}/payload.json"
    # 対照: -I を外した複製は偽の json.py を読む（＝この payload で python3 まで進んでいる）
    copy="$(unisolated_copy "${DW}/scripts/${h}.sh")"
    rm -f "$FAKE_MARKER"
    run in_fake bash -c "'$copy' < '${WORK}/payload.json'"
    [ -s "$FAKE_MARKER" ] || { echo "$h: 対照で偽の json.py が読まれない（python3 まで進んでいない）"; return 1; }
    rm -f "$FAKE_MARKER"

    run in_fake bash -c "'${DW}/scripts/${h}.sh' < '${WORK}/payload.json'"
    [ ! -e "$FAKE_MARKER" ] || { echo "$h: 偽のモジュールが読まれた"; cat "$FAKE_MARKER"; return 1; }
    case "$h" in
      git-destructive-guard)
        [ "$status" -eq 0 ] || { echo "$h: status=$status"; return 1; }
        [[ "$output" == *'"permissionDecision": "ask"'* ]] || { echo "$h: $output"; return 1; }
        [[ "$output" == *'git reset --hard'* ]] || { echo "$h: $output"; return 1; }
        ;;
      agent-model-guard)
        [ "$status" -eq 0 ] || { echo "$h: status=$status"; return 1; }
        [[ "$output" == *'"permissionDecision": "deny"'* ]] || { echo "$h: $output"; return 1; }
        ;;
    esac
  done
}

@test "#847: worktree wt-create-hook does not load json.py from the cwd or PYTHONPATH" {
  local hook="${REPO_ROOT}/plugins/worktree/scripts/wt-create-hook.sh" copy
  # name に / を入れる: python3 で name を読んだ直後に「不正な name」で終わり、worktree を作る手前で止まる。
  # 偽の json.py が読まれると name を読めず、別の文言（'name' が入力に無い）で終わる
  printf '%s' '{"hook_event_name":"WorktreeCreate","name":"iso/x"}' > "${WORK}/payload.json"
  copy="$(unisolated_copy "$hook")"
  run in_fake bash -c "'$copy' < '${WORK}/payload.json'"
  [ -s "$FAKE_MARKER" ] || { echo "対照で偽の json.py が読まれない（python3 まで進んでいない）"; return 1; }
  rm -f "$FAKE_MARKER"

  run in_fake bash -c "'$hook' < '${WORK}/payload.json'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"不正な name: iso/x"* ]] || { echo "$output"; return 1; }
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
