# Tasks

実装とテストはマージ済み（PR #1261）で、この change では変えない。各タスクは、仕様の文がマージ済みの実装・テストと食い違っていないかを確かめる作業である。食い違いが見つかったら実装ではなく仕様の文を直す（実装を変える要件は書かない）。

## 1. hook の要件と実装・テストの対応を確かめる

- [x] 1.1 要件「コンパクト直後に develop を呼んでいた会話へ SKILL.md の読み直しを差し込む hook を登録する」の 2 つの Scenario が、hooks.json の matcher `compact` のエントリとスクリプトの `source` の判定、bats のテストに対応していることを、tasks.md の対応表に書いて確かめる。触る範囲: openspec/changes/develop-compact-reread-spec/specs/dev-workflow-develop/spec.md:3-12、openspec/changes/develop-compact-reread-spec/tasks.md「対応表」、plugins/dev-workflow/hooks/hooks.json:22-30、plugins/dev-workflow/scripts/develop-compact-reread.sh:34-42、plugins/dev-workflow/tests/develop-compact-reread.bats:116-123、plugins/dev-workflow/tests/develop-compact-reread.bats:171-180
- [x] 1.2 要件「develop を呼んでいたかはコンパクト前の 3 種類の記録で判定する」の (a)〜(c) と 4 つの Scenario が、`called()` の 3 つの分岐と bats の 4 件に対応していることを、tasks.md の対応表に書いて確かめる。触る範囲: openspec/changes/develop-compact-reread-spec/specs/dev-workflow-develop/spec.md:14-31、openspec/changes/develop-compact-reread-spec/tasks.md「対応表」、plugins/dev-workflow/scripts/develop-compact-reread.sh:44-70、plugins/dev-workflow/tests/develop-compact-reread.bats:42-60、plugins/dev-workflow/tests/develop-compact-reread.bats:72-76
- [x] 1.3 要件「名前空間の無い develop・別のスキル・文中の言及は数えない」の 4 つの Scenario と、要件「develop を呼んでいたかの判定の守備範囲」の 4 つの Scenario が、名前の完全一致（`NAME`・`CMD`）、assistant の text・tool_result を見ない分岐、bats のテストに対応していることを、tasks.md の対応表に書いて確かめる。守備範囲の Scenario のうち bats に無いものは、実装の行に対応させる。触る範囲: openspec/changes/develop-compact-reread-spec/specs/dev-workflow-develop/spec.md:33-69、openspec/changes/develop-compact-reread-spec/tasks.md「対応表」、plugins/dev-workflow/scripts/develop-compact-reread.sh:44-93、plugins/dev-workflow/tests/develop-compact-reread.bats:49-53、plugins/dev-workflow/tests/develop-compact-reread.bats:62-70、plugins/dev-workflow/tests/develop-compact-reread.bats:92-114
- [x] 1.4 要件「差し込む文は SKILL.md の読み直しと親か子かの確かめ直しを求める」の JSON の形と 2 つの要素が、出力の組み立てと bats の `assert_reread` が確かめる語（SKILL.md のパス・`offset`・`limit`・`親`・`子`・`記録先`）に一致することを、tasks.md の対応表に書いて確かめる。触る範囲: openspec/changes/develop-compact-reread-spec/specs/dev-workflow-develop/spec.md:71-76、openspec/changes/develop-compact-reread-spec/tasks.md「対応表」、plugins/dev-workflow/scripts/develop-compact-reread.sh:95-98、plugins/dev-workflow/tests/develop-compact-reread.bats:28-40
- [x] 1.5 要件「判定できないときは何も出さず、セッションの開始を止めない」の 6 つの Scenario が、スクリプトの早期 exit 0（`CLAUDE_PLUGIN_ROOT`・`python3`・stdin・JSON・`transcript_path`）と行ごとの例外の飛ばし、bats の 6 件に対応していることを、tasks.md の対応表に書いて確かめる。触る範囲: openspec/changes/develop-compact-reread-spec/specs/dev-workflow-develop/spec.md:78-103、openspec/changes/develop-compact-reread-spec/tasks.md「対応表」、plugins/dev-workflow/scripts/develop-compact-reread.sh:22-43、plugins/dev-workflow/scripts/develop-compact-reread.sh:72-100、plugins/dev-workflow/tests/develop-compact-reread.bats:78-90、plugins/dev-workflow/tests/develop-compact-reread.bats:125-169
- [x] 1.6 要件「hook の振る舞いを bats で確かめる」について、`bats plugins/dev-workflow/tests/develop-compact-reread.bats` を実行し、全件が通ることを確かめる（実装とテストは変えない）。触る範囲: openspec/changes/develop-compact-reread-spec/specs/dev-workflow-develop/spec.md:105-110、plugins/dev-workflow/tests/develop-compact-reread.bats:1-180

## 2. 下限の根拠の要件と手順書の対応を確かめる

