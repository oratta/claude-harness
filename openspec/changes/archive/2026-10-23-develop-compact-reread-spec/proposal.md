# Proposal

## Why

#1217 の変更（PR #1261 でマージ済み、merge commit ea0d9b08）は、当時 openspec CLI が入っていなかったので仕様化せずにコードへ直行した。コンパクトのあと、Claude Code が貼り直すのは呼んだスキルの入口と小さい最近読んだファイルだけで、develop の SKILL.md 本体は要約に置き換わる。要約の上では読んだことになっているので、モデルは読み直さずに進む。これを防ぐ hook と、それに伴って待っている間の自動コンパクトの下限を据え置いた根拠が、仕様に無いまま動いている。いまは openspec CLI（1.14.1）があるので、主の指示でマージ済みの振る舞いを仕様として書き起こす。実装とテストは変えない。

## What Changes

- 既存 capability `dev-workflow-develop` に、コンパクト直後に develop の SKILL.md の読み直しを差し込む SessionStart hook（`plugins/dev-workflow/scripts/develop-compact-reread.sh`、`plugins/dev-workflow/hooks/hooks.json` の matcher `compact`）の要件を足す。何を「develop を呼んでいた」と数えるか、何を数えないか、判定できないときに何も出さないこと（fail-open）、差し込む文の 2 つの要素（SKILL.md の読み直しと、エピックの親か子かの確かめ直し）を要件にする
- 既存の要件「時間がたった子・親への返事は待っている間の自動コンパクトの閾値と分ける条件で決める」の、`references/reply-after-idle.md` に書く「根拠と限り」に、読み直しの費用を入れても 120,000 を変えない根拠を足す（マージ済みの記述に合わせる）
- 実装・テスト・hooks.json・SKILL.md・reply-after-idle.md は変えない

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-develop`: コンパクト直後の SKILL.md の読み直しを差し込む hook の要件を足す（ADDED）。待っている間の自動コンパクトの閾値の要件の「根拠と限り」に、読み直しの費用と 120,000 を据え置く根拠を足す（MODIFIED）

## Impact

- 仕様: `openspec/specs/dev-workflow-develop/spec.md`（archive 時に delta が入る）
- コード: なし。仕様はマージ済みの `plugins/dev-workflow/scripts/develop-compact-reread.sh`・`plugins/dev-workflow/hooks/hooks.json`・`plugins/dev-workflow/tests/develop-compact-reread.bats`・`plugins/dev-workflow/skills/develop/references/reply-after-idle.md` の振る舞いに合わせて書く
