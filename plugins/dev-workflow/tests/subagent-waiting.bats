#!/usr/bin/env bats
#
# サブエージェントの待ち方の契約の退行検出（issue #254）
#
# spec: dev-workflow-subagent-waiting, dev-workflow-develop, dev-workflow-pr-review-gate
#
# この change の成果物は手順書の文言なので、退行検出も文言に対して grep で行う。
# テスト名は ASCII のみ。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  CANON="${PLUGIN_DIR}/references/subagent-waiting.md"
  ROLES="${PLUGIN_DIR}/skills/develop/references/roles"
  GATE="${PLUGIN_DIR}/skills/pr-review-gate/SKILL.md"
  WORKER="${ROLES}/worker.md"
  REVIEWER="${ROLES}/spec-reviewer.md"
  RUNNER="${ROLES}/gate-runner.md"
  README="${PLUGIN_DIR}/README.md"

  ROLE_FILES=("$WORKER" "$REVIEWER" "$RUNNER")
  # 禁止語の検査対象＝サブエージェント（W / R1 / G）が手順として読む文書。
  SUBAGENT_DOCS=("$WORKER" "$REVIEWER" "$RUNNER" "$GATE")

  # Claude Code の Bash ツールの前景 1 回あたりの上限（ミリ秒）。
  # ハーネス側の上限が変わったら、この 1 行だけを直せば検査 2 全体が追随する。
  FOREGROUND_LIMIT_MS=600000
}

# --- 検査 1: 待ちを完了通知 / Monitor に委ねる指示が残っていないこと ---
#
# 除外規定はこの検査 1 だけに掛ける。正本（references/subagent-waiting.md）と本テスト自身は
# 「何が禁止か」を説明するために禁止語をそのまま含むため、禁止語スキャンの対象にしない。
# 検査 2（待ち値が前景上限未満）は正本にも掛ける — 正本に 900000 を書き戻したら落ちる。

@test "no subagent handbook delegates the wait to a completion notification or Monitor" {
  for f in "${SUBAGENT_DOCS[@]}"; do
    for pat in '完了通知を待' '通知を待って' 'Monitor ツール' 'Monitor に任せ' '待つのは companion に任せる' '完了したら再開'; do
      if grep -qF "$pat" "$f"; then
        echo "hint: ${f} contains the banned phrase '${pat}'."
        echo "hint: 待ちは同一ターン内の前景ポーリングで行う（正本: plugins/dev-workflow/references/subagent-waiting.md）"
        return 1
      fi
    done
  done
}

@test "handbooks that launch background jobs also show the foreground polling that waits" {
  for f in "${SUBAGENT_DOCS[@]}"; do
    grep -qE 'run_in_background|--background' "$f" || continue
    grep -q '前景' "$f" || {
      echo "hint: ${f} launches a background job but never shows how to wait in the foreground"
      return 1
    }
    grep -qF 'references/subagent-waiting.md' "$f" || {
      echo "hint: ${f} launches a background job but does not point at the canonical waiting contract"
      return 1
    }
  done
}

# --- 検査 2: 待ち値が前景上限未満であること ---

@test "every wait value in dev-workflow docs is below the foreground limit" {
  # 見るのは `--timeout-ms <数値>` と `timeout: <数値>` の 2 パターンだけ。
  # 裸の timeout は無関係な出現（timeout(1) に依存しない旨の説明など）が大半なので対象にしない。
  bad=0
  while IFS= read -r doc; do
    [ -n "$doc" ] || continue
    while IFS= read -r value; do
      [ -n "$value" ] || continue
      if [ "$value" -ge "$FOREGROUND_LIMIT_MS" ]; then
        echo "hint: ${doc} specifies ${value} ms, which is not below the foreground limit ${FOREGROUND_LIMIT_MS} ms"
        echo "hint: dev-workflow の既定は 540000（9 分）。1 回で終わらなければ同じ呼び出しを繰り返す"
        bad=1
      fi
    done <<< "$(grep -oE '(--timeout-ms|timeout:)[[:space:]]*[0-9]+' "$doc" | grep -oE '[0-9]+$')"
  done <<< "$(find "$PLUGIN_DIR" -name '*.md' -type f)"
  [ "$bad" -eq 0 ]
}

# --- 検査 3: 各役割の指示書に禁止 1 行と正本への参照があること ---

@test "each role handbook bans ending the turn on a wait and points at the canonical contract" {
  for f in "${ROLE_FILES[@]}"; do
    grep -qE 'ターンを終え(ない|てはならない)' "$f" || {
      echo "hint: ${f} lacks the ban on ending the turn while waiting"
      return 1
    }
    grep -qF 'references/subagent-waiting.md' "$f" || {
      echo "hint: ${f} does not reference plugins/dev-workflow/references/subagent-waiting.md"
      return 1
    }
  done
}

# --- 正本の中身（禁止・許可・完了シグナル・上限・単位・置き場） ---

@test "the canonical contract covers the ban, what stays allowed, and the polling template" {
  [ -f "$CANON" ]
  grep -q 'ターンを終え' "$CANON"
  grep -qF 'run_in_background' "$CANON"
  grep -qE 'until' "$CANON"
  grep -qF 'timeout: 540000' "$CANON"
  grep -qF 'timeout(1)' "$CANON"
  grep -q 'メインセッション' "$CANON"
}

@test "the canonical contract defines a completion signal per launch path" {
  grep -qF '__CODEX_DONE__' "$CANON"
  grep -qF 'rc=$?' "$CANON"
  grep -qF 'status <job-id> --wait --timeout-ms 540000' "$CANON"
  grep -q 'exit code' "$CANON"
}

@test "the canonical contract caps the total wait and defines the fallback trigger" {
  grep -qE '3 回' "$CANON"
  grep -qE '27 分' "$CANON"
  grep -qF 'needs-reviewer' "$CANON"
  grep -q 'タイムアウト' "$CANON"
}

@test "plugin README lists the canonical waiting contract in the references table" {
  grep -qF 'references/subagent-waiting.md' "$README"
}

# --- 手順書側の書き換え ---

@test "gate-runner shows both codex paths with the completion marker and the wait cap" {
  grep -qF '__CODEX_DONE__' "$RUNNER"
  grep -qF -- '--timeout-ms 540000' "$RUNNER"
  grep -qF 'needs-reviewer' "$RUNNER"
  grep -qE '27 分' "$RUNNER"
}

@test "spec-reviewer notes that the decider path carries no waiting work" {
  grep -qF 'decider' "$REVIEWER"
  grep -q '待ち' "$REVIEWER"
}

@test "pr-review-gate splits the waiting rule by reader" {
  grep -q 'メインセッション' "$GATE"
  grep -q 'サブエージェント' "$GATE"
  grep -q '前景' "$GATE"
  grep -qF 'references/subagent-waiting.md' "$GATE"
  # 前景上限を超える待ちを散文で示唆する記述を残さない
  ! grep -qF '最長 15 分' "$GATE"
}
