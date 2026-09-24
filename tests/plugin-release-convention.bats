#!/usr/bin/env bats
#
# プラグインの版と変更記録の規約（issue #447）
#
# spec: plugin-release-convention
#
# 版は人が上げず、Claude Code が marketplace clone の HEAD の commit SHA から決める。変更の
# 記録は plugins/<name>/changes/<番号>.md に 1 PR 1 ファイルで書き、過去の CHANGELOG.md は
# 凍結する。どの検査も origin/main を要さず、浅い clone の CI でも常に走る。
#
# 守備範囲: changes/ の検査はファイル名と 1 行目の形だけを見る（記録の書き忘れ・番号の実在・
# 本文の中身は見ない）。凍結の検査は移行の 1 行と最新項目の間への `## ` 見出しの挿入・移行の
# 1 行の欠落・3 つ目の CHANGELOG.md の新設だけを見る（既存本文の訂正や下への挿入は見ない）。
#
# Constraints: bash / grep / sed / awk / find のみ。

# 凍結点: 移行時点の最新項目の見出しの先頭。凍結した後は動かさない値なので直書きする。
FROZEN_DEV_WORKFLOW_HEAD='## 2.13.39 —'
FROZEN_PRODUCT_HANDOVER_HEAD='## v0.1.0 —'

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  CONVENTION_DOCS=(rules/plugin-editing.md CLAUDE.md AGENTS.md docs/worktree-recovery.md)
}

# タイトル行（1 行目）の次の非空行
line_after_title() {
  sed -n '2,$p' "$1" | grep -m1 -v '^[[:space:]]*$'
}

# 移行の 1 行より後に現れる最初の `## ` 見出し
first_entry_after_migration() {
  awk 'NR==1{next} !seen && NF{seen=1; next} seen && /^## /{print; exit}' "$1"
}

@test "C1: changes/ records are named <number>.md and start with a heading" {
  bad=""
  for f in "${REPO_ROOT}"/plugins/*/changes/*; do
    [ -e "$f" ] || continue
    rel="${f#"${REPO_ROOT}"/}"
    if ! [[ "$(basename "$f")" =~ ^[0-9]+\.md$ ]]; then
      bad="${bad}${rel}: file name is not <number>.md"$'\n'
      continue
    fi
    head -1 "$f" | grep -q '^# ' || bad="${bad}${rel}: first line is not a '# ' heading"$'\n'
  done
  if [ -n "$bad" ]; then
    printf '%s' "$bad"
    return 1
  fi
}

@test "C2: the #447 migration is recorded in dev-workflow and product-handover" {
  for n in dev-workflow product-handover; do
    [ -f "${REPO_ROOT}/plugins/${n}/changes/447.md" ] || { echo "missing plugins/${n}/changes/447.md"; return 1; }
  done
}

@test "C3: frozen CHANGELOG.md has the migration line right after the title" {
  for n in dev-workflow product-handover; do
    line="$(line_after_title "${REPO_ROOT}/plugins/${n}/CHANGELOG.md")"
    if [[ "$line" != *changes/* ]]; then
      echo "plugins/${n}/CHANGELOG.md: line after title is not the migration line: ${line}"
      return 1
    fi
  done
}

@test "C4: no new entry is added on top of a frozen CHANGELOG.md" {
  check() { # $1=plugin $2=frozen heading prefix
    got="$(first_entry_after_migration "${REPO_ROOT}/plugins/$1/CHANGELOG.md")"
    if [[ "$got" != "$2"* ]]; then
      echo "plugins/$1/CHANGELOG.md is frozen; write plugins/$1/changes/<number>.md instead. added heading: ${got}"
      return 1
    fi
  }
  check dev-workflow "$FROZEN_DEV_WORKFLOW_HEAD"
  check product-handover "$FROZEN_PRODUCT_HANDOVER_HEAD"
}

@test "C5: plugins/*/CHANGELOG.md is only the two frozen files" {
  got="$(cd "$REPO_ROOT" && find plugins -mindepth 2 -maxdepth 2 -name CHANGELOG.md | sort)"
  want="$(printf '%s\n' plugins/dev-workflow/CHANGELOG.md plugins/product-handover/CHANGELOG.md)"
  if [ "$got" != "$want" ]; then
    echo "unexpected CHANGELOG.md set (write plugins/<name>/changes/<number>.md instead):"
    echo "$got"
    return 1
  fi
}

@test "C6: convention docs do not ask for a version bump and point to changes/" {
  for d in "${CONVENTION_DOCS[@]}"; do
    f="${REPO_ROOT}/${d}"
    if grep -n -E '(バージョン|版)を上げ(る|て|、|。)|bump' "$f"; then
      echo "${d}: still asks to bump the plugin version"
      return 1
    fi
    grep -q 'changes/' "$f" || { echo "${d}: no instruction to record changes in plugins/<name>/changes/"; return 1; }
  done
}

@test "C7: worktree-recovery.md does not claim the cache follows HEAD without a version change" {
  f="${REPO_ROOT}/docs/worktree-recovery.md"
  if grep -n -E '据え置きでも中身は入る|上げなくても' "$f"; then
    echo "docs/worktree-recovery.md: the cache does not follow HEAD while the version stays the same"
    return 1
  fi
}

@test "C8: README plugin.json example has no version" {
  example="$(sed -n '/^cat > plugins\/new-plugin\/.claude-plugin\/plugin.json/,/^EOF$/p' "${REPO_ROOT}/README.md")"
  [ -n "$example" ] || { echo "plugin.json example not found in README.md"; return 1; }
  if grep -n '"version"' <<<"$example"; then
    echo "README.md plugin.json example still has \"version\""
    return 1
  fi
}
