#!/usr/bin/env bats
#
# Codex に委譲している全箇所の一覧表（docs/codex-delegation-inventory.md）と、実際の呼び出し元の突き合わせ（issue #324）
#
#   表に無いファイルが Codex の呼び出しの語を含むと落ちる（新しい呼び出し元を足したら表に 1 行足す）。
#   表にあるファイルが消えた・語を含まなくなったときも落ちる（古い行を残さない）。
#
# 検索から外すもの（記録・テスト・仕様本文）:
#   - 変更の記録: plugins/*/changes/ と CHANGELOG
#   - テスト: tests/ 配下（bats・Python とも。検査の対象であって呼び出し元ではない）
#   - openspec/: 要件の本文。呼び出しの手順ではなく、手順の正本は表の行が指すファイル
#   - archive と _longruns: 過去の記録
#   - 表そのもの

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  DOC_REL="plugins/dev-workflow/docs/codex-delegation-inventory.md"
  DOC="${REPO_ROOT}/${DOC_REL}"
  # App Server の起動は 2 つの形で拾う: コマンド行の `codex app-server` と、引数の並びの要素の 'app-server'
  # （['codex', 'app-server', ...] も、実行ファイルを変数で渡す [binary, 'app-server'] も当たる）
  PATTERN="codex exec|codex-companion|codex-worker\\.py|codex-develop\\.py|codex-rescue|codex:adversarial-review|codex review|codex app-server|['\"]app-server['\"]"
}

# 検索の対象の一覧（リポジトリ相対パス）。引数でリポジトリのルートを変えられる（既定は REPO_ROOT）
callers() {
  cd "${1:-$REPO_ROOT}" || return 1
  git ls-files -z | tr '\0' '\n' \
    | grep -vE '(^|/)(changes|tests|archive|_longruns)/|^openspec/|(^|/)CHANGELOG[^/]*$' \
    | grep -vxF "$DOC_REL" \
    | while IFS= read -r f; do
        [ -f "$f" ] && grep -qEI -- "$PATTERN" "$f" && printf '%s\n' "$f"
      done
}

# 表の行（`| `パス` | ... |`）の先頭列のパス。引数で表のファイルを変えられる（既定は DOC）
table_paths() {
  grep -E '^\| `[^`]+` \|' "${1:-$DOC}" | sed -E 's/^\| `([^`]+)` \|.*/\1/'
}

# 表に無い呼び出し元（引数: リポジトリのルート）
missing_callers() {
  root="${1:-$REPO_ROOT}"
  for f in $(callers "$root"); do
    table_paths "${root}/${DOC_REL}" | grep -qxF "$f" || printf '%s\n' "$f"
  done
}

@test "inventory doc exists" {
  [ -f "$DOC" ]
}

@test "every file that names a Codex call is in the table" {
  [ -f "$DOC" ]
  missing="$(missing_callers)"
  [ -z "$missing" ] || { printf 'not in the table:\n%s\n' "$missing" >&2; false; }
}

# App Server を起動する形（codex-worker.py の前景コマンドの起動の形）を足したファイルが、表に無ければ拾われる
@test "a new App Server launcher that is not in the table is caught" {
  fixture="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "${fixture}/$(dirname "$DOC_REL")" "${fixture}/scripts"
  cp "$DOC" "${fixture}/${DOC_REL}"
  printf '%s\n' "proc = subprocess.Popen(['codex', 'app-server', '-c', 'x'], cwd=cwd)" > "${fixture}/scripts/launch_list.py"
  printf '%s\n' "proc = subprocess.Popen([binary, 'app-server'], stdin=PIPE)" > "${fixture}/scripts/launch_binary.py"
  printf '%s\n' 'exec codex app-server "$@"' > "${fixture}/scripts/launch.sh"
  git -C "$fixture" init -q
  git -C "$fixture" add -A
  missing="$(missing_callers "$fixture")"
  for f in scripts/launch_list.py scripts/launch_binary.py scripts/launch.sh; do
    printf '%s\n' "$missing" | grep -qxF "$f" || { printf 'not caught: %s\n' "$f" >&2; false; }
  done
}

@test "every table row still names a Codex call in an existing file" {
  [ -f "$DOC" ]
  stale=""
  for f in $(table_paths); do
    [ -f "${REPO_ROOT}/${f}" ] && grep -qEI -- "$PATTERN" "${REPO_ROOT}/${f}" || stale="${stale}${f}"$'\n'
  done
  [ -z "$stale" ] || { printf 'stale rows:\n%s' "$stale" >&2; false; }
}

@test "every table row has a known class" {
  [ -f "$DOC" ]
  bad="$(grep -E '^\| `[^`]+` \|' "$DOC" | awk -F'|' '{gsub(/^ +| +$/,"",$4); if ($4!="移行済み" && $4!="残置" && $4!="言及のみ" && $4!="実装" && $4!="委譲外") print $0}')"
  [ -z "$bad" ] || { printf 'unknown class:\n%s\n' "$bad" >&2; false; }
}

@test "every table row names a role" {
  [ -f "$DOC" ]
  bad="$(grep -E '^\| `[^`]+` \|' "$DOC" | awk -F'|' '{gsub(/^ +| +$/,"",$3); if ($3=="") print $0}')"
  [ -z "$bad" ] || { printf 'empty role:\n%s\n' "$bad" >&2; false; }
}

@test "the table has no duplicate path" {
  [ -f "$DOC" ]
  [ -z "$(table_paths | sort | uniq -d)" ]
}
