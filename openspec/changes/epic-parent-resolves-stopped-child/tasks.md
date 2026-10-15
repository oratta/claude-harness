## 1. 親が通してよい範囲の基準

- [ ] 1.1 `references/parent-pass-criteria.md` を新しく作る。9 つの通す条件の表（先頭は「既存の規則が主に聞くと定めている止まり（PR トークン上限の exit 2・周の終わりの「選び直しが要る」・マージ）でない」）、判断できなければ主に上げること、通る例 3 つ（hook が止めたファイルの読み取り・手順外の判断を推奨どおり受け入れること・自分の配下の暴走プロセスの停止）と通らない例 6 つ（PR トークン上限の引き上げ・周の終わりで選び直しが要るときの続行・マージの承認・聖域のファイルの変更・実機操作・主しか知らない設計意図）、PR トークン上限の引き上げを通さない理由（既存の規則が exit 2 で主に聞き、新しい上限の記録は主の返事を受けた本体が作る）、マージと既存の規則が主に聞くと定めた止まりを通さないこと（#1030 に任せる）、モデルの出力の 3 行の形、この基準が案で主が PR で決めることと #1030 が参照することを書く（design.md 決定 4）。触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md（新規）

## 2. 判断のスクリプト

- [ ] 2.1 `tests/stop-judge.bats` を新しく作る。`gh` とモデルのコマンド（`EPIC_DISPATCH_JUDGE_CMD`）をスタブにし、入力に渡すもの（エピックの本文・子の本文・注意書きのうち OWNER/MEMBER/COLLABORATOR のもの・最新の `子の停止:` の本文と URL・同じ子への `親の判断:`・基準のファイル・配役表があればその本文）、既定の呼び方（`--model sonnet`・`--tools ""`・`--no-session-persistence`、`EPIC_DISPATCH_JUDGE_MODEL` での上書き）、4 行の出力、形が崩れたときと停止の記録が無いときと `gh` が失敗したときの exit 1、ファイルに `orca` の語が無いことを確かめる。触る範囲: plugins/dev-workflow/tests/stop-judge.bats（新規）
- [ ] 2.2 `scripts/stop-judge.sh` を新しく作り、2.1 を通す。触る範囲: plugins/dev-workflow/scripts/stop-judge.sh（新規）

## 3. epic-dispatch.sh の reply と wait の resolve

- [ ] 3.1 `tests/epic-dispatch.bats` に `reply` のテストを足す（spec の `reply` の表の各行、頭の付け方 2 種、`--relaunch` で閉じるのが作るより先、引数の誤りで `orca` を呼ばない）。既存の `orca` のスタブに端末の一覧と閉じる呼び出しが無ければ足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:1-120（スタブの定義）、plugins/dev-workflow/tests/epic-dispatch.bats:2042（末尾に追記）
- [ ] 3.2 `epic-dispatch.sh` に `reply` を足す。起動コマンドの組み立て（`EPIC_DISPATCH_PARENT_EPIC`・閾値・`EPIC_DISPATCH_CLAUDE_CMD`・`EPIC_DISPATCH_MODEL` の検査）は `launch` と共通にし、送信とターンの開始の確かめ方・送り直しと作り直しの案内も `launch` のものを使う。冒頭のコメント・`usage`・振り分けに `reply` を足す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1-104（冒頭のコメントと usage）、plugins/dev-workflow/scripts/epic-dispatch.sh:158-299（shq・resend_hint・recreate_hint・cmd_launch）、plugins/dev-workflow/scripts/epic-dispatch.sh:550-559（振り分け）
- [ ] 3.3 `tests/epic-dispatch.bats` に `wait --resolve` のテストを足す（通して送れたら `stopped` を出さずに送信のあとでエピックに 1 行、送れたがエピックへの投稿に失敗すると `unrecorded` と stderr の投稿し直しのコマンド、主に上げると子 issue に 2 行目 `停止の記録: <URL>` 付きでコメントして `stopped`、子 issue への投稿に失敗しても `stopped`、判断の exit 1・形の崩れ・送信の失敗で `親の判断: 判断できなかった` と `stopped`、出力が closed/done/stopped/unrecorded の順の 1〜4 行であること、`--resolve` なしでは判断を呼ばず `unrecorded` を出さない（従来の 1〜3 行のまま）、`--resolve` の値が数字でなければ exit 1）。判断は `EPIC_DISPATCH_JUDGE` のスタブにする。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats（3.1 の追記のうしろ）
- [ ] 3.4 `cmd_wait` に `--resolve <epic>` を足し、3.3 を通す。冒頭のコメントと `usage` の `wait` の行も直す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:348-465（cmd_wait）、plugins/dev-workflow/scripts/epic-dispatch.sh:1-104

