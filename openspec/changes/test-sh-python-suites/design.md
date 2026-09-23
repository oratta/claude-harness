## Context

issue #344 は「`scripts/test.sh` が Python のテストを拾わない」と書いているが、着手時点（HEAD 1479f95）では #321 と #310 で入った bats ラッパー 2 本が Python を走らせている。

| ラッパー | 実行内容 | 拾う範囲 |
|---|---|---|
| `plugins/dev-workflow/tests/codex-python.bats` | `unittest discover -s <そのディレクトリ> -p 'test_codex_*.py'` | `test_codex_worker.py`・`test_codex_develop.py` |
| `plugins/statusline/tests/statusline-codex.bats` | `unittest discover -s <そのディレクトリ> -p test_codex.py` | `test_codex.py` |

つまり今ある 3 ファイルは全件実行に入っているが、次の 3 点が残っている。

1. ファイル名を絞っているので、`test_codex_` で始まらないファイルや、ラッパーの無いプラグインに足した `test_*.py` は拾われない（issue の受け入れ条件「新規ファイルを足しても自動で拾われる」を満たさない）
2. `run` で出力を捕まえて `[ "$status" -eq 0 ]` だけを見ているので、落ちたときにどのテストが落ちたかが出ない。Python の 82 件は bats の 2 件として数えられ、件数が見えない
3. 手順文書（`CODEX-WORKER.md`）と `test_codex.py` の docstring がファイル名を絞ったコマンドを載せている

実行時間は手元（macOS）で dev-workflow が約 46 秒、statusline が約 3 秒。

## Goals / Non-Goals

**Goals:**
- `scripts/test.sh` 1 コマンドで `plugins/*/tests/test_*.py` が全件走り、1 件でも落ちれば非 0 になる
- 新しい `test_*.py` を足したとき、ラッパーを書き足さなくても拾われる
- CI と手元で同じ件数が走る
- 手順文書にファイル名を絞ったコマンドを残さない

**Non-Goals:**
- `scripts/poc/codex-appserver/test_poc.py` は対象にしない（PoC の置き場で、issue の対象範囲 `plugins/*/tests` の外。現状も全件実行に入っていない）
- Python テストを pytest に移す、依存パッケージを入れる仕組みを作る（今のテストは標準ライブラリだけで動く）
- `scripts/test.sh` の集計表示を作り直す

## Decisions

### Python を走らせる場所: `scripts/test.sh` に別の実行段を足すのではなく、ルートの bats スイート 1 本にまとめる

案は 2 つあった。

- 案 A: `scripts/test.sh` に bats とは別の Python 実行段を足し、最後に両方の結果を併記する
- 案 B: `tests/python-suites.bats` を 1 本置き、その中で Python のテストディレクトリを見つけて全部走らせる。`scripts/test.sh` は変えない

案 B を採る。理由は、`scripts/test.sh` が持っている仕組みがそのまま Python にも効くからである。

- フィルタ引数と `TEST_EXCLUDE` はスイートのパスで効く。案 B なら `scripts/test.sh python-suites` で Python だけ走らせられ、`scripts/test.sh worktree` のように別のものを絞ったときは Python が走らない。案 A ではフィルタが Python にどう効くかを別に決めて実装し直す必要がある
- 残留プロセス検査（issue #215）は bats のプロセスグループを見ている。Python のテストはサブプロセスを多く起動する（fake Codex、App Server）ので、回収し損ねた子が残ったときに同じ検査で捕まる。案 A では Python 段に同じ検査を作り直すことになる
- `tests/test-sh-residual-guard.bats` は `scripts/test.sh` を使い捨てリポに複製して走らせる。案 A だと Python テストが 1 本も無いリポで Python 段がどう振る舞うかも決め直す必要がある
- CI の `.github/workflows/ci.yml` と、auto-merge の必須チェック名 `shellcheck` / `bats suites`（`.github/workflows/auto-merge.yml` の `REQUIRED_CHECKS`、`scripts/test-auto-merge-workflow.sh` が ci.yml の job 名との一致を検査）に触れずに済む。job 名を変えないので、必須チェックが永久に揃わずマージされなくなる事故は起きない

