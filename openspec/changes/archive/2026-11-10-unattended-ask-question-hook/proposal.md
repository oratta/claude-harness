# Proposal

## Why

画面を見ている人がいないセッション（無人の印 `DEV_WORKFLOW_UNATTENDED` を起動する側が付けた flatmate の住人など）で AskUserQuestion が呼ばれると、選択肢の画面に誰も答えず、セッションが無期限に止まる。#1126 は develop の文面から channel の本体が AskUserQuestion に流れる経路を無くしたが、develop 以外のスキル（wt-clean など）が呼ぶことと、本体が文面に反して呼ぶことは機械的に止めておらず（#1126 の design.md の Non-Goals）、この change でそれを hook で止める。主の着手前承認の範囲は「印のあるセッションでは、どのスキルから呼ばれた AskUserQuestion でも hook で拒否し、質問はチャンネルに送ってターンを終える旨の理由を返す」（https://github.com/oratta/claude-harness/issues/1153#issuecomment-6756880983 ）。

## What Changes

- 新しい PreToolUse hook（matcher `AskUserQuestion`）を `plugins/dev-workflow/hooks/hooks.json` に登録する。hook の本体は新しいスクリプト `plugins/dev-workflow/scripts/unattended-ask-guard.sh`
- hook は、環境変数 `DEV_WORKFLOW_UNATTENDED` の印があるセッションでだけ、呼び出したスキルによらず AskUserQuestion を `deny` で拒否し、「打ち直さず、質問はチャンネルに送ってターンを終える」旨の理由を返す。印の読み方は git ガードと同じ（前後の空白を除いて未設定・空・`0` は印なし、それ以外は印あり）。印が無ければ何も出さずに通す
- develop の `references/channel.md`「channel の聞き方」に、印のあるセッションでは hook が AskUserQuestion を拒否すること、チャンネルの依頼だけで channel になったセッションには効かないことを書き足す。あわせて、AskUserQuestion に触れるファイルの列挙（読み替えの規則の対象）から、手順として読まれない hook の 2 ファイル（`hooks/hooks.json` と `scripts/unattended-ask-guard.sh`）を除くと書き、`tests/develop-channel-mode.bats` の検査もそれに合わせる
- 変更の記録 `plugins/dev-workflow/changes/1153.md` を足す。版は上げない

## Capabilities

### New Capabilities

- `unattended-ask-hook`: 無人の印のあるセッションで AskUserQuestion を PreToolUse hook が拒否し、チャンネルで聞く手順へ誘導する。印の読み方・対象範囲（全スキル）・拒否理由の中身・印が無いときに何もしないこと・守備範囲を定義する

### Modified Capabilities

- `dev-workflow-develop`: 要件「channel モードでは主に聞くときチャンネルに送り、AskUserQuestion を呼ばない」の守備範囲の文（「本体が文面に反して呼ぶことを機械的に止めることは範囲に入れない」）を、印のあるセッションでは `unattended-ask-hook` が止めると書き直し、AskUserQuestion に触れるファイルの列挙の除外に hook の 2 ファイルを足す

## Impact

- 新規: `plugins/dev-workflow/scripts/unattended-ask-guard.sh`、`plugins/dev-workflow/tests/unattended-ask-guard.bats`、`plugins/dev-workflow/changes/1153.md`
- 変更: `plugins/dev-workflow/hooks/hooks.json`（PreToolUse に 1 項目）、`plugins/dev-workflow/skills/develop/references/channel.md`、`plugins/dev-workflow/tests/develop-channel-mode.bats`
- 触らない: `plugins/dev-workflow/scripts/git-destructive-guard.sh`（印の読み方は写すだけで共有部品にしない。Draft PR #1463 と重ならない）、`rules/`・`CLAUDE.md`・`output-styles/`・description（常時注入の予算 `tests/injection-budget.bats` に影響しない）
- hook が実行するスクリプトを変える PR なので、Ready にする前に主のマージ待ちとして止める（human-merge）
- 効く範囲: dev-workflow プラグインを入れたすべてのセッション。印を付けていないセッション（主が画面の前にいる対話のセッション）の振る舞いは変わらない
