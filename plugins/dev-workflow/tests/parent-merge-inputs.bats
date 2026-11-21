#!/usr/bin/env bats
# spec: collect-parent-merge-inputs。gh を PATH の偽物に替え、判断や書き込みをせず入力だけ集める。
setup() {
  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/parent-merge-inputs.sh"
  export CFG="$BATS_TEST_TMPDIR/cfg" CALLS="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$CFG" "$BATS_TEST_TMPDIR/bin" "$BATS_TEST_TMPDIR/repo"
  export TOP="$BATS_TEST_TMPDIR/repo"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  cat > "$BATS_TEST_TMPDIR/bin/gh" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >> "$CALLS"
[ ! -f "$CFG/fail" ] || exit 1
case "$*" in
  'pr view '*) cat "$CFG/pr" ;;
  'pr diff '*) [ ! -f "$CFG/fail-diff" ] || exit 1; echo 'diff --git a/old.sh b/new.sh' ;;
  'api repos/{owner}/{repo}/issues/400') cat "$CFG/epic" ;;
  'api repos/other/child/issues/11') cat "$CFG/child" ;;
  'api --paginate repos/{owner}/{repo}/issues/400/comments') cat "$CFG/epic-comments" ;;
  'api --paginate repos/other/child/issues/11/comments') cat "$CFG/child-comments" ;;
  'api --paginate repos/other/child/issues/99/comments') cat "$CFG/pr-comments" ;;
  'api --paginate repos/other/child/pulls/99/files') echo '[{"filename":"new.sh","previous_filename":"old.sh","status":"renamed"}]' ;;
  'api repos/other/child/contents/.github/workflows/auto-merge.yml?ref=release/v1 --jq .content') base64 < "$CFG/workflow" ;;
  *) echo "unexpected gh: $*" >&2; exit 1 ;;
esac
STUB
  cat > "$BATS_TEST_TMPDIR/bin/git" <<'STUB'
