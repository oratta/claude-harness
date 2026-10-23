# Tasks

実装とテストはマージ済み（PR #1261）で、この change では変えない。各タスクは、仕様の文がマージ済みの実装・テストと食い違っていないかを確かめる作業である。食い違いが見つかったら実装ではなく仕様の文を直す（実装を変える要件は書かない）。

## 1. hook の要件と実装・テストの対応を確かめる

- [ ] 1.1 要件「コンパクト直後に develop を呼んでいた会話へ SKILL.md の読み直しを差し込む hook を登録する」の 2 つの Scenario が、hooks.json の matcher `compact` のエントリと、スクリプトの `source` の判定、bats の「hooks.json registers it under SessionStart for compact」「startup, clear and resume sources print nothing even with develop」に対応していることを、対応表を PR にコメントして確かめる。触る範囲: openspec/changes/develop-compact-reread-spec/specs/dev-workflow-develop/spec.md:3-12、plugins/dev-workflow/hooks/hooks.json:22-30、plugins/dev-workflow/scripts/develop-compact-reread.sh:34-42、plugins/dev-workflow/tests/develop-compact-reread.bats:116-123、plugins/dev-workflow/tests/develop-compact-reread.bats:171-180
- [ ] 1.2 要件「develop を呼んでいたかはコンパクト前の 3 種類の記録で判定する」の (a)〜(c) と 4 つの Scenario が、`called()` の 3 つの分岐と bats の Skill 呼び出し・文字列のコマンド・一覧の text のブロック・invoked_skills の 4 件に対応していることを、対応表に足して確かめる。触る範囲: openspec/changes/develop-compact-reread-spec/specs/dev-workflow-develop/spec.md:14-31、plugins/dev-workflow/scripts/develop-compact-reread.sh:44-70、plugins/dev-workflow/tests/develop-compact-reread.bats:42-60、plugins/dev-workflow/tests/develop-compact-reread.bats:72-76
- [ ] 1.3 要件「名前空間の無い develop・別のスキル・文中の言及は数えない」の 4 つの Scenario が、名前の完全一致（`NAME`・`CMD`）と、assistant の text・tool_result を見ない分岐、bats の名前空間なし・codex-develop と develop-epic・文中と tool_result・develop なしの 4 件に対応していることを、対応表に足して確かめる。触る範囲: openspec/changes/develop-compact-reread-spec/specs/dev-workflow-develop/spec.md:33-50、plugins/dev-workflow/scripts/develop-compact-reread.sh:44-70、plugins/dev-workflow/tests/develop-compact-reread.bats:62-70、plugins/dev-workflow/tests/develop-compact-reread.bats:92-114
- [ ] 1.4 要件「差し込む文は SKILL.md の読み直しと親か子かの確かめ直しを求める」の JSON の形と 2 つの要素が、出力の組み立てと bats の `assert_reread` が確かめる語（SKILL.md のパス・`offset`・`limit`・`親`・`子`・`記録先`）に一致することを、対応表に足して確かめる。触る範囲: openspec/changes/develop-compact-reread-spec/specs/dev-workflow-develop/spec.md:52-57、plugins/dev-workflow/scripts/develop-compact-reread.sh:95-98、plugins/dev-workflow/tests/develop-compact-reread.bats:28-40
- [ ] 1.5 要件「判定できないときは何も出さず、セッションの開始を止めない」の 6 つの Scenario が、スクリプトの早期 exit 0（`CLAUDE_PLUGIN_ROOT`・`python3`・stdin・JSON・`transcript_path`）と行ごとの例外の飛ばし、bats の stdin・会話記録なし・`CLAUDE_PLUGIN_ROOT` 空・`python3` なし・壊れた行・形の違う行の 6 件に対応していることを、対応表に足して確かめる。触る範囲: openspec/changes/develop-compact-reread-spec/specs/dev-workflow-develop/spec.md:59-84、plugins/dev-workflow/scripts/develop-compact-reread.sh:22-43、plugins/dev-workflow/scripts/develop-compact-reread.sh:72-100、plugins/dev-workflow/tests/develop-compact-reread.bats:78-90、plugins/dev-workflow/tests/develop-compact-reread.bats:125-169
- [ ] 1.6 要件「hook の振る舞いを bats で確かめる」について、`bats plugins/dev-workflow/tests/develop-compact-reread.bats` を実行し、全件が通ることを確かめる（実装とテストは変えない）。触る範囲: plugins/dev-workflow/tests/develop-compact-reread.bats:1-180

## 2. 下限の根拠の要件と手順書の対応を確かめる

- [ ] 2.1 MODIFIED の要件「時間がたった子・親への返事は待っている間の自動コンパクトの閾値と分ける条件で決める」の「根拠と限り」に足した文（hook の読み直しの差し込み・約 39k の費用と 40k とは別にかかること・#1264 での計算し直し・120,000 を変えない理由と #1217 の計算コメントの URL）が、reply-after-idle.md の記述と一致することを読んで確かめる。足した文以外が既存の要件と同じであることを `diff` で確かめる。触る範囲: openspec/changes/develop-compact-reread-spec/specs/dev-workflow-develop/spec.md:95-143、openspec/specs/dev-workflow-develop/spec.md:2165-2213、plugins/dev-workflow/skills/develop/references/reply-after-idle.md:55-66
- [ ] 2.2 `bats plugins/dev-workflow/tests/epic-dispatch.bats -f reply-after-idle` を実行し、規則のファイルの記述を確かめるテストが通ることを確かめる（実装とテストは変えない）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:3688-3730

## 3. 検証

- [ ] 3.1 `openspec validate develop-compact-reread-spec --type change --strict` が exit 0 で `is valid` を出すことを確かめる。触る範囲: openspec/changes/develop-compact-reread-spec/
- [ ] 3.2 `git diff origin/main --stat` で、変更が `openspec/changes/develop-compact-reread-spec/` の下だけで、`plugins/` の差分が無いことを確かめる。触る範囲: openspec/changes/develop-compact-reread-spec/

## Workflow follow-up

- 仕様レビューの APPROVE のあと archive し、`openspec/specs/dev-workflow-develop/spec.md` に delta が入ったことを確かめる
