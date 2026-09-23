## Why

`scripts/test.sh` は Python のテストを、プラグインごとに置いた bats の薄いラッパー（`plugins/dev-workflow/tests/codex-python.bats` と `plugins/statusline/tests/statusline-codex.bats`）経由でしか走らせていない。ラッパーは `-p 'test_codex_*.py'` や `-p test_codex.py` とファイル名を絞っているので、`plugins/*/tests/` に `test_*.py` を新しく足しても黙って検証から漏れる。手順文書（`plugins/dev-workflow/scripts/CODEX-WORKER.md`）もファイル名を絞ったコマンドを載せており、2026-09-20 に #334 / PR #343 で「絞ったコマンドだけ走らせて全件 OK と記録し、別ファイルの失敗を見落とす」事故が起きた（issue #344）。

## What Changes

- リポジトリ直下に Python テストを一括で走らせる bats スイート `tests/python-suites.bats` を足す。対象は `git ls-files 'plugins/*/tests/test_*.py'` で見つけたファイルの置き場所すべてで、ディレクトリごとに `python3 -m unittest discover -s <dir> -p 'test_*.py'` を実行する。ファイル名を絞る指定は持たない
- `python3` が無い環境では skip せず失敗させる。実行したテストが 0 件のディレクトリも失敗にする
- ディレクトリごとの `Ran N tests` を成否に関係なく TAP のコメント行に出し、失敗時は unittest の出力全体を出す（bats の件数には 1 件としてしか現れないので、Python 側の件数は別行で見せる）
- プラグインごとの絞り込みラッパー `plugins/dev-workflow/tests/codex-python.bats` と `plugins/statusline/tests/statusline-codex.bats` を削除する（二重実行を避ける）
- `plugins/dev-workflow/scripts/CODEX-WORKER.md` と `plugins/statusline/tests/test_codex.py` の docstring にあるファイル名を絞ったコマンドを、`scripts/test.sh python-suites`（または絞らない unittest コマンド）に置き換える
- `scripts/test.sh` と `.github/workflows/ci.yml` は変更しない。CI の job 名 `bats suites`（auto-merge の必須チェック名）もそのまま

## Capabilities

### New Capabilities

- `test-runner-python-suites`: `scripts/test.sh` の全件実行に `plugins/*/tests/test_*.py` の Python テストがファイル名を絞らずに含まれること、Python が無い・0 件のときに失敗すること、件数と失敗内容の出し方、手順文書にファイル名を絞ったコマンドを残さないこと

### Modified Capabilities

- `codex-role-profiles`: 要件「実モデル受け入れと回帰を残す」のシナリオ「ローカル回帰を実行する」が `scripts/test.sh と test_codex_*.py を実行する` とファイル名のパターンを書いているので、`scripts/test.sh` を引数なしで実行すれば Python 回帰がルートの `tests/python-suites.bats` 経由で全件検出される、という書き方に直す（要件本文は変えない）

## Impact

- 追加: `tests/python-suites.bats`
- 削除: `plugins/dev-workflow/tests/codex-python.bats`、`plugins/statusline/tests/statusline-codex.bats`
- 文書: `plugins/dev-workflow/scripts/CODEX-WORKER.md`、`plugins/statusline/tests/test_codex.py`（docstring）
- バージョン: `plugins/dev-workflow/.claude-plugin/plugin.json`（2.13.27 → 2.13.28、CHANGELOG 追記）、`plugins/statusline/.claude-plugin/plugin.json`（0.5.1 → 0.5.2）
- 実行時間: 現状もラッパー経由で約 50 秒ぶん Python を走らせているので、全件実行の時間はほぼ変わらない（issue で受け入れた「1 分延びる」は発生しない見込み）
- CI: 同じ `scripts/test.sh` がそのまま拾うので `.github/` は触らない
