---
name: casting:init
description: 対象 git repo に `.claude/casting/` 一式（project.md・precedents.md・local.md の gitignore 追記）を雛形から生成する。「観点の配役を導入して」「casting init」で起動する。
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# /casting:init — `.claude/casting/` の初期生成

「観点の配役」フレームワークをこの repo に導入する。既存ファイルは上書きせず、`.gitignore` への追記も冪等に行う。
置き場所・3層の上書き順・判例台帳の書き方は `skills/casting/SKILL.md` と `catalog/catalog.md` が正本。このコマンドは生成だけを行う。

## 手順

1. カレント repo のルートを特定する: `git rev-parse --show-toplevel`
2. このプラグインの `templates/` ディレクトリを特定する（`CLAUDE_PLUGIN_ROOT` を第一候補に、marketplace / installed 配下を探索する）:

   ```bash
   for dir in \
     "${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/templates}" \
     ~/.claude/plugins/marketplaces/*/plugins/casting/templates \
     ~/.claude/plugins/installed/*/casting/templates; do
     [ -n "$dir" ] && [ -f "$dir/project.md" ] && echo "$dir" && break
   done
   ```

3. 下の生成スクリプトを `<repoルート>` `<templatesディレクトリ>` の2引数で実行する。

## 生成スクリプト

```sh
set -eu

REPO_ROOT="${1:?repo root required}"
TEMPLATES_DIR="${2:?templates dir required}"

CASTING_DIR="${REPO_ROOT%/}/.claude/casting"
mkdir -p "$CASTING_DIR"

if [ ! -f "${CASTING_DIR}/project.md" ]; then
  cp "${TEMPLATES_DIR}/project.md" "${CASTING_DIR}/project.md"
  echo "created: ${CASTING_DIR}/project.md"
else
  echo "skip (exists): ${CASTING_DIR}/project.md"
fi

if [ ! -f "${CASTING_DIR}/precedents.md" ]; then
  cp "${TEMPLATES_DIR}/precedents.md" "${CASTING_DIR}/precedents.md"
  echo "created: ${CASTING_DIR}/precedents.md"
else
  echo "skip (exists): ${CASTING_DIR}/precedents.md"
fi

GITIGNORE="${REPO_ROOT%/}/.gitignore"
touch "$GITIGNORE"
if ! grep -qxF '.claude/casting/local.md' "$GITIGNORE"; then
  printf '%s\n' '.claude/casting/local.md' >> "$GITIGNORE"
  echo "appended to .gitignore: .claude/casting/local.md"
else
  echo "skip (already ignored): .claude/casting/local.md"
fi
```

`local.md`（第2層・エージェント/マシン別の上書き）自体は生成しない。gitignore に追記するだけで、必要になったエージェントが各自作成する。

## 完了報告

生成/スキップしたファイルの一覧をそのまま主に伝える。新規生成した場合は「`.claude/casting/project.md` の『既定の担い手』列をこのプロジェクトの実情に合わせて編集してください」と一言添える。
