#!/usr/bin/env bats
#
# spec: cost-ledger-attribution
#
# 会話ログの 1 行から抽出する「事実」の形と、その 1 パスの読み取り（重複排除・古い形の
# キャッシュ書込・ログのルートの解決）を固定する。区間の帰属はここには含まれない。

load helper

setup() {
  cl_setup
  cl_materialize
}

fact_of() {  # $1=requestId -> その事実 1 件を JSON で返す
  python3 "$CL" facts | python3 -c '
import json, sys
want = sys.argv[1]
for line in sys.stdin:
    d = json.loads(line)
    if d["request_id"] == want:
        print(json.dumps(d, ensure_ascii=False))
        break
else:
    sys.exit(1)
' "$1"
}

@test "facts: a per-line fact carries no interval attribution" {  # 1 行から抽出される事実に区間の帰属先 issue が含まれない
  run bash -c "python3 '$CL' facts | head -1 | python3 -c '
import json, sys
d = json.loads(sys.stdin.read())
expected = {\"request_id\", \"timestamp\", \"session_id\", \"is_sidechain\", \"repo_id\",
            \"branch\", \"model\", \"input_tokens\", \"output_tokens\",
            \"cache_write_5m_tokens\", \"cache_write_1h_tokens\", \"cache_read_tokens\",
            \"issues\", \"post_marker\"}
got = set(d)
assert got == expected, sorted(got ^ expected)
print(\"ok\")
'"
  [ "$status" -eq 0 ]
  [[ "$output" == *ok* ]]

  # 帰属先を名乗るフィールドがどこにも無い
  run bash -c "python3 '$CL' facts | grep -cE 'attributed|帰属'"
  [ "$output" = "0" ]
}

@test "facts: touched issue numbers and the post marker are facts of the line" {  # その行が触った issue 番号は事実として残るが、区間の帰属とは別物である
  run fact_of req-003
  [ "$status" -eq 0 ]
  [[ "$output" == *'"issues": ['*'148'*']'* ]]
  [[ "$output" == *'"post_marker": "gh issue comment"'* ]]

  # 投稿していない行は境界の印を持たない
  run fact_of req-001
  [ "$status" -eq 0 ]
  [[ "$output" == *'"post_marker": null'* ]]
  [[ "$output" == *'"issues": []'* ]]
}

@test "facts: a requestId seen in two files is counted once" {  # 同一 requestId が複数ファイルにあっても 1 回しか集計されない
  # fixture は sample-a/session.jsonl と sample-b/duplicate.jsonl に req-001 を重複して持つ
  run bash -c "grep -rho '\"requestId\": \"req-001\"' '$CONFIG_DIR/projects' | wc -l | tr -d ' '"
  [ "$output" = "2" ]

  run bash -c "python3 '$CL' facts | grep -c '\"req-001\"'"
  [ "$output" = "1" ]

  run python3 "$CL" branch oratta/sample-feature
  [ "$status" -eq 0 ]
  [[ "$output" == *'$5.80'* ]]   # 二重計上なら $6.80
}

@test "facts: legacy cache_creation_input_tokens is read as a 5m cache write" {  # cache_creation が無く cache_creation_input_tokens だけがある行はキャッシュ書込 5m として読まれる
  run fact_of req-006
  [ "$status" -eq 0 ]
  [[ "$output" == *'"cache_write_5m_tokens": 400000'* ]]
  [[ "$output" == *'"cache_write_1h_tokens": 0'* ]]
}

@test "facts: an itemised cache_creation splits into 5m and 1h" {  # キャッシュ書込の内訳がある行は 5m と 1h に分かれて読まれる
  run fact_of req-007
  [ "$status" -eq 0 ]
  [[ "$output" == *'"cache_write_1h_tokens": 100000'* ]]
  [[ "$output" == *'"cache_write_5m_tokens": 0'* ]]
}

@test "facts: non-assistant lines yield no facts" {  # assistant 以外の行は事実にならない
  run bash -c "python3 '$CL' facts | wc -l | tr -d ' '"
  [ "$output" = "13" ]   # fixture の assistant 行 13 件（user 行と重複行を除く）
}

@test "facts: the log root comes from CLAUDE_CONFIG_DIR with no hardcoded path" {  # ログのルートは CLAUDE_CONFIG_DIR から解決され、リポジトリ内に固定パスが無い
  # 実装とコマンド定義に、利用者のホームを焼き込んだ絶対パスが無い
  run grep -rnE '/Users/[a-z]|/home/[a-z]' "$PLUGIN_DIR/scripts" "$PLUGIN_DIR/commands"
  [ "$status" -ne 0 ]
  # ~/.claude を直書きせず CLAUDE_CONFIG_DIR を読む
  run grep -rn 'CLAUDE_CONFIG_DIR' "$PLUGIN_DIR/scripts"
  [ "$status" -eq 0 ]

  # 設定ディレクトリを移した環境ではその配下の projects が読まれる
  mv "$CONFIG_DIR" "$BATS_TEST_TMPDIR/elsewhere"
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/elsewhere"
  run bash -c "python3 '$CL' facts | wc -l | tr -d ' '"
  [ "$output" = "13" ]
}
