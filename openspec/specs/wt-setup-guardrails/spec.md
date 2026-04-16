## Purpose

wt-setup スキルにおける LLM の危険なファイル操作を防止するガードレール。SKILL.md の禁止ルールとスクリプト側の防御ガードを定義する。

## Requirements

### Requirement: SKILL.md は .claude/ の直接操作を禁止する

SKILL.md に `## 禁止事項` セクションを設け、LLM が `.claude/` ディレクトリに対して `rm`, `rm -rf`, `mv`, `cp` 等の直接操作コマンドを実行することを禁止する（SHALL NOT）。`.claude/` の操作は全てスクリプト（wt-setup.sh）に委譲するものとする。

#### Scenario: SKILL.md に禁止事項セクションがある
- **WHEN** SKILL.md を読む
- **THEN** `## 禁止事項` セクションが存在し、`.claude/` の直接操作禁止が明記されている

#### Scenario: LLM が rm -rf .claude を実行しようとした場合
- **WHEN** LLM が `rm -rf .claude` または `rm -rf ./.claude` を含むコマンドを生成する
- **THEN** 禁止事項に該当するため実行してはならない

### Requirement: wt-setup.sh は .claude/ の既存状態を安全に扱う

wt-setup.sh の Step 3（.claude/ の共有）は、既存の `.claude/` ディレクトリを削除せず、サブディレクトリ単位でシンボリンクを作成するものとする（SHALL）。`.claude/` が既にシンボリンクの場合はスキップする。

#### Scenario: .claude/ が通常のディレクトリとして存在する場合
- **WHEN** worktree に `.claude/` が通常のディレクトリとして存在する
- **THEN** スクリプトは `.claude/` を削除せず、内部のサブディレクトリのみシンボリンクを作成する

#### Scenario: .claude/ が既にシンボリンクの場合
- **WHEN** worktree の `.claude/` が既にシンボリンクである
- **THEN** スクリプトは `.claude/` のシンボリンク操作をスキップし、警告を出力する

### Requirement: .worktreeinclude 生成は自動判定で完結する

SKILL.md の `.worktreeinclude` 生成処理（Step 2）は、AskUserQuestion を使わず、固定の分類ルールに基づいて自動的にパターンを決定するものとする（SHALL）。

#### Scenario: .worktreeinclude が存在しない場合の自動生成
- **WHEN** スクリプト出力に「.worktreeinclude: なし」が含まれる
- **THEN** AskUserQuestion を使わず、自動判定ルールに基づいて `.worktreeinclude` を生成する

#### Scenario: env 系パターンが自動的に含まれる
- **WHEN** `.worktreeinclude` を自動生成する
- **THEN** `.env`, `.env.*` パターンが含まれる

#### Scenario: ビルド成果物パターンが除外される
- **WHEN** `.worktreeinclude` を自動生成する
- **THEN** `node_modules`, `dist`, `out`, `*.log` パターンが含まれない

#### Scenario: 完了レポートに含めたパターンが表示される
- **WHEN** `.worktreeinclude` の自動生成が完了する
- **THEN** 完了レポートに含めたパターンと除外したパターンの一覧が表示される
