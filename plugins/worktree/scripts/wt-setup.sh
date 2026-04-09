#!/usr/bin/env bash
set -euo pipefail

# wt-setup.sh — Worktree セットアップスクリプト
# SKILL.md から呼び出される。判定ロジックをスクリプトに集約し、
# LLMの解釈ミスによる事故を防ぐ。

#=== Step 1: 環境判定 ===

# worktree内かどうか判定
GIT_COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null)
TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null)
MAIN_REPO=$(git worktree list | head -1 | awk '{print $1}')

if [ "$TOPLEVEL" = "$MAIN_REPO" ]; then
  echo "ERROR: メインリポジトリ内で実行されています。worktree内で実行してください。"
  exit 1
fi

echo "worktree: $TOPLEVEL"
echo "main repo: $MAIN_REPO"

#=== Step 2: .worktreeinclude のファイルコピー ===

if [ -f .worktreeinclude ]; then
  echo ""
  echo "=== .worktreeinclude: 既存 ==="
  COPIED=0
  while IFS= read -r pattern; do
    [[ "$pattern" =~ ^#.*$ || -z "$pattern" ]] && continue
    while IFS= read -r file; do
      dir=$(dirname "$file")
      mkdir -p "$dir"
      cp "$MAIN_REPO/$file" "$file" 2>/dev/null && echo "  copied: $file" && COPIED=$((COPIED + 1))
    done < <(cd "$MAIN_REPO" && find . -path "./$pattern" -type f 2>/dev/null)
  done < .worktreeinclude
  echo "  total: $COPIED files copied"
else
  echo ""
  echo "=== .worktreeinclude: なし（SKILL.mdの手順で生成してください） ==="
fi

#=== Step 3: .claude/ の共有 ===

echo ""
if git ls-files --error-unmatch .claude/ &>/dev/null 2>&1; then
  echo "=== .claude/: git追跡済み → symlinkスキップ（既にworktreeに存在） ==="
else
  echo "=== .claude/: 未追跡 → symlinkを作成 ==="
  mkdir -p .claude

  for subdir in skills commands rules; do
    if [ -d "$MAIN_REPO/.claude/$subdir" ]; then
      ln -sfn "$MAIN_REPO/.claude/$subdir" ".claude/$subdir"
      echo "  symlink: .claude/$subdir"
    fi
  done

  for file in settings.json settings.local.json; do
    if [ -f "$MAIN_REPO/.claude/$file" ]; then
      ln -sfn "$MAIN_REPO/.claude/$file" ".claude/$file"
      echo "  symlink: .claude/$file"
    fi
  done
fi

#=== Step 4: 依存チェック ===

echo ""
echo "=== 依存状況 ==="
if [ -f package.json ] && [ ! -d node_modules ]; then
  echo "  node_modules なし → npm install が必要"
  echo "  NEEDS_NPM_INSTALL=true"
elif [ -f package.json ]; then
  echo "  node_modules あり"
fi

if [ -f Gemfile ] && [ ! -d .bundle ] && ! command -v bundle &>/dev/null; then
  echo "  bundle なし → bundle install が必要"
fi

echo ""
echo "=== wt-setup 完了 ==="
