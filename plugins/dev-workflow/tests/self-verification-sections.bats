#!/usr/bin/env bats
#
# 自己検証の共通原則（references/self-verification.md）と、対象スキルの「## 自己検証」節の検証
#
# spec: skill-verification-sections, dev-workflow-shared-references
#
# 旧 plugins/loops/tests/{self-verification-reference,skill-verification-sections}.bats
# （S36〜S50）を loops の解散（issue #205）に伴い移したもの。対象は 7 スキル（longrun-plan は解散、
# push-guard-setup は #218 の再棚卸しで編入）。S51 は棚卸しリストの網羅性（#218）。
# テスト名は ASCII のみ。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
  REF="${PLUGIN_DIR}/references/self-verification.md"
  REF_PATH="dev-workflow/references/self-verification.md"
  TARGETS=(
    "plugins/worktree/skills/wt-setup/SKILL.md"
    "plugins/worktree/skills/wt-clean/SKILL.md"
    "plugins/daily-report/skills/daily-report/SKILL.md"
    "plugins/weekly-report/skills/weekly-report/SKILL.md"
    "plugins/infra/skills/infra-setup/SKILL.md"
    "plugins/experience-to-skill/skills/experience-to-skill/SKILL.md"
    "plugins/dev-workflow/skills/push-guard-setup/SKILL.md"
  )
}

_section_body() {
  awk '/^## 自己検証[[:space:]]*$/{f=1;next} f&&/^## /{f=0} f{print}' "$1"
}

_section_with_heading() {
  awk '/^## 自己検証[[:space:]]*$/{f=1} f&&/^## /&&!/^## 自己検証[[:space:]]*$/{f=0} f{print}' "$1"
}

_artifact_kw() {
  case "$1" in
    *wt-setup*)     echo "worktree" ;;
    *wt-clean*)     echo "worktree" ;;
    *daily-report*) echo "diary" ;;
    *weekly-report*) echo "weekly" ;;
    *infra-setup*)  echo "infra" ;;
    *experience-to-skill*) echo "SKILL.md" ;;
    *push-guard-setup*) echo "pre-push" ;;
  esac
}

# ============================================================
# reference（旧 S36〜S41）
# ============================================================

@test "S36: self-verification.md exists and states the core principle" {
  [ -f "$REF" ]
  grep -q "完了は主張であり証明ではない" "$REF"
  grep -q "evidence を提示してから完了を宣言する" "$REF"
}

@test "S37: the 4 evidence kinds are enumerated" {
  grep -q "テスト出力" "$REF"
  grep -q "exit code" "$REF"
  grep -Eq "生成物の実在" "$REF"
  grep -q "実行結果ログ" "$REF"
}

@test "S38: the skill-side authoring rule is documented" {
  grep -Eq "1 ?行参照" "$REF"
  grep -Eq "固有" "$REF"
  grep -Eq "コピー.{0,8}(してはならない|しない|禁止|禁じ)" "$REF"
}

@test "S39: the core principle sentence does not appear in any SKILL.md" {
  run bash -c "grep -rl '完了は主張であり証明ではない' ${REPO_ROOT}/plugins/*/skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' '"
  [ "$output" = "0" ]
}

@test "S40: the audit list records the real paths of the 7 target skills" {
  grep -q "対象スキル一覧" "$REF"
  for p in "${TARGETS[@]}"; do
    grep -qF "$p" "$REF" || { echo "missing ${p}"; return 1; }
  done
}

@test "S40b: no bogus path containing e2s-distill as a skill directory" {
  run bash -c "grep -E 'skills/e2s-distill/' '${REF}' | wc -l | tr -d ' '"
  [ "$output" = "0" ]
}

