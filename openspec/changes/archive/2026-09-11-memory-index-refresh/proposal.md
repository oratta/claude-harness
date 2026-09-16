# memory-index-refresh

## Why

メモリ（`~/.claude/projects/<project>/memory/`）の索引 MEMORY.md は毎セッション注入されるが、リポジトリの外にあるため `tests/injection-budget.bats` では測れない。書く規約（1 件 1 事実・repo が記録していることは保存しない・間違いは削除）はあっても見直す手順が無く、claude-harness プロジェクトでは 27 件・58,428 バイト（索引 5,410 バイト / 34 行）まで、終わった事実・名前と中身の食い違い・repo との重複を抱えたまま増えていた（2026-09-11 の実測）。古い記憶は容量より判断を誤らせる方向で効く。エピック #257 の子 #294（検知）と #295（修復）。

## What Changes

- SessionStart hook `session-tripwires.sh` から新しい `memory-tripwire.sh` を呼び、索引のバイト数・行数、本文 1 件の最大バイト数、索引の最終更新からの日数のどれかが閾値を超えたときだけ、`[memory]` で始まる 1 行を注入文の先頭に足す。通知だけで、止めない・削らない
- 閾値の初期値は索引 4,000 バイト / 20 行、本文 1 件 2,500 バイト、最終更新から 30 日で、環境変数で上書きできる。本文の閾値は issue #294 本文の案（1,500）ではなく、初回整理の実測（維持と判断した 12 件の最大が 2,192 で、5 件が 1,500 を超える）から 2,500 にした
- メモリを 1 件ずつ削除・統合・短縮・維持に分類し、主の承認と控えを取ってから手で適用する `memory-refresh` スキルと `/memory-refresh` コマンドを足す。スクリプトにはしない（判断の中身が「終わった事実か」「repo が持っているか」のため）

## Capabilities

### New Capabilities

- `dev-workflow-memory-refresh`: メモリ索引の検知（SessionStart の通知）と、見直しの手順（memory-refresh スキル）

### Modified Capabilities

なし。`dev-workflow-escalation-tripwires` の SessionStart 要件（トリップワイヤー節と残量モードの注入）はそのまま成り立ち、閾値未満では注入内容が 1 バイトも変わらない。`dev-workflow-execution-strategy` の「監査の出力を SessionStart の注入に足してはならない」はサブエージェントのコンテキスト監査の出力についての要件で、この change の通知は対象外（閾値を超えたときだけの 1 行で、固定分を常時増やさない）。

## Impact

- `plugins/dev-workflow/scripts/memory-tripwire.sh`（新規）と `scripts/session-tripwires.sh`（呼び出しと注入の 5 行）
- `plugins/dev-workflow/skills/memory-refresh/SKILL.md` と `commands/memory-refresh.md`（新規）
- `plugins/dev-workflow/tests/memory-tripwire.bats` と `tests/memory-refresh-skill.bats`（新規）
- `plugins/dev-workflow/.claude-plugin/plugin.json`（2.11.0、スキルとコマンドの登録）・`.claude-plugin/marketplace.json`・`plugins/dev-workflow/CHANGELOG.md`
- 常時注入の予算: スキルとコマンドの description で 278 バイト増え、合計 54,234 / 予算 54,500（予算ファイルは変更なし）
