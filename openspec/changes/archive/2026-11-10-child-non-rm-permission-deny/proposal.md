# Proposal

## Why

`rm-permission-guard.sh`（PermissionRequest hook、matcher `Bash`）は、子（サブエージェント）のコマンドの単純コマンドの先頭の語が `rm` のときだけ答え、それ以外は何も出さずに本体の確認画面に任せる。2026-11-10、flatmate #2061 の作業者が `gh issue comment 2061 --body "$(printf '...')"`（rm を含まない）を打ったところ、本体の確認画面「Dangerous rm operation not ruled out — the shell may read this command differently than it was parsed」が出て、誰も見ていない子のセッションが約 30 分止まった。権限確認を省く起動モード（`--dangerously-skip-permissions`）でもこの確認は出るし、親の見張りは確認画面で止まった子を検知できない。

## What Changes

- 子の Bash の PermissionRequest で、コマンドの先頭の語が `rm` でなく、`permission_mode` が `bypassPermissions` のときは、`deny` と打ち直し方の理由を返す。理由には、既存の rm の判定に当たらないコマンドで確認が求められたこと・確認の原因が本文の引用や置換なら本文をファイルに書いて `--body-file` で渡すなどの形で打ち直せること・打ち直せなければ何をしたかったか（コマンドの全文）を報告に書いて親に返ることを書く
- 子でも `permission_mode` が `bypassPermissions` 以外のときの rm でない確認、主の呼び出しには今までどおり何も返さない（普通の権限確認を巻き込まない）
- 先頭の語が `rm` の子の確認への答え方（親の許可・拒否の記録）は変えない
- `hooks/hooks.json`（聖域）は触らない（登録済みの matcher `Bash` のままで足りる）

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `rm-permission-hook`: 要件「子の rm の確認画面に、親の許可に従って答える」の「rm でない確認には何も返さない」を、新しい要件に当たる場合を除く形に直す。新しい要件「子の rm でない確認画面は、権限確認を省くモードでは拒否する」「子の rm でない確認への deny は、許可と拒否の記録を使わない」「子の rm でない確認への拒否の理由に、打ち直し方と親に返る条件を書く」「確認を求めるモードの子と主の rm でない確認には答えない」を足す

## Impact

- `plugins/dev-workflow/scripts/rm-permission-guard.sh`（入口の判定と、rm でない確認への deny）
- `plugins/dev-workflow/tests/rm-permission-guard.bats`（新しい振る舞いと、変わらない振る舞いのテスト）
- `plugins/dev-workflow/changes/1610.md`（変更の記録）
- hook が実行するスクリプトを変えるので、PR は Ready にする前に `human-merge` を付けて主のマージ待ちで止める（親エピック #1476 の注意書き）
