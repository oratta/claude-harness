## Why

`wt-clean` は現状「ローカル `main` に既にマージされている worktree」しか Safe と判定できない。一方、Issue-Driven workflow（plan → exec → PR → GitHub マージ）では feature ブランチは **GitHub 側でマージ**されるため、ローカル `main` は遅れたままで、worktree は依然 Active 扱いになる。

このギャップを埋めるため、過去に「`longrun-pr-merge-sync`」という別スキルが想定されていた（`git pull origin main` で同期してから feature ブランチを削除する役割）。だが両者の差は実質「事前に `git pull origin <main>` するか否か」の 1 点だけで、責務分割するほどの差ではない。`wt-clean` に remote 同期フェーズを 1 段追加すれば、PR マージ後の片付けも同一フローで処理できる。

合わせて `wt-clean` Step 7b に明記されている「`git pull` / `git fetch` — 最新化はユーザー責任」という方針は、Step 7b 内部（再利用化処理中）の限定事項に書き換える。診断前の事前同期は wt-clean の責務とする。

## What Changes

- `wt-clean` 実行フローの先頭に **Step 0: Remote 同期** を追加する
  - `git fetch origin` を実行
  - `origin/<main_branch>` がローカル `<main_branch>` より進んでいれば、`git pull --ff-only origin <main_branch>` を実行
  - メインリポ自体が `<main_branch>` をチェックアウトしている前提（既存の Step 1 と同じ前提）
- デフォルト挙動を「同期 ON」とする（破壊的変更）。後方互換のため `--no-sync` オプションを追加し、従来の「同期しない」挙動を選べるようにする
- `--keep` との併用可：`wt-clean --keep` と `wt-clean --no-sync` は組み合わせて指定可能
- Step 7b の「実行してはならない操作」記述から `git pull` / `git fetch` を取り除き、その範囲を Step 7b 内部に限定する旨を明記する
- Step 8 完了レポートに「Remote 同期: ✅ pulled N commits / -- skipped (--no-sync) / -- already up-to-date」のいずれかを 1 行追加する
- `longrun-pr-merge-sync` という別スキル候補は **作成しない**ことを backlog に明記する（重複機能のため）

## Capabilities

### New Capabilities

- `wt-clean-remote-sync`: `wt-clean` の事前 remote 同期フェーズの仕様。`git fetch` + `git pull --ff-only` の実行条件、`--no-sync` オプション、失敗時の扱い、完了レポートでの表示を定義する。

### Modified Capabilities

- `wt-clean-reuse`: Step 7b 内の「実行してはならない操作」記述を、`wt-clean` 全体ではなく Step 7b（再利用化処理）に閉じた制約として明確化する。事前同期フェーズで `git pull` するのは Step 7b の禁則と衝突しない、と spec 上明記する。

## Impact

- **影響ファイル**:
  - `plugins/worktree/commands/wt-clean.md` — Step 0 追加、`--no-sync` オプション、Step 7b 文言調整、Step 8 レポート行追加
  - `plugins/worktree/skills/wt-clean/SKILL.md` — 同上、frontmatter `version` を 1.1.0 → 1.2.0 に bump、`description` に PR マージ後の同期に対応する旨を追記
  - `plugins/worktree/.claude-plugin/plugin.json` — `version` を bump（キャッシュ無効化）
  - `.claude-plugin/marketplace.json` — `worktree` プラグインの version を同期
  - `openspec/backlog.md` — `longrun-pr-merge-sync` 候補のキャンセル理由を 1 セクション追記
- **互換性**: デフォルト挙動が変わる（同期 ON）。`--no-sync` で従来挙動を再現可能。CI 等で wt-clean を非対話で叩いている箇所がある場合は `--no-sync` への移行が必要だが、現状そのようなユースケースは存在しない見込み。
- **依存関係**: 追加の外部依存なし。`git fetch` / `git pull --ff-only` のみ使用。`gh` CLI 等は使わない（PR 状態の問い合わせは不要 — `git branch --merged` で十分）。
