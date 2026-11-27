# Proposal

## Why

エピックの子（別セッション方式の子セッション）は、待っている間の自動コンパクト（Claude Code が止まったセッションの会話を約 54 分後に要約へ置き換える機能。以下「アイドル時のコンパクト」）のあと、develop の `SKILL.md` の中身を持たないまま、要約だけを頼りにゲートの実行まで進んでいた（2026-10-23 の issue-1244 の子のログ。#1323）。#1039 は子の閾値を 120,000 にし、コンパクトされた子にはそのまま返事を送ると決めたが、手順を守る前提と合わない。起動し直しとの費用の差は 1 回あたり約 $0.5 で、1 時間以上たってから返事が来る止まり方は子全体の 3.2% なので、#1039 の決定を覆す。

## What Changes

- `epic-dispatch.sh launch`（と、端末が無い子を起動し直す `reply`）が作る子の起動コマンドから `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=<値>` を外し、`<cmd> --settings '{"idleCompaction":false}' --model '<model>'` にする。子のプロセスだけでアイドル時のコンパクトを切り、通常の自動コンパクト（会話が上限に近づいたときのもの）は止めない
- **BREAKING**: 環境変数 `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS`（子の閾値の上書き）と、その値の検査（空・数字以外で exit 1）を消す。設定されていても無視する
- `references/reply-after-idle.md` の子への返事の分け方を「端末が無い → 起動し直す / 60 分未満 → そのまま送る / 60 分以上 → コンパクトの有無と会話量によらず起動し直す」にし、根拠（コンパクトされた子は `SKILL.md` の中身を持たない）を書く。親は今の分け方（コンパクトの有無と会話量 150,000 で分ける）と閾値（120,000、主の起動コマンドが入れる）のまま、親向けの表として分けて残す
- `wait --resolve` が親の代わりに通す返事の起動し直しの判定を子の表に合わせ、最後のリクエストから 60 分以上なら起動し直す。**BREAKING**: `EPIC_DISPATCH_RELAUNCH_MIN_TOKENS` とその検査を消す（`EPIC_DISPATCH_RELAUNCH_IDLE_SEC` は残す）
- `references/epic.md` の子の起動コマンドを書いた文（`nested` の説明・起動コマンドの説明・`epic-dispatch.sh` が足す引数の説明）を新しい形に合わせる。issue の「SKILL.md の該当する 1 文」は、今の `SKILL.md` に当たる文が無く（#1219 で `references/epic.md` に移っている）、`references/epic.md` の文を直す

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-develop`: 子の起動コマンドの形（要件「エピックの並列起動は 1 段で止める」と「launch は worktree create が作った空のシェルの端末を…」の Scenario）、時間がたった子・親への返事の規則（要件「時間がたった子・親への返事は待っている間の自動コンパクトの閾値と分ける条件で決める」）、`wait --resolve` の起動し直しの判定（要件「wait --resolve は通す返事を送る前に起動し直すかを表で決める」）

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（冒頭のコメント、`agent_setup`、`decide_relaunch`、`wait` の引数の検査）
- `plugins/dev-workflow/skills/develop/references/reply-after-idle.md`、`plugins/dev-workflow/skills/develop/references/epic.md`
- `plugins/dev-workflow/tests/epic-dispatch.bats`、`plugins/dev-workflow/tests/develop-skill.bats`
- `plugins/dev-workflow/changes/1323.md`（新規）
- 主の手元のセッション・親・`~/.claude/settings.json`・主の起動コマンド（`cld`）は変えない。この変更より前に起動された子は、従来どおり閾値 120,000 のアイドル時のコンパクトで動く
- Claude Code は v2.1.290 以降が要る（`idleCompaction` の設定キーが入った版）
