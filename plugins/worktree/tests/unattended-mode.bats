#!/usr/bin/env bats
#
# Tests for issue #87 — unattended cron execution.
#
# Three changes:
#   1. --unattended : report Pass 2 targets instead of asking (see also skill-safety.bats)
#   2. --repo <path>: operate on a repository other than cwd
#   3. harmless dirty (lockfile-only) counts as clean for classification
#
# Background: 86 worktrees / 39GB had accumulated because the resident agents
# have no structural path to discard a worktree, and wt-clean could not run
# unattended.

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  wt_setup_paths
}

# --- option surface ---

@test "skill: frontmatter advertises --unattended and --repo" {
  local fm
  fm="$(wt_frontmatter "$WT_CLEAN_SKILL")"
  [[ "$fm" == *"--unattended"* ]]
  [[ "$fm" == *"--repo"* ]]
}

@test "command: wt-clean.md passes --unattended and --repo through to the skill" {
  grep -q '\-\-unattended' "$WT_CLEAN_CMD"
  grep -q '\-\-repo' "$WT_CLEAN_CMD"
  # command 側で意味を再定義しないという既存の規約が維持されていること
  grep -q 'この command で意味を再定義・上書きしない' "$WT_CLEAN_CMD"
}

@test "command: wt-clean.md warns that allowed-tools is not an unattended permission" {
  grep -q '無人モードでの使用許可ではない' "$WT_CLEAN_CMD"
}

# --- change 2: --repo ---

@test "skill: defines Step -1 repository resolution before any git call" {
  grep -q '### Step -1: 対象リポジトリの解決' "$WT_CLEAN_SKILL"
  grep -q 'MAIN_REPO=\$(git -C "\$REPO_ARG" worktree list --porcelain' "$WT_CLEAN_SKILL"
}

@test "skill: --repo defaults to cwd for backward compatibility" {
  grep -q 'REPO_ARG="\${REPO_ARG:-\$PWD}"' "$WT_CLEAN_SKILL"
  grep -q '未指定時は cwd（現行どおり）' "$WT_CLEAN_SKILL"
}

@test "skill: --repo normalises a worktree path to its main worktree" {
  grep -q 'worktree のパスを渡されてもここでメイン側へ正規化される' "$WT_CLEAN_SKILL"
}

@test "skill: the precondition check is split by whether --repo was given" {
  grep -q 'REPO_OPT_GIVEN' "$WT_CLEAN_SKILL"
  # --repo 未指定時は現行どおり「メインリポで実行してください」
  grep -q 'メインリポで実行してください' "$WT_CLEAN_SKILL"
}

@test "skill: forbids bare cwd-dependent git calls" {
  grep -q '素の `git ...`（= cwd 依存）を書いてはならない' "$WT_CLEAN_SKILL"
}

