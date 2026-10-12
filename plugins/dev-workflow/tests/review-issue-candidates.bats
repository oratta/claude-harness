#!/usr/bin/env bats
#
# review-issue-candidates.sh: レビューの指摘が指すファイルについて、同じ場所を直す open の issue の
# 候補（番号と題名）をパスごとに 1 回の検索で返す。gh は偽物に差し替え、実物の GitHub は呼ばない。
#
# spec: openspec/changes/review-finding-issue-candidates（dev-workflow-review-issue-candidates）

TAB=$'\t'

bats_require_minimum_version 1.5.0

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/review-issue-candidates.sh"
  WORK="$(cd "$(mktemp -d)" && pwd -P)"
  GH_LOG="${WORK}/gh.log"
  mkdir -p "${WORK}/bin" "${WORK}/gh"
  : > "$GH_LOG"
  # gh の偽物: 呼び出しを 1 行 1 回で記録する。
  #   issue list: 検索語の最初の "<ファイル名>" から gh/list-<ファイル名>.json（無ければ gh/list.json、それも無ければ []）を返す。
  #               gh/list-<ファイル名>.fail があれば非 0 で終わる
  #   api .../sub_issues: gh/sub.json（無ければ []）を返す。gh/sub.fail があれば非 0 で終わる
  cat > "${WORK}/bin/gh" <<EOS
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${GH_LOG}"
case "\$1" in
  issue)
    q=""
    prev=""
    for a in "\$@"; do
      [ "\$prev" = "--search" ] && q="\$a"
      prev="\$a"
    done
    name="\$(printf '%s' "\$q" | sed -nE 's/^"([^"]*)".*/\1/p')"
    [ -e "${WORK}/gh/list-\${name}.fail" ] && { echo "gh: HTTP 502" >&2; exit 1; }
    if [ -e "${WORK}/gh/list-\${name}.json" ]; then cat "${WORK}/gh/list-\${name}.json"
    elif [ -e "${WORK}/gh/list.json" ]; then cat "${WORK}/gh/list.json"
    else echo '[]'; fi
    ;;
  api)
    [ -e "${WORK}/gh/sub.fail" ] && { echo "gh: HTTP 502" >&2; exit 1; }
    cat "${WORK}/gh/sub.json" 2>/dev/null || echo '[]'
    ;;
  *) exit 1 ;;
esac
EOS
  chmod +x "${WORK}/bin/gh"
  export PATH="${WORK}/bin:${PATH}"
}

teardown() {
  rm -rf "$WORK"
}

