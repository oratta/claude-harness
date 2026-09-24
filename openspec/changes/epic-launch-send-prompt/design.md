## Context

`epic-dispatch.sh launch` は Orca の子ワークツリーを作るとき、`orca worktree create ... --agent claude --prompt "<指示>"` に最初の指示を任せ、create の終了コードだけで `launched` を出している（2026-09-23 の change `epic-orca-dispatch` で導入）。2026-09-24 の起動 6 件では、Claude Code（v2.1.281）は立ち上がったが入力欄が空のままだった。`ps` では指示文が `claude` の位置引数として渡っていたので、Orca が落としているのか Claude Code が起動時の位置引数を実行しなくなったのかは切り分けられていない。一方、`orca terminal wait --for tui-idle` が満たされたあとに `orca terminal send --text <指示> --enter --wait-submit 15 --json` で送り直すと、6 件とも `stages: [input_accepted, turn_started]` を返して動き出した。

`orca terminal send` は、テキストを入力として受け付けたこと（`input_accepted`）と、Enter で送信されてターンが始まったこと（`turn_started`）を分けて返し、`--wait-submit <秒>` の間だけ観測する。観測時間内にターンが始まらなければ、再送せずに受け付けまでの結果を返す（`orca terminal send --help`）。

`epic-dispatch.sh` は後続の子 issue（#460 のエピック並列起動の深さ制限など）も触るので、変更は `cmd_launch` の中に閉じる。

## Goals / Non-Goals

**Goals:**
- 子の Claude Code が最初の指示を 1 回だけ受け取り、ターンを始めたことを `launch` が確かめてから `launched` を出す
- 指示が届かなかった子を `failed` として親に知らせ、手で送り直す手段をその場で示す

**Non-Goals:**
- Claude Code が位置引数を実行しなくなった原因の切り分け（`--prompt` に戻す判断はしない）
- `skipped` の子に指示だけ送り直すサブコマンドの追加
- 子の起動の並列化（今までどおり子を 1 件ずつ順に起動する）
- エピック並列起動の深さ制限（#460）

## Decisions

**最初の指示は `orca terminal send` だけで送り、create に `--prompt` を渡さない。** `--prompt` を残して送信を足すと、Claude Code が位置引数を実行する環境（2026-09-23 の起動ではそうだった）では指示が 2 回届き、同じ issue で develop が 2 本走る。どちらか一方にするなら、結果を観測できる送信の側を選ぶ。`--prompt` だけを残して `orca terminal read` で入力欄を読んで判定する案は、画面の文字列の解析に頼ることになり、届かなかったときに結局送信が要るので採らない。

**送る前に `orca terminal wait --for tui-idle` で起動の完了を待つ。** Claude Code の起動が終わる前に送ると、端末は入力を受け付けても Claude Code がそれを捨てる可能性がある（issue #458 の懸念）。送信の観測で `turn_started` が無ければ `failed` にはなるので誤って `launched` を出すことはないが、待たずに送ると失敗が増え、そのたびに人が送り直すことになる。2026-09-24 の手動の送り直しは tui-idle が満たされたあとに行って 6 件とも成功した。待ちの上限は既定 60 秒（`EPIC_DISPATCH_READY_TIMEOUT_MS`）。待ちが失敗・時間切れになったら送らずに `failed` にする（起動していない端末に送っても届かないため）。tui-idle が本当に要るかは実装工程の実機確認で確かめ、要らないと分かっても安全側としてこの待ちは残す（コストは子 1 件あたり数秒）。

**`launched` の条件は送信の JSON 出力のどこかの `stages` 配列に `turn_started` があること。** issue のコメントに記録された出力は `stages: [input_accepted, turn_started]` だが、配列がどの階層に置かれるか（`result.stages` か、その下の受領オブジェクトか）は記録に無い。階層に依存しないよう `jq` で出力全体から `stages` 配列を拾って判定する。実機確認で実際の形を確かめ、bats のスタブはその形に合わせる。観測時間は既定 30 秒（`EPIC_DISPATCH_SUBMIT_WAIT`）。手動の送り直しで使った 15 秒は tui-idle 後の送信で足りていたが、ターンの開始が遅れて `failed` になる誤判定のほうが、`launch` が 15 秒長くかかることより高くつくので倍にする。

**送れなかった子には、送り直しのコマンドを stderr に出すだけにする。** ワークツリーは残るので、`launch` を再実行するとその子は `skipped` になって指示は送られない。`resend` のようなサブコマンドを足す案もあるが、既存の要件では `failed` は本体がユーザーに報告して止まる扱いで、人か親が 1 コマンド打てば済む。スクリプトの守備範囲を広げると #460 など後続の子との衝突面も増えるので、今回は足さない。

**ハンドルは `result.agentTerminalHandle`、無ければ `result.startupTerminal.handle`。** issue の直し方の指定どおり。どちらも無ければ送り先が無いので `failed` にする。

## Risks / Trade-offs

- [tui-idle が満たされても Claude Code の入力欄がまだ入力を受け付けない（信頼確認のダイアログなど）] → 送信の観測で `turn_started` が出ず `failed` になり、stderr のコマンドで送り直せる。誤って `launched` にはならない
- [`orca terminal send` の JSON の形が Orca の更新で変わる] → `stages` の階層に依存しない判定にしてある。`turn_started` という語自体が変わった場合は全件 `failed` になり、黙って待ち続けるよりは早く表に出る
- [`launch` にかかる時間が子 1 件あたり最長およそ 90 秒延びる] → 本体は `launch` を前景で待つが、子の件数はエピックの並列数（数件）に限られる
- [送信の観測時間内にターンが始まらなかったが、実はその後に始まった。または送信が非 0 で終わったが指示は届いていた] → `failed` と報告され、確かめずに送り直すと指示が 2 回届く。stderr の案内に「送る前に `orca terminal read` で入力欄とターンの状態を確かめる」と添え、`terminal send` の JSON に送り直し用の ID があれば送り直しのコマンドに `--retry-request <id>` を付ける（Orca はこの ID で同じ送信の二重実行を防ぐ）
- [`failed` の子に送り直さないまま、別セッションで同じエピックを再開する] → 再開時の `launch` はその子を `skipped` と出し、本体は動いている子として `wait` に入るので、子が何もしないまま最長 6 時間（`EPIC_DISPATCH_TIMEOUT` の既定）待つ。SKILL.md に「`failed` の子は送り直して動き出したのを確かめてから再開する」と書いて防ぐ

## Migration Plan

`launch` の出力の書式（`launched` / `skipped` / `failed` の 1 行）と exit code の規則は変えないので、SKILL.md の本体の手順は変えずに済む。`launched` と `failed` の意味の説明だけを直す。戻すときは `cmd_launch` の変更を revert する。

## Open Questions

- 実機確認に使う子（Orca で実際に起動する 2 件以上の issue）を何にするか。エピック #420 の本物の子を起動すると develop が走り出すので、使い捨ての issue とテスト用エピックを作るかどうかを実装工程の前に決める
