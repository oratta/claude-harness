## Why

mainにマージ済みのworktreeを削除すると、次の作業開始時に `wt-setup` で `.env` コピー / `.claude/` symlink / `npm install` 等を再実行する必要がある。クリーンで完全にマージ済みのworktreeはディレクトリごと残して再利用すれば、セットアップコストをゼロにできる。現状の `wt-clean` は「削除一択」なので再利用の選択肢を提供していない。

## What Changes

- `wt-clean` に `--keep` オプションを追加する（デフォルト動作は現状維持 = 削除）
- `--keep` 指定時、🟢 Safe に分類された worktree のみを「再利用可能化」する:
  - worktree ディレクトリは削除せず残す
  - worktree 内のブランチを `main`（または `master`）に切り替える
  - 元のマージ済みブランチを `git branch -d` で削除する
  - `node_modules` / `.env` / その他 untracked ファイルは一切触らない
- 🟡 Recoverable / 🔴 Active は `--keep` 指定時も従来通りの動作（LLM保全→削除 / スキップ）を維持する
- 完了レポートに「再利用可能化」されたworktreeのパスと、次作業開始コマンド（`cd <path> && git checkout -b <new-branch>`）を表示する
- Step 6 サニティチェックで FAIL した worktree は `--keep` 指定時も再利用化せず保留する（安全側）

## Capabilities

### New Capabilities
- `wt-clean-reuse`: `wt-clean` の再利用モード（`--keep` オプション）の動作仕様。🟢 Safe worktreeを削除せずにmain切替＋ブランチ削除で再利用可能化する挙動、および対象制限・完了レポート・サニティチェック連携を定義する。

### Modified Capabilities
<!-- 既存の wt-clean spec は存在しないため、Modified は無し -->

## Impact

- **影響ファイル**:
  - `plugins/worktree/commands/wt-clean.md` — `--keep` オプション受け入れとStep 7分岐
  - `plugins/worktree/skills/wt-clean/SKILL.md` — 同上、スキル版の記述も同期
  - `plugins/worktree/.claude-plugin/plugin.json` — バージョンを上げる（プラグインキャッシュ無効化のため）
- **互換性**: 既存動作は完全に維持。オプション未指定時は従来の全削除挙動。破壊的変更なし。
- **依存関係**: 追加の外部依存なし。`git worktree` / `git checkout` / `git branch -d` のみ使用。
