## Why

develop スキルの作業者（W）が本体に成果を返す区切りは、いま「(1) 仕様化まで」と「(3) 実装から PR 作成までの全部」の 2 つしかない。(3) は TDD 実装 → verify → archive → PR → 仕様宣言の 5 段階を 1 回の return で束ねているため、本体がコンテキスト量を測れる機会（return の直後）が (3) の中に 1 つも無い。監査（2026-08-31〜09-05）では W の平均コンテキストが 33 万トークンで、消費の 3 分の 2 が 30 万トークン超のリクエストだった。膨張の大半は実装区間で起きるので、コードを書き終えた区切りで測れるようにする。

## What Changes

- 1 ループの (3) を **(3a) 実装＋verify** と **(3b) archive＋PR＋仕様宣言** の 2 段に分け、W が 2 回 return する
- 本体は (3a) の return を受けたあと、(3b) を指示する SendMessage の前に `scripts/subagent-context.sh <W の名前>` でコンテキスト量を測る。上限超なら再開せず手渡す（手渡しの規則そのものは既存どおり `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本で、本文を増やさない）
- (3a) の return には**実行したテストコマンドと exit code**を含めさせる（手渡し先が verify をやり直さずに (3b) から続けられるようにする唯一の入力）
- `工程完了:` の 1 行目に載る工程名が「(1) 仕様化まで／(3a) 実装＋verify／(3b) archive＋PR＋仕様宣言」の 3 つになる
- **これより細かく（タスク単位で）切らない。** 手渡しのたびに固定分（指示書の再読・記録先の再取得・`git status` / `git diff` の再確認）と再オリエンテーションの費用がかかり、品質が保たれた証拠は 1 セッション分しか無いため

## Capabilities

### New Capabilities

（無し）

### Modified Capabilities

- `dev-workflow-develop`: 1 ループの規定（(3) が 1 回の return）を (3a)/(3b) の 2 回に改める。あわせて `worker.md` が (3a)/(3b) それぞれの return 内容を列挙する義務と、SKILL.md が (3a) と (3b) のあいだの計測手順を書く義務を足す

## Impact

- `plugins/dev-workflow/skills/develop/SKILL.md`（1 ループ (3)）
- `plugins/dev-workflow/skills/develop/references/roles/worker.md`（実装の節・PR と仕様宣言の節・コンテキスト上限と手渡しの節）
- `plugins/dev-workflow/README.md`（1 ループの 1 行説明）
- `plugins/dev-workflow/.claude-plugin/plugin.json`（description と version）
- `plugins/dev-workflow/tests/develop-skill.bats` / `develop-roles.bats`（(3a)/(3b) の記述を固定する検査を足す）
- 隣の子 issue #263（手渡しの規則を `decision-criteria.md` 1 箇所に畳む）が同じファイル群を触るため、この change では手渡しの規則の本文を新しく増やさない
