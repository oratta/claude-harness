# worktree-setup-script-integrity Specification

## Purpose
TBD - created by archiving change worktree-command-dedup. Update Purpose after archive.
## Requirements
### Requirement: wt-setup.sh の find -path グロブと settings.local.json symlink の挙動を検証し意図を文書化する

`plugins/worktree/scripts/wt-setup.sh` の `.worktreeinclude` パターン展開に使う `find -path "./$pattern"` グロブ（`.worktreeinclude` の各パターンをメインリポ配下のファイルに展開する処理）と、`.claude/settings.json` / `.claude/settings.local.json` を worktree に symlink する処理について、実挙動を確認しなければならない (MUST)。確認の結果、問題がなければ現状の挙動を維持し (MAY keep)、その判断意図を説明するコメントをスクリプトに追記しなければならない (MUST document)。問題が確認された場合は修正すること。いずれの結論でも、`bash -n plugins/worktree/scripts/wt-setup.sh` の構文検証を通過しなければならない (MUST)。

#### Scenario: find -path グロブの挙動が検証され意図がコメント化されている

- **WHEN** ユーザーが `plugins/worktree/scripts/wt-setup.sh` の `.worktreeinclude` 展開ループ（`find -path "./$pattern"` を含む箇所）を読む
- **THEN** `find -path` のグロブ展開挙動（例: `.env.*` のような 1 階層パターンとサブディレクトリを含むパターンで一致範囲が異なる点）についての確認結果を示すコメントが存在する、または挙動を是正する修正が入っている

#### Scenario: settings.local.json の symlink 是非が判断・文書化されている

- **WHEN** ユーザーが `plugins/worktree/scripts/wt-setup.sh` の `.claude/` 配下ファイルを symlink するループ（`settings.json` / `settings.local.json` を対象とする箇所）を読む
- **THEN** `settings.local.json`（マシンローカルな権限設定を含みうる）を worktree に symlink する／しないの判断理由を示すコメントが存在する、または是正する修正が入っている

#### Scenario: スクリプトの構文検証が通る

- **WHEN** ユーザーが `bash -n plugins/worktree/scripts/wt-setup.sh` を実行する
- **THEN** 構文エラーなく終了する（exit 0）

### Requirement: wt-setup.sh は追跡されている .githooks をリポジトリローカルのフックとして有効にする

`plugins/worktree/scripts/wt-setup.sh` は、ワークツリーが `.githooks/` 配下のファイルを git で追跡しており（`git ls-files -- .githooks` が空でない）、かつ `core.hooksPath` の実効値が未設定か、実効値のスコープが `global` / `system` のとき、`git config --local core.hooksPath .githooks` を設定しなければならない (MUST)。実効値とそのスコープは `git config --show-scope --get core.hooksPath` で判定し、git 2.26 以上を前提とする。設定したときは、そのことを `=== git フック:` で始まる見出し 1 行で出力し、あわせて、それまで実行されていたフック（スコープが `global` / `system` ならその値、未設定なら `.git/hooks/`）が以後その clone では走らなくなることを知らせる注意を出力しなければならない (MUST)。それまでの値がグローバル側（`global` / `system`）のときは、マージ済みブランチの拒否などグローバル側のチェックも要るならローカルの pre-push からグローバルのフックを呼ぶこと（push-guard-setup を参照）も知らせなければならない (MUST)。注意にグローバルのフックの場所を固定の文字列（`~/.githooks` など）で書いてはならない (MUST NOT)。

実効値のスコープが `local` / `worktree` / `command` のとき（`extensions.worktreeConfig` による `config.worktree` の値や、`include.path` 経由でローカル設定から読み込まれた値を含む）は、値が `.githooks` 以外でも上書きしてはならず (MUST NOT)、何も出力してはならない (MUST NOT)。読み取りの終了コードが 0（値あり）・1（未設定）以外のときも触ってはならない (MUST NOT)。`.githooks/` を追跡していないとき（ディスク上に未追跡の `.githooks/` があるだけのときを含む）は何もしてはならない (MUST NOT)。

clone の共通フックディレクトリ（`git rev-parse --git-common-dir` の `hooks/`）に `.sample` 以外のファイルが 1 つでもあるときは、設定してはならず (MUST NOT)、`.githooks` を追跡しているが `.git/hooks/` に既存のフックがあるため自動では有効化しなかったことを、`=== git フック:` で始まる 1 行で出力しなければならない (MUST)。Git LFS の pre-push などを黙って止めないためである。

設定に失敗したときは WARNING を 1 行出力し、wt-setup.sh の残りの処理を続けなければならない (MUST)。

SessionStart の自動実行（`plugins/worktree/scripts/wt-setup-guard.sh`）は、wt-setup.sh の出力に `=== git フック:` で始まる行が含まれるとき、その注意を残タスクとして Claude に渡さなければならず (MUST)、「残タスクなし」として扱ってはならない (MUST NOT)。

