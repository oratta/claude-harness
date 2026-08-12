---
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, Skill, ToolSearch
description: Fieldy音声+Obsidian Vault編集+LLMログ+Claude Codeセッションを集約して自然言語の日記を生成。--with-album でトイカメラ風 Vlog アルバムも併せて生成（デフォルトは女子 3 人版、--gene male で男性 Gene 版に切替）。
---

$ARGUMENTS に日付（例: `2026-05-13` または `yesterday`）が指定されていればその日、空欄なら **昨日** を対象にする。

## オプション

- `--with-album` — 日記生成完了後に marketing-harness の `vlog-album` スキルを呼び出し、diary.md と同じディレクトリに `album.png` を出力する（トイカメラ風 1024×1024 コンタクトシート）
- `--cells 9|16` — `--with-album` 指定時に vlog-album へ pass-through（デフォルト `9`、3×3）
- `--split office:private` — `--with-album` 指定時に vlog-album へ pass-through（デフォルト `2:1`）
- `--gene female|male` — `--with-album` 指定時に vlog-album へ pass-through（デフォルト `female`：3 人とも女性 startup 友達。`male` で旧デフォルトの男性 Gene を opt-in）

`--cells` / `--split` / `--gene` は `--with-album` を伴わない場合は無視される。

## 例

- `/daily-report` — 昨日の日記のみ
- `/daily-report 2026-05-13` — 指定日の日記のみ
- `/daily-report --with-album` — 昨日の日記 + Vlog アルバム（デフォルト = 女子 3 人）
- `/daily-report --with-album --gene male` — 昨日の日記 + Vlog アルバム（男性 Gene 版）
- `/daily-report 2026-05-13 --with-album --cells 16 --split 10:6` — 指定日の日記 + 4×4 アルバム

`skills/daily-report/SKILL.md` を読んでスキルの手順に従い、自然言語ナラティブの日次日記（および `--with-album` 指定時はアルバム）を生成してください。
