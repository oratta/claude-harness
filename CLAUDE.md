# CLAUDE.md — oratta-claude-harness

このリポジトリは Claude Code プラグインの配布元（marketplace）で、install すると `~/.claude/plugins/marketplaces/oratta-claude-harness/` に clone が置かれる。
その clone は Claude Code が自動更新するインストール成果物であって、**開発場所ではない**。開発は marketplace dir の外に置いた別の clone とその worktree で行う。

## 開発場所

- 開発用 clone は marketplace dir の外に置く。場所は PC ごとに違うのでパスを文書やスクリプトに固定で書かず、環境変数 **`CLAUDE_HARNESS_DEV_DIR`**（`~/.claude/settings.json` の `env`）で解決する。worktree はその clone から生やす
- marketplace dir では **feature ブランチを checkout しない・編集しない**。常に main のまま自動更新に任せる（feature ブランチにすると自動更新や `scripts/sync.sh` の pull がそのブランチ上で走り、実行時に読まれる `~/.claude/plugins/cache/` にマージ前の内容が入る）
- 他のプロジェクトで作業中に harness を直したくなったときの手順、マージ前の `claude --plugin-dir` での動作確認、マージ後の反映、`plugin.json` の bump、状態が壊れたときの復旧は `docs/worktree-recovery.md` を参照

## PR 運用ルール

Draft PR は早い段階で作る。目的は作業のバックアップではなく、レビューと可視化（何が進行中かを remote 側から見える状態にすること）。

- worktree 作成と同時に **Draft PR を作る**（`/wt-setup --with-pr` 推奨）
- 細かい単位で commit → push し、PR を逐次更新する
- 動作確認まで終わったら **Ready for Review** に切り替えて merge する
- main への直接 push は禁止（明示承認が必要）

旧運用（marketplace dir 配下で checkout し worktree を生やす形）からの移行と、marketplace dir に残った worktree の扱いは `docs/worktree-recovery.md` を参照。

## LLM ログ保存先

**LLM 会話ログはこのリポジトリの配下に置かない**（`./LLM/` を含む。marketplace dir 側・開発用 clone 側とも）。marketplace dir は自動更新で再 clone されると untracked ファイルごと消える。

- 保存先は環境変数 **`LLM_LOG_DIR`** を参照する。未設定なら **ユーザーに保存先を確認する**（デフォルトパスを勝手に決めて書き込まない）
- `daily-report` / `weekly-report` など LLM ログを扱う skill を呼び出すときも、この優先順位でパスを解決する

CI を将来追加する場合の設計指針（Draft PR では skip するパターン）は `docs/ci-design.md` を参照。

## 常時注入の予算

常時注入される固定分（`rules/` / `CLAUDE.md` / `output-styles/` / 各種 `description`）の合計は、`tests/injection-budget.bats` が `tests/injection-budget.txt` の予算と突き合わせ、増えすぎても減らしすぎても落ちる。予算ファイルは聖域（機械マージの対象外）なので、値を動かす PR は本文に理由（何を削ろうとして、なぜその値にするか）を書くこと。

## 適用範囲

この開発場所と PR 運用のルールは **「Claude Code プラグインの配布元リポジトリ（install 先が自動更新される）」** だから必要なもので、一般の作業 repo には適用しない。

関連: `~/.claude/rules/git-commit-policy.md`（細かい commit 推奨、main 直 push 禁止）、`~/.claude/rules/plugin-editing.md`（プラグインをどこで編集するか・バージョン運用）。
