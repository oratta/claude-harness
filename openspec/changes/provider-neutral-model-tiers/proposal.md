# Proposal

## Why

今は呼び出し先を決めたあと、選ばれた先ごとに別の仕組みでモデルが決まる。Claude だけの既定では事前分類と残量モードが効くのに、自動選択の固定表では効かず、#605 では事前分類に当たる W が自動選択の経路で sonnet になった。経路を足すたびに規則を写すことになり、写し漏れがまた起きるので、格を決める場所を 1 つにする。

## What Changes

- 役・事前分類・設計判断・失敗・残量モードから格（最安・中位・上位・最上位）を 1 つ決める規則を `codex-develop.py request` に置く。提供元・構成・自動選択かどうかは入力にしない
- 格からモデル名への対応表 `plugins/dev-workflow/references/model-tier-map.json` を新設する。引く口として `codex-develop.py tier-model` を足す
- `request` に `--pre-class`、`--design-judgment`、`--failure`、`--unmanned` を足す。出力に格の欄を足し、残量モードの適用を本体の文章規則から `request` へ移す
- `usage_view.py` に残量モードの導出を足して `codex-develop.py` から呼ぶ。`session-tripwires.sh` と `agent-model-guard.sh` は触らない
- **BREAKING** `codex-role-profiles.json` を形式版 2 にする。entry は `{executor, account, effort, tier_cap(任意)}` で、`model` キーは拒否する。外部 profile-file の形式版 1 も拒否する
- `claude-default` を組み込み profile に足し、コード内の既定表を消す
- SKILL.md「モデル」節と `codex-develop.md` は規則の説明と `request` への参照にし、経路ごとのモデル名の書き分けをなくす
- 聖域パスだけではレビューを上げない側に文書を揃える（`pre-classification.md`、`decision-criteria.md`）
- `model-resolution-current.md` を削除し、#613 のテストを「構成を変えても格が変わらない」形に改める

範囲外: 失敗時の昇格の手順（#424）、実行役の上限の強制（#615）、再開前の上限確認（SKILL.md の本体の文章規則のまま）。

## Capabilities

### New Capabilities

- `model-tier-resolution`: develop の各役の格を提供元によらない規則で決め、対応表でモデル名に置き換える

### Modified Capabilities

- `codex-role-profiles`: profile の形式を形式版 2 にして `model` を除き、`claude-default` を足す。resolver が残量モードを反映する
- `manual-codex-develop`: Claude role は `request` が返した model で起動する。要求値と適用値の区別を出力の欄に移す
- `dev-workflow-develop`: 「モデル」節を格と `request` への参照にする。本体は `request` に入力を渡し、返った model を使う
- `dev-workflow-spec-review`: R1 の既定を「上位の格」と呼び直し、model の決定元を `request` にする

## Impact

- コード: `plugins/dev-workflow/scripts/codex-develop.py`、`plugins/dev-workflow/scripts/usage_view.py`
- データ: `plugins/dev-workflow/references/codex-role-profiles.json`、`plugins/dev-workflow/references/model-tier-map.json`（新規）
- 文書: `SKILL.md`、`pre-classification.md`、`decision-criteria.md`、`model-tiers.md`、`codex-develop.md`、`codex-develop-explicit.md`、`docs/codex-develop.md`
- 削除: `plugins/dev-workflow/references/model-resolution-current.md`
- テスト: `test_model_resolution_current.py`、`test_codex_develop.py`、`model-escalation-policy.bats`
- 利用者: 外部 profile-file を持つ人は形式版 2 への書き換えが要る。版の固定は旧形式 `--account --model` だけに残る
