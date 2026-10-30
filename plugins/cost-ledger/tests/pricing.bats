#!/usr/bin/env bats
#
# spec: cost-ledger-pricing
#
# 料金表と換算レートが 1 ファイルにしかないこと、単価が最長一致の前方一致で引かれること、
# 未知モデルが黙って 0 円にならないこと、円換算が固定レートで環境変数から上書きできることを固定する。

load helper

setup() {
  export LC_ALL=C.UTF-8
  cl_setup
}

# --- 単価の置き場所 ---

@test "pricing: rates live only in pricing.json, never in the implementation" {  # 料金表と換算レートは pricing.json にしかなく、実装は自前の単価を持たない
  [ -f "$PRICING" ]
  # 実装側（scripts/ と commands/）にモデル名つきの単価や換算レートの定義が無いこと
  run grep -rnE '"claude-(fable|opus|sonnet|haiku)[^"]*"[[:space:]]*:[[:space:]]*[0-9(\{]' \
      "$PLUGIN_DIR/scripts" "$PLUGIN_DIR/commands"
  [ "$status" -ne 0 ]
  run grep -rnE '(usd_jpy_rate|レート)[[:space:]]*=[[:space:]]*[0-9]+' "$PLUGIN_DIR/scripts"
  [ "$status" -ne 0 ]
}

@test "pricing: editing a rate changes the reported cost" {  # 単価を書き換えると /cost の出力がその単価で計算し直される
  cl_mini_log mini claude-opus-5 '{"input_tokens":1000000,"output_tokens":0,"cache_read_input_tokens":0}'
  run python3 "$CL" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *'$5.00'* ]] || return 1

  python3 - "$PRICING" "$BATS_TEST_TMPDIR/pricing.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
d["models"]["claude-opus-5"]["input"] = 50
json.dump(d, open(sys.argv[2], "w", encoding="utf-8"))
PY
  run python3 "$CL" --pricing "$BATS_TEST_TMPDIR/pricing.json" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *'$50.00'* ]] || return 1
}

# --- 引き方 ---

@test "pricing: longest prefix wins regardless of table order" {  # 単価は最長一致の前方一致で引かれ、表の並び順に依存しない
  # 短い鍵（claude-fable-5）を先に置いた表を作る。順次走査ならこちらが当たってしまう。
  python3 - "$BATS_TEST_TMPDIR/pricing.json" <<'PY'
import json, sys
d = {"usd_jpy_rate": 150, "usd_jpy_rate_env": "COST_LEDGER_USD_JPY", "models": {}}
d["models"]["claude-fable-5"] = {"input": 1, "output": 1, "cache_write_5m": 1,
                                 "cache_write_1h": 1, "cache_read": 1}
d["models"]["claude-fable-5-1"] = {"input": 10, "output": 10, "cache_write_5m": 10,
                                   "cache_write_1h": 10, "cache_read": 10}
json.dump(d, open(sys.argv[1], "w", encoding="utf-8"))
PY
  cl_mini_log mini claude-fable-5-1 '{"input_tokens":1000000,"output_tokens":0,"cache_read_input_tokens":0}'
  run python3 "$CL" --pricing "$BATS_TEST_TMPDIR/pricing.json" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *'$10.00'* ]] || return 1
  [[ "$output" != *'$1.00'* ]] || return 1
}

@test "pricing: claude-opus-5-5 resolves to its own row, not claude-opus-5" {  # claude-opus-5-5 は claude-opus-5 の前方一致に食われず、自分の行の単価で引かれる
  cl_mini_log mini claude-opus-5-5 '{"input_tokens":1000000,"output_tokens":0,"cache_read_input_tokens":0}'
  run python3 "$CL" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *'$4.00'* ]] || return 1   # claude-opus-5 の単価に食われると $5.00 になる
  [[ "$output" != *'$5.00'* ]] || return 1
}

@test "pricing: claude-opus-5-5 prices output and cache_read tokens from its own row too" {  # claude-opus-5-5 の output / cache_read 単価も自分の行で引かれる（input 4 + output 20 + cache_read 0.2）
  cl_mini_log mini claude-opus-5-5 '{"input_tokens":1000000,"output_tokens":1000000,"cache_read_input_tokens":1000000}'
  run python3 "$CL" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *'$24.20'* ]] || return 1
  [[ "$output" != *'$30.50'* ]] || return 1   # claude-opus-5 の単価に食われると $30.50 になる
}

