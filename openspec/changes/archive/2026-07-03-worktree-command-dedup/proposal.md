# Proposal: worktree-command-dedup

## Why

`plugins/worktree/` は command（`commands/wt-clean.md` / `commands/wt-setup.md`）と skill（`skills/wt-clean/SKILL.md` / `skills/wt-setup/SKILL.md`）に **同一の実行フロー本文を二重に持っている**。SKILL.md は v2.0.0 で squash マージ検出（検証 A/B/C）と「AskUserQuestion 回答到着後の別ターンで破壊操作を実行する絶対禁則」を備えているが、`commands/wt-clean.md` は旧分類表（`AHEAD_COUNT>0 → 🔴`）のまま取り残されており、command 経由で起動すると squash 済みブランチをマージ済みと認識できず **誤削除事故が再発しうる**（付録 D-1）。`commands/wt-setup.md` も SKILL.md とほぼ全文重複しており drift の温床になっている（付録 D-2）。

散文契約の二重管理は、片方だけ更新されて無言でドリフトする本 run 全体の根本課題そのものである。安全性クリティカルな診断ロジックを **正の 1 箇所（SKILL.md）に一本化** し、command はそれを Read して実行する薄いラッパーに落とすことで、command 経由と skill 経由の診断フローを構造的に一致させる。

加えて、`scripts/wt-setup.sh` の `.worktreeinclude` 展開に使う `find -path` グロブと `.claude/settings.local.json` の symlink 処理は、実挙動未確認のまま放置されている（付録 D-3・低優先）。実挙動を確認し、問題がなければ意図をコメントで明文化する。

## What Changes

- `plugins/worktree/commands/wt-clean.md` を、対応する `${CLAUDE_PLUGIN_ROOT}/skills/wt-clean/SKILL.md` を Read tool で読み込みメインセッションでインライン実行する薄いラッパーに置き換える（`plugins/lr/commands/e.md` 方式）。診断分類表・実行フロー本文・squash 検出ロジックの重複コピーを command から除去する
- `plugins/worktree/commands/wt-setup.md` を同様に `skills/wt-setup/SKILL.md` の薄いラッパーに置き換える。Step 1-6 の手順本文の重複コピーを除去する
- 両 command の frontmatter（`allowed-tools`、wt-setup の `argument-hint`）を維持し、`$ARGUMENTS` を SKILL.md の実行にそのまま透過する
- squash マージ検出（検証 A/B/C）と AskUserQuestion 別ターン実行の絶対禁則は `skills/wt-clean/SKILL.md` の 1 箇所にのみ残し、command 経由・skill 経由のどちらでも同一の SKILL.md 本文が実行されることを保証する
- `plugins/worktree/scripts/wt-setup.sh` の `find -path` グロブ挙動と `settings.local.json` symlink の是非を実挙動確認し、問題がなければ現状維持 + 意図コメント追記、問題があれば修正する
- バージョン: worktree plugin.json を 2.1.1 → 2.2.0 に bump（marketplace.json の version・description 最終同期は change-7 が担当。本 change は marketplace.json に手を出さない）

## Capabilities

### New Capabilities

- `worktree-command-wrapper`: wt-clean / wt-setup の両 command を SKILL.md の薄いラッパーに落とす構造、command からの手順本文重複の排除、frontmatter 維持と引数透過、安全性クリティカル禁則の SKILL.md 一本化、command 経由と skill 経由の診断フロー一致を定義する
- `worktree-setup-script-integrity`: `wt-setup.sh` の `find -path` グロブと `settings.local.json` symlink の実挙動確認と意図の文書化（現状維持 + コメント、または修正）を定義する

## Impact

- **変更ファイル**:
  - `plugins/worktree/commands/wt-clean.md`（全文重複 → SKILL.md ラッパーへ置換）
  - `plugins/worktree/commands/wt-setup.md`（全文重複 → SKILL.md ラッパーへ置換）
  - `plugins/worktree/scripts/wt-setup.sh`（`find -path` グロブ / symlink の意図コメント追記、必要なら修正）
  - `plugins/worktree/.claude-plugin/plugin.json`（version 2.1.1 → 2.2.0）
- **不変更（正の一本化先）**:
  - `plugins/worktree/skills/wt-clean/SKILL.md`（squash 検出 A/B/C・絶対禁則を含む正。一言一句失わない）
  - `plugins/worktree/skills/wt-setup/SKILL.md`（Step 1-6 の正）
- **依存**: 独立（他 change に依存しない）。ただし marketplace.json の最終同期は change-7 が全編集プラグインをまとめて行う
- **非対象**: SKILL.md 側のフロー本文の書き換え（squash 検出・禁則を含め現状を保全する）、wt-clean/wt-setup の機能追加、他プラグインの command
