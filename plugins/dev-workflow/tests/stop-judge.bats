#!/usr/bin/env bats
# stop-judge.sh（止まったエピックの子を、親が通すか主に上げるかをモデル 1 回で判断する）の振る舞いを、
# gh・git・claude を PATH 上のスタブにして確かめる。
#
# スタブは自分の名前と引数（printf '%q'）を共通のログ（${STUB_LOG}）に 1 行ずつ追記する。
# 返り値は $STUB_CFG の設定ファイルで切り替える:
#   gh    : api ... issues/<N> は {"body": body_<N> の中身, "author_association": assoc_<N> の中身（無ければ OWNER）}
#           を出す（fail_body_<N> があれば exit 1。raw_issue_<N> があればその中身をそのまま出す）。
#           api --paginate ... issues/<N>/comments は comments_<N>（JSON の配列）を出す
#           （fail_comments_<N> があれば exit 1。無ければ []）
#   git   : rev-parse --show-toplevel は toplevel を出す
#   claude: 標準入力を model_in に、引数を model_args に書き、model_out を出して model_exit で終わる
# スクリプトは PATH="<スタブ置き場>:/usr/bin:/bin" で走らせる（jq は実物）。
#
# spec: dev-workflow-develop（epic-dispatch.sh の wait は止まった子を判断し、通すものには返事を送って待ちを続ける）

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/stop-judge.sh"
  CRITERIA="${PLUGIN_DIR}/skills/develop/references/parent-pass-criteria.md"
  STUB_BIN="${BATS_TEST_TMPDIR}/bin"
  export STUB_CFG="${BATS_TEST_TMPDIR}/cfg"
  export STUB_LOG="${BATS_TEST_TMPDIR}/calls.log"
  mkdir -p "$STUB_BIN" "$STUB_CFG" "$BATS_TEST_TMPDIR/repo"
  : > "$STUB_LOG"
  printf '%s\n' "$BATS_TEST_TMPDIR/repo" > "$STUB_CFG/toplevel"
  printf '%s\n' 'エピックの本文: 止まった子を親が解決する' > "$STUB_CFG/body_400"
  printf '%s\n' '子の本文: 受け入れ条件はこれ' > "$STUB_CFG/body_11"
  cat > "$STUB_CFG/comments_11" <<'EOF'
[
 {"body":"親エピックからの注意書き: #400\n\n他の子の範囲に手を出さない","author_association":"OWNER","html_url":"https://github.com/o/r/issues/11#issuecomment-1"},
 {"body":"親エピックからの注意書き: #400\n\n外の人の注意書き","author_association":"NONE","html_url":"https://github.com/o/r/issues/11#issuecomment-2"},
 {"body":"子の停止: 主の返事待ち\n古い止まり","author_association":"OWNER","html_url":"https://github.com/o/r/issues/11#issuecomment-3"},
 {"body":"関係ないコメント","author_association":"OWNER","html_url":"https://github.com/o/r/issues/11#issuecomment-4"},
 {"body":"子の停止: 主の返事待ち\n止まった理由: hook がファイルの読み取りを止めた\n主に聞く理由: なし（hook に止められ子の側では読めない）\n前提: 読むのは作業ツリーの中\n推奨: 読む\n推奨の根拠: 作業ツリーの中なので戻せる\n受け入れるリスク: なし\n再開に要る途中経過: なし","author_association":"OWNER","html_url":"https://github.com/o/r/issues/11#issuecomment-5"}
]
EOF
  cat > "$STUB_CFG/comments_400" <<'EOF'