@test "pricing: claude-sonnet-5-5 resolves to its own row, not claude-sonnet-5" {  # claude-sonnet-5-5 は claude-sonnet-5 に食われず、自分の行の単価（input 2 + output 10 + cache_read 0.1）で引かれる
  cl_mini_log mini claude-sonnet-5-5 '{"input_tokens":1000000,"output_tokens":1000000,"cache_read_input_tokens":1000000}'
  run python3 "$CL" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *'$12.10'* ]] || return 1
  [[ "$output" != *'$12.20'* ]] || return 1   # claude-sonnet-5 の単価に食われると $12.20 になる
  [[ "$output" != *"未知モデル"* ]] || return 1
}

@test "pricing: claude-haiku-5-5 has its own row, not unknown and not claude-haiku-4-5" {  # claude-haiku-5-5 は未知扱いにならず、自分の行の単価（input 0.1 + output 0.5 + cache_read 0.01）で引かれる
  # プロンプト長（入力 + キャッシュ読み）を閾値 100,000 以下にして、閾値以下の単価の行を確かめる
  cl_mini_log mini claude-haiku-5-5 '{"input_tokens":40000,"output_tokens":1000000,"cache_read_input_tokens":40000}'
  run python3 "$CL" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *'$0.50'* ]] || return 1   # 0.004 + 0.5 + 0.0004 = 0.5044
  [[ "$output" != *"未知モデル"* ]] || return 1
}

@test "pricing: a dated model name resolves to the undated key" {  # 日付付きのモデル名が日付なしの鍵の単価で引かれる
  cl_mini_log mini claude-haiku-4-5-20251001 '{"input_tokens":1000000,"output_tokens":0,"cache_read_input_tokens":0}'
  run python3 "$CL" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *'$1.00'* ]] || return 1
  [[ "$output" != *"未知モデル"* ]] || return 1
}

@test "pricing: cache read is cheaper than the same tokens at the input rate" {  # キャッシュ読出は同じトークン数を入力単価で計算するより安くなる
  cl_mini_log mini claude-opus-5 '{"input_tokens":0,"output_tokens":0,"cache_read_input_tokens":1000000}'
  run python3 "$CL" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *'$0.50'* ]] || return 1   # 入力単価なら $5.00
}

@test "pricing: all five token kinds add up to the hand-computed cost" {  # トークン 5 種すべてが 0 でない行の金額が、料金表の単価から手計算した値と一致する
  # 5 種それぞれが $0.15 以上になる数にして、どれか 1 種を落とせば合計がずれるようにする
  cl_mini_log mini claude-sonnet-4-6 '{"input_tokens":100000,"output_tokens":20000,"cache_creation_input_tokens":90000,"cache_creation":{"ephemeral_5m_input_tokens":40000,"ephemeral_1h_input_tokens":50000},"cache_read_input_tokens":1000000}'
  expected="$(python3 - "$PRICING" <<'PY'
import json, sys
p = json.load(open(sys.argv[1], encoding="utf-8"))["models"]["claude-sonnet-4-6"]
tokens = {"input": 100000, "output": 20000, "cache_write_5m": 40000,
          "cache_write_1h": 50000, "cache_read": 1000000}
print("$%.2f" % (sum(n * p[k] for k, n in tokens.items()) / 1e6))
PY
)"
  run python3 "$CL" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *"$expected"* ]] || { echo "want $expected in: $output"; return 1; }
}

# --- 未知モデル ---

@test "pricing: an unknown model is reported by name and line count, not silently zero" {  # どの鍵にも前方一致しないモデルが 0 円で黙って落ちず、名前と行数が出力に出る
  cl_mini_log mini claude-nope-9 '{"input_tokens":1000000,"output_tokens":1000000,"cache_read_input_tokens":0}'
  run python3 "$CL" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *"未知モデル"* ]] || return 1
  [[ "$output" == *"claude-nope-9"* ]] || return 1
  [[ "$output" == *"1 行"* ]] || return 1
}

# --- 円換算 ---

@test "pricing: yen uses the fixed rate and the rate is printed" {  # 円換算は固定レートで、出力にレートが添えられる
  cl_mini_log mini claude-opus-5 '{"input_tokens":1000000,"output_tokens":0,"cache_read_input_tokens":0}'
  run python3 "$CL" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *'¥750 @150'* ]] || return 1
}

@test "pricing: COST_LEDGER_USD_JPY overrides the rate and the printed rate follows" {  # 換算レートは環境変数 COST_LEDGER_USD_JPY で上書きでき、添えられるレートも変わる
  cl_mini_log mini claude-opus-5 '{"input_tokens":1000000,"output_tokens":0,"cache_read_input_tokens":0}'
  export COST_LEDGER_USD_JPY=200
  run python3 "$CL" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *'¥1,000 @200'* ]] || return 1
}

