## 1. テストを先に書く（Red）

- [ ] 1.1 `tests/python-suites.bats` の骨組みを作り、次の検査を先に書く: 対象ディレクトリが `git ls-files 'plugins/*/tests/test_*.py'` の置き場所と一致すること、ディレクトリごとの unittest が exit 0 であること、`Ran N tests` の N が 1 以上であること、`Ran N tests` の行が TAP コメント（fd 3 に `# `）に出ること
- [ ] 1.2 同じスイートに、使い捨てディレクトリ（`BATS_TEST_TMPDIR` 配下の git リポ）で走らせる検査を書く: 落ちるテストを 1 件置くと失敗し `FAIL:` 行が出る／テストを持たない `test_*.py` だけだと `Ran 0 tests` で失敗する／`test_codex_` で始まらない新しいファイルが拾われる／`python3` を `PATH` から外すと導入方法を出して失敗する。検査対象の処理（discover と判定）はスイート内の関数にまとめ、本番の実行と使い捨てリポの検査で同じ関数を使う
- [ ] 1.3 `git ls-files '*.bats' | xargs grep -ln 'unittest discover'` が `tests/python-suites.bats` だけになることを検査するテストを足す（この時点ではラッパー 2 本が残っているので Red）

## 2. 実装（Green）

- [ ] 2.1 `tests/python-suites.bats` の本体を実装する（`PYTHONDONTWRITEBYTECODE=1`、ディレクトリごとの `python3 -m unittest discover -s <dir> -p 'test_*.py'`、失敗時は unittest の出力全体を表示、0 件・対象なし・python3 不在は失敗）
- [ ] 2.2 `plugins/dev-workflow/tests/codex-python.bats` と `plugins/statusline/tests/statusline-codex.bats` を削除する
- [ ] 2.3 `plugins/dev-workflow/scripts/CODEX-WORKER.md` のテスト実行コマンドを `scripts/test.sh python-suites` に置き換え、プラグイン名のフィルタだけでは Python が走らないこと（`scripts/test.sh <plugin> python-suites` と並べる）を書く
- [ ] 2.4 `plugins/statusline/tests/test_codex.py` の docstring のコマンドを `scripts/test.sh python-suites` に置き換える

## 3. 版と記録

- [ ] 3.1 `plugins/dev-workflow/.claude-plugin/plugin.json` を 2.13.28 に上げ、`plugins/dev-workflow/CHANGELOG.md` に追記する（着手時に origin/main の版を確認し、先に上がっていればその次にする）
- [ ] 3.2 `plugins/statusline/.claude-plugin/plugin.json` を 0.5.2 に上げる（marketplace.json に版があれば同期する）

## 4. 確認

- [ ] 4.1 受け入れ条件を手で確かめ、コマンドと exit code を記録する: Python のテストを 1 件わざと落として `bash scripts/test.sh` が非 0／新しい `plugins/<plugin>/tests/test_<name>.py` を足して `scripts/test.sh python-suites` の件数が増える（確認後は両方とも元に戻す）
- [ ] 4.2 `grep -rn "test_codex_worker.py\|test_codex_\*.py\|-p test_codex.py" --include='*.md' plugins scripts docs README.md` がヒットしないことを確認する
- [ ] 4.3 `bash scripts/test.sh` を引数なしで全件実行し、exit 0 と `Ran N tests` の行（合計 82 件前後）を記録する。`scripts/lint.sh` も通す
- [ ] 4.4 PR の CI（job `bats suites`）のログで、手元と同じディレクトリ一覧と件数が出ていることを確認する