[
 {"body":"回し方: Orca（並列可能な子 2 件）","author_association":"OWNER","html_url":"u1"},
 {"body":"親の判断: 子 #11 通した — 前回の件 https://github.com/o/r/issues/11#issuecomment-3","author_association":"OWNER","html_url":"u2"},
 {"body":"親の判断: 子 #12 通した — 他の子の件 x","author_association":"OWNER","html_url":"u3"},
 {"body":"親の判断: 子 #111 通した — 番号違い y","author_association":"OWNER","html_url":"u4"}
]
EOF
  printf '%s\n' '判断: 通す' '理由: 範囲の内側で戻せる' '返事: 推奨どおり読んでよい' > "$STUB_CFG/model_out"
  make_stubs
  unset EPIC_DISPATCH_JUDGE_CMD EPIC_DISPATCH_JUDGE_MODEL
}

make_stubs() {
  cat > "$STUB_BIN/gh" <<'EOF'
#!/bin/bash
{ printf '%s' gh; printf ' %q' "$@"; echo; } >> "$STUB_LOG"
path=""
for a in "$@"; do case "$a" in repos/*) path="$a" ;; esac; done
case "$path" in
  */comments)
    n="${path%/comments}"; n="${n##*/}"
    [ -e "$STUB_CFG/fail_comments_$n" ] && { echo "gh: mock failure" >&2; exit 1; }
    cat "$STUB_CFG/comments_$n" 2>/dev/null || echo '[]'
    exit 0 ;;
  *)
    n="${path##*/}"
    [ -e "$STUB_CFG/fail_body_$n" ] && { echo "gh: mock failure" >&2; exit 1; }
    [ -e "$STUB_CFG/raw_issue_$n" ] && { cat "$STUB_CFG/raw_issue_$n"; exit 0; }
    jq -n --arg b "$(cat "$STUB_CFG/body_$n" 2>/dev/null)" \
      --arg a "$(cat "$STUB_CFG/assoc_$n" 2>/dev/null || echo OWNER)" \
      '{body: $b, author_association: $a}'
    exit 0 ;;
esac
EOF
  cat > "$STUB_BIN/git" <<'EOF'
#!/bin/bash
{ printf '%s' git; printf ' %q' "$@"; echo; } >> "$STUB_LOG"
[ "$1" = rev-parse ] && { cat "$STUB_CFG/toplevel"; exit 0; }
exit 0
EOF
  cat > "$STUB_BIN/claude" <<'EOF'
#!/bin/bash
{ printf '%s' claude; printf ' %q' "$@"; echo; } >> "$STUB_LOG"
printf '%s\n' "$@" > "$STUB_CFG/model_args"
cat > "$STUB_CFG/model_in"
cat "$STUB_CFG/model_out"
exit "$(cat "$STUB_CFG/model_exit" 2>/dev/null || echo 0)"
EOF
  chmod +x "$STUB_BIN/gh" "$STUB_BIN/git" "$STUB_BIN/claude"
}

judge() { PATH="$STUB_BIN:/usr/bin:/bin" "$SCRIPT" "$@" 2>"$BATS_TEST_TMPDIR/stderr"; }

calls() { LC_ALL=C grep -c -- "$1" "$STUB_LOG" || true; }

@test "stop-judge: prints the model's three lines and the record URL as the fourth" {
  run judge 400 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "${#lines[@]}" -eq 4 ]
  [ "${lines[0]}" = "判断: 通す" ]
  [ "${lines[1]}" = "理由: 範囲の内側で戻せる" ]
  [ "${lines[2]}" = "返事: 推奨どおり読んでよい" ]
  [ "${lines[3]}" = "記録: https://github.com/o/r/issues/11#issuecomment-5" ]
}

@test "stop-judge: an escalation with an empty reply is passed through" {
  printf '%s\n' '判断: 主に上げる' '理由: 主の好みが要る' '返事:' > "$STUB_CFG/model_out"
  run judge 400 11
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "判断: 主に上げる" ]
  [ "${lines[1]}" = "理由: 主の好みが要る" ]
  [ "${lines[2]}" = "返事: " ] || [ "${lines[2]}" = "返事:" ]
  [ "${lines[3]}" = "記録: https://github.com/o/r/issues/11#issuecomment-5" ]
}

