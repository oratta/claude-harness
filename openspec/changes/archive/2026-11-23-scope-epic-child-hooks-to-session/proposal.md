# Proposal

## Why

子の worktree で主が別セッションや `claude -p` を起動すると、その入力が本来の子の `turn_input` を置き換え、子の状態が消え、本来の Stop がセッション不一致で捨てられる（https://github.com/oratta/claude-harness/issues/1756）。worktree による候補検索と実際の対象セッションの照合を区別し、親が読むターン記録を別セッションから保護する。

## What Changes

- 既存の `turn_input.session_id` と一致するセッションだけの通常入力・Stop を対象にする。異なる ID の通常入力では、世代・送り手・時刻・終了状態を含む記録全体を変えない。
- 初回登録と別 ID への切替は、記録の子・親・エピックのリポジトリと一致する既存 launcher の起動指示に限る。起動し直しでも世代を巻き戻さない。
- 未登録の旧記録に対する任意の通常入力や Stop は対象外にし、登録には一致する起動指示を送り直す。これまでの「最初の任意入力で登録する」「未登録 Stop を block する」契約を改訂する。
- 対象外 Stop では状態行を要求せず、既存の番号・URL 検査の出力・終了コードをそのまま返す。対象判定をログ読取・拡張の詳細検査・状態の無効化より先に行う。
- 新旧セッションが交錯する回帰試験と子の手順を更新し、変更記録を `plugins/dev-workflow/changes/1756.md` に残す。版は上げない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-epic-state`: ターン状態フックの対象、既存 ID による登録・切替、未登録の旧記録と対象外 Stop の扱いを改訂する。

## Impact

実装予定は `plugins/dev-workflow/scripts/epic-child-state.sh`、同プラグインの `tests/epic-child-state.bats`、`skills/develop/references/epic-child-stop.md`、`changes/1756.md`。現行仕様への反映は archive 工程で行う。

記録の schema=1、`turn_input` / `turn_state` の形、端末ハンドル `session`、親の読み取り・送信・監視、launcher の API とフック配線は変更しない。起動指示の形は認証ではなく、別セッションに同じ親子・リポジトリの起動指示を意図的に送れば切替として受理する限界を明記する。

仕様化・分割・採用理由は https://github.com/oratta/claude-harness/issues/1756#issuecomment-7087845392 と https://github.com/oratta/claude-harness/issues/1756#issuecomment-7087845611 に記録済み。今回は仕様までで、R1 APPROVE 前に実装しない。