案 B で失うのは、Python の件数が bats の集計（`ok` / `not ok` の行数）に 1 件としてしか入らないこと。これはディレクトリごとの `Ran N tests` を TAP のコメント行（fd 3 に `# ` で始まる行）へ毎回出すことで補う。CI のログでも手元でも同じ行が出るので、件数の突き合わせはこの行で行う。

### 対象の見つけ方: `git ls-files` で見つけたファイルの置き場所ごとに、ファイル名を絞らず discover する

`git ls-files 'plugins/*/tests/test_*.py'` の結果からディレクトリを重複なく取り出し、ディレクトリごとに `python3 -m unittest discover -s <dir> -p 'test_*.py'` を実行する。

- git 追跡下だけを見るのは `scripts/test.sh` が `.bats` を `git ls-files` で見つけるのと揃えるため（作業ツリーの一時ファイルを拾わない）
- `-p 'test_*.py'` はディレクトリ内の全テストファイルに当たる。ファイル名の一部（`test_codex_`）を書かない
- `plugins` 全体を 1 回で discover しない。各 `tests/` は `__init__.py` を持たないパッケージではないディレクトリで、テストは `Path(__file__)` から相対にスクリプトを読み込む。ディレクトリごとに `-s` を渡すのが今の書き方と同じで、テスト側を変えずに済む
- 環境変数 `PYTHONDONTWRITEBYTECODE=1` を付けて、作業ツリーに `__pycache__` を作らない（`CODEX-WORKER.md` が今書いているのと同じ）

### Python が無い・0 件のときは失敗させる

- `python3` が見つからなければ、導入方法を出して失敗させる。skip にすると、Python の無い環境で「全件 pass」と表示されてしまい、issue の発端と同じ見落としが起きる。`scripts/test.sh` が bats の無い環境で失敗するのと同じ扱い。CI の ubuntu ランナーには python3 がプリインストールされている（ci.yml のヘッダに記載済み）ので CI では落ちない
- あるディレクトリで `Ran 0 tests` になったら失敗にする。import に失敗したファイルは unittest がエラーとして数えるが、テストクラスを 1 つも持たないファイルだけのディレクトリなど「走ったつもりで何も走っていない」状態を通さないため
- `git ls-files` で 1 件も見つからないときも失敗にする。今 3 ファイルある前提が崩れた（パス変更など）ことを黙って通さないため

### 失敗時の出力

bats の `run` は出力を捕まえるだけで表示しないので、失敗したディレクトリについては unittest の出力全体を表示してから失敗させる。成功したディレクトリは `Ran N tests` と `OK` の要約だけを出す。

### プラグインごとのラッパーは消す

新しいスイートが同じテストを走らせるので、残すと Python が 2 回走り（約 50 秒の重複）、ファイル名を絞った書き方も残り続ける。削除する。

## Risks / Trade-offs

- [bats の集計上、Python 82 件が 1 件に見える] → ディレクトリごとの `Ran N tests` を TAP コメントに毎回出す。issue の「集計を揃えるか併記するか」には「併記（TAP コメントとして）」で答える
- [Python が無い手元環境では全件実行が必ず落ちる] → これは意図した挙動。失敗メッセージに導入コマンドを出す。プラットフォームの都合で外したいときは既存の `TEST_EXCLUDE=python-suites` で明示的に除外でき、その場合は `skipped by TEST_EXCLUDE: N` に数えられる
- [`scripts/test.sh` のフィルタでプラグイン名（例: `statusline`）を指定しても、そのプラグインの Python テストは走らない] → 以前はプラグイン配下のラッパーがフィルタに当たっていた。Python も走らせたいときは `scripts/test.sh statusline python-suites` と並べる。この挙動を `CODEX-WORKER.md` に書く

## Migration Plan

1 PR で、新しいスイートの追加・ラッパー 2 本の削除・文書の書き換え・plugin.json の bump をまとめて入れる。戻すときは PR を revert すればラッパーが戻る。
