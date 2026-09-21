## Why

pr-review-gate がレビュアー（Codex CLI または Task サブエージェント）に課しているのは「受け入れ条件を根拠に落とせる欠陥を探す」「欠陥ありなら再現手順と修正点を書いて failed」の 2 行だけで、指摘の書き方が決まっていない（issue #349）。そのため深刻度・網羅・直し方の粒度・検証済みか推測かの区別がレビュアーの裁量になり、改善提案レベルの指摘でも failed になる、直したら別の箇所が次の周で出る、直し方を W が推測して外す、誤検出と本物が同じ重さで並ぶ、が起きている。

加えて #351 で入った収束ルールは「1 周目は一般則（欠陥ありなら failed）、2 周目からは引用による仕分け」と周ごとに判定を分けている。主と確認した方針（issue #349 のコメント「判定は全周で同じにする」、2026-09-21）は、**マージを止めるかの判定は 1 周目から全周共通**で、周によって変わるのは止める指摘が残ったときの動き方だけ、というもの。

## What Changes

- レビュアーの指摘 1 件ごとに固定書式を課す: 見出し（命令形 1 行）・深刻度（`blocking` / `should` / `nit`）・検証（`confirmed` / `plausible`）・根拠（`blocking` のとき必須。受け入れ条件または spec の原文の引用、または例外 3 種のどれか）・場所・何が起きるか・直し方。再レビューでは各指摘に状態（`fixed` / `unresolved` / `wontfix`）を足す。書式の正本は SKILL.md 手順 2-1 に 1 か所だけ置く
- **判定を全周共通にする**: マージを止めるのは「`blocking`（G が引用を確認できる）かつ `confirmed`」の指摘だけ。例外として安全機構の穴・データ破壊・無言の機能不全は、引用できなくても `blocking` として扱う。それ以外は follow-up issue。判定の文は SKILL.md に 1 か所だけ書き、収束ルールの仕分けはそれを参照する
- 周によって変わるのは動き方だけにする: 1 周目に止める指摘が残れば failed にして W が直す。2 周目と主の続行指示で開いた周は、#351 の収束ルールどおり `needs-approval` で止まり主に聞く。**BREAKING**（運用上）: 1 周目でも `should` / `nit`、`plausible`、引用できない `blocking` は failed の理由にならなくなる
- #351 が SKILL.md に足した「この一般則は1周目に適用する。2周目…は収束ルールが優先する」の一文を、全周共通の判定への参照に置き換える
- 1 周目は該当する指摘を全部列挙するまで止まらないこと、再レビューは前回指摘の閉鎖確認に限り新規 `nit` を出さない（全体レビューに戻っても新規に出してよいのは `blocking` だけ）こと、「直し方」どおりに直した箇所は再指摘しないことをレビュアーへの指示に入れる
- Codex への指示文の雛形（`references/subagent-waiting.md`）と、Task サブエージェントをレビュアーにする経路（`gate-runner.md` の needs-reviewer）の両方で、同じ書式と全件列挙の 1 文を渡す
- `codex exec` 直叩きで Codex 公式ルーブリック（`[P0]`〜`[P3]`・`confidence_score`・全件列挙）が適用されるかを実測し、結果で分岐する（適用されないなら指示文に書式を書く。適用されるなら Codex の JSON から固定書式への対応表を SKILL.md に置く）
- `gate-runner.md` の needs-reviewer 節の要約受領（「手順 3 以降を続ける」の無条件指示）を再開節の分岐への参照にして、分岐を 1 か所にする（issue #352 を同梱）

範囲外: R1 の観点に守備範囲を足すこと（#287）、PR 単位のトークン累計で止める仕組み（#288）、新 Codex モード（App Server）の review thread の指示文、`agents/decider.md` の出力契約、手順 2-2（原因分類とモデル昇格）の中身。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-pr-review-gate`: レビュアーの出力書式と全周共通の判定を要件に足し、2 周目終了時の仕分けと G の指示書の要件をその判定への参照に書き換える

## Impact

- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`: 手順 2-1（固定書式・深刻度表・判定・143 行目の一文・レビュアーへの指示）、収束ルール節（「2周目の終わりにやること」の仕分けを判定への参照に）、手順 5（合格条件に判定を明記）
- `plugins/dev-workflow/references/subagent-waiting.md`: 58 行目の指示文雛形
- `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`: needs-reviewer 節（payload とレビュー要約受領の記述）、再開節の「レビュアーの要約受領」
- `openspec/specs/dev-workflow-pr-review-gate/spec.md`（archive 時に delta を反映）
- テスト: `plugins/dev-workflow/tests/pr-review-gate-skill.bats`、`plugins/dev-workflow/tests/develop-roles.bats`
- `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の version（2.13.16 → 2.13.17）、`CHANGELOG.md`
