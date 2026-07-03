# Proposal: report-plugins-update

## Why

`plugins/weekly-report/` の Step 3b は `{source_path}/LLM/*.md`（廃止予定の obsidian-llm-session-rules / auto-save.py が生成する劣化コピー）を読む設計になっており、change-6（plugin-retirement）が両プラグインを削除すると weekly-report のセッションログ収集が壊れる。daily-report 側には `agents/llm-log-compactor.md` に native jsonl（`~/.claude/projects/*/`）を jq で直読する既存ロジックがあり、これを weekly-report に流用して依存を断ち切る必要がある（change-6 の前提条件）。

加えてレビューで以下の小粒バグが見つかっている: (1) weekly-report command が存在しないパス `.claude/skills/weekly-report/SKILL.md` を参照している、(2) weekly-report SKILL.md に個人パス `/Users/oratta/Dropbox/WorkSpace` がハードコードされている、(3) 同 SKILL.md に廃止済みの「1h-cooking」命名が残っている、(4) daily-report command の `allowed-tools` frontmatter に `Agent` が無いのに SKILL.md Phase 1 は Agent tool_use を 2 並列起動している。さらに両プラグインを `/schedule`（cron）経由で非対話実行したいというニーズがあるが、現状 SKILL.md はどちらも対話（AskUserQuestion 等）を前提にしており、非対話時の振る舞いが未定義。

## What Changes

- `plugins/weekly-report/skills/weekly-report/SKILL.md` の Step 3b/4d を、`{source_path}/LLM/*.md` 読み込みから `plugins/daily-report/agents/llm-log-compactor.md:33-100` の jq ロジックを流用した native jsonl（`~/.claude/projects/*/`）直読に置換する。auto-save.py 出力への参照を完全に断つ
- 同 SKILL.md の個人パス `/Users/oratta/Dropbox/WorkSpace` を環境変数ベース（未設定時は当該サブセクションを省略するフェイルソフト）に置換する
- 同 SKILL.md の「1h-cooking」言及を harvest plugin の現行命名・実態（`data/sessions/<slug>.jsonl`、作業 repo cwd 直下分散）に更新する
- `plugins/weekly-report/commands/weekly-report.md` の SKILL.md 参照パスを、存在しない `.claude/skills/weekly-report/SKILL.md` から plugin-relative な `skills/weekly-report/SKILL.md`（daily-report と同方式）に修正する
- `plugins/daily-report/commands/daily-report.md` の frontmatter `allowed-tools` に `Agent` を追加する（SKILL.md Phase 1 が Agent tool_use を並列起動する実挙動に合わせる）
- `plugins/daily-report/skills/daily-report/SKILL.md` と `plugins/weekly-report/skills/weekly-report/SKILL.md` の両方に「/schedule（cron）非対話実行モード」節を追加する。方針: AskUserQuestion が使えない場合はデフォルト値（daily=昨日、weekly=先週）で続行し、対話依存ステップは代替（ファイル出力等）に切り替え、下した判断は出力に判断ログとして残す
- `plugins/weekly-report/.claude-plugin/plugin.json` / `plugins/daily-report/.claude-plugin/plugin.json` の version bump と `.claude-plugin/marketplace.json` 対応エントリの同期（change-7 の依存関係リストに change-5 が含まれないため、本 change が自己完結で同期する）

## Capabilities

### New Capabilities

- `weekly-report-jsonl-direct`: weekly-report のセッションログ収集を native jsonl 直読に移行し、個人パス・廃止命名を解消する
- `report-command-hygiene`: weekly-report / daily-report 両 command ファイルの参照・frontmatter 不整合を修正する
- `report-noninteractive-mode`: daily-report / weekly-report 両 SKILL.md に cron 非対話実行モードを定義する

## Impact

- **変更ファイル**:
  - `plugins/weekly-report/skills/weekly-report/SKILL.md`
  - `plugins/weekly-report/commands/weekly-report.md`
  - `plugins/daily-report/commands/daily-report.md`
  - `plugins/daily-report/skills/daily-report/SKILL.md`
  - `plugins/weekly-report/.claude-plugin/plugin.json` / `plugins/daily-report/.claude-plugin/plugin.json`
  - `.claude-plugin/marketplace.json`（weekly-report / daily-report エントリの version・description 同期）
- **新規ファイル**: `plugins/weekly-report/tests/*.bats`（既存 daily-report と同様のテスト基盤を新設）
- **依存**: なし（独立）。ただし change-6（plugin-retirement）は本 change の完了（weekly-report が `{source_path}/LLM/` 参照を断つこと）を前提条件とする
- **非対象**: `plugins/obsidian-llm-session-rules/` / `plugins/skill-aware-workflow/` 自体の削除（change-6 の範囲）
