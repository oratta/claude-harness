# Tasks

## 1. notify-closed は完了の印の無い子に止まった印の有無によらず促す（#1182）

- [x] 1.1 `deliver_reply` に 7 つ目の引数 `closed_notify` を足す。`1` のときも送る直前の止まりの確かめ 3 つ（`stop` が `stopped` / `stopped-seen` か、`stop_turn` の `wait_received`、`stopped-seen` の会話ログの進み）と `launcher deliver` の直前の `wait_received` は行い、どれかで止まっていないと決まったら `skipped <N> not-stopped` を返さずに `relaunch` を 0 にして送り続ける（端末があれば子のセッションの端末に送るだけで、閉じない）。止まっていると決まった子は渡された `relaunch` のとおり。関数の上のコメントに引数と、止まっていない子に起動し直しを当てない理由（作業中の子や主が会話中の子の端末を閉じない）を足す。`reply` と `wait --resolve` の呼び出しは変えない。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1013-1078（deliver_reply）
- [x] 1.2 `cmd_notify_closed` から `stop` の `case`（`skipped <N> not-stopped`）を消し、`deliver_reply` を `closed_notify` に 1 を渡して（6 つ目は空）呼ぶ。`--relaunch` はそのまま `deliver_reply` の 1 つ目に渡す（止まっていない子に当てないのは 1.1 の `deliver_reply` が決める）。結果の `case` の `skipped $n not-stopped` の枝も消す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1124-1196（cmd_notify_closed）
- [x] 1.3 冒頭のコメントの notify-closed の説明と、`--help` の notify-closed の `skipped` の理由から `not-stopped` を消し、「止まった印の有無によらず、完了の印の無い子に送る」と書く。上の要件名を指すコメントは変えない。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:156-161、plugins/dev-workflow/scripts/epic-dispatch.sh:245-249、plugins/dev-workflow/scripts/epic-dispatch.sh:316-321

## 2. 完了推定に stopped-seen を含める（#1598）

- [x] 2.1 `infer_done` の先頭の `stop` の検査と `es_modify` の確かめ直しの条件から `stopped-seen` を外す（`stopped` だけを外す）。関数の上のコメントの「止まった印でない」を「親がまだ受けていない止まり（stopped）でない」に直す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1401-1438（infer_done）
- [x] 2.2 冒頭のコメントの wait の推定の 6 つの条件の 2 つ目を同じに直す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:95-104

## 3. 親の操作が要る止まりを stopped で返す（#1620）

