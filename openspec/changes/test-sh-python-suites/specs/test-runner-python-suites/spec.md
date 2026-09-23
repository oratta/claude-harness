## ADDED Requirements

### Requirement: 全件実行に Python テストがファイル名を絞らずに含まれる

`scripts/test.sh` を引数なしで実行したとき、git 追跡下の `plugins/*/tests/test_*.py` がすべて実行されなければならない（MUST）。実行はリポジトリ直下の bats スイート `tests/python-suites.bats` が担い、対象は `git ls-files 'plugins/*/tests/test_*.py'` で見つけたファイルの置き場所（ディレクトリ）ごとに `python3 -m unittest discover -s <dir> -p 'test_*.py'` を実行して決めなければならない（MUST）。ファイル名の一部（例: `test_codex_`）で対象を絞ってはならない（MUST NOT）。どれか 1 つのディレクトリで unittest が非 0 を返したら、このスイートは失敗し、`scripts/test.sh` は exit 0 以外で終わらなければならない（MUST）。

`scripts/test.sh` と `.github/workflows/ci.yml` はこの要件のために変更しない。CI は既存の `scripts/test.sh` の実行でこのスイートを拾い、job 名 `bats suites`（auto-merge の必須チェック名）は変えてはならない（MUST NOT）。

#### Scenario: Python テストを 1 件落とすと全件実行が失敗する
- **WHEN** `plugins/*/tests/test_*.py` のいずれかのテストを 1 件わざと失敗させた状態で `bash scripts/test.sh` を実行する
- **THEN** `tests/python-suites.bats` が `not ok` になり、`scripts/test.sh` の exit code が 0 以外になる

#### Scenario: 新しいテストファイルをラッパーなしで拾う
- **WHEN** 既存と別の名前の `plugins/<plugin>/tests/test_<name>.py`（`test_codex_` で始まらない名前。テストを持たないプラグインの新しい `tests/` ディレクトリでもよい）を追加して `git add` し、`scripts/test.sh python-suites` を実行する
- **THEN** 追加したファイルのテストが実行され、そのディレクトリの `Ran N tests` の N に含まれる

#### Scenario: CI と手元で同じ対象が走る
- **WHEN** 同じコミットで手元と CI（`.github/workflows/ci.yml` の `scripts/test.sh`）の全件実行を行う
- **THEN** 両方のログに、同じディレクトリ一覧と同じ `Ran N tests` の件数が出る

### Requirement: Python が無い・何も走らないときは失敗する

`python3` が見つからない環境では、このスイートは skip ではなく失敗しなければならず（MUST）、失敗メッセージに導入方法を示さなければならない（MUST）。`git ls-files` で対象が 1 件も見つからないとき、およびあるディレクトリの unittest が `Ran 0 tests` を報告したときも失敗しなければならない（MUST）。プラットフォームの都合で除外する場合は既存の `TEST_EXCLUDE=python-suites` を使い、除外は `scripts/test.sh` の `skipped by TEST_EXCLUDE: N` に数えられる。

#### Scenario: python3 が無い
- **WHEN** `PATH` から `python3` を外した状態で `tests/python-suites.bats` を実行する
- **THEN** スイートは失敗し、出力に `python3` が見つからないことと導入方法が出る

#### Scenario: 何も走らないディレクトリ
- **WHEN** テストメソッドを 1 つも持たない `test_*.py` だけを置いたディレクトリが対象に含まれる状態で実行する
- **THEN** そのディレクトリが `Ran 0 tests` として失敗扱いになり、スイートが失敗する

### Requirement: Python の件数と失敗内容を出力に出す

このスイートは、成否に関係なくディレクトリごとに対象ディレクトリと unittest の `Ran N tests` の行を TAP のコメント行（`# ` で始まる行）として出さなければならない（MUST）。失敗したディレクトリについては unittest の出力全体を表示しなければならない（MUST）。bats の `run` で出力を捕まえたまま捨ててはならない（MUST NOT）。

#### Scenario: 成功時にも件数が見える
- **WHEN** 全テストが成功する状態で `scripts/test.sh python-suites` を実行する
- **THEN** 出力に対象ディレクトリごとの `Ran N tests` の行が出る

#### Scenario: 失敗時にどのテストが落ちたか分かる
- **WHEN** テストを 1 件わざと失敗させて実行する
- **THEN** 出力に unittest の `FAIL:` 行と失敗したアサーションの内容が出る

### Requirement: ファイル名を絞った Python テストの実行方法を残さない

Python テストを走らせるための、ファイル名を絞った bats ラッパー（`-p 'test_codex_*.py'` や `-p test_codex.py` を渡すもの）をリポジトリに置いてはならない（MUST NOT）。`tests/python-suites.bats` 以外の `.bats` は `unittest discover` を呼んではならない（MUST NOT。同じテストの二重実行を避ける）。手順を書いた文書（`*.md`）と Python テストファイルの docstring は、Python テストの実行方法として `scripts/test.sh python-suites` またはファイル名を絞らないコマンドを書かなければならない（MUST）。`openspec/changes/archive/` と過去の検証記録（`openspec/changes/*/VERIFICATION.md` など、当時の実行を記録したもの）は書き換えの対象外とする。

#### Scenario: 手順文書にファイル名を絞ったコマンドが無い
- **WHEN** `grep -rn "test_codex_worker.py\|test_codex_\*.py\|-p test_codex.py" --include='*.md' plugins scripts docs README.md` を実行する
- **THEN** 実行方法としてファイル名を絞ったコマンドはヒットしない

#### Scenario: 二重実行のラッパーが無い
- **WHEN** `git ls-files '*.bats' | xargs grep -ln 'unittest discover'` を実行する
- **THEN** ヒットは `tests/python-suites.bats` だけである