@test "pricing: the override env var name is recorded in pricing.json" {  # 環境変数の名前が pricing.json に書かれている（後続の台帳とゲート連携が同じ名前を読む）
  run grep -F 'COST_LEDGER_USD_JPY' "$PRICING"
  [ "$status" -eq 0 ]
}

# --- プロンプト長で変わる単価（閾値超の単価。#1103） ---

# 応答 1 件（先頭の行 + 確定行）の合成ログ。haiku-5-5 の閾値は 100,000。
# $1=入力 $2=キャッシュ書込 5m $3=キャッシュ読出 $4=確定行の出力
tier_log() {
  mkdir -p "$CONFIG_DIR/projects/tier"
  python3 - "$CONFIG_DIR/projects/tier/tier.jsonl" "${5:-claude-haiku-5-5}" "$@" <<'PY'
import json, sys
path, model, i, w, r, out = sys.argv[1], sys.argv[2], *map(int, sys.argv[3:7])
def row(uuid, ts, output, stop):
    usage = {"input_tokens": i, "output_tokens": output, "cache_read_input_tokens": r,
             "cache_creation": {"ephemeral_5m_input_tokens": w, "ephemeral_1h_input_tokens": 0}}
    msg = {"model": model, "role": "assistant", "content": [{"type": "text", "text": "x"}],
           "stop_reason": stop, "usage": usage}
    return json.dumps({"type": "assistant", "requestId": "r1", "uuid": uuid, "timestamp": ts,
                       "sessionId": "T1", "isSidechain": False, "cwd": "/nonexistent/t",
                       "gitBranch": "tier", "message": msg}, separators=(",", ":"))
lines = [row("u1", "2026-09-01T00:00:01.000Z", 8, None),
         row("u2", "2026-09-01T00:00:02.000Z", out, "end_turn")]
open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
PY
}

@test "pricing tier: a prompt of exactly the threshold uses the lower rates for every token" {  # プロンプト長がちょうど 100,000 なら全トークンが閾値以下の単価（0.01*0.1 + 0.5）
  cl_mini_log mini claude-haiku-5-5 '{"input_tokens":0,"output_tokens":1000000,"cache_read_input_tokens":100000}'
  run python3 "$CL" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *'$0.50'* ]] || return 1
}

@test "pricing tier: a prompt one token over the threshold prices every token at the higher rates" {  # 100,001 なら出力を含む全トークンが閾値超の単価（0.05*0.100001 + 2.5）
  cl_mini_log mini claude-haiku-5-5 '{"input_tokens":0,"output_tokens":1000000,"cache_read_input_tokens":100001}'
  run python3 "$CL" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *'$2.51'* ]] || return 1
  [[ "$output" != *'$0.50'* ]] || return 1
}

@test "pricing tier: input and cache writes count toward the prompt length" {  # 入力 + キャッシュ書込 5m + キャッシュ書込 1h + 読出の合計で判定する
  cl_mini_log mini claude-haiku-5-5 '{"input_tokens":1,"output_tokens":0,"cache_read_input_tokens":0,"cache_creation":{"ephemeral_5m_input_tokens":50000,"ephemeral_1h_input_tokens":49999}}'
  run python3 "$CL" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *'$0.02'* ]] || return 1   # 合計 100,000 は閾値以下（0.016）
  cl_mini_log mini claude-haiku-5-5 '{"input_tokens":2,"output_tokens":0,"cache_read_input_tokens":0,"cache_creation":{"ephemeral_5m_input_tokens":50000,"ephemeral_1h_input_tokens":49999}}'
  run python3 "$CL" branch mini
  [[ "$output" == *'$0.08'* ]] || return 1    # 合計 100,001 は閾値超（0.081）
}

@test "pricing tier: a model without a long-prompt rate is priced as before however long the prompt" {  # 閾値を持たないモデルは、プロンプトが非常に長くても従来の単価
  cl_mini_log mini claude-opus-5 '{"input_tokens":0,"output_tokens":0,"cache_read_input_tokens":5000000}'
  run python3 "$CL" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *'$2.50'* ]] || return 1   # 5,000,000 * 0.5 / 1e6
}