## 4. develop の手順書

- [ ] 4.1 SKILL.md の Orca 経路の手順 2 の `wait` に `--resolve <エピック番号>` を足し、`--resolve` を付けたときの出力が closed/done/stopped/unrecorded の 1〜4 行で、付けないときは従来どおり 1〜3 行であることを書き、`unrecorded` で起こされたら主に上げず stderr の投稿し直しのコマンドでエピックに 1 行を残す（読めなければ「理由は記録できなかった」と停止の記録の URL で残す）ことを足し、手順 8 を「最新の `子の停止:` と、2 行目の `停止の記録:` がその URL と一致する最新の `親の判断:` を読む（一致しなければ判断が無いものとして主に上げる）→ 送信だけが失敗した件は `reply --as parent` で送り直してよい → それ以外は readable の順で主に上げる（エピックの目的・他の子との関係・記録の URL、実機操作はどの子の・どの画面で・何を）→ 主の答えは `reply-after-idle.md` の表で決めてから `reply --as owner`（起動し直すなら `--relaunch`）に答えをそのまま渡す → `failed` は主に報告 → 2 に戻る」に書き換え、`references/parent-pass-criteria.md` を指す。`orca` のサブコマンドを書かない。手順 8 以外（#1030 が触るマージの段落、#1033 の手順 5 の文言）は変えない。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:392（手順 2）、plugins/dev-workflow/skills/develop/SKILL.md:398（手順 8）
- [ ] 4.2 SKILL.md「エピックの子が主の返事を待って止まるとき」の箇条の末尾に、親から届いた返事（2 つの頭の文字列）の扱いを 1 項目足す（止まった件への返事として受け取り `mark resumed`、親の判断で進めた件は完了報告に書く、親の判断を聖域・破壊的操作の承認にしない）。記録の項目と完了報告の書式（#1036 の範囲）は変えない。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:322-332
- [ ] 4.3 `references/reply-after-idle.md` の「子の端末の有無」の確かめ方を `epic-dispatch.sh reply` が持つと直し、「親が通した判断はまだ記録されない」の段落を消して、復元の表に `親の判断: 子 #N 通した` の行を足す。送り方の手順本体はこのファイルに書かない。触る範囲: plugins/dev-workflow/skills/develop/references/reply-after-idle.md:30、plugins/dev-workflow/skills/develop/references/reply-after-idle.md:40-50
- [ ] 4.4 `tests/epic-dispatch.bats` に手順書の文言のテストを足す（spec の「親の手順に resolve と主に上げる説明の順が書かれている」（出力 1〜4 行・`unrecorded` の扱い・`停止の記録:` の URL の照合を含む）「子の手順に親から届いた返事の扱いが書かれている」「基準のファイルに通す条件と出力の形が書かれている」（9 つの条件、PR トークン上限の引き上げが通らない例にあり理由が添えられていること、既存の規則が主に聞く止まりを通さないこと）、reply-after-idle.md の復元の表に `親の判断: 子 #N 通した` があること）。既存の「手順書に orca を実行する書き方が無い」「orca を呼ぶスクリプトは 1 本だけ」のテストが通ることも確かめる。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:2016-2042（reply-after-idle と skill のテストの近く）

## 5. 記録と確認

- [ ] 5.1 `plugins/dev-workflow/changes/1034.md` を書く（何を変えたか、基準が案で主が PR で決めること、判断のモデルの既定と費用）。触る範囲: plugins/dev-workflow/changes/1034.md（新規）
- [ ] 5.2 `bats plugins/dev-workflow/tests/epic-dispatch.bats plugins/dev-workflow/tests/stop-judge.bats` と、常時注入の予算（`tests/injection-budget.bats`）が通ることを確かめる。触る範囲: なし（実行のみ）
- [ ] 5.3 実機の Orca 経路の確認の手順を PR 本文に書く（受け入れ条件「子が止まった印を付けると、主が触らずに、進めてよいものは子が続きから進み、そうでないものは親のタブに主向けの説明が出る」「親が通した判断がエピックに残っている」）。試しのエピックで、通る止まり 1 件と主に上げる止まり 1 件を起こし、`wait --resolve` の出力・子の端末・エピックの `親の判断:` の行・親のタブの説明を見る。主の環境で行うので、手順とどこを見れば合格かを書く。触る範囲: なし（PR 本文）