@test "S41: out-of-scope skills each carry a judgment reason" {
  run bash -c "grep -E '対象外' '${REF}' | grep -Ec '理由|既に|成果物|委譲|委ね|設定|分類'"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# S51: 棚卸しリストの網羅性（issue #218）。実在する SKILL.md は全件が対象表か対象外表に実パスで現れる。
# 発見は ls glob で動的に行い、スキルを新設して載せ忘れたらここで落ちる。
@test "S51: every existing SKILL.md appears in the audit list by real path" {
  missing=""
  for f in "${REPO_ROOT}"/plugins/*/skills/*/SKILL.md; do
    rel="${f#"${REPO_ROOT}"/}"
    grep -qF "$rel" "$REF" || missing="${missing} ${rel}"
  done
  [ -z "$missing" ] || { echo "not in audit list:${missing}"; return 1; }
}

# ============================================================
# 対象スキルの節（旧 S42〜S50）
# ============================================================

@test "S42: each target has exactly one self-verification heading" {
  for rel in "${TARGETS[@]}"; do
    f="${REPO_ROOT}/${rel}"
    [ -f "$f" ]
    run bash -c "grep -c '^## 自己検証[[:space:]]*\$' '$f'"
    [ "$output" = "1" ]
  done
}

@test "S43: each section references self-verification.md at least once via the new path" {
  for rel in "${TARGETS[@]}"; do
    f="${REPO_ROOT}/${rel}"
    body="$(_section_body "$f")"
    n="$(printf '%s\n' "$body" | grep -cF "$REF_PATH")"
    [ "$n" -ge 1 ] || { echo "${rel}: no reference to ${REF_PATH}"; return 1; }
    if printf '%s\n' "$body" | grep -qF "loops/references/self-verification.md"; then
      echo "${rel}: still references the old loops path"; return 1
    fi
  done
}

@test "S44: each section has at least one backtick command or artifact path" {
  for rel in "${TARGETS[@]}"; do
    f="${REPO_ROOT}/${rel}"
    body="$(_section_body "$f")"
    stripped="$(printf '%s\n' "$body" | grep -vF "$REF_PATH")"
    printf '%s\n' "$stripped" | grep -q '`'
  done
}

@test "S45: no two section bodies excluding the reference line are identical" {
  hashes=()
  for rel in "${TARGETS[@]}"; do
    f="${REPO_ROOT}/${rel}"
    body="$(_section_body "$f" | grep -vF "$REF_PATH" | sed 's/[[:space:]]*$//' | grep -v '^[[:space:]]*$')"
    h="$(printf '%s' "$body" | shasum | awk '{print $1}')"
    for prev in "${hashes[@]}"; do
      [ "$h" != "$prev" ]
    done
    hashes+=("$h")
  done
}

@test "S46: each section names a concrete skill-specific artifact" {
  for rel in "${TARGETS[@]}"; do
    f="${REPO_ROOT}/${rel}"
    kw="$(_artifact_kw "$rel")"
    body="$(_section_body "$f")"
    printf '%s\n' "$body" | grep -qi "$kw"
  done
}

# S47: skill identity (name:) unchanged vs merge-base. description は意図的な改訂を許す。
@test "S47: skill name is unchanged vs merge-base with main" {
  base="$(cd "$REPO_ROOT" && git merge-base HEAD main 2>/dev/null)" || skip "no merge-base"
  [ -n "$base" ] || skip "no merge-base"
  for rel in "${TARGETS[@]}"; do
    run bash -c "cd '$REPO_ROOT' && git diff '$base' -- '$rel' | grep -E '^[+-]name:' | wc -l | tr -d ' '"
    [ "$output" = "0" ]
  done
}

@test "S47b: every target skill still has a non-empty description" {
  for rel in "${TARGETS[@]}"; do
    f="${REPO_ROOT}/${rel}"
    desc="$(awk 'NR==1 && $0=="---"{infm=1; next} infm && $0=="---"{exit} infm' "$f" \
      | sed -n 's/^description:[[:space:]]*//p')"
    [ -n "$desc" ]
    [ "${#desc}" -ge 40 ]
  done
}

# S48: 自己検証節が merge-base から書き換えられていない（追記は可、削除・書き換えは不可）。
# 参照行（self-verification.md を含む行）は比較対象から除く — #205 で旧 loops パスから
# 新パスへ差し替えるのは spec が要求する変更であり、守りたいのは固有手順の非書き換え。
@test "S48: self-verification section is not rewritten vs merge-base (reference line excluded)" {
  base="$(cd "$REPO_ROOT" && git merge-base HEAD main 2>/dev/null)" || skip "no merge-base"
  [ -n "$base" ] || skip "no merge-base"
  for rel in "${TARGETS[@]}"; do
    old_section="$(cd "$REPO_ROOT" && git show "$base:$rel" 2>/dev/null | awk '/^## 自己検証[[:space:]]*$/{f=1} f&&/^## /&&!/^## 自己検証[[:space:]]*$/{f=0} f{print}' | grep -v 'self-verification\.md')"
    [ -n "$old_section" ] || continue
    new_section="$(_section_with_heading "$REPO_ROOT/$rel")"
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      grep -qxF -- "$line" <<<"$new_section" || { echo "${rel}: line dropped: ${line}"; return 1; }
    done <<<"$old_section"
  done
}

@test "S49: skills at or under 500 lines keep the section inline" {
  for rel in "${TARGETS[@]}"; do
    f="${REPO_ROOT}/${rel}"
    lines="$(wc -l < "$f" | tr -d ' ')"
    if [ "$lines" -le 500 ]; then
      body="$(_section_body "$f")"
      [ -n "$body" ]
    fi
  done
}

@test "S50: skills over 500 lines split detail to references with a short section" {
  for rel in "${TARGETS[@]}"; do
    f="${REPO_ROOT}/${rel}"
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
