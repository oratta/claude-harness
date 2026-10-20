## Why

エピック #1137 の仕組み（子の拒否の記録 → 親が許可を書く → 子を再開）が、通常の Claude Code の親セッションで動かない。Claude Code が全セッションの Bash に入れる `GIT_CONFIG_COUNT=2`（キーは `credential.interactive` と `credential.guiPrompt`）を、許可を書くスクリプトが「行き先・設定を変える環境変数」として毎回拒むため。また、拒否された子に、許可を受けられる打ち方の例（変数を使わない実パスの単独コマンド）が伝わらず、許可が書けない形で打ち続ける。issue #1165。

## What Changes

- 一時領域の判定の環境変数の条件で、`GIT_CONFIG_COUNT` / `GIT_CONFIG_KEY_<n>` / `GIT_CONFIG_VALUE_<n>` の組は、すべてのキーが無害なキーの一覧（`credential.interactive`・`credential.guiPrompt`）にあるときだけ、設定されていないものとして扱う。一覧にないキー、組の崩れ、`GIT_CONFIG`・`GIT_CONFIG_GLOBAL`・`GIT_CONFIG_PARAMETERS` などは今までどおり判定を落とす
- 子への拒否メッセージ（git の PreToolUse hook と rm の PermissionRequest hook の両方）に、親の許可を受けられる打ち方を 1 文で足す
- 範囲外: `cd <一時領域> && rm` の形の許可（#1159）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `destructive-git-hook`: 要件「許可を書くスクリプトは一時領域の中に収まるコマンドだけを許可する」の環境変数の条件と、要件「拒否理由は承認の取り方を案内する」の子への理由
- `rm-permission-hook`: 要件「子の rm の確認画面に、親の許可に従って答える」の deny の message

## Impact

- `plugins/dev-workflow/scripts/git-guard-scratchpad.py`（`_redirect_env`）
- `plugins/dev-workflow/scripts/git-destructive-guard.sh`、`plugins/dev-workflow/scripts/rm-permission-guard.sh`（子への拒否メッセージ）
- `plugins/dev-workflow/tests/git-destructive-guard.bats`、`plugins/dev-workflow/tests/rm-permission-guard.bats`
- hook と許可の仕組みは聖域なので、マージに主の承認が要る
