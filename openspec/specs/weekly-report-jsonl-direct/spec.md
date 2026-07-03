# weekly-report-jsonl-direct Specification

## Purpose
TBD - created by archiving change report-plugins-update. Update Purpose after archive.
## Requirements
### Requirement: weekly-report は LLM セッションログを native jsonl から直読する

`plugins/weekly-report/skills/weekly-report/SKILL.md` の Step 3b（ソースリポジトリ LLM セッション収集）は、`{source_path}/LLM/*.md`（obsidian-llm-session-rules の auto-save.py が生成する劣化コピー）を読んではならない (MUST NOT)。代わりに `plugins/daily-report/agents/llm-log-compactor.md:33-100` の jq ロジックを流用し、`~/.claude/projects/*/` 配下の native セッション jsonl を対象週の日付範囲でフィルタして直読しなければならない (MUST)。セッションのグルーピング・要約抽出は jq/grep ベースで完結させ、jsonl 本文をそのまま週次ノートに転記しない。

#### Scenario: Step 3b が LLM/*.md への参照を持たない

- **WHEN** `plugins/weekly-report/skills/weekly-report/SKILL.md` 内で `{source_path}/LLM` という文字列を grep する
- **THEN** 該当行は 0 件である

#### Scenario: Step 3b が native jsonl を参照する

- **WHEN** `plugins/weekly-report/skills/weekly-report/SKILL.md` の Step 3b（ソースリポジトリ LLM セッション収集）を読む
- **THEN** `~/.claude/projects` への参照と、jq ベースでセッション（初回指示・要約・件数等）を抽出する手順が記載されている

#### Scenario: llm-log-compactor のロジックを流用している旨が明記されている

- **WHEN** ユーザーが Step 3b の説明文を読む
- **THEN** `plugins/daily-report/agents/llm-log-compactor.md` の jq ロジックを流用・参照している旨が記載されている

### Requirement: weekly-report は個人パスをハードコードしない

`plugins/weekly-report/skills/weekly-report/SKILL.md` は `/Users/oratta/Dropbox/WorkSpace` のような個人環境固有の絶対パスをハードコードしてはならない (MUST NOT)。harvest セッション（旧 1h-cooking）の検索ルートは環境変数（例: `$WORKSPACE_ROOT`）で解決し、未設定の場合は当該サブセクションを省略してレポート生成自体は継続しなければならない (MUST)。

#### Scenario: 個人パスのハードコードが無い

- **WHEN** `plugins/weekly-report/skills/weekly-report/SKILL.md` 内で `/Users/oratta/Dropbox/WorkSpace` という文字列を grep する
- **THEN** 該当行は 0 件である

#### Scenario: 環境変数未設定時にフェイルソフトする

- **WHEN** harvest セッション検索用の環境変数が未設定の状態でレポート生成が実行される
- **THEN** SKILL.md の記述に従い該当サブセクション（harvest セッション集計）は省略され、レポート生成の他のセクションは通常どおり出力される

### Requirement: weekly-report は harvest plugin の現行命名・実態に整合する

`plugins/weekly-report/skills/weekly-report/SKILL.md` は廃止済みの「1h-cooking」命名を使用してはならない (MUST NOT)。harvest plugin の現行の責務分離モデル（プラグイン本体は marketplace dir、コンテンツは各作業 repo の cwd 直下 `data/sessions/<slug>.jsonl`）に整合する記述に更新しなければならない (MUST)。

#### Scenario: 1h-cooking 言及が残っていない

- **WHEN** `plugins/weekly-report/skills/weekly-report/SKILL.md` 内で大文字小文字を無視して `1h-cooking` を grep する
- **THEN** 該当行は 0 件である

#### Scenario: harvest の実態に沿った検索パターンが記載されている

- **WHEN** ユーザーが更新後の該当サブセクション（旧 Step 4d）を読む
- **THEN** `data/sessions/<slug>.jsonl` という作業 repo cwd 直下分散のパターンでセッション jsonl を検索する旨が記載されている

