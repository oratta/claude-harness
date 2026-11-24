# Proposal

## Why

しきい値がモデルを問わない定数で、モデルが変わっても実測の前提との違いに気付けない。#1800 の change 1 として、#1799 の結論を変えずに、根拠を持つモデル別の表と共通の解決処理、再検証への入口を用意する。

## What Changes

- 固定モデル ID ごとに 150,000 / 220,000 / 30,000,000 / 60,000,000 と、各値の測定対象モデル・判断日・実測の出典を持つ表を追加する。
- 表を引く共通処理を追加する。未登録・モデル不明は安全側の共通既定値へ倒し、出力に理由を残す。測定対象と異なるモデルには再検証を知らせる。明示の数値環境変数を既定値より優先する。
- #1799 の集計を再実行する段取りを 1 か所にまとめ、値の変更ごとに同じ手順の結果を残す契約とする。decision-criteria.md から表と手順へリンクする。
- 単独で呼べる共通処理のテストを追加する。既存の計測・停止スクリプトへの配線は後続 change とする。

## Capabilities

### New Capabilities

- `dev-workflow-token-thresholds`: 根拠付きモデル別しきい値の解決、フォールバック・再検証の通知、根拠を更新する再検証手順。

### Modified Capabilities

なし。既存の `dev-workflow-execution-strategy` と `dev-workflow-pr-token-budget` の計測・停止・権限はこの change では変えない。

## Impact

実装予定ファイルは次の 5 個に限定する（この仕様 artifact 一式と、後工程の archive・変更記録は別）。

1. `plugins/dev-workflow/references/token-thresholds.json`（新規の表）
2. `plugins/dev-workflow/scripts/token_thresholds.py`（新規の共通処理・CLI）
3. `plugins/dev-workflow/tests/test_token_thresholds.py`（新規の unittest）
4. `plugins/dev-workflow/skills/develop/references/token-thresholds.md`（新規の再検証手順）
5. `plugins/dev-workflow/skills/develop/references/decision-criteria.md`（入口の追記）

Python 3 標準ライブラリだけを使う。`subagent-context.sh`・`context-tripwire.sh`・`pr-token-budget.sh` とそれらのテスト、`pr-token-budget.md` は変更しない。#1802 の粒度計算や集計スクリプトの追加は対象外。後続は change 1 のマージ後に開始する change 2（文脈上限の配線）と change 3（累計上限の配線）で、両者は互いに独立する。

判断の正本: [分割判断](https://github.com/oratta/claude-harness/issues/1800#issuecomment-7120396689)、[採用する実測結論](https://github.com/oratta/claude-harness/issues/1799#issuecomment-7120074012)、[環境変数優先の参照](https://github.com/genetta-inc/flatmate/issues/2334)。仕様化判断は再投稿しない。
