# Proposal

## Why

change 1 で固定モデル ID と根拠を持つ共通解決処理を追加したが、文脈の計測と途中停止はまだ固定値を独自に選んでいる。計測対象自身のモデルに対応する値と診断を使い、未知モデルでも再検証の必要を見落とさないようにする。

## What Changes

- `subagent-context.sh` と `context-tripwire.sh` が、各々の既存の計測で採った assistant レコードの `message.model` を共通処理へ渡し、文脈上限・強制停止の値を取得する。親・別名から固定 ID を推測しない。
- fallback・再検証の診断を stderr に出し、再検証手順を実行中のプラグイン配下の絶対パスで案内する。stdout の JSON と既存の通知・拒否の形を保つ。
- `--cap` 最優先、関係する環境変数だけの解釈、CLI と hook の 0 の扱い、共通処理の失敗時の fail-open を明文化してテストする。
- `decision-criteria.md` の文脈上限・強制停止の未配線注記を接続済みの事実へ更新する。#1799 の値は変えない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-execution-strategy`: 再開前チェックと途中計測のしきい値を共通処理へ接続し、診断と失敗時の出力の契約を定める。
- `dev-workflow-token-thresholds`: 文脈計測の呼出元がモデル・上書き・診断を扱う契約を追加し、文書入口の配線状況を更新する。

## Impact

記録先は #1800（親 #1803）。[分割判定](https://github.com/oratta/claude-harness/issues/1800#issuecomment-7120396689)と[文書分担の補正](https://github.com/oratta/claude-harness/issues/1800#issuecomment-7121511137)の change 2。前提はマージ済み PR #1804（`model-threshold-foundation`）。実装で編集するファイルは次の 5 個だけ。

1. `plugins/dev-workflow/scripts/subagent-context.sh`
2. `plugins/dev-workflow/scripts/context-tripwire.sh`
3. `plugins/dev-workflow/tests/subagent-context.bats`
4. `plugins/dev-workflow/tests/context-tripwire.bats`
5. `plugins/dev-workflow/skills/develop/references/decision-criteria.md`

共通処理・JSON 表は変更せず import API を利用する。`pr-token-budget.sh`・そのテスト・`pr-token-budget.md`・利用手順 `token-thresholds.md` の未配線注記は change 3 の担当で、この change では編集しない。change 2 と 3 の間だけ利用手順の注記が古いままになる点は補正コメントの合意どおり。#1802 の集計・見積もり機能も対象外。OpenSpec artifact と後工程で同期・archive する仕様はこの実装予定 5 ファイルとは別の仕様記録である。
