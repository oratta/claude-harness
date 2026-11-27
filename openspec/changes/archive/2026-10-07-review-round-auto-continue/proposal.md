## Why

レビューは 2 周で打ち切り、残った指摘は主に上げる決まりになっている（仕様レビューは `spec-reviewer.md` の「3 周目の例外は設けない」、PR のレビューは `stages/triage.md` の収束ルール）。2026-09-16〜10-06 の 3 週間で、3 周目に進んでよいかの確認が約 10 件あり（週ごとに 2→5→8 件）、主の返事は全部「進めて」「許容する」「回す」だった。主への依頼が挙げる受け入れるリスクは「トークンが 1 周分増える」だけで、これは PR トークン上限（`scripts/pr-token-budget.sh`）がすでに見張っている。返事を待つ間、作業は止まっている（issue #722、親エピック #725）。

## What Changes

- 仕様レビューと PR のレビューの両方で、2 周目以降の周の終わりに止める指摘が残ったら、主に聞く前に決める役（`dev-workflow:decider`）が「残った指摘の直し方が決まっているか」を判定する（直し方の判定）。
- 判定が「決まっている」で PR トークン上限の内側（計測が exit 2 でない）なら、主に聞かずに次の周を回し、周の終わりに記録先へ事後報告のコメントを残す。
- 主に聞くのは、判定が「選び直しが要る」（設計の選択肢が複数ある、記録先の範囲を変える、前の周で「決まっている」とした直し方で閉じなかった）とき、判定が入力不足で出なかったとき、PR トークン上限を超えたとき（`pr-token-budget.sh` が exit 2）だけにする。
- 判定の記録（1 行目 `直し方の判定: 決まっている` / `直し方の判定: 選び直しが要る`）と事後報告（1 行目 `主に聞かずに回した周: <N> 周目`）の書式を `skills/develop/SKILL.md` に 1 か所だけ置く。
- PR のレビューでは、G が新しい Status `needs-fix-check` で本体に判定を依頼する。G が判定に回すのは、周の終わりに残った止める指摘のうち同じ型の再発（順 6）でないものが、1 周目なら順 2〜4 に当たる指摘だけのときに限る。それ以外は従来どおり順 5（主に切り出すかを聞く）。
- 仕分け表の順 6（同じ型の再発は決める役が方式を裁定する）と、その PR ごとに 1 回までの数え方は変えない。

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-spec-review`: 「仕様レビューは 2 周で確定し結果を issue に記録する」の 3 周目の禁止を、直し方の判定を通す続行に置き換える。
- `dev-workflow-pr-review-gate`: 収束ルール（3 周目を開ける条件）・2 周目終了時に止める指摘が残ったときの扱い・仕分け表の周の終わりの段落・G の指示書の Status と周回欄に、直し方の判定と `needs-fix-check` を足す。G 側の手順（判定に回す条件・裁定を受けた後の動き・順 6 との混在の処理順）を要件として足す。
- `dev-workflow-develop`: 1 ループの 2 周キャップの記述と、`spec-reviewer.md` の 2 周キャップの記述を直し方の判定つきに改め、本体の手順（判定役・入力・返答の 1 行目・判定の記録と事後報告の書式・`needs-fix-check` を受けた動き）を要件として足す。

## Impact

- `plugins/dev-workflow/skills/develop/references/roles/spec-reviewer.md`（往復の上限）
- `plugins/dev-workflow/skills/develop/SKILL.md`（1 ループの (2) と (4)、新しい節「レビューの周を主に聞かずに続ける（直し方の判定）」、保留で止まるときの引き継ぎの場面の一覧）
- `plugins/dev-workflow/skills/pr-review-gate/stages/triage.md`（周の終わりの段落・混在の段落・収束ルール・手順 2-2 の「2 周目が最終周」の理由・`needs-fix-check` のとき）
- `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`（Status・`次の段:` の表・段ごとの表・周回欄・レビュアーの要約受領の分岐）
- テスト: `plugins/dev-workflow/tests/spec-decision-and-review.bats`・`develop-skill.bats`・`pr-review-gate-skill.bats`・`develop-roles.bats`・`model-escalation-policy.bats`
- `plugins/dev-workflow/agents/decider.md` は変えない（直し方の判定は順 6 と同じ「可否と根拠」の契約で依頼する）
- 変更の記録: `plugins/dev-workflow/changes/722.md`
- 受け入れるリスク（主が 2026-10-07 に認めた）: 主が見ないまま 3 周目以降の修正が進む。止めるのはトークン上限と、方針の選び直しの判定だけになる。
