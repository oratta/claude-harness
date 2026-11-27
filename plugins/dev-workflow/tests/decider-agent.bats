#!/usr/bin/env bats
#
# 決める役の種別 dev-workflow:decider の定義検証（issue #250）
#
#   agents/decider.md   model: fable・読み取り専用ツール・入出力契約
#   plugin.json         agents 配列での宣言
#   横断規約            Fable を既定モデルに持つエージェント定義は編集系ツールを持たない
#
# spec: dev-workflow-decider-agent

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  DECIDER="${PLUGIN_DIR}/agents/decider.md"
  PLUGIN_JSON="${PLUGIN_DIR}/.claude-plugin/plugin.json"
}

# frontmatter（先頭 --- から次の --- まで）を取り出す
frontmatter() { awk 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit} f' "$1"; }

# frontmatter の 1 キーの値（`key: value`）
fm_value() { frontmatter "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -1; }

@test "decider: the agent definition exists" {
  [ -f "$DECIDER" ]
}

@test "decider: frontmatter declares model fable and read-only tools" {
  [ "$(fm_value "$DECIDER" model)" = "fable" ]
  tools="$(fm_value "$DECIDER" tools)"
  echo "$tools" | grep -q 'Read'
  echo "$tools" | grep -q 'Grep'
  echo "$tools" | grep -q 'Glob'
  echo "$tools" | grep -qvE '(Edit|Write|NotebookEdit|Bash)'
}

@test "decider: frontmatter has name and description" {
  [ "$(fm_value "$DECIDER" name)" = "decider" ]
  [ -n "$(fm_value "$DECIDER" description)" ]
}

@test "decider: plugin.json declares ./agents/decider.md" {
  grep -qF './agents/decider.md' "$PLUGIN_JSON"
  python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if './agents/decider.md' in d.get('agents',[]) else 1)" "$PLUGIN_JSON"
}

@test "decider: the body states the input contract" {
  # 記録先の本文とコメントは呼び出し側が貼る（Bash を持たないので自分では取りに行けない）
  grep -q '記録先' "$DECIDER"
  grep -q '呼び出し側' "$DECIDER"
  # 失敗の出力・対象ファイルのパス・実行役の return
  grep -qE 'テストログ|失敗の出力' "$DECIDER"
  grep -q '対象ファイルのパス' "$DECIDER"
  grep -qF '指示のどこまでやって、どこで何が起きたか' "$DECIDER"
}

@test "decider: the body states the three outputs" {
  grep -q '原因の分類' "$DECIDER"
  grep -qE '判断側' "$DECIDER"
  grep -qE '実行側' "$DECIDER"
  grep -q 'そのまま実行できる' "$DECIDER"
  grep -qE '次の実行役のモデル' "$DECIDER"
  grep -qE 'sonnet' "$DECIDER"
  grep -qE 'opus' "$DECIDER"
}

@test "decider: the body says it does not write code and does not post to the record" {
  grep -qE 'コードを書か|コードを触らない' "$DECIDER"
  grep -qE '投稿できません|投稿しない' "$DECIDER"
  grep -q '呼び出し側の責務' "$DECIDER"
}

@test "decider: the body says Opus keeps the same subagent_type" {
  grep -qF 'dev-workflow:decider' "$DECIDER"
  grep -qF 'model: opus' "$DECIDER"
  grep -qF 'general-purpose' "$DECIDER"
}

@test "cross-plugin: agent definitions whose model is Fable carry no editing tools" {
  run python3 - "$REPO_ROOT" <<'PY'
import glob, os, re, sys

root = sys.argv[1]
EDITING = ("Edit", "Write", "NotebookEdit", "Bash")
violations = []
checked = 0

for path in sorted(glob.glob(os.path.join(root, "plugins", "*", "agents", "*.md"))):
    lines = open(path, encoding="utf-8").read().splitlines()
    if not lines or lines[0].strip() != "---":
        continue
    fm = {}
    for line in lines[1:]:
        if line.strip() == "---":
            break
        m = re.match(r"^([A-Za-z_-]+):\s*(.*)$", line)
        if m:
            fm[m.group(1)] = m.group(2).strip()
    model = fm.get("model", "").strip().lower()
    if not (model == "fable" or model.startswith("claude-fable")):
        continue
    checked += 1
    tools = [t.strip() for t in fm.get("tools", "").split(",") if t.strip()]
    bad = [t for t in tools if t in EDITING or t == "*"]
    if bad:
        violations.append(f"{os.path.relpath(path, root)}: tools に {', '.join(bad)} がある")

if violations:
    print("\n".join(violations))
    sys.exit(1)
if checked == 0:
    print("model: fable のエージェント定義が 1 つも見つからない（検査が空振りしている）")
    sys.exit(1)
PY
  [ "$status" -eq 0 ] || { echo "$output"; false; }
}
