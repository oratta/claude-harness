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
  [[ "$output" == *ok* ]] || return 1

  # 帰属先を名乗るフィールドがどこにも無い
  run bash -c "python3 '$CL' facts | grep -cE 'attributed|帰属'"
  [ "$output" = "0" ]
}

@test "facts: touched issue numbers and the post marker are facts of the line" {  # その行が触った issue 番号は事実として残るが、区間の帰属とは別物である
  run fact_of req-003
  [ "$status" -eq 0 ]
  [[ "$output" == *'"issues": ['*'148'*']'* ]] || return 1
  [[ "$output" == *'"post_marker": "gh issue comment"'* ]] || return 1

  # 投稿していない行は境界の印を持たない
  run fact_of req-001
  [ "$status" -eq 0 ]
  [[ "$output" == *'"post_marker": null'* ]] || return 1
  [[ "$output" == *'"issues": []'* ]] || return 1
}

@test "facts: a requestId seen in two files is counted once" {  # 同一 requestId が複数ファイルにあっても 1 回しか集計されない
  # fixture は sample-a/session.jsonl と sample-b/duplicate.jsonl に req-001 を重複して持つ
  run bash -c "grep -rho '\"requestId\": \"req-001\"' '$CONFIG_DIR/projects' | wc -l | tr -d ' '"
  [ "$output" = "2" ]

  run bash -c "python3 '$CL' facts | grep -c '\"req-001\"'"
  [ "$output" = "1" ]

  run python3 "$CL" branch oratta/sample-feature
  [ "$status" -eq 0 ]
  [[ "$output" == *'$5.80'* ]] || return 1   # 二重計上なら $6.80
}

@test "facts: legacy cache_creation_input_tokens is read as a 5m cache write" {  # cache_creation が無く cache_creation_input_tokens だけがある行はキャッシュ書込 5m として読まれる
  run fact_of req-006
  [ "$status" -eq 0 ]
  [[ "$output" == *'"cache_write_5m_tokens": 400000'* ]] || return 1
  [[ "$output" == *'"cache_write_1h_tokens": 0'* ]] || return 1
}

@test "facts: an itemised cache_creation splits into 5m and 1h" {  # キャッシュ書込の内訳がある行は 5m と 1h に分かれて読まれる
  run fact_of req-007
  [ "$status" -eq 0 ]
  [[ "$output" == *'"cache_write_1h_tokens": 100000'* ]] || return 1
  [[ "$output" == *'"cache_write_5m_tokens": 0'* ]] || return 1
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

@test "facts: issue numbers come only from an executed Bash command" {  # issue 番号は実行された Bash の command からだけ拾い、他ツールの入力に現れた文字列は帰属させない
  {
    cl_row_tool S9 req-agent  2026-09-11T00:00:00.000Z main "$REPO_A" 0 Agent \
      '{"description":"x","prompt":"Read with gh issue view 999"}'
    cl_row_tool S9 req-edit   2026-09-11T00:00:01.000Z main "$REPO_A" 0 Edit \
      '{"file_path":"/tmp/x","old_string":"a","new_string":"gh issue comment 998"}'
    cl_row_tool S9 req-write  2026-09-11T00:00:02.000Z main "$REPO_A" 0 Write \
      '{"file_path":"/tmp/x","content":"gh issue edit 997"}'
    cl_row_tool S9 req-send   2026-09-11T00:00:03.000Z main "$REPO_A" 0 SendMessage \
      '{"to":"w","message":"gh issue close 996"}'
    cl_row     S9 req-realgh 2026-09-11T00:00:04.000Z main "$REPO_A" 0 "gh issue view 888"
  } | cl_write_log tooltypes

  # 実行していない文字列は 4 種とも帰属しない
  for rid in req-agent req-edit req-write req-send; do
    run fact_of "$rid"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"issues": []'* ]] || return 1
  done

  # 実行された Bash の command からは拾う
  run fact_of req-realgh
  [ "$status" -eq 0 ]
  [[ "$output" == *'"issues": ['*'888'*']'* ]] || return 1

  # 区間の帰属先も 888 だけになる（誤マッチが 1 つでも残れば別の番号に寄る）
  run bash -c "python3 '$CL' intervals --json | python3 -c '
import json, sys
rows = json.load(sys.stdin)[\"intervals\"]
print(sorted({r[\"issue\"] for r in rows if \"req-agent\" in r[\"request_ids\"] or \"req-realgh\" in r[\"request_ids\"]}, key=str))
'"
  [ "$status" -eq 0 ]
  [ "$output" = "['888']" ]
}

@test "facts: a structurally broken line is skipped and counted, not fatal" {  # 構造不正な 1 行で集計が落ちず、捨てた件数が出力に出る
  {
    cl_row S8 req-ok1 2026-09-11T01:00:00.000Z cost-broken "$REPO_A" 1000000
    printf '%s\n' '{"type": "assistant", "requestId": "bad-1", "gitBranch": "cost-broken", "message": {"usage": "broken"}}'
    printf '%s\n' '{"type": "assistant", "requestId": "bad-2", "gitBranch": "cost-broken", "message": [1, 2, 3]}'
    printf '%s\n' '["assistant", "cost-broken", "not-an-object"]'
    cl_row S8 req-ok2 2026-09-11T01:00:01.000Z cost-broken "$REPO_A" 1000000
  } | cl_write_log broken

  # 壊れた行があっても集計は完走し、健全な行は残る
  run bash -c "python3 '$CL' facts 2>/dev/null | grep -c 'req-ok'"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]

  run python3 "$CL" branch cost-broken
  [ "$status" -eq 0 ]
  [[ "$output" == *'$2.00'* ]] || return 1
  # 黙って捨てず件数を出す
  [[ "$output" == *"読み取れなかった行: 3 件"* ]] || return 1

  run python3 "$CL" report
  [ "$status" -eq 0 ]
  [[ "$output" == *"読み取れなかった行: 3 件"* ]] || return 1

  # 監査用の JSON にも件数が載る
  run bash -c "python3 '$CL' report --json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)[\"unreadable_lines\"])'"
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]
}