@test "pricing tier: the supplement of a long prompt carries prompt_tokens and zero tokens" {  # 補足の事実は prompt_tokens（200,001）を持ち、入力・キャッシュは 0、内訳の数には足されない
  tier_log 1 100000 100000 1000008
  run python3 - "$PLUGIN_DIR/scripts" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import cost_ledger as cl
import os, io
root = os.path.join(os.environ["CLAUDE_CONFIG_DIR"], "projects")
facts = []
for path in cl.log_files(root):
    with open(path, "rb") as fh:
        facts += list(cl.facts_from_lines((l.decode() for l in fh), path, cl.RepoResolver(), cl.SeenSet()))
sup = [f for f in facts if f.get("continuation")]
head = [f for f in facts if not f.get("continuation")]
assert len(sup) == 1 and len(head) == 1, facts
s = sup[0]
assert s["prompt_tokens"] == 200001, s
assert all(s[k] == 0 for k in ("input_tokens", "cache_write_5m_tokens", "cache_write_1h_tokens", "cache_read_tokens")), s
assert "prompt_tokens" not in head[0], head[0]
per = cl.summarise(facts, cl.Pricing.load(cl.DEFAULT_PRICING))["per_model"]["claude-haiku-5-5"]
assert per["input_tokens"] == 1 and per["cache_read_tokens"] == 100000, per
print("ok")
PY
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$output" = "ok" ]
}

@test "pricing tier: the supplement output is priced with the response's tier" {  # 補足の事実の出力（差分）も応答と同じ閾値超の単価で出る
  tier_log 1 100000 100000 1000008
  run python3 "$CL" branch tier
  [ "$status" -eq 0 ]
  [[ "$output" == *'$2.57'* ]] || return 1   # 低い単価なら $0.51
  [[ "$output" != *'$0.51'* ]] || return 1
}

@test "pricing tier: a supplement without prompt_tokens (older ledger row) is priced at the lower rates" {  # prompt_tokens の無い古い補足の事実は閾値以下の単価
  run python3 - "$PLUGIN_DIR/scripts" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import cost_ledger as cl
p = cl.Pricing.load(cl.DEFAULT_PRICING)
fact = {"model": "claude-haiku-5-5", "continuation": True, "input_tokens": 0, "output_tokens": 1000000,
        "cache_write_5m_tokens": 0, "cache_write_1h_tokens": 0, "cache_read_tokens": 0}
assert abs(p.cost(fact)[0] - 0.5) < 1e-9, p.cost(fact)
assert abs(p.cost(dict(fact, prompt_tokens=200001))[0] - 2.5) < 1e-9
print("ok")
PY
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  [ "$output" = "ok" ]
}

@test "pricing tier: reading through the ledger keeps prompt_tokens and gives the same cost" {  # ledger-sync を経ても prompt_tokens が残り、金額は直読みと同じ
  tier_log 1 100000 100000 1000008
  run python3 "$CL" branch tier
  direct="$output"
  export COST_LEDGER_PATH="$BATS_TEST_TMPDIR/ledger/cost-ledger.jsonl"
  run python3 "$CL" ledger-sync --quiet
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  grep -q '"prompt_tokens": 200001' "$COST_LEDGER_PATH"
  run python3 "$CL" branch tier
  [ "$status" -eq 0 ]
  [ "$output" = "$direct" ] || { echo "$direct"; echo "$output"; return 1; }
}

@test "pricing tier: a long-prompt rate with a missing or non-numeric field fails the load" {  # 閾値超の単価や閾値が欠けた・数でない料金表は読み込みで失敗する
  cl_mini_log mini claude-haiku-5-5 '{"input_tokens":1,"output_tokens":1,"cache_read_input_tokens":0}'
  for mutation in 'del d["models"]["claude-haiku-5-5"]["long_prompt"]["cache_read"]' \
                  'del d["models"]["claude-haiku-5-5"]["long_prompt"]["threshold"]' \
                  'd["models"]["claude-haiku-5-5"]["long_prompt"]["output"]="x"' \
                  'd["models"]["claude-haiku-5-5"]["long_prompt"]["threshold"]=True'; do
    python3 - "$PRICING" "$BATS_TEST_TMPDIR/bad.json" "$mutation" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
exec(sys.argv[3])
json.dump(d, open(sys.argv[2], "w", encoding="utf-8"))
PY
    run python3 "$CL" --pricing "$BATS_TEST_TMPDIR/bad.json" branch mini
    [ "$status" -ne 0 ] || { echo "accepted: $mutation"; return 1; }
  done
}

@test "pricing tier: editing the threshold and the higher rates in pricing.json changes the cost" {  # 閾値と閾値超の単価を書き換えると出力が変わる
  cl_mini_log mini claude-haiku-5-5 '{"input_tokens":0,"output_tokens":1000000,"cache_read_input_tokens":100001}'
  python3 - "$PRICING" "$BATS_TEST_TMPDIR/pricing.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
d["models"]["claude-haiku-5-5"]["long_prompt"]["threshold"] = 200000
json.dump(d, open(sys.argv[2], "w", encoding="utf-8"))
PY
  run python3 "$CL" --pricing "$BATS_TEST_TMPDIR/pricing.json" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *'$0.50'* ]] || return 1
}