#!/bin/bash
[ "$*" = 'rev-parse --show-toplevel' ] || exit 1
printf '%s\n' "$TOP"
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/gh" "$BATS_TEST_TMPDIR/bin/git"
  echo '{"body":"エピック本文","author_association":"OWNER"}' > "$CFG/epic"
  echo '{"body":"子本文","author_association":"MEMBER"}' > "$CFG/child"
  echo '{"body":"Refs #11\nCloses #22","labels":[{"name":"human-merge"}],"state":"OPEN","headRefOid":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","baseRefName":"release/v1","statusCheckRollup":[{"conclusion":"SUCCESS"}]}' > "$CFG/pr"
  echo '[{"body":"親エピックからの注意書き: trusted-note","author_association":"COLLABORATOR"},{"body":"親エピックからの注意書き: untrusted-note","author_association":"NONE"}]' > "$CFG/child-comments"
  echo '[]' > "$CFG/epic-comments"
  echo '[]' > "$CFG/pr-comments"
  printf '%s\n' 'parent-merge-approved' '# >>> sacred-paths' 'SACRED=secret' '# <<< sacred-paths' '# >>> merge-condition-paths' 'MERGE_CONDITION=workflow' '# <<< merge-condition-paths' > "$CFG/workflow"
  printf '%s\n' '子の最後の全文' '止まった理由: PR のマージ待ち（human-merge）' > "$CFG/last"
}
collect() {
  # stderr は stdout と分け、exit 1 の stdout 空の契約を検査する。
  /bin/bash "$SCRIPT" 400 'other/child#11' https://github.com/other/child/pull/99 --last-message "$CFG/last" "$@" 2> "$CFG/stderr"
}
mutate_pr() { jq "$1" "$CFG/pr" > "$CFG/new" && mv "$CFG/new" "$CFG/pr"; }
assert_escalated() {
  [ "$status" -eq 3 ]
  [[ "$output" == '主に上げる: '* ]] || return 1
  [ "${#lines[@]}" -eq 1 ]
}
@test "inputs: all sections, full last message, base workflow and rename source" {
  run collect
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'HEAD: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' ]
  for title in 'エピックの本文' '子 issue の本文' '親エピックからの注意書き' '子の最後の発言' 'PR の本文とラベル' '変更ファイルの一覧' '差分' 'PR のコメント' 'CI の結果' 'auto-merge.yml の聖域とマージ条件の行' 'human-merge を付けた投稿' '配役表' '委任の記録の候補' '委任の確認の場所'; do
    [[ "$output" == *"## $title"* ]] || return 1
  done
  for value in エピック本文 子本文 trusted-note 子の最後の全文 '止まった理由:' 'SACRED=secret' 'MERGE_CONDITION=workflow' old.sh new.sh SUCCESS; do
    [[ "$output" == *"$value"* ]] || return 1
  done
  [[ "$output" != *untrusted-note* ]] || return 1
  [[ "$output" == *'## 配役表（なし）'* ]] || return 1
  grep -qF '?ref=release/v1' "$CALLS"
  if grep -Eq 'merge|comment|edit' < <(grep -vE '^api |^pr view |^pr diff ' "$CALLS"); then
    return 1
  fi
}
@test "precondition: base workflow has no approval support" {
  echo '# no support' > "$CFG/workflow"
  run collect
  assert_escalated
  [[ "$output" == *auto-merge.yml* ]] || return 1
}
@test "precondition: only human-merge, on an open PR" {
  mutate_pr '.labels += [{"name":"needs-approval"}]'
  run collect
  assert_escalated
  [[ "$output" == *ラベル* ]] || return 1
  mutate_pr '.labels = []'
  run collect
  assert_escalated
  mutate_pr '.labels = [{"name":"human-merge"}] | .state = "CLOSED"'
  run collect
  assert_escalated
}
@test "precondition: first closing reference must name the child" {
  mutate_pr '.body = "Fixes #22\nCloses #11"'
  run collect
  assert_escalated
  [[ "$output" == *番号* ]] || return 1
}
@test "precondition: an approval for this HEAD escalates with troubleshooting" {
  echo '[{"body":"親のマージ判断: 可\n親が見た HEAD: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","author_association":"OWNER"}]' > "$CFG/pr-comments"
  run collect
  assert_escalated
  [[ "$output" == *docs/auto-merge.md* ]] || return 1
  [[ "$output" == *親の判断の印を付けたのにマージされないとき* ]] || return 1
}
@test "inputs: stale approval does not block" {
  echo '[{"body":"親のマージ判断: 可\n親が見た HEAD: bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","author_association":"OWNER"}]' > "$CFG/pr-comments"
  run collect
  [ "$status" -eq 0 ]
}
@test "unreadable: either untrusted issue gives exit 1 and empty stdout" {
  for file in epic child; do
    cp "$CFG/$file" "$CFG/saved"
    echo '{"body":"untrusted","author_association":"NONE"}' > "$CFG/$file"
    run collect
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    mv "$CFG/saved" "$CFG/$file"
  done
}
@test "unreadable: missing last message, bad arguments, gh failure and broken JSON" {
  run collect --last-message "$CFG/missing"
  [ "$status" -eq 1 ]; [ -z "$output" ]
  run /bin/bash -c '"$1" 2> "$2"' _ "$SCRIPT" "$CFG/stderr"
  [ "$status" -eq 1 ]; [ -z "$output" ]
  touch "$CFG/fail"
  run collect
  [ "$status" -eq 1 ]; [ -z "$output" ]
  rm "$CFG/fail"
  echo broken > "$CFG/pr"
  run collect
  [ "$status" -eq 1 ]; [ -z "$output" ]
}
@test "inputs: trusted comments only, but sacred-path bot post is included" {
  cat > "$CFG/pr-comments" <<'JSON'
[{"body":"trusted-gate","author_association":"MEMBER"},
 {"body":"untrusted-gate","author_association":"NONE"},
 {"body":"🔒 **auto-merge 対象外（聖域パス接触）**\nbot-post","author_association":"NONE"}]
JSON
  run collect
  [ "$status" -eq 0 ]
  [[ "$output" == *trusted-gate* ]] || return 1
  [[ "$output" != *untrusted-gate* ]] || return 1
  [[ "$output" == *$'## human-merge を付けた投稿\n\n'*bot-post* ]] || return 1
}
@test "inputs: latest trusted delegation candidate and supplied confirmation verbatim" {
  cat > "$CFG/epic-comments" <<'JSON'
[{"body":"主の委任: 論点なしの止まり\nold-candidate","html_url":"old-url","created_at":"2026-01-01T00:00:00Z","author_association":"OWNER"},
 {"body":"主の委任: 論点なしの止まり\nnew-candidate","html_url":"new-url","created_at":"2026-02-01T00:00:00Z","author_association":"COLLABORATOR"},
 {"body":"主の委任: 論点なしの止まり\nforged-candidate","html_url":"forged-url","created_at":"2026-03-01T00:00:00Z","author_association":"NONE"}]
JSON
  run collect --delegation-place '委任の確認の場所: セッション abc / uuid xyz / 記録 new-url'
  [ "$status" -eq 0 ]
  for value in new-candidate new-url '委任の確認の場所: セッション abc / uuid xyz / 記録 new-url'; do
    [[ "$output" == *"$value"* ]] || return 1
  done
  [[ "$output" != *old-candidate* ]] || return 1
  [[ "$output" != *forged-candidate* ]] || return 1
  [[ "$output" != *'委任は有効'* ]] || return 1
}
@test "inputs: no delegation candidate unless the parent supplied --delegation-place" {
  echo '[{"body":"主の委任: 論点なしの止まり\nunchecked-candidate","html_url":"unchecked-url","created_at":"2026-02-01T00:00:00Z","author_association":"OWNER"}]' > "$CFG/epic-comments"
  run collect
  [ "$status" -eq 0 ]
  [[ "$output" == *'## 委任の記録の候補（なし）'* ]] || return 1
  [[ "$output" != *unchecked-candidate* ]] || return 1
  [[ "$output" != *unchecked-url* ]] || return 1
}
@test "inputs: only casting files present in the worktree are included" {
  mkdir -p "$TOP/.claude/casting"
  echo project-only > "$TOP/.claude/casting/project.md"
  run collect
  [ "$status" -eq 0 ]
  [[ "$output" == *project-only* ]] || return 1
  [[ "$output" != *local.md* ]] || return 1
}

@test "unreadable: late collection failure leaves stdout empty" {
  touch "$CFG/fail-diff"
  run collect
  [ "$status" -eq 1 ]; [ -z "$output" ]
}
@test "inputs: trusted empty issue bodies are readable, absent CI has a none heading" {
  echo '{"body":"","author_association":"OWNER"}' > "$CFG/epic"
  mutate_pr '.statusCheckRollup = []'
  run collect
  [ "$status" -eq 0 ]
  [[ "$output" == *'## エピックの本文（なし）'* ]] || return 1
  [[ "$output" == *'## CI の結果（なし）'* ]] || return 1
}
