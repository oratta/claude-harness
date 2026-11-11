# Proposal

## Why

「実行役（spec-write・implement）を最上位の格にしない」という上限は、Claude の Agent 呼び出しでは `agent-model-guard.sh` が `fable` の文字列で止めているが、Codex の実行役には強制が無い。#424 では本体が implement を最上位の astra に差し替え、1 回で約 376 万トークンを使って Codex の週次枠を使い切った。#614 で格と対応表（`model-tier-map.json`）が入ったので、上限もその表に置き、Claude と Codex の強制層が同じ値を読むようにする。

## What Changes

- `model-tier-map.json` に役ごとの上限の格 `role_caps` を足す（初期値は spec-write・implement とも `上位`）。上限を持たない役は上限なし
- `codex-develop.py request` が、profile 形式・自動選択では適用後の格（`executed_tier`）が役の上限を超えたら、旧形式 `--account --model` では指定された model を対応表で格に戻して上限を超えたら、依頼ファイルを作らずに拒否する
- **BREAKING（要件の変更）** 旧形式は「格の規則・対応表を通らない」から、上限を持つ役に限って対応表で上限を確かめる形に変わる。上限を持つ役で対応表が読めなければ旧形式も止まる
- `agent-model-guard.sh` が、`dev-workflow:worker`（spec-write・implement）と `dev-workflow:gate-runner`（implement）の `model` を対応表で格に戻し、上限を超えたら拒否する。表が読めないときは今の Fable 判定に戻る
- model 名から格を引く規則と拒否の文面を、両方の強制層が同じ小さなモジュールから使う。拒否の文面には役・要求された格・その役の上限の格が入る
- テストで、表の上限を 1 段下げた一時コピーを両方に渡すと、両方の判定が同時に変わることを確かめる

範囲外: 本体が昇格で実装役を差し替えない規則の文言（#424）、`tier_cap` を付けた役の再開判定（PR #1621 のレビュー指摘）。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `model-tier-resolution`: 対応表に役の上限を足し、`request` が上限を超える格の依頼を拒否する。旧形式も上限を持つ役では上限を確かめる
- `dev-workflow-execution-strategy`: `agent-model-guard.sh` が対応表の役の上限で実行役の種別を判定する。判定の入力に同梱の対応表が加わる

## Impact

- `plugins/dev-workflow/references/model-tier-map.json`（`role_caps` を足す）
- `plugins/dev-workflow/scripts/codex-develop.py`（`load_tier_map`・`build_request`）
- `plugins/dev-workflow/scripts/agent-model-guard.sh`
- `plugins/dev-workflow/scripts/tier_caps.py`（新規。両方が読む）
- `plugins/dev-workflow/references/model-tiers.md`（強制層の説明）
- テスト: `plugins/dev-workflow/tests/agent-model-guard.bats`、`plugins/dev-workflow/tests/test_codex_develop.py`
