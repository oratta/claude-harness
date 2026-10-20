## Why

子（サブエージェント）の `rm` は、`cd <dir>; rm … <rel>/*` のような形だと Claude Code 本体の確認画面（Dangerous rm operation on statically-unresolvable target）で止まる（flatmate #701）。#1133 で git の破壊的操作には「親が一時領域の中と確かめて 1 回だけ許可する」仕組みを入れたが、`rm` の確認画面は PreToolUse hook では通せない。#1132 の実機確認で、この確認画面には `PermissionRequest` hook（matcher Bash）が allow / deny で答えられると分かった。親の許可を `rm` にも効かせる。

## What Changes

- `PermissionRequest` hook `rm-permission-guard.sh` を追加する。子の呼び出しで先頭の語が `rm` のコマンドにだけ答え、#1133 と同じ key の許可が一致し、使う時点の rm 用の一時領域の判定も満たせば allow、そうでなければ deny と「何を・なぜ消したかったかを報告に書いて親に返す」理由（と拒否の記録のパス）を返す。主の呼び出しと `rm` でない確認には何も返さない
- `git-guard-scratchpad.py` に rm 用の一時領域の判定を足す（削除先を絶対パスに解決し、scratchpad の中かを見る。`cd` が失敗した場合の基準でも見る）
- `git-guard-permit.sh` が、記録のコマンドに `rm` を含むとき rm 用の判定で許可を書く（git のコマンドの扱いは変えない）
- `hooks.json` に `PermissionRequest` を登録する
- 範囲外: 拒否されて返った子を親が判断して許可・再開する develop の手順（#1135）。deny の繰り返しを数えての打ち切りは作らない

## Capabilities

### New Capabilities
- `rm-permission-hook`: 子の rm の確認画面に親の許可に従って答える hook と、rm の一時領域の判定

### Modified Capabilities
- `destructive-git-hook`: 許可を書くスクリプトが、`rm` のコマンドの記録には rm 用の判定を使う

## Impact

- `plugins/dev-workflow/hooks/hooks.json`、`scripts/rm-permission-guard.sh`（新規）、`scripts/git-guard-scratchpad.py`、`scripts/git-guard-permit.sh`、`tests/rm-permission-guard.bats`（新規）、`changes/1134.md`
- hook は聖域。マージは主の承認が要る
