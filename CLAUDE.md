# CLAUDE.md — oratta-claude-harness

このリポジトリは Claude Code プラグインの配布元（marketplace）で、install すると `~/.claude/plugins/marketplaces/oratta-claude-harness/` に clone が置かれる。
その clone は Claude Code が自動更新するインストール成果物であって、**開発場所ではない**。開発は marketplace dir の外に置いた別の clone とその worktree で行う。

## 開発場所

- 開発用 clone は marketplace dir の外の任意の場所に置く。置き場所は PC ごとに自由で、パスをこのリポジトリの文書やスクリプトに固定で書かない。場所は環境変数 **`CLAUDE_HARNESS_DEV_DIR`**（`~/.claude/settings.json` の `env`）で解決する。他のプロジェクトで作業中に harness を直したくなったときの手順は `rules/plugin-editing.md` の「開発用 clone の場所」を参照 — 作業中のリポジトリの中でも marketplace dir でも直さない
- worktree はその開発用 clone から生やす
- marketplace dir では **feature ブランチを checkout しない・編集しない**。常に main のまま自動更新に任せる
- Claude Code が実行時に読むのは `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` で、marketplace dir はそのコピー元にすぎない。cache はバージョンを上げなくても marketplace dir の HEAD に追随する。marketplace dir を feature ブランチにしていると、Claude Code の自動更新や `scripts/sync.sh` の `git pull --ff-only` がそのブランチ上で走り、cache にもマージ前の内容が入る
- worktree の管理情報は再 clone されうる `.git` の中にあるため、marketplace dir から生やした worktree は自動更新で失われることがある。開発を外に出すのはこの構造を避けるため
- マージ前の動作確認は `claude --plugin-dir <worktree のパス>/plugins/<プラグイン名>` で、そのセッションだけプラグインを読み込ませて行う。`--plugin-dir` が取るのは `.claude-plugin/plugin.json` を持つ**プラグイン 1 個のディレクトリ**で、リポジトリのルート（`.claude-plugin/marketplace.json` を持つ marketplace）を渡しても警告なしに何も読み込まれない。複数のプラグインを見るときは `--plugin-dir` を繰り返す
- マージ後の反映は `/plugin marketplace update oratta-claude-harness`（または新規セッション起動時の自動更新）→ `/reload-plugins` か新規セッション。`/plugin update` というスラッシュコマンドは存在しない

## PR 運用ルール

Draft PR は早い段階で作る。目的は作業のバックアップではなく、レビューと可視化（何が進行中かを remote 側から見える状態にすること）。

- worktree 作成と同時に **Draft PR を作る**（`/wt-setup --with-pr` 推奨）
- 細かい単位で commit → push し、PR を逐次更新する
- PR はマージ前ならクローズしても取り戻せる。Draft 状態は破壊的でない
- 動作確認まで終わったら **Ready for Review** に切り替えて merge する
- main への直接 push は禁止（明示承認が必要）

`/wt-setup --with-pr` を使わずに手動で運用する場合は、以下のフローを踏む:

```bash
git commit --allow-empty -m "chore: init draft PR for <branch>"
git push -u origin <branch>
gh pr create --draft --head <branch> --base main --title "<branch>" --body "<テンプレ>"
```

旧運用（marketplace dir 配下で checkout し worktree を生やす形）からの移行と、marketplace dir に残った worktree の扱いは `docs/worktree-recovery.md` を参照。

## LLM ログ保存先

**LLM 会話ログはこのリポジトリの配下に置かない**（marketplace dir 側・開発用 clone 側とも）。marketplace dir は自動更新で再 clone されると untracked ファイルごと消えるし、開発用 clone でもログは tracked の対象ではない。

- 保存先は環境変数 **`LLM_LOG_DIR`** を参照する
- `LLM_LOG_DIR` が未設定の場合は **ユーザーに保存先を確認すること**。デフォルトパスを勝手に決めて書き込まない（個人のディレクトリ構成を git に残さないため）
- このリポジトリ配下（`./LLM/` を含む）には絶対に書かない

`daily-report` / `weekly-report` など LLM ログを扱う skill を呼び出すときも、この優先順位でパスを解決すること。

CI を将来追加する場合の設計指針（Draft PR では skip するパターン）は `docs/ci-design.md` を参照。

## 適用範囲

この開発場所と PR 運用のルールは **「Claude Code プラグインの配布元リポジトリ（install 先が自動更新される）」** だから必要なものです。
一般の作業 repo にはこのルールを適用する必要はありません。

関連: `~/.claude/rules/git-commit-policy.md`（細かい commit 推奨、main 直 push 禁止）、`~/.claude/rules/plugin-editing.md`（プラグインをどこで編集するか・バージョン運用）も参照。