@test "stop-judge: the model gets the epic, the child, the owner's note, the latest stop, past decisions and the criteria" {
  run judge 400 11
  [ "$status" -eq 0 ]
  in="$STUB_CFG/model_in"
  grep -qF 'エピックの本文: 止まった子を親が解決する' "$in"
  grep -qF '子の本文: 受け入れ条件はこれ' "$in"
  grep -qF '他の子の範囲に手を出さない' "$in"
  # 停止の記録は 7 つの項目の形のまま渡す（項目名を解釈しない）
  for item in '止まった理由: hook がファイルの読み取りを止めた' '主に聞く理由: なし（hook に止められ子の側では読めない）' \
              '前提: 読むのは作業ツリーの中' '推奨: 読む' \
              '推奨の根拠: 作業ツリーの中なので戻せる' '受け入れるリスク: なし' '再開に要る途中経過: なし'; do
    grep -qxF "$item" "$in" || { echo "missing: $item"; false; }
  done
  grep -qF 'https://github.com/o/r/issues/11#issuecomment-5' "$in"
  grep -qF '親の判断: 子 #11 通した — 前回の件' "$in"
  grep -qF "$(sed -n 1p "$CRITERIA")" "$in"
  grep -qF '| 繰り返していない |' "$in"
}

@test "stop-judge: a stop record in the older six-item form without the ask-reason item is passed as is" {
  cat > "$STUB_CFG/comments_11" <<'EOF'
[
 {"body":"子の停止: 主の返事待ち\n止まった理由: hook がファイルの読み取りを止めた\n前提: 読むのは作業ツリーの中\n推奨: 読む\n推奨の根拠: 作業ツリーの中なので戻せる\n受け入れるリスク: なし\n再開に要る途中経過: なし","author_association":"OWNER","html_url":"https://github.com/o/r/issues/11#issuecomment-6"}
]
EOF
  run judge 400 11
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "${#lines[@]}" -eq 4 ]
  [ "${lines[3]}" = "記録: https://github.com/o/r/issues/11#issuecomment-6" ]
  in="$STUB_CFG/model_in"
  for item in '止まった理由: hook がファイルの読み取りを止めた' '前提: 読むのは作業ツリーの中' '推奨: 読む' \
              '推奨の根拠: 作業ツリーの中なので戻せる' '受け入れるリスク: なし' '再開に要る途中経過: なし'; do
    grep -qxF "$item" "$in" || { echo "missing: $item"; false; }
  done
  run grep -F '主に聞く理由:' "$in"; [ "$status" -eq 1 ]
}

@test "stop-judge: notes from other authors, older stops, other children's decisions and other comments are not passed" {
  run judge 400 11
  [ "$status" -eq 0 ]
  in="$STUB_CFG/model_in"
  run grep -F '外の人の注意書き' "$in"; [ "$status" -eq 1 ]
  run grep -F '古い止まり' "$in"; [ "$status" -eq 1 ]
  run grep -F '関係ないコメント' "$in"; [ "$status" -eq 1 ]
  run grep -F '他の子の件' "$in"; [ "$status" -eq 1 ]
  run grep -F '番号違い' "$in"; [ "$status" -eq 1 ]
  run grep -F '回し方:' "$in"; [ "$status" -eq 1 ]
}

@test "stop-judge: casting tables in the repo are passed when they exist" {
  mkdir -p "$BATS_TEST_TMPDIR/repo/.claude/casting"
  echo '配役表の本文 project' > "$BATS_TEST_TMPDIR/repo/.claude/casting/project.md"
  echo '配役表の本文 local' > "$BATS_TEST_TMPDIR/repo/.claude/casting/local.md"
  run judge 400 11
  [ "$status" -eq 0 ]
  grep -qF '配役表の本文 project' "$STUB_CFG/model_in"
  grep -qF '配役表の本文 local' "$STUB_CFG/model_in"
}

