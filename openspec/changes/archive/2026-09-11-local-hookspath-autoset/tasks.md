## 1. wt-setup.sh の自動設定（worktree プラグイン）

- [x] 1.1 `plugins/worktree/tests/setup-script.bats` に回帰テストを 5 本足す（追跡あり・未設定 → 設定されメインチェックアウトからも見え、注意が出る／既に `.githooks` → 無出力で不変／別の値 → 上書きしない／`.githooks` 無し → 何もしない／未追跡の `.githooks` だけ → 何もしない）
- [x] 1.2 追加したテストが現状の wt-setup.sh に対して落ちる（Red）ことを確認する
- [x] 1.3 `plugins/worktree/scripts/wt-setup.sh` の `.claude/` 共有の後に `wt_enable_repo_githooks` を置き、依存チェックを次のステップに繰り下げる。ワークツリーで 1 回走ればメインチェックアウトにも効くこと、相対 `.githooks` は各作業ツリーのルートから解決されることをコメントに書く
- [x] 1.4 `plugins/worktree/skills/wt-setup/SKILL.md` に自動設定を追記し version を上げる。`plugins/worktree/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の worktree の description に 1 文足し、version を両方そろえて上げる
- [x] 1.5 worktree の bats が全部通る（Green）ことを確認する

## 2. push-guard-setup の文書（dev-workflow プラグイン）

- [x] 2.1 `plugins/dev-workflow/tests/push-guard-setup.bats` に、優先関係の成立条件・有効化の手順と確認方法・wt-setup の自動設定・kg-recruit#126 の文言検査と、例のローカル pre-push を実際に動かす検査（main 拒否・グローバルへ同じ標準入力と引数を渡す・自分自身を指すときは呼ばない）を足し、落ちることを確認する
- [x] 2.2 `plugins/dev-workflow/skills/push-guard-setup/SKILL.md` の層の構成の節を直し、リポジトリローカルのフックを有効にする手順の節を足して version を上げる
- [x] 2.3 `plugins/dev-workflow/.claude-plugin/plugin.json`・`.claude-plugin/marketplace.json`・`plugins/dev-workflow/CHANGELOG.md` を 2.10.1 にする

## 3. 検証

- [x] 3.1 worktree の bats 全部・`push-guard-setup.bats`・`tests/marketplace-sync.bats`・`tests/injection-budget.bats`・`tests/openspec-specs-format.bats` を `env -u CLAUDE_SECURESTORAGE_CONFIG_DIR` 付きで走らせ、`not ok` が 0 件であることを確認する
- [x] 3.2 `scripts/lint.sh` が通ることを確認する
- [x] 3.3 `openspec validate local-hookspath-autoset --strict` が通ることを確認する
