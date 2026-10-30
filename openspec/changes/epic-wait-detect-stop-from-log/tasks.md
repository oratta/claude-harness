# Tasks

行番号は仕様づくりの時点の値で、前のタスクの編集でずれうる。編集前に該当範囲を読む。bats の実行は `scripts/test.sh <名前>`。

## 1. 会話ログの読み取りの部品

- [x] 1.1 `child-log-read.py <dir>` を作り、最新の会話ログ（`entrypoint == cli`）から session・uuid・at・text・questions・turn_ended・bg_running・last_input_at・last_activity_at・最後の主の発言を JSON で出す。声かけの往復と背景のタスクの通知は入力に数えず、`isApiErrorMessage` の行は発言に数えない。確認: 新規の bats で、質問で終わるログ・ターンの途中・未回答の AskUserQuestion・背景のタスクの実行中と終わり・声かけの往復・hook のセッションの混在の各 fixture の JSON を確かめる。触る範囲: `plugins/dev-workflow/scripts/child-log-read.py`（新規）、`plugins/dev-workflow/tests/child-log-read.bats`（新規）、`plugins/dev-workflow/scripts/epic-dispatch.sh:1038-1085`（`cache_ttl_of` の絞り方の前例）、`plugins/dev-workflow/scripts/epic-dispatch.sh:1134-1161`（`last_activity`）
- [x] 1.2 `child_log_line` を部品の JSON の整形に置き換え、1 行の出力を保つ。確認: `scripts/test.sh epic-dispatch` の既存の `child-log` のテストが値を変えずに通る（fixture に `entrypoint` を足すのは可）。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:1611-1744`
- [x] 1.3 `child-log --last <N>` を足す（全文は末尾を残し、上限は `EPIC_DISPATCH_STOP_TEXT_MAX`（既定 8000。数字でなければ既定）、uuid、時刻、問い、記録の `stop_uuid`、読めなければ `unreadable`）。確認: 500 文字の発言が全部出るテスト、`EPIC_DISPATCH_STOP_TEXT_MAX` を小さくすると末尾が残るテスト、`unreadable` のテストを足す。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:1721-1744`、`plugins/dev-workflow/tests/epic-dispatch.bats`

## 2. 記録の項目

- [x] 2.1 `stop_uuid`・`stop_at` を任意項目として足す。無い記録は空として読み、読めない記録にしない。`stop` の写しに親の `wait` と `dismiss` の `resumed` を通す。確認: 以前の形の記録を読むテストと、`stop_uuid`・`stop_at` が文字列でない記録が読めない記録になるテスト。触る範囲: `plugins/dev-workflow/scripts/epic-state.sh:6-153`（`ES_VALID` は 85 行付近）、`plugins/dev-workflow/scripts/epic-dispatch.sh:368`

## 3. wait の検知