@test "stop-judge: the default call is claude -p with sonnet, no tools and no session persistence" {
  run judge 400 11
  [ "$status" -eq 0 ]
  args="$(cat "$STUB_CFG/model_args")"
  printf '%s\n' "$args" | grep -qxF -- '-p'
  printf '%s\n' "$args" | grep -A1 -xF -- '--model' | tail -1 | grep -qxF sonnet
  printf '%s\n' "$args" | grep -qxF -- '--no-session-persistence'
  # --tools の次の引数は空文字
  [ "$(printf '%s\n' "$args" | awk 'p { print "[" $0 "]"; exit } $0 == "--tools" { p = 1 }')" = "[]" ]
  [ "$(calls '^claude ')" -eq 1 ]
}

@test "stop-judge: EPIC_DISPATCH_JUDGE_MODEL changes the model" {
  EPIC_DISPATCH_JUDGE_MODEL=haiku run judge 400 11
  [ "$status" -eq 0 ]
  grep -A1 -xF -- '--model' "$STUB_CFG/model_args" | tail -1 | grep -qxF haiku
}

@test "stop-judge: EPIC_DISPATCH_JUDGE_CMD replaces the whole command and gets the prompt on stdin" {
  cat > "$STUB_BIN/other-model" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" > "$STUB_CFG/other_args"
cat > "$STUB_CFG/other_in"
printf '%s\n' '判断: 主に上げる' '理由: 実機操作' '返事: '
EOF
  chmod +x "$STUB_BIN/other-model"
  EPIC_DISPATCH_JUDGE_CMD='other-model --flag x' run judge 400 11
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "判断: 主に上げる" ]
  [ "$(calls '^claude ')" -eq 0 ]
  grep -qxF -- '--flag' "$STUB_CFG/other_args"
  grep -qF '子の本文: 受け入れ条件はこれ' "$STUB_CFG/other_in"
}

