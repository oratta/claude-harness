# Proposal

## Why

主の返事待ちの子の会話キャッシュが切れると、再開時に会話全体の書き直し費用がかかる。#1383 は、主への質問と停止状態を保ちながら短い往復でキャッシュを維持し、親子双方の費用を実測する。

## What Changes

- 親が起動する既存の `epic-dispatch.sh wait` が、返事待ちの子に固定の声かけを送る。声かけでは親を起こさない。質問保持は型どおりの正常な往復に限り、型違い・複数行の返事は表示し、停止の印は保つ。
- 声かけ文・返事の型・欄名を 1 か所の機械可読定義に置き、子の受信手順と `child-log` の除外で共有する。`待ち:`・`次:` は #1374 の案として受け入れ、欄の内容の確定や異常の判定は取り込まない。
- 既存セッションへの送信に限定し、完了・片付け済み・再起動対象・TTL 不明/5 分・最後のリクエストから 1 時間以上・同じ停止から 24 時間以上の子には送らない。
- 親の既存の短い wait と掛け直しを維持する。声かけ時の子は停止の印を変えず、質問や停止コメントを再投稿しない。
- #1379 の timestamp 回帰テストを追加し、#1324 から引き継いだ費用比較を親子双方へ広げる。費用削減は実エピックの計測が済むまで未検証とする。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-epic-state`: Orca/tmux 共通の `keepalive <worktree> <text>` の引数・出力・終了コードと、許す観測・送信操作を既存の起動部品の契約へ追加する。
- `dev-workflow-develop`: 停止中の子への声かけの条件、送受信、質問・停止状態の保持、費用比較。既存の child-log の発言選択に除外を加える。

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`、Orca/tmux の既存起動部品、声かけの共通定義。
- `references/epic-child-stop.md`、`reply-after-idle.md`、`epic.md` と関連 Bats、`plugins/dev-workflow/changes/` の変更記録。
- 新しい常駐プロセス・hook・状態ファイル項目・依存パッケージは作らない。状態の正本は引き続き epic-state の記録で、費用集計は既存 cost-ledger を使う。
- 自動コンパクトの制御は #1385、返事の欄の内容は #1374 の範囲。規約の再確認は行わない（#1324 で主が許容済み）。Draft PR 作成と実装はこの spec 段に含めない。

記録: https://github.com/oratta/claude-harness/issues/1383#issuecomment-6417062289
分割判定: https://github.com/oratta/claude-harness/issues/1383#issuecomment-6417068526