# 検索結果の JSON を作る: $1=ファイル名 以降は "番号:題名" の並び
set_list() {
  local name="$1"; shift
  local item out='[]'
  for item in "$@"; do
    out="$(jq -c --argjson n "${item%%:*}" --arg t "${item#*:}" '. + [{number: $n, title: $t, body: "BODY-SECRET"}]' <<<"$out")"
  done
  printf '%s' "$out" > "${WORK}/gh/list-${name}.json"
}

gh_calls() { grep -c . "$GH_LOG" || true; }

# --- パスごとに 1 回検索して番号と題名を返す ---

@test "two paths are searched once each" {  # 2 つのパスを渡すと、パスごとに 1 回ずつ検索する
  run "$SCRIPT" --repo o/r plugins/x/scripts/pr-state.sh plugins/x/stages/triage.md
  [ "$status" -eq 0 ]
  [ "$(gh_calls)" -eq 2 ]
  grep -qF -- '--search "pr-state.sh" in:title,body' "$GH_LOG"
  grep -qF -- '--search "triage.md" in:title,body' "$GH_LOG"
  [ "$(grep -c -- '--state open' "$GH_LOG")" -eq 2 ]
  [ "$(grep -c -- '--repo o/r' "$GH_LOG")" -eq 2 ]
}

@test "candidates are listed under the heading as number and title" {  # 候補は見出し行の下に番号と題名で出る
  set_list triage.md "886:triage.md の --repo を明記する" "578:bats を triage.md に向ける"
  run "$SCRIPT" --repo o/r plugins/x/stages/triage.md
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "== plugins/x/stages/triage.md" ]
  [ "${lines[1]}" = "886${TAB}triage.md の --repo を明記する" ]
  [ "${lines[2]}" = "578${TAB}bats を triage.md に向ける" ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "tabs in a title become one space" {  # 題名のタブは空白 1 個に置き換わる
  set_list a.md "5:前${TAB}後"
  run "$SCRIPT" --repo o/r x/a.md
  [ "${lines[1]}" = "5${TAB}前 後" ]
}

@test "a path with no candidates prints the none marker" {  # 候補が無いパスは該当なしと出る
  run "$SCRIPT" --repo o/r x/none.sh
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "== x/none.sh" ]
  [ "${lines[1]}" = "(該当なし)" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "a repeated path is searched once" {  # 同じパスを 2 回渡しても検索は 1 回
  run "$SCRIPT" --repo o/r x/a.md x/a.md
  [ "$status" -eq 0 ]
  [ "$(gh_calls)" -eq 1 ]
  [ "$(printf '%s\n' "$output" | grep -c '^== ')" -eq 1 ]
}

@test "issue bodies are never printed or requested" {  # 本文は出力に含まれない
  set_list a.md "1:題名"
  run "$SCRIPT" --repo o/r x/a.md
  run grep -q BODY-SECRET <<<"$output"
  [ "$status" -eq 1 ]
  run grep -q -- '--json [a-z,]*body' "$GH_LOG"
  [ "$status" -eq 1 ]
  grep -qF -- '--json number,title' "$GH_LOG"
}

# --- 外す番号と 15 件の打ち切り ---

@test "excluded numbers are dropped" {  # 外す番号は候補に出ない
  set_list a.md "973:自分" "886:相手"
  run "$SCRIPT" --repo o/r --exclude 973 --exclude 980 x/a.md
  [ "$status" -eq 0 ]
  [[ "$output" == *"886${TAB}相手"* ]] || return 1
  [[ "$output" != *"973${TAB}"* ]] || return 1
}

@test "limit is 15 plus excludes plus 1" {  # 外す番号の分だけ多く取り寄せる
  run "$SCRIPT" --repo o/r --exclude 1 --exclude 2 x/a.md
  [ "$status" -eq 0 ]
  grep -qF -- '--limit 18' "$GH_LOG"
}

@test "16 candidates are cut at 15 with a note" {  # 16 件以上あれば 15 件で打ち切ったと出る
  local items=() i
  for i in $(seq 101 116); do items+=("${i}:題名${i}"); done
  set_list a.md "${items[@]}"
  run "$SCRIPT" --repo o/r x/a.md
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 17 ]
  [ "${lines[1]}" = "101${TAB}題名101" ]
  [ "${lines[15]}" = "115${TAB}題名115" ]
  [ "${lines[16]}" = "(15 件で打ち切り。ほかにも一致あり)" ]
}

@test "exactly 15 candidates print no note" {  # ちょうど 15 件なら打ち切りの行は出ない
  local items=() i
  for i in $(seq 101 115); do items+=("${i}:題名${i}"); done
  set_list a.md "${items[@]}"
  run "$SCRIPT" --repo o/r x/a.md
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 16 ]
  [[ "$output" != *打ち切り* ]] || return 1
}

@test "15 after excluding prints no note" {  # 外す番号を除いて 15 件になるなら打ち切りの行は出ない
  local items=() i
  for i in $(seq 101 116); do items+=("${i}:題名${i}"); done
  set_list a.md "${items[@]}"
  run "$SCRIPT" --repo o/r --exclude 101 x/a.md
  [ "${#lines[@]}" -eq 16 ]
  [[ "$output" != *打ち切り* ]] || return 1
}

# --- エピック ---

@test "epic marks child and other" {  # エピックの子とそれ以外を見分ける
  printf '[{"number":721},{"number":694}]' > "${WORK}/gh/sub.json"
  set_list a.md "721:子" "886:外"
  run "$SCRIPT" --repo o/r --epic 725 x/a.md
  [ "$status" -eq 0 ]
  [ "${lines[1]}" = "721${TAB}子${TAB}child" ]
  [ "${lines[2]}" = "886${TAB}外${TAB}other" ]
}

@test "sub_issues is fetched once per run" {  # 子の一覧は 1 回だけ取る
  run "$SCRIPT" --repo o/r --epic 725 x/a.md x/b.md x/c.md
  [ "$status" -eq 0 ]
  [ "$(grep -c '^api ' "$GH_LOG")" -eq 1 ]
  grep -q '^api .*repos/o/r/issues/725/sub_issues' "$GH_LOG"
  [ "$(grep -c '^issue list' "$GH_LOG")" -eq 3 ]
}

@test "children-only adds parent-issue to the query" {  # 子だけに絞ると検索語に親の指定が足される
  set_list triage.md "721:子"
  run "$SCRIPT" --repo o/r --epic 725 --children-only plugins/x/stages/triage.md
  [ "$status" -eq 0 ]
  grep -qF -- '--search "triage.md" in:title,body parent-issue:o/r#725' "$GH_LOG"
  [ "$(grep -c '^api ' "$GH_LOG")" -eq 0 ]
  [ "${lines[1]}" = "721${TAB}子${TAB}child" ]
}

@test "without epic there are two columns" {  # エピックを指定しなければ 2 列
  set_list a.md "1:題名"
  run "$SCRIPT" --repo o/r x/a.md
  [ "${lines[1]}" = "1${TAB}題名" ]
  [ "$(grep -c '^api ' "$GH_LOG")" -eq 0 ]
}

# --- 失敗と引数の不備 ---

@test "a failed search prints nothing and exits 1" {  # 2 つ目のパスの検索が失敗したら何も出さない
  set_list a.md "1:題名"
  : > "${WORK}/gh/list-b.md.fail"
  run --separate-stderr "$SCRIPT" --repo o/r x/a.md x/b.md
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ -n "$stderr" ]
}

