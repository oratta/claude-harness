## 1. 判定の変更

- [x] 1.1 `_redirect_env()` が、無害なキー（`credential.interactive`・`credential.guiPrompt`）だけの `GIT_CONFIG_COUNT` / `KEY_<n>` / `VALUE_<n>` の組を数えないようにする。組が崩れている・一覧にないキーがある・COUNT の範囲外の番号がある・COUNT が整数でないときは、`GIT_CONFIG` で始まる変数をすべて今までどおり返す。触る範囲: plugins/dev-workflow/scripts/git-guard-scratchpad.py:80-92

## 2. 拒否メッセージ

- [x] 2.1 git の子への拒否理由に、親の許可を受けられる打ち方を 1 文足す（「打ち直さず」は残す。許可スクリプトの名前は書かない）。触る範囲: plugins/dev-workflow/scripts/git-destructive-guard.sh:915-925
- [x] 2.2 rm の子への deny の message に同じ 1 文を足す。触る範囲: plugins/dev-workflow/scripts/rm-permission-guard.sh:146-156

## 3. テスト

- [x] 3.1 bats: Claude Code 相当の `GIT_CONFIG_COUNT=2` の組で許可が書け、hook が allow を返す。触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:1285-1310 付近（許可のテスト群）
- [x] 3.2 bats: KEY に `core.worktree` が 1 つでもある・組が崩れている・`GIT_CONFIG_GLOBAL` / `GIT_CONFIG_PARAMETERS` を足したときは拒む。触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:1285-1310 付近
- [x] 3.3 bats: git の子への拒否理由と rm の message に「実パスで単独のコマンド」が含まれる。触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats（子への理由のテスト付近）、plugins/dev-workflow/tests/rm-permission-guard.bats（deny のテスト付近）
- [x] 3.4 既存の setup は `GIT_CONFIG*` を unset している。新しいテストは自分で環境変数を設定する。触る範囲: plugins/dev-workflow/tests/git-destructive-guard.bats:13-16

## 4. 実機確認（受け入れ条件）

- [ ] 4.1 環境変数を外さない通常の `claude -p --plugin-dir` の親で、子の `git checkout --` と `rm -f <dir>/*`（一時領域の中）が拒否 → 親が許可 → 再開で通ることを確かめ、結果をエピック #1137 に記録する。触る範囲: なし（実機確認。コードは触らない）
