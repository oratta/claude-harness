# Proposal

## Why

`plugins/dev-workflow/scripts/session-tripwires.sh`（SessionStart hook）は `{"additionalContext": …}` をトップレベルで出している。Claude Code（v2.1.327 で確認）が SessionStart の JSON 出力から文脈に足すのは `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": …}}` の形だけなので、昇格トリップワイヤー・Fable 残量モード・メモリの見直しの `[memory]` の 1 行が、どのセッションの開始時にもエージェントに届いていない（issue #1673。会話ログの hook_success の stdout には出ているが、文脈に入った印の attachment が無い）。#1654 で足した「`patches:` の issue が閉じたら知らせる」も同じ理由で見えない。仕様の要件自体がトップレベルの形を定めているので、仕様から直す。

## What Changes

- `session-tripwires.sh` の通常の出力（`TRIPWIRES_SCOPE` が `subagent-budget` 以外）を `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "<本文>"}}` にする。本文の中身・並び・fail-soft の条件は変えない
- `TRIPWIRES_SCOPE=subagent-budget` の本文テキスト出力は変えない
- この出力を読んで再注入する `prompt-tripwires-refresh.sh`（UserPromptSubmit hook）の読み取りを、新しい形の `hookSpecificOutput.additionalContext` に合わせる（片方だけ直すと、プラグイン更新時の再注入が無言で止まる）
- 出力の形を確かめているテストを新しい形に合わせ、`hookEventName == "SessionStart"` を確かめる検査を足す

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-escalation-tripwires`: 要件「SessionStart hook がトリップワイヤーを常駐注入する」の出力の JSON の形を `hookSpecificOutput` 入りに改め、シナリオで `hookEventName` を確かめる
- `dev-workflow-escalation-tripwires`: 要件「SubagentStart hook が dev-workflow の役に運用情報を注入する」の「`TRIPWIRES_SCOPE` が未設定、または `subagent-budget` 以外のときの出力は従来と変えない」を、出力の形は SessionStart の要件に従い、本文の中身と `subagent-budget` の本文テキスト出力は変えない、に改める。シナリオ「SessionStart の出力は変わらない」は名前を保ち（本文の中身が変わらないことを指す）、中身を`hookSpecificOutput.hookEventName` と `hookSpecificOutput.additionalContext` を見る形にする

## Impact

- コード: `plugins/dev-workflow/scripts/session-tripwires.sh`、`plugins/dev-workflow/scripts/prompt-tripwires-refresh.sh`
- テスト: `plugins/dev-workflow/tests/` の `tripwire-hook.bats`・`memory-tripwire.bats`・`usage-probe.bats`・`subagent-start-context.bats`（トップレベルの `additionalContext` を読んでいる箇所）。`prompt-tripwires-refresh.bats` は実物の `session-tripwires.sh` を写して走らせるので、読み取り側の追随漏れをそのまま検出する
- 振る舞い: 全セッションの開始時（startup / clear / compact）に、これまで届いていなかった本文が実際に文脈に入る。設計上は最初から入る前提の文面で、増えるのは実際に載る量だけ。`tests/injection-budget.bats` の測定対象（rules / CLAUDE.md / output-styles / description の 8 種）に hook の出力は含まれないので、予算値は変わらない
- 変更の記録: `plugins/dev-workflow/changes/1673.md`
