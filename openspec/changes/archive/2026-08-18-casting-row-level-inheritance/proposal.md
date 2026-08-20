## Why

#112 の初期実装は `/casting:init` がカタログ全行を project.md に丸写しするコピー方式のため、カタログ（ユーザーデフォルト）を変更しても導入済みプロジェクトに反映されない。2026-08-18 に主と確定した期待仕様は「下の層は変えたい観点の行だけを書き、書いていない観点は自動的にカタログを踏襲する。カタログを書き換えれば上書きしていない全プロジェクトに自動で効く」。あわせて「カタログの書き込みは専用スクリプト経由に固定し、変更記録を自動で残す」「差分方式で失われる全体視認性は合成表示コマンドで補う」も確定した（oratta/claude-harness#114）。

## What Changes

- **行単位の差分上書き方式**: 解決順（強い順）セッション宣言 > local.md > project.md > catalog.md を観点（行）単位に確定。templates/project.md はカタログ全行コピーをやめ、空の差分表＋書き方説明に変更
- **`scripts/casting-set.sh` 新設**: カタログ書き込みの唯一の入口。`owner`（既定の担い手の行単位書き換え・軽量ルート）と `replace-catalog`（丸ごと差し替え・重量ルート・version 増加を強制）。変更記録の自動追記と、導入 repo 台帳を使った影響一覧（継承中／上書き中）の表示
- **導入 repo 台帳**: `~/.claude/casting/registry.txt`。`/casting:init` が冪等追記
- **`casting-check.sh resolve` 新設**: カタログ＋project＋local を行単位で合成した有効な配役表を由来列つきで出力
- **フィードバック動線の明文化**: 主のチャンネル発言による配役フィードバックを、そのターンで該当行の更新＋判例記録につなげる規約を SKILL.md と rules/perspective-casting.md に追記
- hooks による直接 Edit 禁止（強制層）はスコープ外（自己統治物件のため別途主承認）

## Capabilities

### Modified Capabilities

- `casting-catalog`: カタログの変更手続きに「書き込みは casting-set.sh 経由」を追加。返信前チェック rule にフィードバック動線を追加
- `casting-project-files`: 配置規約を行単位差分方式に変更。/casting:init の生成物と registry 追記。resolve の新要件

## Impact

- `plugins/casting/scripts/casting-set.sh` — 新設
- `plugins/casting/scripts/casting-check.sh` — resolve サブコマンド追加
- `plugins/casting/commands/init.md` — registry 追記の手順追加
- `plugins/casting/templates/project.md` — 差分方式に書き換え
- `plugins/casting/skills/casting/SKILL.md` — 行単位解決規則・casting-set 経由の変更手続き・フィードバック動線
- `rules/perspective-casting.md` — フィードバック動線1行追加（30行以内維持）
- `plugins/casting/tests/` — casting-set.bats / resolve ケース / registry ケース追加、既存フィクスチャの差分方式対応
- 未マージ PR #113 と同一ブランチに積む（互換性負債なし。導入済みプロジェクトはまだ無い）
