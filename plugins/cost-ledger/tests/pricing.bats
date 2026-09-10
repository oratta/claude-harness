#!/usr/bin/env bats
#
# spec: cost-ledger-pricing
#
# 料金表と換算レートが 1 ファイルにしかないこと、単価が最長一致の前方一致で引かれること、
# 未知モデルが黙って 0 円にならないこと、円換算が固定レートで環境変数から上書きできることを固定する。

load helper

setup() {
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
  [[ "$output" == *'$5.00'* ]]

  python3 - "$PRICING" "$BATS_TEST_TMPDIR/pricing.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
d["models"]["claude-opus-5"]["input"] = 50
json.dump(d, open(sys.argv[2], "w", encoding="utf-8"))
PY
  run python3 "$CL" --pricing "$BATS_TEST_TMPDIR/pricing.json" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *'$50.00'* ]]
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
  [[ "$output" == *'$10.00'* ]]
  [[ "$output" != *'$1.00'* ]]
}

@test "pricing: a dated model name resolves to the undated key" {  # 日付付きのモデル名が日付なしの鍵の単価で引かれる
  cl_mini_log mini claude-haiku-4-5-20251001 '{"input_tokens":1000000,"output_tokens":0,"cache_read_input_tokens":0}'
  run python3 "$CL" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *'$1.00'* ]]
  [[ "$output" != *"未知モデル"* ]]
}

@test "pricing: cache read is cheaper than the same tokens at the input rate" {  # キャッシュ読出は同じトークン数を入力単価で計算するより安くなる
  cl_mini_log mini claude-opus-5 '{"input_tokens":0,"output_tokens":0,"cache_read_input_tokens":1000000}'
  run python3 "$CL" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *'$0.50'* ]]   # 入力単価なら $5.00
}

# --- 未知モデル ---

@test "pricing: an unknown model is reported by name and line count, not silently zero" {  # どの鍵にも前方一致しないモデルが 0 円で黙って落ちず、名前と行数が出力に出る
  cl_mini_log mini claude-nope-9 '{"input_tokens":1000000,"output_tokens":1000000,"cache_read_input_tokens":0}'
  run python3 "$CL" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *"未知モデル"* ]]
  [[ "$output" == *"claude-nope-9"* ]]
  [[ "$output" == *"1 行"* ]]
}

# --- 円換算 ---

@test "pricing: yen uses the fixed rate and the rate is printed" {  # 円換算は固定レートで、出力にレートが添えられる
  cl_mini_log mini claude-opus-5 '{"input_tokens":1000000,"output_tokens":0,"cache_read_input_tokens":0}'
  run python3 "$CL" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *'¥750 @150'* ]]
}

@test "pricing: COST_LEDGER_USD_JPY overrides the rate and the printed rate follows" {  # 換算レートは環境変数 COST_LEDGER_USD_JPY で上書きでき、添えられるレートも変わる
  cl_mini_log mini claude-opus-5 '{"input_tokens":1000000,"output_tokens":0,"cache_read_input_tokens":0}'
  export COST_LEDGER_USD_JPY=200
  run python3 "$CL" branch mini
  [ "$status" -eq 0 ]
  [[ "$output" == *'¥1,000 @200'* ]]
}

@test "pricing: the override env var name is recorded in pricing.json" {  # 環境変数の名前が pricing.json に書かれている（後続の台帳とゲート連携が同じ名前を読む）
  run grep -F 'COST_LEDGER_USD_JPY' "$PRICING"
  [ "$status" -eq 0 ]
}