@test "skill: every executable git call is routed through git -C" {
  # SKILL.md のコード行（bash フェンス内・行頭 git、または $( 内の git）に
  # -C の付かない git が残っていないこと。1 箇所でも漏れると別リポを掃除しに行く。
  local leaks
  leaks=$(awk '
    /^```bash$/ {inblock=1; next}
    /^```$/     {inblock=0; next}
    !inblock    {next}
    /^[[:space:]]*#/ {next}                 # コメント行は対象外
    /^[[:space:]]*echo /{next}              # 利用者向けメッセージ内の "git status" 等は対象外
    /^[[:space:]]*git /       {print; next} # コマンドとしての git
    /\$\(git /                {print; next} # コマンド置換の中の git
  ' "$WT_CLEAN_SKILL" \
    | grep -v 'git -C' \
    | grep -v 'git worktree add' \
    || true)
  if [ -n "$leaks" ]; then
    echo "bare git calls found:" >&2
    echo "$leaks" >&2
  fi
  [ -z "$leaks" ]
}

@test "skill: gh pr list runs inside the target repository" {
  # gh は -C を持たないため subshell で cd する必要がある
  grep -q 'cd "\$MAIN_REPO" && gh pr list' "$WT_CLEAN_SKILL"
}

@test "skill: Step C reports which repository was cleaned" {
  grep -q '対象リポジトリ: \$MAIN_REPO' "$WT_CLEAN_SKILL"
}

# --- change 2 behaviour: two real repos, one cwd ---

@test "repo resolution: lists worktrees of a repo other than cwd" {
  local repo_a repo_b wt out
  repo_a="$(wt_make_repo repoA)"
  repo_b="$(wt_make_repo repoB)"
  wt="${BATS_TEST_TMPDIR}/wt-b"
  git -C "$repo_b" worktree add -q -b feat-b "$wt" >/dev/null 2>&1

  # cwd = repo_a のまま repo_b の worktree が見えること
  out=$(cd "$repo_a" && git -C "$repo_b" worktree list --porcelain | awk '/^worktree /{print $2}')
  [[ "$out" == *"$(basename "$wt")"* ]]

  # repo_a 側には worktree が無いこと（取り違えの検出）
  local out_a
  out_a=$(git -C "$repo_a" worktree list --porcelain | grep -c '^worktree ')
  [ "$out_a" -eq 1 ]
}

@test "repo resolution: a worktree path resolves back to its main repo" {
  local repo wt resolved
  repo="$(wt_make_repo mainrepo)"
  wt="${BATS_TEST_TMPDIR}/wt-main"
  git -C "$repo" worktree add -q -b feat-m "$wt" >/dev/null 2>&1

  # SKILL.md の解決ロジックそのもの: worktree list の 1 行目 = メイン worktree
  resolved=$(git -C "$wt" worktree list --porcelain | awk '/^worktree /{print $2; exit}')
  [ "$(realpath -m "$resolved")" = "$(realpath -m "$repo")" ]
}

# --- change 3: harmless (lockfile-only) dirty ---

@test "skill: defines classify_dirty and the harmless file set" {
  grep -q 'classify_dirty' "$WT_CLEAN_SKILL"
  grep -q 'HARMLESS_DIRTY_FILES="package-lock.json yarn.lock pnpm-lock.yaml Cargo.lock poetry.lock"' "$WT_CLEAN_SKILL"
}

@test "skill: classification uses EFFECTIVE_DIRTY, display keeps raw DIRTY" {
  grep -q 'EFFECTIVE_DIRTY' "$WT_CLEAN_SKILL"
  grep -q '実効 dirty なし（`EFFECTIVE_DIRTY` が空）' "$WT_CLEAN_SKILL"
  grep -q '\*\*表示に使うのは `DIRTY`（生データ）\*\*' "$WT_CLEAN_SKILL"
}

@test "skill: one non-harmless file keeps the whole worktree dirty" {
  grep -q '1 つでもあれば従来どおり dirty 扱い（安全側）' "$WT_CLEAN_SKILL"
}

@test "skill: harmless-dirty deletion still prints its evidence" {
  # 無音削除の禁止は無害 dirty でも維持される
  grep -q 'dirty=lockfileのみ' "$WT_CLEAN_SKILL"
  grep -q '\${HARMLESS_DIRTY:-clean}' "$WT_CLEAN_SKILL"
}

@test "skill: harmless dirty does not weaken the LLM or active-session guards" {
  grep -q '禁則 2（LLM）・禁則 3（稼働シグナル）の判定には一切影響しない' "$WT_CLEAN_SKILL"
}

# --- change 3 behaviour: run classify_dirty against real porcelain output ---

wt_load_classify_dirty() {
  local snippet="${BATS_TEST_TMPDIR}/classify.sh"
  {
    grep '^HARMLESS_DIRTY_FILES=' "$WT_CLEAN_SKILL"
    awk '/^classify_dirty\(\) \{/,/^}$/' "$WT_CLEAN_SKILL"
  } >"$snippet"
  [ -s "$snippet" ]
  echo "$snippet"
}

@test "classify_dirty: is valid under bash and zsh" {
  local snippet
  snippet="$(wt_load_classify_dirty)"
  bash -n "$snippet"
  # `command -v zsh && zsh -n` を最終文にすると zsh が無い CI（ubuntu）で
  # テスト自体が落ちる。if で包んで「無ければ bash だけ検査」にする。
  if command -v zsh >/dev/null 2>&1; then
    zsh -n "$snippet"
  fi
}

@test "classify_dirty: lockfile-only porcelain yields no offenders" {
  local snippet out
  snippet="$(wt_load_classify_dirty)"
  out=$(bash -c ". '$snippet'; classify_dirty ' M package-lock.json'")
  [ -z "$out" ]

  out=$(bash -c ". '$snippet'; classify_dirty ' M package-lock.json
 M yarn.lock
 M sub/dir/pnpm-lock.yaml'")
  [ -z "$out" ]
}

@test "classify_dirty: a single source file makes the whole set dirty" {
  local snippet out
  snippet="$(wt_load_classify_dirty)"
  out=$(bash -c ". '$snippet'; classify_dirty ' M package-lock.json
 M src/foo.ts'")
  [ "$out" = "src/foo.ts" ]
}

@test "classify_dirty: an untracked directory is never harmless" {
  local snippet out
  snippet="$(wt_load_classify_dirty)"
  # "?? dir/" は中身が分からないので無害と見なさない
  out=$(bash -c ". '$snippet'; classify_dirty '?? node_stuff/'")
  [ "$out" = "node_stuff/" ]
}

@test "classify_dirty: a rename is judged by its new path" {
  local snippet out
  snippet="$(wt_load_classify_dirty)"
  out=$(bash -c ". '$snippet'; classify_dirty 'R  old.txt -> src/new.ts'")
  [ "$out" = "src/new.ts" ]
}

@test "classify_dirty: behaves identically under bash and zsh" {
  command -v zsh >/dev/null 2>&1 || skip "zsh unavailable"
  local snippet input out_bash out_zsh
  snippet="$(wt_load_classify_dirty)"
  input=' M package-lock.json
 M src/foo.ts
?? build/'
  out_bash=$(bash -c ". '$snippet'; classify_dirty '$input'")
  out_zsh=$(zsh -c ". '$snippet'; classify_dirty '$input'")
  [ "$out_bash" = "$out_zsh" ]
  [ "$(printf '%s\n' "$out_bash" | wc -l | tr -d ' ')" -eq 2 ]
}

@test "classify_dirty: matches real git status --porcelain output" {
  local snippet repo out porcelain
  snippet="$(wt_load_classify_dirty)"
  repo="$(wt_make_repo dirtyrepo)"
  printf '{}\n' >"$repo/package-lock.json"
  git -C "$repo" add -A >/dev/null 2>&1
  git -C "$repo" commit -qm lock >/dev/null 2>&1
  printf '{"x":1}\n' >"$repo/package-lock.json"

  porcelain=$(git -C "$repo" status --porcelain)
  [ -n "$porcelain" ]
  out=$(bash -c ". '$snippet'; classify_dirty \"\$1\"" _ "$porcelain")
  [ -z "$out" ]

  # 成果物を 1 つ足すと dirty 扱いに戻ること
  printf 'export const x = 1\n' >"$repo/app.ts"
  porcelain=$(git -C "$repo" status --porcelain)
  out=$(bash -c ". '$snippet'; classify_dirty \"\$1\"" _ "$porcelain")
  [[ "$out" == *"app.ts"* ]]
}

# --- unattended report contents ---

@test "skill: unattended report lists number, path, branch, class and reason" {
  local section
  section=$(awk '/^## 無人モード/,/^## 🔴 Active/' "$WT_CLEAN_SKILL")
  [ -n "$section" ]
  echo "$section" | grep -q '番号・パス・ブランチ名・分類・理由'
  echo "$section" | grep -q 'ブランチ:'
  echo "$section" | grep -q '分類:'
  echo "$section" | grep -q '理由:'
}

@test "skill: unattended report refuses a count-only summary" {
  awk '/^## 無人モード/,/^## 🔴 Active/' "$WT_CLEAN_SKILL" \
    | grep -q '件数だけの要約で済ませてはならない'
}

@test "skill: unattended mode keeps Pass 1 criteria unchanged" {
  awk '/^## 無人モード/,/^## 🔴 Active/' "$WT_CLEAN_SKILL" \
    | grep -q '無人だからといって甘くしてはならない'
}

@test "skill: unattended mode with an empty DEFERRED omits the remainder section" {
  grep -q '`--unattended` で `DEFERRED` が 0 件' "$WT_CLEAN_SKILL"
}

# --- self-verification + reference ---

@test "skill: self-verification covers unattended, --repo and harmless dirty" {
  local section
  section=$(awk '/## 自己検証/,0' "$WT_CLEAN_SKILL")
  echo "$section" | grep -q 'AskUserQuestion'
  echo "$section" | grep -q '\-\-repo'
  echo "$section" | grep -q 'lockfileのみ'
}

@test "reference: wt-clean-verification.md covers the three new behaviours" {
  grep -q '無害 dirty で自動処理した根拠が出ている' "$WT_CLEAN_VERIFICATION"
  grep -q '`--unattended` で対話していない' "$WT_CLEAN_VERIFICATION"
  grep -q '`--repo` が cwd のリポジトリを汚していない' "$WT_CLEAN_VERIFICATION"
}

# --- version bump (cache invalidation) ---

@test "version: worktree plugin.json is bumped to at least 2.8.0" {
  local v
  v=$(jq -r .version "$PLUGIN_JSON")
  run bash -c "printf '%s\n%s\n' '2.8.0' '$v' | sort -V | head -1"
  [ "$output" = "2.8.0" ]
}

@test "version: wt-clean SKILL.md version is bumped to at least 3.4.0" {
  local v
  v=$(wt_frontmatter "$WT_CLEAN_SKILL" | awk -F': *' '/^version:/{print $2}')
  run bash -c "printf '%s\n%s\n' '3.4.0' '$v' | sort -V | head -1"
  [ "$output" = "3.4.0" ]
}
