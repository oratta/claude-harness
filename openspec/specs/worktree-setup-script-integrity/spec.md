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

`plugins/worktree/scripts/wt-setup.sh` は、ワークツリーが `.githooks/` 配下のファイルを git で追跡しており（`git ls-files -- .githooks` が空でない）、かつその clone のローカル設定に `core.hooksPath` が無いとき、`git config --local core.hooksPath .githooks` を設定しなければならない (MUST)。設定したときは、そのことを 1 行出力し、あわせて以後グローバルの `core.hooksPath` のフックが走らなくなることと、マージ済みブランチの拒否も要るならローカルの pre-push からグローバルのフックを呼ぶこと（push-guard-setup を参照）を知らせる注意を出力しなければならない (MUST)。

ローカル設定に `core.hooksPath` の値が既にあるときは、値が `.githooks` 以外でも上書きしてはならず (MUST NOT)、何も出力してはならない (MUST NOT)。ローカル設定の読み取りが「値あり」「未設定」のどちらとも判定できないときも触ってはならない (MUST NOT)。`.githooks/` を追跡していないとき（ディスク上に未追跡の `.githooks/` があるだけのときを含む）は何もしてはならない (MUST NOT)。

設定に失敗したときは WARNING を 1 行出力し、wt-setup.sh の残りの処理を続けなければならない (MUST)。

#### Scenario: 追跡されている .githooks が有効になりメインチェックアウトからも見える

- **WHEN** `.githooks/pre-push` を追跡しローカルの `core.hooksPath` が無いリポジトリのワークツリーで wt-setup.sh を実行する
- **THEN** ワークツリーとメインチェックアウトの両方で `git config --local --get core.hooksPath` が `.githooks` を返し、設定したことと注意が出力される

#### Scenario: 既に .githooks が入っていれば何も出さない

- **WHEN** ローカルの `core.hooksPath` が既に `.githooks` のリポジトリのワークツリーで wt-setup.sh を実行する
- **THEN** 値は `.githooks` のままで、`core.hooksPath` についての出力は無い

#### Scenario: 別の値が入っていれば上書きしない

- **WHEN** ローカルの `core.hooksPath` に `.husky/_` が入っているリポジトリのワークツリーで wt-setup.sh を実行する
- **THEN** 値は `.husky/_` のままで、`core.hooksPath` についての出力は無い

#### Scenario: .githooks が無いリポジトリでは何もしない

- **WHEN** `.githooks/` を持たないリポジトリのワークツリーで wt-setup.sh を実行する
- **THEN** ローカルの `core.hooksPath` は未設定のままである

#### Scenario: 未追跡の .githooks だけでは何もしない

- **WHEN** ワークツリーのディスク上に未追跡の `.githooks/pre-push` があるだけのリポジトリで wt-setup.sh を実行する
- **THEN** ローカルの `core.hooksPath` は未設定のままである