- [x] 3.1 `stop-judge.sh` の 1 行目の検査に `判断: 親が動く` を足す（`判断: 通す`・`判断: 主に上げる` と同じ枝）。ヘッダの判断の説明と出力の説明に 4 つ目の値を足す。触る範囲: plugins/dev-workflow/scripts/stop-judge.sh:1-30（ヘッダ）、plugins/dev-workflow/scripts/stop-judge.sh:211-221（1 行目の検査）
- [x] 3.2 `resolve_stopped` に `判断: 親が動く` の枝を足す（`判断: 主に上げる` の枝の後ろ）。子 issue に 1 行目 `親の判断: 親の操作が要る`・`止まりの発言:`・`停止の記録:`・理由・`送るはずだった返事: <返事か なし>` のコメントを投稿し（失敗したら `repost_hint`）、1 を返す。「どれでもない」の `why` の文に 4 つ目の値を足す。関数の上のコメントに戻り値の説明を足す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1440-1537（resolve_stopped。枝は 1486-1503）
- [x] 3.3 冒頭のコメントの `--resolve` の説明に `判断: 親が動く` の扱いを足す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:119-131
- [x] 3.4 `parent-pass-criteria.md` に、親の操作の定義（この子への返事以外で親がすること。起動し直しは含めない）と、推奨が親の操作を含む通してよい止まりに `判断: 親が動く` を出すこと、主に聞く理由に当たるなら `判断: 主に上げる` が先なこと、`理由:` に操作を・`返事:` に操作のあとの返事を書くことを足す。出力の形の段落（1 行目の値の列挙）にも足す。止まった子の起動し直し（71 行目付近）は親の操作に当たらないと分かる書き方を保つ。触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:9-37（通す条件と主に上げるとき）、plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:90-118（出力の形）
- [x] 3.5 `epic-stop.md` の手順 8 に、`親の判断: 親の操作が要る` の件の扱い（理由の操作を親の権限で行う→主に聞く理由に当たれば主に上げる→送るはずだった返事を `reply --as parent` で送る→エピックに通した行を残す。操作をせずに返事だけを送らない）を足す。順番も書く: 今回の止まった理由が `PR トークン上限（`・`PR のマージ待ち（` で始まるものはそれぞれの手順を先に当て、それ以外は `dismiss` の判定・主の委任・基準への照らし直しより先に扱い、照らし直さない。`dismiss` の文（`今回の停止の記録が無く、最後の発言に…dismiss <N>` を呼んでから…手順 2 に戻る`）は `tests/develop-skill.bats` がそのままの文字列で検査しているので変えず、その前に「`親の判断: 親の操作が要る` の件は下の段落を先に読む」の 1 文を置く形にする。「pending-owner の復元」に、最新の `親の判断:` が `親の判断: 親の操作が要る` の子は手順 8 と同じく操作をしてから返事を送り、出し直さないと足す。手順 8 の `dismiss` の理由の括弧書きの「完了の推定が止まり、」を消す（閉じた子は `stopped-seen` のままでも推定されるようになる）。触る範囲: plugins/dev-workflow/skills/develop/references/epic-stop.md:7（手順 8 の段落。`dismiss` の文と `通すが送れなかった` の文の付近）、plugins/dev-workflow/skills/develop/references/epic-stop.md:15（pending-owner の復元）

## 4. 新しいセッションで再開した子に owner-away を出さない（#1815）

- [x] 4.1 `detect_owner_away` で、`snapshot` が取れたあと `es_modify` の前に `record_log_json "$f"` を読み、`session` が空でなく `snapshot.turn_state.session_id` と違い、`last_input_at`（小数秒を落として秒にする）が `turn_state.recorded_at` より新しければ 1 を返す（記録は書かない）。読めない・値が空なら今までどおり進む。関数の上のコメントに足す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:2047-2066（detect_owner_away）、plugins/dev-workflow/scripts/epic-dispatch.sh:1880-1887（record_log_json。読むだけ）、plugins/dev-workflow/scripts/child-log-read.py:1-40（出力のキー。読むだけ）
- [x] 4.2 冒頭のコメントの owner-away の説明に、新しいセッションで再開した子を外すことを足す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:110-118

## 5. 回し方の文書

- [x] 5.1 `epic-loop.md` の親だけの片付けの段落を、`waiting` と `stopped` は完了推定の対象外・`stopped-seen` は対象・completed で閉じた完了の印の無い子には `notify-closed` で促す、に直す。触る範囲: plugins/dev-workflow/skills/develop/references/epic-loop.md:72
- [x] 5.2 `epic-loop.md` の手順 2 の推定の括弧書き（推定しない子）を、`waiting` の子・親がまだ受けていない止まり（`stopped`）の子・トランスクリプトが無い子に直し、`stopped-seen` は対象に入ると書く。手順 4 の `notify-closed` の説明から「止まった印の無い子…には何も送らない」と `skipped <N> not-stopped` の子の文を消し、止まった印の有無によらず促すこと、促しの届かなかった子（`failed` の子など）は `--watch-done` の推定で片付くので主にステータスを変えるよう頼まないことを書く。触る範囲: plugins/dev-workflow/skills/develop/references/epic-loop.md:75（手順 2）、plugins/dev-workflow/skills/develop/references/epic-loop.md:77（手順 4）

- [x] 5.3 `reply-after-idle.md` 7 行の「停止中の completed の子への notify-closed」を「完了の印の無い completed の子への notify-closed」に直す。「そのまま送るか、起動し直すか（子）」の前置きの「主が子のタブで始めたターンの子には何も送らず、端末を閉じず、起動し直さない。」は文字列を変えずに残し（`tests/develop-skill.bats` が検査している）、その後ろに「`notify-closed` の完了の促しだけは、止まっていない子にも送る。その子には `--relaunch` を付けても端末を閉じず、起動し直さない」の 1 文を足す。42 行の「`notify-closed` は本体が表で分類し、必要なら `--relaunch` を付ける」に「`--relaunch` が効くのは止まっている子だけ」を足す。触る範囲: plugins/dev-workflow/skills/develop/references/reply-after-idle.md:7、plugins/dev-workflow/skills/develop/references/reply-after-idle.md:42-44

## 6. テスト

- [x] 6.1 notify-closed: 「a child that is not stopped gets nothing」を、`stop` が空・`resumed`、`status` が `running`・`waiting` の子にも送って `notified` とエピックの通した行が出るテストに置き換える。`stopped-seen` で `stop_turn` が合わない・会話ログが進んだ子にも送るテストを足す。止まっていない子（`stop` が空・`resumed`、`stop_turn` が合わない、会話ログが進んだ）に `notify-closed --relaunch` を呼ぶと、偽の `orca` に `terminal close` と `terminal create` が呼ばれず `terminal send` だけが呼ばれて `notified` が出るテストと、止まっている子に `--relaunch` を呼ぶと閉じて作り直して `notified` が出るテストを足す。`already-done`・`not-closed`・`not-completed` のテストは変えない。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:5050-5240（notify-closed の節。5135 が置き換え対象）
- [x] 6.2 回し方の文面のテスト: 手順 4 の `skipped <N> not-stopped` の検査を、止まった印の有無によらず促す文と推定で片付く文の検査に直す。手順 2 の `止まった印` の検査を `stopped` の検査に直す。親だけの片付けの段落の `完了推定の対象外` の検査を新しい文面に合わせる。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:5240-5265、plugins/dev-workflow/tests/epic-dispatch.bats:10375-10385
- [x] 6.3 推定: 「waiting, stopped and stopped-seen children are not inferred」から `stopped-seen` を外し、`stopped-seen` で条件を満たせば `done 11` が出て `stop`・`stop_uuid` が残るテストを足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:2516-2530
- [x] 6.4 `wait --resolve`: 判断のスタブが `判断: 親が動く` を出すと、子の端末に送られず、エピックに通した行が無く、子 issue に `親の判断: 親の操作が要る` と `送るはずだった返事:` の行のコメントが投稿され、`stopped 11` が出るテストを足す（投稿の失敗で `repost_hint` が出るものも）。`判断: 通す` で返事に「親が」を含む止まり（`返事: 親が見張りを続けるので、そのまま待つ`）が今までどおり送られるテストも足す。`parent-pass-criteria.md` と `epic-stop.md` の文面の検査を足す（`epic-stop.md` は、`親の操作が要る` の件が `dismiss` の文より前に現れることと、「pending-owner の復元」の扱いも確かめる）。既存の通すテストは変えずに通ることを確かめる。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:4841-4900（wait --resolve の節の先頭。足すのは 4892 の主に上げるテストの後ろ）
- [x] 6.5 stop-judge: スタブが `判断: 親が動く` を出すと 4 行が出て exit 0 になること（止まりの JSON の有無の両方）を足す。触る範囲: plugins/dev-workflow/tests/stop-judge.bats:94-113（足すのは 104 のテストの後ろ）
- [x] 6.6 owner-away: `turn_state.session_id` と違うセッションの最新ログに `recorded_at` より新しい `last_input_at`（主の入力の時刻）があると `owner-away` が出ず `owner_away_told` が書かれないテストと、同じセッション・ログが読めないときは今までどおり出るテストを足す。トランスクリプトの作り方は同じファイルの推定のテストにならう。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:9734-9837（owner-away の節）
- [x] 6.7 `bats plugins/dev-workflow/tests/epic-dispatch.bats plugins/dev-workflow/tests/stop-judge.bats plugins/dev-workflow/tests/epic-stop-from-log-scenario.bats plugins/dev-workflow/tests/develop-skill.bats`（`develop-skill.bats` は `epic-stop.md` の `dismiss` の文・`reply-after-idle.md` の前置きの文をそのままの文字列で検査している）と `bats tests/injection-budget.bats` を通す。触る範囲: なし（実行だけ）

## 7. 記録

- [ ] 7.1 変更の記録を書く（PR 番号が決まってから。元の issue 5 本の条件と証拠のテスト名を並べる）。触る範囲: plugins/dev-workflow/changes/<PR番号>.md（新規）
