## Context

`reply` は子の端末へ返事を送る共用の送信処理（`deliver_reply`）で、`wait --resolve` と `notify-closed` も同じ処理を使う。主が子のタブで答えると、子は `mark resumed` で記録の `stop` を `resumed` に変えるが、`reply` はそれを見ていなかった。

## Decisions

- **確認の場所は `deliver_reply`（ワークツリーが 1 件に決まったあと・起動部品を選ぶ前）**。`reply`・`wait --resolve`・`notify-closed` が同じ確認を通る。代案の「`cmd_reply` だけに入れる」は、`wait --resolve` が判断のあいだに再開された子へ送る穴が残るので採らない
- **戻り値 2 を「送らなかった（失敗ではない）」にする**。`cmd_reply` は 0 と 2 を exit 0 にし、`wait --resolve` は `skipped` を受けたら投稿せず待ちを続ける。`notify-closed` は元から同じ出力なので変わらない
- **記録が `stopped-seen` のままでも会話ログが進んでいれば送らない（Codex レビューの指摘）**。子が `mark resumed` を呼ばず会話だけで再開すると、次の `wait` のポーリングが記録を直すまで古い判断が送られる。`pending-owner` と `resume_moved` と同じ `record_log_json` と `log_moved` を使う。会話ログを読めないときは今までどおり送る（読めないことで返事を止めると、本当に止まっている子が止まったままになるため）

## Risks / Trade-offs

- 止まっている子の会話ログに親の送った見張りなどの入力が入っていると、`log_moved` が真になり、止まっている子に返事を送らない恐れがある。`pending-owner` が同じ判定を使っていて、見張りは実質的な入力に数えない既存の扱いに従う