@test "a failed sub_issues fetch stops before searching" {  # 子の一覧が取れなければ検索に進まない
  : > "${WORK}/gh/sub.fail"
  run --separate-stderr "$SCRIPT" --repo o/r --epic 725 x/a.md
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ -n "$stderr" ]
  [ "$(grep -c '^issue list' "$GH_LOG")" -eq 0 ]
}

@test "no path exits 2" {  # パスが無ければ終了コード 2
  run "$SCRIPT" --repo o/r
  [ "$status" -eq 2 ]
  [ -z "$(cat "$GH_LOG")" ]
}

@test "missing repo exits 2" {  # リポジトリの指定が無ければ終了コード 2
  run "$SCRIPT" x/a.md
  [ "$status" -eq 2 ]
  [ -z "$(cat "$GH_LOG")" ]
}

@test "malformed repo exits 2" {  # リポジトリの指定が owner/name の形でなければ終了コード 2
  run "$SCRIPT" --repo claude-harness x/a.md
  [ "$status" -eq 2 ]
  [ -z "$(cat "$GH_LOG")" ]
}

@test "missing gh or jq exits 2" {  # gh か jq が無ければ終了コード 2
  local bin="${WORK}/nogh"
  mkdir -p "$bin"
  ln -s "$(command -v bash)" "$bin/bash"
  ln -s "$(command -v jq)" "$bin/jq"
  PATH="$bin" run /bin/bash "$SCRIPT" --repo o/r x/a.md
  [ "$status" -eq 2 ]
  rm -f "$bin/jq"
  ln -s "${WORK}/bin/gh" "$bin/gh"
  PATH="$bin" run /bin/bash "$SCRIPT" --repo o/r x/a.md
  [ "$status" -eq 2 ]
  [ -z "$(cat "$GH_LOG")" ]
}

@test "non-integer numbers exit 2" {  # 数字でない番号は終了コード 2
  run "$SCRIPT" --repo o/r --exclude abc x/a.md
  [ "$status" -eq 2 ]
  run "$SCRIPT" --repo o/r --epic '#725' x/a.md
  [ "$status" -eq 2 ]
  run "$SCRIPT" --repo o/r --epic 0 x/a.md
  [ "$status" -eq 2 ]
  [ -z "$(cat "$GH_LOG")" ]
}

@test "children-only without epic exits 2" {  # エピックなしの子だけ指定は終了コード 2
  run "$SCRIPT" --repo o/r --children-only x/a.md
  [ "$status" -eq 2 ]
  [ -z "$(cat "$GH_LOG")" ]
}

@test "unknown option exits 2" {  # 知らないオプションは終了コード 2
  run "$SCRIPT" --repo o/r --nope x/a.md
  [ "$status" -eq 2 ]
  [ -z "$(cat "$GH_LOG")" ]
}

@test "paths without a usable file name exit 2" {  # ファイル名を取り出せないパスは終了コード 2
  run "$SCRIPT" --repo o/r plugins/x/
  [ "$status" -eq 2 ]
  run "$SCRIPT" --repo o/r 'x/a"b.md'
  [ "$status" -eq 2 ]
  [ -z "$(cat "$GH_LOG")" ]
}

@test "all paths empty still exits 0" {  # 全パスが 0 件でも終了コード 0
  run "$SCRIPT" --repo o/r x/a.md x/b.md
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "== x/a.md" ]
  [ "${lines[1]}" = "(該当なし)" ]
  [ "${lines[2]}" = "== x/b.md" ]
  [ "${lines[3]}" = "(該当なし)" ]
}