- [x] 3.1 `wait --watch-stopped` が部品の JSON で止まった子を検知し、`stopped-seen`・`stop_uuid`・`stop_at` を書く。`EPIC_DISPATCH_STOP_IDLE_SEC`（120）と `EPIC_DISPATCH_STOP_BG_IDLE_SEC`（1800）の待ち時間と、未回答の質問ツールを待たない扱いを入れる。確認: spec の「wait は子の会話ログから止まった子を検知する」「wait は背景のタスクの有無で止まりとみなす待ち時間を変える」のシナリオを `epic-dispatch.bats` に足す。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:1401-1576`（止まりの判定は 1507-1541）
- [x] 3.2 印の子はターンの終わりか質問ツールで返し、`EPIC_DISPATCH_STOP_BG_IDLE_SEC` を過ぎたら待たずに返す。読めない印の子は今どおり返し uuid は空にする。確認: spec の「wait は印の付いた子をターンの終わりまで待って返す」のシナリオと、既存の `--watch-stopped` のテストが通ること。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:1507-1541`
- [x] 3.3 同じ uuid を二度判断しない規則と、`stop_uuid` が空の `stopped-seen` を黙って埋める処理を入れる。確認: spec の「wait は同じ発言を二度判断しない」のシナリオ。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:1507-1541`
- [x] 3.4 `wait` が位置引数の子と `--watch-done` の子で、`stop_uuid` より後の動きを `resumed` に書き、Orca の印へ写す。声かけの往復は数えない。同じポーリングでは再開を先に見る。確認: spec の「wait は止まりのあとの動きを再開として記録に書く」のシナリオと、「wait の会話ログの検知の守備範囲を限る」の言い直しのシナリオ。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:1401-1576`、`plugins/dev-workflow/scripts/epic-dispatch.sh:1170-1201`（`infer_done` は変えないが読む）
- [ ] 3.5 受け入れ条件 1 件目のリハーサルを作る。記録も印も無い子を fixture で用意し、`wait` が `stopped <N>` を返すこと、`--resolve` で判断のスタブに止まりの JSON が渡ること、判断のスタブが `主に上げる` のとき `親の判断:` に発言の本文が入らないことを確かめる。確認: `scripts/test.sh epic-stop-from-log-scenario` が通る。スクリプトの写しで検知を壊すと落ちることも確かめる。触る範囲: `plugins/dev-workflow/tests/epic-stop-from-log-scenario.bats`（新規。形式は `plugins/dev-workflow/tests/owner-reply-relayed-scenario.bats:1-20`）
- [x] 3.6 親が呼ぶ `dismiss <N>...` を足す。親の見張りの照合で記録を探し、排他の中で `stopped-seen` かつ `stop_uuid` ありを確かめて `resumed` に書き、Orca の印へ写す（`stop_uuid`・`stop_at` は変えない）。`--resolve` の `問いではない` と同じ書き換えの処理を使う。それ以外は `skipped <N> not-stopped`、読めない記録は `failed <N> state-unreadable`、2 件以上は `failed <N> ambiguous-worktree`、`failed` があれば exit 1。確認: spec の「親は問いでない止まりを dismiss で再開に戻す」のシナリオ（戻したあと同じ発言で判断されない・`pending-owner` に出ない・完了の推定が働く、を含む）を `epic-dispatch.bats` に足す。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:1-20`（使い方）、`plugins/dev-workflow/scripts/epic-dispatch.sh:370`（`mirror_state`）、`plugins/dev-workflow/scripts/epic-dispatch.sh:901-960`（`cmd_notify_closed`。照合の前例）、`plugins/dev-workflow/scripts/epic-dispatch.sh:2013-2018`（サブコマンドの振り分け）、`plugins/dev-workflow/tests/epic-dispatch.bats`

## 4. 判断の入力と出力

- [x] 4.1 `stop-judge.sh` が任意の第 3 引数の止まりの JSON を受ける。発言の全文（上限は 1.3 と同じ `EPIC_DISPATCH_STOP_TEXT_MAX` で `wait` が切る）・問い・背景のタスクの有無を入力に足し、記録は最後の入力より後のものに限り、4 行目を `記録: <URL か なし>` にする。JSON が無いときは今どおりにする。確認: spec の「最後の入力より古い記録は判断に渡さない」「JSON も記録も無ければ判断しない」のシナリオと既存の `stop-judge.bats`。触る範囲: `plugins/dev-workflow/scripts/stop-judge.sh:7-22`、`plugins/dev-workflow/scripts/stop-judge.sh:80-178`、`plugins/dev-workflow/tests/stop-judge.bats`
- [x] 4.2 `判断: 問いではない` を出力の形に足し、JSON が無い・今回の記録がある・問いがある・印があるときは形の崩れとして exit 1 にする。確認: spec の「今回の記録がある止まりの問いではないは形の崩れになる」のシナリオ。触る範囲: `plugins/dev-workflow/scripts/stop-judge.sh:160-178`、`plugins/dev-workflow/tests/stop-judge.bats`
- [x] 4.3 `resolve_stopped` を止まりの JSON の受け渡し・`止まりの発言:`・`停止の記録: <URL か なし>`・`発言 <uuid>` の形に替え、`問いではない` で `stop` を `resumed` に戻して stderr にだけ出す。確認: spec の「問いではないと判断した子は親を起こさず待ちを続ける」と、書式を更新した既存の `--resolve` のテスト。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:1207-1259`、`plugins/dev-workflow/scripts/epic-dispatch.sh:113-115`（ヘッダのコメント）、`plugins/dev-workflow/tests/epic-dispatch.bats`
- [x] 4.4 基準に子の最後の発言の読み方・`理由:` に引用しない規則・`問いではない`・入力の範囲を足す。確認: `develop-skill.bats` に spec の「基準のファイルが子の最後の発言の読み方を書いている」の文言の検査を足す。触る範囲: `plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:3`、`plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:80-96`、`plugins/dev-workflow/tests/develop-skill.bats`

## 5. 記録の無い止まりの扱い

- [ ] 5.1 `pending-owner` を会話ログの確かめと `pending <N> <uuid>` の形に替える。読み取り専用を保つ。確認: spec の「pending-owner は会話ログが進んだ子を出さない」のシナリオと、既存の `pending 11` のテスト。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:1579-1589`、`plugins/dev-workflow/scripts/epic-dispatch.sh:163`
- [ ] 5.2 `keepalive_candidate` の 24 時間の基点を `stop_at`（空なら記録の作成時刻）に、通した判定を uuid に替え、停止コメントの必須をやめる。確認: spec の「記録の無い止まりにも送る」のシナリオと既存の声かけのテスト。触る範囲: `plugins/dev-workflow/scripts/epic-dispatch.sh:1264-1367`（照合は 1318-1326）
- [ ] 5.3 手順書を直す。手順 2・5 の注意、手順 7・8 の `child-log --last` と uuid の照合、記録の無い止まりの組み立て、問いでなければ `dismiss` を呼んでから 2 に戻ること（手順 7 の出し直しも同じ）、状態の正本の説明、復元元の表と声かけの節。`委任で送る` は記録のある止まりに限ると添える。確認: `develop-skill.bats` に spec の手順 5・8 のシナリオ（「問いでない止まりは dismiss してから待ちに戻る」と、uuid 照合に揃えた「親の手順に resolve と主に上げる説明の順が書かれている」「主に聞く理由の無い止まりは親が通す」を含む）の文言の検査を足す。`epic-child-stop.md` は編集しない。触る範囲: `plugins/dev-workflow/skills/develop/references/epic.md:33`、`plugins/dev-workflow/skills/develop/references/epic.md:80-86`、`plugins/dev-workflow/skills/develop/references/epic.md:104-105`、`plugins/dev-workflow/skills/develop/references/reply-after-idle.md:61-65`、`plugins/dev-workflow/skills/develop/references/reply-after-idle.md:97-98`、`plugins/dev-workflow/tests/develop-skill.bats`

## 6. 仕上げの確認

- [ ] 6.1 全体の回帰を確かめる。`owner-reply-relayed-scenario` と `owner-reply-delegated-scenario` が変更なしで通り、`scripts/test.sh` 全体が通り、`tests/injection-budget.bats` が通る。`orca` の語が `stop-judge.sh` と develop の手順書に増えていない。触る範囲: 確認のみ
- [ ] 6.2 変更の記録を書く。確認: `plugins/dev-workflow/changes/1382.md` に、1 本目で変わること（記録の無い子の検知・`親の判断:` の書式）と 2 本目の予定がある。main に同じ番号の記録があれば PR 番号の名前にする。触る範囲: `plugins/dev-workflow/changes/1382.md`（新規）
