## Why

意思決定移譲のフレームワーク「観点の配役」（正本: claude.ai artifact、2026-08-17 主承認済み）で、主へのエスカレーション可否は「論点に必要な観点を配役表に当て、担い手が主のときだけ上げる」方式に確定した。観点カタログ v1（3グループ14観点・列定義・変更手続き）と判例台帳の形式も確定している（oratta/claude-harness#112 にデータ全文）。

しかし現状、カタログ（観点語彙の正本）・配役既定表・判例台帳には置き場所も宣言形式も存在せず、フレームワークは宣言止まりである。フレームワーク自身が「移譲は観点を担う仕組みの実装が伴って初めて成立する」と定めており、仕組みが無い限り主の認知負荷は下がらない。全プロジェクト共通に効かせられる層は harness（rules/ の常時ロード層＋plugins/ の参照時ロード層）にしかないため、ここに実装する。

## What Changes

- **新プラグイン `plugins/casting/`**: 観点カタログの正本 `catalog/catalog.md`（version front matter・列定義・14観点・横断軸・変更手続き・変更記録）、配役表と判例台帳の書き方を定義する `skills/casting/SKILL.md`、対象 repo に `.claude/casting/` 一式を生成する `/casting:init` コマンド、雛形2枚（project.md / precedents.md）、語彙 lint と起案シグナル検出の `scripts/casting-check.sh`
- **`rules/perspective-casting.md` 新設**: 主に判断を求める前の返信前チェック5手順だけを持つ薄い常時ロード層（30行以内）。`rules/README.md` の一覧にも追記
- **`.claude-plugin/marketplace.json`**: casting プラグイン登録とトップレベル version 同期

## Capabilities

### New Capabilities

- `casting-catalog`: 観点カタログ正本の構成（version・列定義・14観点・横断軸）、語彙の固定、変更手続き（軽量/重量2ルート）、常時ロード層 rule の要件を規定する capability
- `casting-project-files`: プロジェクト側 `.claude/casting/` の3層配置規約（project.md / local.md / セッション宣言）、判例台帳の形式、`/casting:init` の生成動作、`casting-check.sh` の検出項目を規定する capability

## Impact

- `plugins/casting/.claude-plugin/plugin.json` — 新設
- `plugins/casting/README.md` — 新設
- `plugins/casting/catalog/catalog.md` — 新設（正本データは issue #112 の表から転記）
- `plugins/casting/skills/casting/SKILL.md` — 新設
- `plugins/casting/commands/init.md` — 新設
- `plugins/casting/templates/project.md` / `templates/precedents.md` — 新設
- `plugins/casting/scripts/casting-check.sh` — 新設
- `plugins/casting/tests/casting-check.bats` / `tests/casting-init.bats` — 新設
- `rules/perspective-casting.md` — 新設、`rules/README.md` — 一覧追記
- `.claude-plugin/marketplace.json` — casting 追加・version bump
- 既存プラグインへの変更なし。既存プロジェクトへの影響は `/casting:init` を実行するまで無い