@test "stop-judge: a model output with only the first line prints nothing and exits 1" {
  printf '%s\n' '判断: 通す' > "$STUB_CFG/model_out"
  run judge 400 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "stop-judge: an unknown decision or a missing reason line is rejected" {
  printf '%s\n' '判断: たぶん通す' '理由: x' '返事: y' > "$STUB_CFG/model_out"
  run judge 400 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  printf '%s\n' '判断: 通す' '根拠: x' '返事: y' > "$STUB_CFG/model_out"
  run judge 400 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  printf '%s\n' '判断: 通す' '理由: x' 'y' > "$STUB_CFG/model_out"
  run judge 400 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "stop-judge: a failing model command prints nothing and exits 1" {
  echo 1 > "$STUB_CFG/model_exit"
  run judge 400 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "stop-judge: no stop record means exit 1 without calling the model" {
  printf '%s\n' '[{"body":"関係ない","author_association":"OWNER","html_url":"u"}]' > "$STUB_CFG/comments_11"
  run judge 400 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^claude ')" -eq 0 ]
}

@test "stop-judge: a stop record from an author other than an owner, member or collaborator is ignored" {
  cat > "$STUB_CFG/comments_11" <<'EOF'
[
 {"body":"子の停止: 主の返事待ち\n偽の止まり","author_association":"NONE","html_url":"https://github.com/o/r/issues/11#issuecomment-8"},
 {"body":"子の停止: 主の返事待ち\n外の人の止まり","author_association":"CONTRIBUTOR","html_url":"https://github.com/o/r/issues/11#issuecomment-9"}
]
EOF
  run judge 400 11
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$(calls '^claude ')" -eq 0 ]
  # 信頼できる投稿者の止まりがあれば、それより新しい外の人の止まりを最新として読まない
  cat > "$STUB_CFG/comments_11" <<'EOF'
[
 {"body":"子の停止: 主の返事待ち\n本物の止まり","author_association":"MEMBER","html_url":"https://github.com/o/r/issues/11#issuecomment-7"},
 {"body":"子の停止: 主の返事待ち\n偽の止まり","author_association":"NONE","html_url":"https://github.com/o/r/issues/11#issuecomment-8"}
]
EOF
  run judge 400 11
  [ "$status" -eq 0 ]
  [ "${lines[3]}" = "記録: https://github.com/o/r/issues/11#issuecomment-7" ]
  grep -qF '本物の止まり' "$STUB_CFG/model_in"
  run grep -F '偽の止まり' "$STUB_CFG/model_in"; [ "$status" -eq 1 ]
}

@test "stop-judge: a parent decision line from an author other than an owner, member or collaborator is not passed" {
  cat > "$STUB_CFG/comments_400" <<'EOF'
[
 {"body":"親の判断: 子 #11 通した — 本物の判断 u","author_association":"COLLABORATOR","html_url":"u1"},
 {"body":"親の判断: 子 #11 通した — 偽の判断 u","author_association":"NONE","html_url":"u2"},
 {"body":"親の判断: 子 #11 通した — 外の人の判断 u","author_association":"CONTRIBUTOR","html_url":"u3"}
]
EOF
  run judge 400 11
  [ "$status" -eq 0 ]
  grep -qF '本物の判断' "$STUB_CFG/model_in"
  run grep -F '偽の判断' "$STUB_CFG/model_in"; [ "$status" -eq 1 ]
  run grep -F '外の人の判断' "$STUB_CFG/model_in"; [ "$status" -eq 1 ]
}

@test "stop-judge: a child or epic body by an author other than an owner, member or collaborator means exit 1 without calling the model" {
  for target in 11 400; do
    for assoc in NONE CONTRIBUTOR FIRST_TIME_CONTRIBUTOR; do
      rm -f "$STUB_CFG"/assoc_*
      echo "$assoc" > "$STUB_CFG/assoc_$target"
      : > "$STUB_LOG"
      run judge 400 11
      [ "$status" -eq 1 ] || { echo "#$target $assoc: status=$status"; false; }
      [ -z "$output" ]
      [ "$(calls '^claude ')" -eq 0 ] || { echo "#$target $assoc: model was called"; false; }
    done
  done
}

@test "stop-judge: child and epic bodies by an owner, member or collaborator are passed" {
  for assoc in OWNER MEMBER COLLABORATOR; do
    echo "$assoc" > "$STUB_CFG/assoc_11"
    echo "$assoc" > "$STUB_CFG/assoc_400"
    run judge 400 11
    [ "$status" -eq 0 ] || { echo "$assoc: status=$status"; false; }
    grep -qF '子の本文: 受け入れ条件はこれ' "$STUB_CFG/model_in"
    grep -qF 'エピックの本文: 止まった子を親が解決する' "$STUB_CFG/model_in"
  done
}

@test "stop-judge: an issue without author_association or with an unreadable reply means exit 1 without calling the model" {
  for raw in '{"body":"子の本文"}' '{"body":"子の本文","author_association":null}' 'not json'; do
    printf '%s\n' "$raw" > "$STUB_CFG/raw_issue_11"
    : > "$STUB_LOG"
    run judge 400 11
    [ "$status" -eq 1 ] || { echo "$raw: status=$status"; false; }
    [ -z "$output" ]
    [ "$(calls '^claude ')" -eq 0 ] || { echo "$raw: model was called"; false; }
  done
}

@test "stop-judge: a failing gh call means exit 1 without calling the model" {
  for f in fail_body_400 fail_body_11 fail_comments_11 fail_comments_400; do
    rm -f "$STUB_CFG"/fail_*
    touch "$STUB_CFG/$f"
    : > "$STUB_LOG"
    run judge 400 11
    [ "$status" -eq 1 ] || { echo "$f: status=$status"; false; }
    [ -z "$output" ]
    [ "$(calls '^claude ')" -eq 0 ] || { echo "$f: model was called"; false; }
  done
}

@test "stop-judge: non-numeric or missing arguments are rejected without calling gh" {
  run judge 400
  [ "$status" -eq 1 ]
  run judge x 11
  [ "$status" -eq 1 ]
  run judge 400 y
  [ "$status" -eq 1 ]
  [ "$(calls '^gh ')" -eq 0 ]
  [ "$(calls '^claude ')" -eq 0 ]
}

# 別のリポジトリの子（<owner>/<repo>#<N>）
xchild_setup() {
  printf '%s\n' '別リポジトリの子の本文' > "$STUB_CFG/body_1615"
  cat > "$STUB_CFG/comments_1615" <<'EOT'
[
 {"body":"親エピックからの注意書き: oratta/claude-harness#400\n\n別リポジトリの注意","author_association":"OWNER","html_url":"x1"},
 {"body":"子の停止: 主の返事待ち\n止まった理由: 別リポジトリの停止","author_association":"OWNER","html_url":"https://github.com/genetta-inc/flatmate/issues/1615#issuecomment-9"}
]
EOT
  cat > "$STUB_CFG/comments_400" <<'EOT'
[
 {"body":"親の判断: 子 genetta-inc/flatmate#1615 通した — 前回の別リポジトリの件 u","author_association":"OWNER","html_url":"u1"},
 {"body":"親の判断: 子 #1615 通した — 同じ番号の同じリポジトリの子の件","author_association":"OWNER","html_url":"u2"},
 {"body":"親の判断: 子 other/repo#1615 通した — 別の別リポジトリの件","author_association":"OWNER","html_url":"u3"}
]
EOT
}

@test "stop-judge: a child given as <owner>/<repo>#<N> is read from that repository and its past decisions use the same name" {
  xchild_setup
  run judge 400 genetta-inc/flatmate#1615
  [ "$status" -eq 0 ] || { echo "status=$status output=$output"; cat "$BATS_TEST_TMPDIR/stderr"; false; }
  [ "${lines[3]}" = "記録: https://github.com/genetta-inc/flatmate/issues/1615#issuecomment-9" ]
  grep -qF 'repos/genetta-inc/flatmate/issues/1615' "$STUB_LOG"
  grep -qF 'repos/genetta-inc/flatmate/issues/1615/comments' "$STUB_LOG"
  grep -qF 'repos/\{owner\}/\{repo\}/issues/400' "$STUB_LOG"
  in="$STUB_CFG/model_in"
  grep -qF '別リポジトリの子の本文' "$in"
  grep -qF '親の判断: 子 genetta-inc/flatmate#1615 通した — 前回の別リポジトリの件' "$in"
  if grep -qF '同じ番号の同じリポジトリの子の件' "$in"; then false; fi
  if grep -qF '別の別リポジトリの件' "$in"; then false; fi
  grep -qF '## 子 genetta-inc/flatmate#1615 の本文' "$in"
}

@test "stop-judge: a same-repository child still reads {owner}/{repo} and matches past decisions by #<N>" {
  run judge 400 11
  [ "$status" -eq 0 ]
  grep -qF 'repos/\{owner\}/\{repo\}/issues/11' "$STUB_LOG"
  grep -qF '## 子 #11 の本文' "$STUB_CFG/model_in"
}

@test "stop-judge: a malformed <owner>/<repo>#<N> is rejected without calling gh" {
  run judge 400 'genetta-inc/flatmate#'
  [ "$status" -eq 1 ]
  run judge 400 'flatmate#1615'
  [ "$status" -eq 1 ]
  [ "$(calls '^gh ')" -eq 0 ]
}

@test "stop-judge: the script does not contain the word orca" {
  run grep -iw orca "$SCRIPT"
  [ "$status" -eq 1 ]
}