- [x] 2.1 MODIFIED の要件「時間がたった子・親への返事は待っている間の自動コンパクトの閾値と分ける条件で決める」の「根拠と限り」に足した文（hook の読み直しの差し込み・約 39k の費用と 40k とは別にかかること・#1264 での計算し直し・120,000 を変えない理由と #1217 の計算コメントの URL）が、reply-after-idle.md の記述と一致することを読んで確かめる。足した文以外が既存の要件と同じであることを `diff` で確かめる。触る範囲: openspec/changes/develop-compact-reread-spec/specs/dev-workflow-develop/spec.md:114-162、openspec/specs/dev-workflow-develop/spec.md:2165-2213、plugins/dev-workflow/skills/develop/references/reply-after-idle.md:55-66
- [x] 2.2 `bats plugins/dev-workflow/tests/epic-dispatch.bats -f reply-after-idle` を実行し、規則のファイルの記述を確かめるテストが通ることを確かめる（実装とテストは変えない）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:3688-3730

## 3. 検証

- [x] 3.1 `openspec validate develop-compact-reread-spec --type change --strict` が exit 0 で `is valid` を出すことを確かめる。触る範囲: openspec/changes/develop-compact-reread-spec/
- [x] 3.2 `git diff origin/main --stat` で、変更が `openspec/changes/develop-compact-reread-spec/` の下だけで、`plugins/` の差分が無いことを確かめる。触る範囲: openspec/changes/develop-compact-reread-spec/

## 対応表

各 Scenario を、確かめる bats のテスト名（`plugins/dev-workflow/tests/develop-compact-reread.bats`）か、bats に無いものは実装の行（`plugins/dev-workflow/scripts/develop-compact-reread.sh`・`plugins/dev-workflow/hooks/hooks.json`）に対応させる。行番号は仕様づくりの時点の値。タスク 1.1〜1.5 で実物と照らし、食い違えばこの表か仕様の文を直す。

| 要件 | Scenario | bats のテスト名 | 実装の行 |
|---|---|---|---|
| hook を登録する | hooks.json が compact の SessionStart に登録している | hooks.json registers it under SessionStart for compact | hooks.json:22-30 |
| hook を登録する | compact 以外の起動では何も出さない | startup, clear and resume sources print nothing even with develop | develop-compact-reread.sh:38-39 |
| 3 種類の記録で判定する | Skill 呼び出しで数える | compact after a Skill call of dev-workflow:develop injects the reread instruction | develop-compact-reread.sh:51-55 |
| 3 種類の記録で判定する | 文字列の user の発言のコマンドで数える | compact after the /dev-workflow:develop command injects the reread instruction | develop-compact-reread.sh:56-58 |
| 3 種類の記録で判定する | 一覧の user の発言の text のブロックのコマンドで数える | the command in a text block of a list-form user message counts | develop-compact-reread.sh:59-63 |
| 3 種類の記録で判定する | 前のコンパクトのあとの invoked_skills で数える | compact after an earlier compaction's invoked_skills record injects the reread instruction | develop-compact-reread.sh:64-69 |
| 数えない | 名前空間の無い develop は数えない | a develop without the dev-workflow namespace does not count | develop-compact-reread.sh:44-45 |
| 数えない | 名前に develop を含む別のスキルは数えない | other skills whose name contains develop do not count | develop-compact-reread.sh:44-45 |
| 数えない | 文中や tool_result で触れただけなら数えない | develop only mentioned in text or tool results does not count | develop-compact-reread.sh:51-63（tool_use と text のブロックだけを見る） |
| 数えない | develop を呼んでいない会話では何も出さない | compact in a conversation without develop prints nothing | develop-compact-reread.sh:92-93 |
| 判定の守備範囲 | 呼び終えたあと別の作業をしていても毎回差し込む | （なし） | develop-compact-reread.sh:72-89（会話記録の全体のどこかに 1 つあれば数える） |
| 判定の守備範囲 | 手で打ったコマンドの文字列は呼び出しとして数える | compact after the /dev-workflow:develop command injects the reread instruction | develop-compact-reread.sh:56-58 |
| 判定の守備範囲 | SKILL.md を Read で読んだだけの会話は数えない | （なし） | develop-compact-reread.sh:51-55（Skill の tool_use だけを見て、Read の tool_use は見ない） |
| 判定の守備範囲 | 会話記録の形が変わって判定が外れても止めない | valid JSON lines of an unexpected shape do not stop the scan | develop-compact-reread.sh:83-93 |
| 差し込む文 | 差し込む文が 2 つの要素を含む | （全件の `assert_reread`） | develop-compact-reread.sh:95-98 |
| 判定できないとき | stdin が JSON でなければ何も出さない | stdin that is not JSON prints nothing | develop-compact-reread.sh:28-29、34-37 |
| 判定できないとき | 会話記録が無ければ何も出さない | missing transcript prints nothing | develop-compact-reread.sh:40-42 |
| 判定できないとき | CLAUDE_PLUGIN_ROOT が空なら何も出さない | empty CLAUDE_PLUGIN_ROOT prints nothing | develop-compact-reread.sh:24-25 |
| 判定できないとき | python3 が無ければ何も出さない | python3 not on PATH prints nothing | develop-compact-reread.sh:26 |
| 判定できないとき | 壊れた行を飛ばして走査を続ける | broken lines in the transcript are skipped | develop-compact-reread.sh:79-82 |
| 判定できないとき | 形の違う行を飛ばして走査を続ける | valid JSON lines of an unexpected shape do not stop the scan | develop-compact-reread.sh:83-86 |
| bats で確かめる | bats が通る | （ファイル全体） | — |

## Workflow follow-up

- 仕様レビューの APPROVE のあと archive し、`openspec/specs/dev-workflow-develop/spec.md` に delta が入ったことを確かめる
