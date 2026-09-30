# test-runner-python-suites Specification

## Purpose
TBD - created by archiving change test-sh-python-suites. Update Purpose after archive.
## Requirements
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

スイートが呼ぶ Python のコマンド名は環境変数 `PYTHON_SUITES_PYTHON`（既定 `python3`）で差し替えられなければならない（MUST）。python3 不在の検査はこの変数に存在しないコマンド名を入れて行う。`PATH` からディレクトリを外す方法は、CI の ubuntu ランナーで `python3` と `git`・`bash` が同じ `/usr/bin` にあり一緒に消えるので使わない。

守備範囲: この判定が受け取る入力は、git 追跡下の `plugins/*/tests/test_*.py` と、その unittest の実行結果（exit code と `Ran N tests` の行）、および実行環境に `python3` があるかどうかである。拾いたい誤りは「走ったつもりで何も走っていない」状態の素通りで、具体的には Python が無い環境で全件 pass と表示されること、パス変更などで対象ファイルが 0 件になったこと、テストメソッドを持たないファイルだけのディレクトリが `Ran 0 tests` で通ることの 3 つに限る。次の入力は通ってよい: 全テストが skip されたディレクトリ（`Ran N tests` の N は 1 以上になる）、テストメソッドは持つが中身の検査が弱いテスト、`plugins/*/tests` の外に置いた Python テスト（`scripts/poc/` など）。見つかった穴を塞ぐ検査を足し続けて抜け道を無くすことを、この要件の完了条件にしない。

#### Scenario: python3 が無い
- **WHEN** `PYTHON_SUITES_PYTHON` に存在しないコマンド名（例: `python3-not-installed`）を入れてスイートの判定関数を実行する
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

守備範囲: この検査が受け取る入力は、このリポジトリで人とエージェントが書く git 追跡下の `.bats`、`plugins` `scripts` `docs` 配下と `README.md` の手順文書、`plugins/*/tests/test_*.py` の docstring である。拾いたい誤りは、#334 で起きた「`unittest discover` に `-p` でファイル名の一部を渡して一部のファイルだけを走らせ、全件走らせたと思い込む」書き方の再発と、それを手順として人から人へ受け渡す文書の記述に限る。次の入力は通ってよい: `unittest discover` を使わずに単一ファイルを指定して走らせる bats や手元のコマンド（例: `python3 -m unittest plugins/x/tests/test_a.py`）、`-k` でテスト名を絞った実行、`openspec/changes/` 配下の過去の実行記録やレビュー記録、テストファイル名を実行方法ではなく説明として挙げる文。見つかった穴を塞ぐ検査を足し続けて抜け道を無くすことを、この要件の完了条件にしない。

#### Scenario: 手順文書にファイル名を絞ったコマンドが無い
- **WHEN** `grep -rn "test_codex_worker.py\|test_codex_\*.py\|-p test_codex.py" --include='*.md' plugins scripts docs README.md` を実行する
- **THEN** ヒットが 0 件である

#### Scenario: テストファイルの docstring にファイル名を絞ったコマンドが無い
- **WHEN** `grep -n -- "-p test_codex" plugins/*/tests/test_*.py` を実行する
- **THEN** ヒットが 0 件である

#### Scenario: 二重実行のラッパーが無い
- **WHEN** `git ls-files '*.bats' | xargs grep -ln 'unittest discover'` を実行する
- **THEN** ヒットは `tests/python-suites.bats` だけである

