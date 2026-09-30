#!/usr/bin/env bats
#
# spec: cost-ledger-attribution
#
# 合成 fixture が PII と秘密を含まないこと、および 5 種類の検出対象（sidechain・重複
# requestId・削除済み cwd・複数 issue への投稿・キャッシュ書込の内訳が無い古い行）を
# 実際に含んでいることを固定する。前例: plugins/experience-to-skill/tests/sanitize.bats

load helper

setup() {
  cl_setup
  FIXTURES="$PLUGIN_DIR/tests/fixtures/projects"
}

@test "fixture: contains no secrets and no PII" {  # fixture に API キー・トークン・メールアドレス等の秘密と PII が含まれない
  run grep -rnE 'sk-ant-|sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,}|github_pat_|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' "$FIXTURES"
  [ "$status" -ne 0 ]
}

@test "fixture: contains no real home directory paths" {  # fixture に利用者のホームディレクトリの実パスが焼き込まれていない
  run grep -rnE '/Users/[a-z]|/home/[a-z]' "$FIXTURES"
  [ "$status" -ne 0 ]
}

@test "fixture: every line parses as JSON" {  # fixture の全行が JSON として読める
  run python3 -c '
import json, pathlib, sys
n = 0
for p in pathlib.Path(sys.argv[1]).rglob("*.jsonl"):
    for i, line in enumerate(p.open(encoding="utf-8"), 1):
        if line.strip():
            json.loads(line)
            n += 1
print(n)
' "$FIXTURES"
  [ "$status" -eq 0 ]
  [ "$output" -ge 14 ]
}

@test "fixture: carries all five detection targets" {  # fixture が 5 種類の検出対象をすべて含む
  run grep -rl '"isSidechain": true' "$FIXTURES"
  [ "$status" -eq 0 ]
  # 同じ requestId が 2 ファイルに現れる
  run bash -c "grep -rho '\"requestId\": \"[^\"]*\"' '$FIXTURES' | sort | uniq -d"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  # 削除済み cwd
  run grep -rl 'cost-ledger-deleted-cwd-does-not-exist' "$FIXTURES"
  [ "$status" -eq 0 ]
  # 1 セッションから複数 issue への投稿
  run grep -rl 'gh issue comment 148' "$FIXTURES"
  [ "$status" -eq 0 ]
  run grep -rl 'gh issue comment 213' "$FIXTURES"
  [ "$status" -eq 0 ]
  # キャッシュ書込の内訳が無い古い形
  run grep -rl 'cache_creation_input_tokens' "$FIXTURES"
  [ "$status" -eq 0 ]
}
