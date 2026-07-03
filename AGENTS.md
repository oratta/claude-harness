# AGENTS.md — oratta-claude-harness

このリポジトリは Claude Code プラグインの marketplace dir として運用される（インストール後は `~/.claude/plugins/marketplaces/oratta-claude-harness/` に展開される）。
Claude Code のプラグイン自動更新で dir が書き換えられて worktree が吹き飛ぶ事故が再発するため、worktree の作業内容は常に remote の Draft PR にバックアップしておく運用とする。

このファイルは `CLAUDE.md` と同内容で、Codex CLI などの他コーディングエージェントから参照される。両ファイルを同期して保つこと。

## PR 運用ルール

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

## 復元手順（worktree dir がプラグイン更新で消えた場合）

```bash
# 1. branch を取得
git fetch origin <branch-name>

# 2. 新しい worktree を作る（marketplace dir の外がおすすめ）
git worktree add ~/.superset/worktrees/<uuid>/<branch-name> <branch-name>

# 3. wt-setup で開発環境を整える
cd ~/.superset/worktrees/<uuid>/<branch-name>
# Claude Code を立ち上げて /wt-setup
```

session.jsonl のような ephemeral ファイルは **復元対象外**。Draft PR にバックアップされるのは git tracked なファイルと commit 履歴のみ。

## LLM ログ保存先

このリポジトリ配下に `LLM/` を作っても plugin update（dir 再 clone）で untracked ファイルごと消える。**LLM 会話ログはこの marketplace dir の外に保存すること**。

- 保存先は環境変数 **`LLM_LOG_DIR`** を参照する
- `LLM_LOG_DIR` が未設定の場合は **ユーザーに保存先を確認すること**。デフォルトパスを勝手に決めて書き込まない（個人のディレクトリ構成を git に残さないため）
- このリポジトリ配下（`./LLM/` を含む）には絶対に書かない

`daily-report` / `weekly-report` など LLM ログを扱う skill を呼び出すときも、この優先順位でパスを解決すること。

## CI 設計指針（将来 CI を追加するときの参考）

現状このリポジトリには `.github/workflows/` が無いが、追加する場合は **Draft PR では CI を skip するパターン** を使う:

```yaml
on:
  push:
  pull_request:
    types: [opened, reopened, ready_for_review, synchronize]

jobs:
  build:
    if: github.event_name == 'push' || github.event.pull_request.draft == false
    runs-on: ubuntu-latest
    # ...
```

- 普通の push（feature branch への直接 push 含む）では走る
- Draft PR の push では skip
- Ready for Review に切り替えた瞬間に走る
- Preview deploy 系は Draft でも走らせて OK（プレビュー用途のため）

## 適用範囲

この PR 運用ルールは **「Claude Code プラグイン自体のリポジトリ（marketplace dir 配下に置かれる前提）」** だから必要なものです。
一般の作業 repo にはこのルールを適用する必要はありません。

関連: `~/.claude/rules/git-commit-policy.md`（細かい commit 推奨、main 直 push 禁止）、`~/.claude/rules/plugin-editing.md`（marketplace 版のみを編集する）も参照。
