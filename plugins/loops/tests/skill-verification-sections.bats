#!/usr/bin/env bats
#
# Tests for capability: skill-verification-sections
# Spec: openspec/changes/skill-verification/specs/skill-verification-sections/spec.md
# Covers verification-guide.md scenarios S42-S50.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  loops_setup_paths
  TARGETS=(
    "plugins/longrun/skills/longrun-plan/SKILL.md"
    "plugins/worktree/skills/wt-setup/SKILL.md"
    "plugins/worktree/skills/wt-clean/SKILL.md"
    "plugins/daily-report/skills/daily-report/SKILL.md"
    "plugins/weekly-report/skills/weekly-report/SKILL.md"
    "plugins/infra/skills/infra-setup/SKILL.md"
    "plugins/experience-to-skill/skills/experience-to-skill/SKILL.md"
  )
  REF_PATH="loops/references/self-verification.md"
}

# Extract the self-verification section body (lines after the heading, up to next "## " or EOF).
_section_body() {
  awk '/^## 自己検証[[:space:]]*$/{f=1;next} f&&/^## /{f=0} f{print}' "$1"
}

# Extract the self-verification section including its heading line.
_section_with_heading() {
  awk '/^## 自己検証[[:space:]]*$/{f=1} f&&/^## /&&!/^## 自己検証[[:space:]]*$/{f=0} f{print}' "$1"
}

# Per-skill concrete artifact keyword (rejects generic-only sections; S46 machine approximation).
_artifact_kw() {
  case "$1" in
    *longrun-plan*) echo "plan.md" ;;
    *wt-setup*)     echo "worktree" ;;
    *wt-clean*)     echo "worktree" ;;
    *daily-report*) echo "diary" ;;
    *weekly-report*) echo "weekly" ;;
    *infra-setup*)  echo "infra" ;;
    *experience-to-skill*) echo "SKILL.md" ;;
  esac
}

# --- S42: each of the 7 target SKILL.md has exactly one self-verification heading ---
@test "S42: each target has exactly one self-verification heading" {
  for rel in "${TARGETS[@]}"; do
    f="${PLUGIN_ROOT}/${rel}"
    [ -f "$f" ]
    run bash -c "grep -c '^## 自己検証[[:space:]]*\$' '$f'"
    [ "$output" = "1" ]
  done
}

# --- S43: each section references the shared reference file ---
@test "S43: each section references self-verification.md at least once" {
  for rel in "${TARGETS[@]}"; do
    f="${PLUGIN_ROOT}/${rel}"
    body="$(_section_body "$f")"
    n="$(printf '%s\n' "$body" | grep -cF "$REF_PATH")"
    [ "$n" -ge 1 ]
  done
}

# --- S44: each section has at least one backtick command or artifact path ---
@test "S44: each section has at least one backtick command or artifact path" {
  for rel in "${TARGETS[@]}"; do
    f="${PLUGIN_ROOT}/${rel}"
    body="$(_section_body "$f")"
    stripped="$(printf '%s\n' "$body" | grep -vF "$REF_PATH")"
    printf '%s\n' "$stripped" | grep -q '`'
  done
}

# --- S45: no two section bodies (excluding the reference line) are identical ---
@test "S45: no two section bodies excluding the reference line are identical" {
  hashes=()
  for rel in "${TARGETS[@]}"; do
    f="${PLUGIN_ROOT}/${rel}"
    body="$(_section_body "$f" | grep -vF "$REF_PATH" | sed 's/[[:space:]]*$//' | grep -v '^[[:space:]]*$')"
    h="$(printf '%s' "$body" | shasum | awk '{print $1}')"
    for prev in "${hashes[@]}"; do
      [ "$h" != "$prev" ]
    done
    hashes+=("$h")
  done
}

# --- S46: each section names a concrete artifact (not generic-only) ---
@test "S46: each section names a concrete skill-specific artifact" {
  for rel in "${TARGETS[@]}"; do
    f="${PLUGIN_ROOT}/${rel}"
    kw="$(_artifact_kw "$rel")"
    body="$(_section_body "$f")"
    printf '%s\n' "$body" | grep -qi "$kw"
  done
}

