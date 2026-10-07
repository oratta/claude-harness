## Why

pr-review-gate の手順 3（`skills/pr-review-gate/declarations.md`）は、7 つの分類（プロダクトのユーザーに及ぶ影響・データ喪失・課金/法務・外部公開面の変化・資格情報への接触・安全ゲートの弱体化・エージェント権限の拡張）のどれかに当たれば、必ず「主のリスク許容が必要」にして保留する。機能の目的そのものが権限の拡張やゲートの変更である issue（#420・#522・#568 など）でも、PR の段階でもう一度聞いている。2026-09-16〜10-06 の 3 週間で、初めてのリスク宣言に提案どおり「許容」とだけ返した例が 34 件あり、「許容しない」と答えた例は無く、主が中身を確かめたのは 2 件だけだった（issue #723、エピック #725）。主が書いたか承認した issue に目的として書いてある効果は、その承認で許容済みとして扱い、聞くのは issue に書かれていなかった影響と、外に及ぶ影響（外部公開面・データ喪失・課金/法務・プロダクトのユーザー）に絞る。

## What Changes

- 手順 3 の宣言に「issue で承認済み」の状態を足す。当てられるのは資格情報への接触・安全ゲートの弱体化・エージェント権限の拡張の 3 分類だけで、外部公開面の変化・データ喪失・課金/法務・プロダクトのユーザーに及ぶ影響は issue に書いてあっても主に聞く
- 「issue で承認済み」を当てる条件を 3 つ置く: (1) issue の本文がその効果を目的として書いている（該当の文を宣言に引用する） (2) 主がその issue を承認した証拠が会話ログにある（主が起票を承認した、または主が自分で `/develop <番号>` を打った。確認は #721 の `owner-reply-check.sh` の exit 0） (3) 実装中に発覚した影響ではない
- `agent-proposed` のままの issue と、主の承認の記録が無いままエージェントが起こした issue（エピックの親が自動で起こした子など）には当てない。Orca の親セッションが子に打ち込んだ `/develop` と、無人ループの `/develop --unmanned` は主の打ち込みとして数えない
- 宣言の書式は「主のリスク許容が必要。」のまま残し（リスクなしに書き換えない）、末尾に「issue で承認済み」の 3 行（目的の引用・承認の証拠・真正性確認）を追記する。保留（`needs-approval`）にせず手順 4・5 へ進む
- 手順 5 の合格条件の表に「issue で承認済み」の行を足し、合格のあと主に事後報告する（宣言のリンクと引用を 1 回で伝える）
- 手順 6・3-c（`stages/hold.md`）に、この状態の宣言は保留に入らないこと、引き継ぎの元にはせず新しい HEAD で判定し直すことを書く。試す順は 3-c の引き継ぎ → 「issue で承認済み」 → 手順 6 とする
- unmanned（develop の `--unmanned`）のゲートでは「issue で承認済み」を当てない（事後報告の載せ先が無いため）
- develop の本体は、G の passed の return に `issue で承認済み:` の行があれば、CI の見張りを始める前に主へ 1 回伝える

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 手順 3 のリスク宣言に「issue で承認済み」の状態と当てる条件・書式を足し（既存要件「リスク宣言は 7 観点で判定し、新 3 観点も主のリスク許容待ちに流す」を変える）、手順 5 の合格条件と事後報告、手順 6・3-c との関係を足す
- `dev-workflow-develop`: 要件「G が passed を返したら本体が CI を見張る」に、return の `issue で承認済み:` の行を見張りの前に主へ伝えることを足す

## Impact

- 変更: `plugins/dev-workflow/skills/pr-review-gate/declarations.md`（手順 3）、`plugins/dev-workflow/skills/pr-review-gate/stages/pass.md`（手順 5 の表・確認の段落・G の return）、`plugins/dev-workflow/skills/pr-review-gate/stages/hold.md`（入口・3-c・手順 6）、`plugins/dev-workflow/skills/develop/SKILL.md`（(4) の passed の行）、`plugins/dev-workflow/tests/pr-review-gate-skill.bats`、必要なら develop の SKILL.md の文言を固定している bats
- 新規: `plugins/dev-workflow/changes/723.md`
- 依存: #721 で入った `plugins/dev-workflow/scripts/owner-reply-check.sh`（変更しない）。issue 本文の最終編集日時は `gh api graphql` の `lastEditedAt` で取る
- 安全面: 合格条件を緩める変更なので、この PR 自体が「安全ゲートの弱体化」に当たり主の許容で保留になる見込み。受け入れるリスク（主が 2026-10-07 の会話で認めた）: 主が一度も見ないまま、権限を広げる変更が main に入る機会が増える。事後報告で気づけるが、事前には止まらない