#### Scenario: 追跡されている .githooks が有効になりメインチェックアウトからも見える

- **WHEN** `.githooks/pre-push` を追跡し `core.hooksPath` がどのスコープにも無いリポジトリのワークツリーで wt-setup.sh を実行する
- **THEN** ワークツリーとメインチェックアウトの両方で `git config --local --get core.hooksPath` が `.githooks` を返し、`=== git フック:` の見出しと、それまでのフックが `.git/hooks/` であった旨の注意が出力される

#### Scenario: グローバルの値があれば注意がその値と push-guard-setup を示す

- **WHEN** グローバル設定の `core.hooksPath` に値があり、ローカル側に値の無いリポジトリのワークツリーで wt-setup.sh を実行する
- **THEN** ローカルの `core.hooksPath` が `.githooks` になり、注意にそのグローバルの値と push-guard-setup が含まれ、`~/.githooks` の固定文字列は含まれない

#### Scenario: 既に .githooks が入っていれば何も出さない

- **WHEN** ローカルの `core.hooksPath` が既に `.githooks` のリポジトリのワークツリーで wt-setup.sh を実行する
- **THEN** 値は `.githooks` のままで、`core.hooksPath` についての出力は無い

#### Scenario: 別の値が入っていれば上書きしない

- **WHEN** ローカルの `core.hooksPath` に `.husky/_` が入っているリポジトリのワークツリーで wt-setup.sh を実行する
- **THEN** 値は `.husky/_` のままで、`core.hooksPath` についての出力は無い

#### Scenario: config.worktree の値は上書きしない

- **WHEN** `extensions.worktreeConfig` を有効にし、ワークツリーの `config.worktree` に `core.hooksPath` の値があるリポジトリのワークツリーで wt-setup.sh を実行する
- **THEN** clone の共通設定に `core.hooksPath` は書かれず、ワークツリーの実効値は元の値のままで、git フックについての出力は無い

#### Scenario: include.path 経由のローカル値は上書きしない

- **WHEN** ローカル設定の `include.path` が指すファイルに `core.hooksPath` の値があるリポジトリのワークツリーで wt-setup.sh を実行する
- **THEN** ローカル設定そのものに `core.hooksPath` は書かれず、実効値は読み込み先の値のままで、git フックについての出力は無い

#### Scenario: .git/hooks に既存のフックがあれば切り替えずに知らせる

- **WHEN** `.githooks/pre-push` を追跡し、clone の `.git/hooks/` に `.sample` 以外のフック（例: `pre-push`）があるリポジトリのワークツリーで wt-setup.sh を実行する
- **THEN** ローカルの `core.hooksPath` は未設定のままで、自動では有効化しなかったことを示す `=== git フック:` の行が 1 行だけ出力される

#### Scenario: .git/hooks に .sample しか無ければ切り替える

- **WHEN** clone の `.git/hooks/` に `.sample` のファイルだけがあるリポジトリのワークツリーで wt-setup.sh を実行する
- **THEN** ローカルの `core.hooksPath` が `.githooks` になる

#### Scenario: 設定の失敗は WARNING 1 行で続行する

- **WHEN** `git config --local core.hooksPath .githooks` が失敗する状態で wt-setup.sh を実行する
- **THEN** WARNING が 1 行だけ出力され、wt-setup.sh は後続の依存状況の出力まで続き、ローカルの `core.hooksPath` は未設定のままである

#### Scenario: 読み取りが 0 / 1 以外で終わったら触らない

- **WHEN** `git config --show-scope --get core.hooksPath` が 0 / 1 以外の終了コードで終わる状態で wt-setup.sh を実行する
- **THEN** ローカルの `core.hooksPath` は未設定のままで、git フックについての出力も WARNING も無く、wt-setup.sh は後続の処理を続ける

#### Scenario: .githooks が無いリポジトリでは何もしない

- **WHEN** `.githooks/` を持たないリポジトリのワークツリーで wt-setup.sh を実行する
- **THEN** ローカルの `core.hooksPath` は未設定のままである

#### Scenario: 未追跡の .githooks だけでは何もしない

- **WHEN** ワークツリーのディスク上に未追跡の `.githooks/pre-push` があるだけのリポジトリで wt-setup.sh を実行する
- **THEN** ローカルの `core.hooksPath` は未設定のままである

#### Scenario: SessionStart の自動実行で設定したとき、注意が残タスクとして載る

- **WHEN** `.githooks/pre-push` と `.worktreeinclude` を追跡し、`core.hooksPath` がどのスコープにも無いリポジトリで、未セットアップのワークツリーのセッションを開始して wt-setup-guard.sh が wt-setup.sh を自動実行する
- **THEN** SessionStart の additionalContext の残タスクに git フックの注意が載り、「残タスクなし」の文言は含まれない
