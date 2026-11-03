## Why

pr-review-gate 手順 3-c（前の HEAD の許容の引き継ぎ）は、1 本目の change `risk-carryover-pr-own-diff`（PR #1282）で、根拠ファイルの PR 自身の差分が前後で違うときに `risk-carryover-check.sh` が終了コード 4（`CARRYOVER=if-judged`）を返すようになった。しかし 3-c は終了コード 4 をまだ主に聞くので、レビュー指摘や CI 落ちの直しが根拠ファイルに数行触れるたびに、主は中身の同じリスクの許容を聞き直される（issue #1238 本文の実例は、子プロセスを止める書き方を置き換えただけの 4 行で、送るシグナルも止める対象も同じだった）。主の決定（issue #1238 のコメント、2026-10-23）は、PR 自身の差分が変わったときだけ、作業の文脈を持たない判定役（`dev-workflow:decider`、`model: opus`）に比べさせて、リスクの中身が同じなら引き継ぐことである。この change はその経路を入れる。

## What Changes

- `pr-review-gate/stages/hold.md` 手順 3-c: 終了コード 4 で、ほかの条件（根拠ファイルの行・真正性・宣言の本文の一致、許可リスト外の衝突解消があれば PR 全体を見たレビュー）を満たし、`EVIDENCE_DIFF_LINES=` が 100 以下のときは、主に聞く前に判定役に比べさせる。渡すのは `EVIDENCE_PR_CHANGED=` のファイルの `git diff <前 HEAD> <新しい HEAD>` と、前の宣言の本文だけ。返答の 1 行目を `引き継ぎ判定: 同じ|変わった|判断できない` に固定し、判定の記録を PR にコメントする。「同じ」なら引き継ぎ、引き継ぎの根拠の行に終了コード 4・判定の結果・判定の記録のリンクを書く。「変わった」「判断できない」（1 行目が 3 形に一致しないときを含む）、および行数の上限を超えたときは今どおり手順 6 で主に聞き、理由を質問に添える
- 判定役を起こすのは、ゲートを回しているセッションのうち Agent ツールで決める役を起こせるもの。メインセッションで pr-review-gate を回すときはゲート自身が起こす。develop の合格処理の G（サブエージェントで決める役を起こせない）は、新しい Status **`needs-carryover-judge`**（`次の段: 合格処理`）で返し、develop の本体が判定役を起こして判定の記録を PR に投稿し、判定と記録の URL を渡して新しい合格処理の G を起こす（`needs-fix-check` と同じ形）
- 判定役を起こせないセッション（従来経路の一括の G）と、共有枠モード `SHARED_BUDGET_MODE=depleted`（全役割 sonnet 固定）のときは、判定役を起こさず主に聞く
- `develop/SKILL.md` の (4) に `needs-carryover-judge` の分岐を足し、モデルの表に判定役の行を足す。`develop/references/roles/gate-runner.md` の Status の一覧・`次の段:` の表・段ごとの表の合格処理の行に足す。`pass.md` と `hold.md` の「G として動くとき（develop）」節に、この Status の return の書式と、判定を受けて起こされた合格処理の G の入力を足す
- 1 本目のレビューで残した表現の直し: `openspec/specs/dev-workflow-pr-review-gate/spec.md` の Requirement 名「risk-carryover-check.sh が差分の範囲と根拠ファイルの無変更を判定する」を「risk-carryover-check.sh が差分の範囲と根拠ファイルの PR 自身の差分を判定する」に変える（`## RENAMED Requirements`）。`pr-review-gate/declarations.md` の根拠ファイルの説明「手順 3-c がこのファイルの無変更を確かめる」を「手順 3-c がこのファイルの PR 自身の差分が前後で同じかを確かめる」に直す
- `risk-carryover-check.sh` は変えない（`EVIDENCE_DIFF_LINES=` の数え方は、判定役に渡す差分と同じ前後の HEAD の diff のまま）

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-pr-review-gate`: Requirement「前の HEAD の許容を新しい HEAD に引き継いでよい条件」（終了コード 4 の扱い・守備範囲・シナリオ）、「引き継いだ宣言の書式と合格条件」（引き継ぎの根拠の行に終了コード 4 の形を足す）を変え、「risk-carryover-check.sh が差分の範囲と根拠ファイルの無変更を判定する」の名前を変え、判定役に比べさせる Requirement（回す条件・渡すものと行数の上限・返答と記録の形・記録の選び方・起こすセッション・`needs-carryover-judge` の return の欄）を足す
- `dev-workflow-develop`: Requirement「G は段ごとに新しく起こし、SendMessage で再開しない」（段の表の合格処理の行）、「Gate Result は段と次の段を持つ」（Status と `次の段:` の表）を変え、本体が `needs-carryover-judge` を受けたときの動きと、モデルの表の判定役の行の Requirement を足す

## Impact

- `plugins/dev-workflow/skills/pr-review-gate/stages/hold.md`（3-c と「G として動くとき（develop）」節）
- `plugins/dev-workflow/skills/pr-review-gate/stages/pass.md`（「G として動くとき（develop）」節の入力）
- `plugins/dev-workflow/skills/pr-review-gate/declarations.md`（根拠ファイルの説明の 1 文）
- `plugins/dev-workflow/skills/develop/SKILL.md`（(4) の Status の一覧と分岐、モデルの表）
- `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`（Status の一覧・`次の段:` の表・段ごとの表・Status ごとの欄の書式の参照先）
- `plugins/dev-workflow/tests/pr-review-gate-skill.bats`・`develop-roles.bats`・`develop-skill.bats`（文面検査）、`risk-carryover-check.bats`（9 行目のコメントが指す Requirement 名の直しだけ）
- `plugins/dev-workflow/changes/1238.md`（変更の記録に追記。版は上げない）
- Codex の G（`scripts/codex-develop.py`・`references/codex-develop.md`）は変えない見込み。Codex の G は `gate-runner.md` と段のファイルを正本として受け取り、Status を受けて次を決めるのは Claude の本体なので、新しい Status は本体の (4) の分岐で扱える（実装時に確かめる）
- 新しい部品（ファイル）は足さないので `docs/public-private-split.md` の表は変えない
- 関連: issue #1238（記録先。PR は `Closes #1238`）、1 本目の change `risk-carryover-pr-own-diff`（PR #1282）、#722（`needs-fix-check` の形）