# --- S47: skill identity (name:) unchanged vs merge-base with main ---
# NOTE (S48 と同じスコープ縮小): 旧 S47 は name: と description: の両方を
# merge-base から凍結していた。しかし spec の要件文は「**本 change の**実装前後で
# frontmatter を変更しない」であり、これは「自己検証セクションを追加する作業が
# ついでに発火条件を書き換えてしまわないように」というポイントインタイムガード
# だった。恒久ガードとして残すと、対象 7 スキルの description が**未来永劫**
# 変更できなくなる — 新オプションの追加も、発火フレーズの改善もできない。
# 実際 wt-clean は --unattended / --repo の追加（issue #87）で description の
# 更新が必要になり、ここで詰まった。
#
# 本テストが本当に守りたいのは「スキルの同一性（ルーティングキー）が黙って
# すり替わらないこと」なので、ガードを name: だけに絞る。description: の変更は
# 発火条件の意図的な改訂として許可し、PR の diff レビューで担保する。
@test "S47: skill name is unchanged vs merge-base with main" {
  base="$(cd "$PLUGIN_ROOT" && git merge-base HEAD main 2>/dev/null)" || skip "no merge-base"
  [ -n "$base" ] || skip "no merge-base"
  for rel in "${TARGETS[@]}"; do
    run bash -c "cd '$PLUGIN_ROOT' && git diff '$base' -- '$rel' | grep -E '^[+-]name:' | wc -l | tr -d ' '"
    [ "$output" = "0" ]
  done
}

# --- S47b: description は消さない（空にする・削除するのは禁止） ---
# description を「変更してよい」にした代償として、最低限「発火条件が失われて
# いないこと」だけは機械的に守る。中身の良し悪しはレビューの担当。
@test "S47b: every target skill still has a non-empty description" {
  for rel in "${TARGETS[@]}"; do
    f="${PLUGIN_ROOT}/${rel}"
    desc="$(awk 'NR==1 && $0=="---"{infm=1; next} infm && $0=="---"{exit} infm' "$f" \
      | sed -n 's/^description:[[:space:]]*//p')"
    [ -n "$desc" ]
    [ "${#desc}" -ge 40 ]
  done
}

# --- S48: self-verification section is preserved vs merge-base ---
# NOTE (loops-integration / change-5, decisions.md D-5c → loop-dev-agent-tripwires で
# スコープ縮小): 旧 S48 は対象ファイル「全体」の行削除を禁止していたが、これは change-5
# 時点のポイントインタイムガードであり、後続の spec 承認済み編集（例: longrun-plan の
# ヒューリスティクス改訂 = longrun-exec-model-allocation）まで恒久的にブロックしてしまう。
# 本テストの実際の保護対象は「自己検証」セクションなので、ガードをセクション単位に絞る:
# merge-base 時点の自己検証セクションの各行が HEAD でも残っていること（追記は可、
# 削除・書き換えは不可）。
@test "S48: self-verification section is not rewritten vs merge-base" {
  base="$(cd "$PLUGIN_ROOT" && git merge-base HEAD main 2>/dev/null)" || skip "no merge-base"
  [ -n "$base" ] || skip "no merge-base"
  for rel in "${TARGETS[@]}"; do
    old_section="$(cd "$PLUGIN_ROOT" && git show "$base:$rel" 2>/dev/null | awk '/^## 自己検証[[:space:]]*$/{f=1} f&&/^## /&&!/^## 自己検証[[:space:]]*$/{f=0} f{print}')"
    [ -n "$old_section" ] || continue
    new_section="$(_section_with_heading "$PLUGIN_ROOT/$rel")"
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      grep -qxF -- "$line" <<<"$new_section"
    done <<<"$old_section"
  done
}

# --- S49: skills at/under 500 lines keep the section inline ---
@test "S49: skills at or under 500 lines keep the section inline" {
  for rel in "${TARGETS[@]}"; do
    f="${PLUGIN_ROOT}/${rel}"
    lines="$(wc -l < "$f" | tr -d ' ')"
    if [ "$lines" -le 500 ]; then
      body="$(_section_body "$f")"
      [ -n "$body" ]
    fi
  done
}

# --- S50: skills over 500 lines split detail to references and keep section <=15 lines ---
@test "S50: skills over 500 lines split detail to references with a short section" {
  for rel in "${TARGETS[@]}"; do
    f="${PLUGIN_ROOT}/${rel}"
    lines="$(wc -l < "$f" | tr -d ' ')"
    if [ "$lines" -gt 500 ]; then
      sec_lines="$(_section_with_heading "$f" | wc -l | tr -d ' ')"
      [ "$sec_lines" -le 15 ]
      plugin_dir="${f%/skills/*}"
      run bash -c "ls '${plugin_dir}/references/'*.md 2>/dev/null | wc -l | tr -d ' '"
      [ "$output" -ge 1 ]
      _section_body "$f" | grep -Eq 'references/[^ ]+\.md'
    fi
  done
}
