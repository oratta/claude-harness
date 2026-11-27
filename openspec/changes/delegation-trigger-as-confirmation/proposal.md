# Proposal

## Why

エピックの親セッションで主が「子のリスク許容は親が通してよい」と会話で述べても、今の主の委任は「定型の記録を投稿 → 本文で問う → 主の直後の確認」でしか受けられない。2026-11-09 の genetta-inc/flatmate#1995 では、主が一度任せたのに子 #2058 のゲートが受け付けず、主が定型の記録への確認をもう一度打ち、さらに確認より前に止まっていた 1 件には本人の「許容する」がもう一度要った（issue #1609）。同じ承認を言い直させないため、主の会話の発言そのものを確認として受ける経路を作る。

## What Changes

主の決定（https://github.com/oratta/claude-harness/issues/1609#issuecomment-7212285228 。2 つの決めごとをどちらも推奨の案 A）に従う。

- **きっかけの発言を確認にする形（`主の委任: リスク許容` だけ）**: 親は、主が子のリスク許容を任せる旨を述べたら、問いを出さずに、その発言の全文を `きっかけ:` に入れた委任の記録（4 行目の `期間:` がきっかけの形の定型）を投稿し、その発言の uuid を `委任の確認の場所:` に残して、主には範囲・期間・取り消し方と同じターンで送った子を事後に報告する。きっかけの形で受けるのは、全文だけから子の止まりを任せる旨が読め、直前の親の発言を読まないと対象が決まらない発言（「この件は任せる」「それでいい」など）でなく、除外・期限・条件の付かない発言に限る。ほかはきっかけの形にせず、子の止まり全般を任せる旨とも読める発言だけを問いの形で受け、残りは元の問い・報告への答えとして扱う。`主の委任: 論点なしの止まり`（聖域の変更・破壊的な git 操作まで含む）は今どおり問いと確認を通す
- **`owner-reply-check.sh --delegated-trigger` を足す**: 指した uuid の行が主の発言で、委任の記録より前で、空白をまとめた全文が記録の `きっかけ:` と同じで、その発言から記録の投稿までに別の主の発言が無いことを確かめる
- **確認より前に止まった子にも、リスク許容の止まりなら委任を当てる**: 「委任が効く止まり」のリスク許容の条件③から、委任の確認との前後を外す（停止の記録が最新・宣言の後・対象 HEAD が今の HEAD・`主の回答:` が無い・推奨が許容・論点なしは今どおり確かめる）。`--delegated` の停止の記録の作成日時の引数に `-` を渡すと `not-before` を確かめない。親は委任の確認の場所を残した直後に、`epic-dispatch.sh pending-owner` が `pending <N>` を返す子の今回の停止の記録にも委任が効くかを確かめて送る
- **子と G（pr-review-gate）**: 委任の記録の 4 行目で形を見分け、きっかけの形なら `--delegated-trigger` で、問いの形なら `--delegated` で確かめる。宣言コメントに追記する行（`主の回答: 許容 — 親経由で受領（委任）…`）は変えない。真正性確認の行の末尾に使った照合の名前を書く
- 聖域の変更・破壊的な git 操作・マージ待ちの止まりの委任、委任の範囲、取り消しと失効の条件は変えない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 親が委任を受ける手順（きっかけの形）・委任の確認の場所・委任が有効かの定型の行・委任が効く止まりの条件③・親の送り方と守備範囲・子が委任の返事を確かめる手順と子の経路の守備範囲・委任の種類ごとの判定の守備範囲
- `dev-workflow-pr-review-gate`: 委任の形の真正性確認（形ごとの照合と REASON の一覧）と、引き継ぎで委任の形を確かめ直すときの照合の選び方
- `dev-workflow-owner-reply-check`: `--delegated-trigger` の追加と、`--delegated` の停止の記録の引数 `-`

## Impact

- 手順書: `plugins/dev-workflow/skills/develop/references/epic-delegation.md`・`epic-stop.md`・`epic-child-stop.md`
- 聖域（マージ条件のパス）: `plugins/dev-workflow/skills/pr-review-gate/stages/authenticity-delegated.md`・`carryover.md`・`hold-resume.md`
- スクリプト: `plugins/dev-workflow/scripts/owner-reply-check.sh`
- テスト: `plugins/dev-workflow/tests/owner-reply-delegated-scenario.bats`・`pr-review-gate-skill.bats`・`develop-skill.bats`・`owner-escalation-narrowing.bats`、ゲートの文言の控え `tests/fixtures/gate-contracts/prose.json`（当たれば `blocks.json`）と読込予算 `tests/gate-reading-budget.txt`
- 変更の記録: `plugins/dev-workflow/changes/1609.md`
- ゲートが主の承認として受け付けるものが広がる（主の会話の 1 回の発言で、以後のリスク許容と、すでに止まっていたリスク許容が親経由で通る）。主の判断が要る変更
