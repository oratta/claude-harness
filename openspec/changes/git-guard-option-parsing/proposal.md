## Why

`git-destructive-guard.sh` は git のオプションを git 本体と違うように読む箇所があり、次の 4 種の入力を素通りさせている（実 hook は無出力。いずれも PR #794 以前から同じ挙動）。どれも git では実際に push・削除・reset が起きる（2.40.1 の手元の bare リポジトリで、`git push -n --no-dry origin main` が push し、`git clean --excl -n -f` がファイルを消すことを確かめた）。

- `env -u FOO git reset --hard`: `env` の値を取るオプションの値 `FOO` をコマンド名と読み、git に辿り着かない
- `git push -n --no-dry-run origin main`、`git clean -n --no-dry-run -f`、`git push --dry-run --no-dry-run --force origin main`: 後ろの `--no-dry-run` が dry-run を打ち消すのに、`-n` / `--dry-run` があるだけで dry-run として除外する
- `git push --push-opt -n origin main`、`git clean --excl -n -f`: git は長いオプションの一意な省略形を受け付けるので `-n` は `--push-option` / `--exclude` の値だが、省略形を知らないので `-n` を dry-run と読む
- `git push --end-of-options -n origin main`: `--end-of-options` より後ろはオプションではなく、`-n` は送り先のリモート名（`main` は refspec）だが、`-n` を dry-run と読む

仕分けは PR #794 のコメント https://github.com/oratta/claude-harness/pull/794#issuecomment-6047892298 。

## What Changes

- `env` の値を取るオプション（`-u` / `--unset`、`-C` / `--chdir`、`-S` / `--split-string`、`-P`、`-a` / `--argv0`）の値を読み飛ばしてからコマンドを決める
- `git push` / `git clean` の dry-run は、オプションを左から読んで最後に効いているものだけで決める。`-n` / `--dry-run` は dry-run にし、`--no-dry-run` とその省略形（`--no-dry` など）は打ち消す
- 値を取る長いオプション（サブコマンドごとの既存の一覧）は、一意な省略形（`--push-opt`、`--excl`）も同じオプションとして読み、次の字句を値として読み飛ばす
- `--end-of-options` は `--` と同じく、それより後ろの字句をすべて位置引数として読む
- 上の 4 種以外の読み方（他の wrapper のオプション、値を取らないオプションの省略形、`--no-force` などの他の打ち消し）は変えない

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `destructive-git-hook`: 要件「破壊的 git 操作を Bash の実行前に検出する」の、dry-run の除外条件（4・5・6 番）と、wrapper・オプション値の読み飛ばしの文を変え、Scenario を足す

## Impact

- `plugins/dev-workflow/scripts/git-destructive-guard.sh`（`judge_simple` の wrapper の読み飛ばし、`parse_opts`、`judge_push` と `clean` の dry-run 判定）
- `plugins/dev-workflow/tests/git-destructive-guard.bats`（列挙 4 種の止まるテストと、本当の dry-run を止めないテスト）
- #820・#822 が同じ 2 ファイルを並行して直しているので、既存関数の大きな書き換えはしない
