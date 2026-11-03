## Why

主（判断を下す人間のオーナー）が「意味わからん」「説明して」と返しても、Claude は同じ言葉のまま説明し直し、言い直しが何度も続く（過去 90 日で 9 場面・言い直しを含め 12 回。親エピック #1176 の背景）。書き方の正本（`output-styles/readable.md` の節 3）は PR #1179 で直したが、正本は常時載っているだけで、「いま伝わらなかった」という瞬間には目立たない。主の発言に伝わっていない合図があったときだけ、その場で正本の型での言い直しを促す。

## What Changes

- dev-workflow プラグインに `UserPromptSubmit` hook のスクリプト `scripts/unclear-reply-rephrase.sh` を足し、`hooks/hooks.json` の `UserPromptSubmit` に 2 件目のエントリとして登録する
- 主の発言に決めた語（「わからん」「意味がわから」「説明して」「読みにくい」など）があるときだけ、「直前の説明は伝わっていない。正本（`~/.claude/output-styles/readable.md` の節 3）の型で、子の作業の言葉を使わずに言い直す」旨の文を `additionalContext` で差し込む。語が無い発言では何も出さない
- 差し込む文は正本の場所を指すだけで、型の中身（6 段の名前・理由の 3 つなど）を写さない
- hook は失敗しても発言の送信を止めない（どの経路でも exit 0）
- bats のテストを足す。公開版と個人版の仕分けの文書（`docs/public-private-split.md`）の、dev-workflow の hook の配線先の本数の記述を直す

## Capabilities

### New Capabilities
- `dev-workflow-unclear-reply-rephrase`: 主の発言に説明が伝わっていない合図の語があるときだけ、正本の型での言い直しを促す文を差し込む `UserPromptSubmit` hook（配線・語の判定・差し込む文の中身・失敗時の振る舞い）

### Modified Capabilities

（なし。既存の `UserPromptSubmit` のエントリ `prompt-tripwires-refresh.sh`〈`dev-workflow-escalation-tripwires`〉は変えず、その後ろに足す）

## Impact

- 足す: `plugins/dev-workflow/scripts/unclear-reply-rephrase.sh`、`plugins/dev-workflow/tests/unclear-reply-rephrase.bats`、`plugins/dev-workflow/changes/1184.md`
- 直す: `plugins/dev-workflow/hooks/hooks.json`（`UserPromptSubmit` に 1 件足す）、`docs/public-private-split.md`（配線先の本数）
- 聖域（人の承認なしに変えてはならない設定や決まり）の hooks に触るので、PR のマージは主が行う
- 常時注入の固定分（`tests/injection-budget.bats` が測る rules・CLAUDE.md・output-styles・description）は増えない。差し込みは語に当たった発言のときだけで、1 回あたり約 500 バイト
- 対象外: 親エピック #1176 のもう一方の子 #1183（子の停止の記録の `主に聞く理由:`・手順 8・parent-pass-criteria.md）と issue #1181
