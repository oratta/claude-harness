# Proposal

## Why

親の `wait --resolve` が、主と対話中の子の作業報告を会話ログから止まりと推測し、150,000 トークン超を理由に端末を閉じた。#1744（エピック #1732 の子）は、#1670 で実装済みの `turn_input` / `turn_state` を親が読み、主の対話に介入しないようにする。

## What Changes

- `wait --watch-stopped` の検知を、有効な入力・終了状態の組だけに切り替える。`sender` が `parent` / `startup` かつ `value` が `主の返事待ち` の子だけを対象にする。
- `owner` のターン、`作業報告` / `完了`、終了状態の欠落・null・型不正・世代やセッション不一致は、自動判断・返事・端末終了・再起動の対象にしない。長い待ちの再判断と送信直前にも同じ条件を適用する。
- **BREAKING**: フックの無い古い子は、停止の印や会話ログが残っていても自動検知しない。会話ログのアイドル時間と背景タスクから停止を推測する方式を廃止する。
- 有効な停止に対する既存の判断・通知・返事・再起動条件と、発言本文を公開コメントに載せない契約を維持する。依存待ちのマーカーも、状態の記録による対象判定を満たした後でだけ扱う。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: 親の停止検知、自動解決・再判断・再起動への入口、停止の重複処理と再開の読み取りを状態記録方式にする。`dev-workflow-epic-state` の既存の有効な終了状態の契約を利用し、その生成・型の契約は変更しない。

## Impact

実装・テストの編集対象は次の 4 ファイルに限定する。

- `plugins/dev-workflow/scripts/epic-dispatch.sh`
- `plugins/dev-workflow/tests/epic-dispatch.bats`
- `plugins/dev-workflow/tests/epic-stop-from-log-scenario.bats`
- `plugins/dev-workflow/tests/epic-child-state.bats`

`epic-stop.md` と `reply-after-idle.md` の手順書変更は #1760 に分離済み。主が席を離れたときの時間による通知は別の子 issue の範囲。新しい依存パッケージや子側フックの変更は不要。

## 分割判定（Step C）

単一 change。更新後の #1744 の有効な受け入れ条件 4 件は「親が状態記録を根拠に介入する」という一つの機能領域に閉じる。設計判断は検知の正本を会話ログから状態記録へ切り替える一点で、同時更新が必要な回帰テストを含めて一つの PR で完結する。独立した手順書変更は既に #1760 に分離されている。
