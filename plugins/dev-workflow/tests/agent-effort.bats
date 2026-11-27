#!/usr/bin/env bats
#
# dev-workflow の agent 定義が役ごとの effort を frontmatter に持つことの検査（issue #711）
#
#   worker / gate-runner = medium、reviewer / decider = high
#
# 守備範囲: frontmatter（先頭 --- から次の ---）内の `effort:` 行の数と値だけを見る。
# 本文中の `effort:` は数えない。値の綴り違い（大文字など）や、環境変数
# CLAUDE_CODE_EFFORT_LEVEL による実行時の上書きは検査しない。範囲外の穴をすべて塞ぐことは
# この検査の完了条件にしない。
#
# spec: dev-workflow-agent-effort

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  AGENTS="${PLUGIN_DIR}/agents"
}

# frontmatter（先頭 --- から次の --- まで）を取り出す
frontmatter() { awk 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit} f' "$1"; }

# frontmatter 内の `effort:` 行の数
effort_count() { frontmatter "$1" | grep -c '^effort:' || true; }

# frontmatter の effort の値
effort_value() { frontmatter "$1" | sed -n 's/^effort:[[:space:]]*//p' | head -1; }

@test "effort: every agent has exactly one effort line in its frontmatter" {
  for a in worker gate-runner reviewer decider; do
    [ -f "${AGENTS}/${a}.md" ]
    [ "$(effort_count "${AGENTS}/${a}.md")" = "1" ]
  done
}

@test "effort: worker and gate-runner are medium" {
  [ "$(effort_value "${AGENTS}/worker.md")" = "medium" ]
  [ "$(effort_value "${AGENTS}/gate-runner.md")" = "medium" ]
}

@test "effort: reviewer and decider are high" {
  [ "$(effort_value "${AGENTS}/reviewer.md")" = "high" ]
  [ "$(effort_value "${AGENTS}/decider.md")" = "high" ]
}
