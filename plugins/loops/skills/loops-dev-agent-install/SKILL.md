---
name: loops-dev-agent-install
description: 自律開発ループ（loop-dev-agent レシピ）を対象リポジトリに導入する。docs/agent-loop.md（憲法ファイル）の生成、GitHub ラベル一式の作成、issue テンプレート、permission deny ルール、pre-push フックの設置までを一括で行う。`/loops:dev-agent-install` で起動するほか、「自律開発ループを導入して」「dev-agent ループをセットアップ」でも起動。既存のバックログ md ファイルがあれば issue への移行も提案する。
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

# /loops:dev-agent-install — 自律開発ループの導入

`plugins/loops/recipes/loop-dev-agent.md` レシピをプロジェクトに導入する。
このスキルは**セットアップのみ**を行う。ループの実行系はネイティブプリミティブ `/loop` であり、
このスキルは常駐プロセスやラッパースクリプトを一切作らない。

導入の設計原則（レシピ本文より）:

- **提案と実行の分離**: 人間のゴーサインは issue への `agent-ready` ラベル付与のみ
- **ガードはプロンプトでなくインフラ**: main の封鎖は deny ルール + pre-push フックで物理的に行う
- **1 issue = 1 worktree = 1 ブランチ = 1 Draft PR**、マージは人間
- **証拠ベースの完了判定**: テスト・ビルドの exit code をターン内に表示

## Step 0: preflight

対象リポジトリのルートで以下を確認する。満たさないものがあれば報告して中断する。

```bash
git rev-parse --show-toplevel        # git リポジトリであること
gh auth status                       # gh CLI が認証済みであること
git remote get-url origin            # GitHub remote があること
gh repo view --json viewerPermission # push 権限があること
```

`docs/agent-loop.md` が既に存在する場合は「再導入（上書き）か中断か」を確認する。

## Step 1: プロジェクト情報の収集

まず自動検出を試みる。検出できた値は質問せず、確認だけに使う:

- **main ブランチ名**: `git symbolic-ref refs/remotes/origin/HEAD` から検出
- **テスト / lint / ビルドコマンド**: `package.json` の scripts、`Makefile`、`Cargo.toml` 等から検出
- **dev サーバー起動コマンドと URL**: 同上（例: `npm run dev` / `http://localhost:3000`）

検出できなかった項目と以下の運用値を AskUserQuestion でまとめて確認する（デフォルトを推奨選択肢にする）:

| 項目 | デフォルト |
|---|---|
| ブラウザ実機検証（Web アプリか否か） | あり（Web アプリなら） |
| レート閾値 | 5時間枠 70% / 7日枠 85% |
| 朝ダイジェスト時刻 | 7 時 |
| 提案ストック上限 | 3 件 |
| worktree 置き場 | `~/orca/workspaces/<プロジェクト名>`（orca 標準） |

## Step 2: GitHub ラベルの作成

```bash
gh label create "agent-ready"          -c "#0E8A16" -d "人間が承認済み。ループが拾ってよい" --force
gh label create "agent-proposed"       -c "#FBCA04" -d "ループの自己生成タスク案。実行禁止" --force
gh label create "agent-wip"            -c "#1D76DB" -d "ループが着手中" --force
gh label create "agent-blocked"        -c "#B60205" -d "2回失敗して隔離。人間の判断待ち" --force
gh label create "needs-approval"       -c "#D93F0B" -d "実行に人間の承認が必要" --force
gh label create "human-only"           -c "#5319E7" -d "ループは触らない" --force
gh label create "size:large"           -c "#C2E0C6" -d "大型。着手せず分割提案のみ" --force
gh label create "agent-review:pending" -c "#BFD4F2" -d "レビューエージェント待ち" --force
gh label create "agent-review:passed"  -c "#0E8A16" -d "レビュー合格。マージ判断待ち" --force
gh label create "agent-review:failed"  -c "#E99695" -d "レビュー不合格。修正対象" --force
```

## Step 3: issue テンプレートの設置

`.github/ISSUE_TEMPLATE/agent-task.md` を作成する。**受け入れ条件の測定可能性がループの成功率を最も左右する**
（スコープ・コンテキスト・解決方向・粒度が揃った issue は PR マージ率を大きく上げるという実証がある）。

```markdown
---
name: Agent Task
about: 自律開発ループに実行させるタスク
---

## 概要

<!-- 1 issue = 1 論理タスク。複数の変更をバンドルしない -->

## 触るファイル・関数

<!-- 分かる範囲で。エージェントの探索時間を削る -->

## 受け入れ条件（測定可能な形で）

<!-- コマンド + 期待値で書く。例:
- [ ] `npm test` が exit 0
- [ ] `/api/foo` に GET すると 200 と `{ok: true}` が返る
- [ ] トップページに「◯◯」ボタンが表示され、押すと △△ に遷移する
-->

## 備考
```

## Step 4: 憲法ファイルの生成

`${CLAUDE_PLUGIN_ROOT}/templates/agent-loop-template.md` を読み、`{{...}}` プレースホルダを
Step 1 の値で置換して対象リポジトリの `docs/agent-loop.md` に書き出す。

置換対象: `{{MAIN_BRANCH}}` `{{TEST_CMD}}` `{{LINT_CMD}}` `{{BUILD_CMD}}` `{{DEV_SERVER_CMD}}`
`{{DEV_URL}}` `{{BROWSER_VERIFY}}` `{{WORKTREE_BASE}}` `{{RATE_5H_MAX}}` `{{RATE_7D_MAX}}`
`{{DIGEST_HOUR}}` `{{PROPOSAL_CAP}}`

該当しない項目（例: CLI ツールで dev サーバーが無い）は値を `なし` にする。

あわせてループの**状態ディレクトリ**を作成する。状態ファイルは git 管理外に置く
（ループがログを main にコミットすると origin と恒常的に分岐し、人間のマージ作業が再生産されるため。
main はループによって一切動かない設計とする）:

1. `.agent-loop/log.md` — 実行ログ（テーブルヘッダのみの初期状態）
2. `.agent-loop/GUARDRAILS.md` — 教訓集（「このプロジェクトで踏んだ地雷と回避策を1行ずつ追記する」という説明だけの初期状態）
3. `.gitignore` に `.agent-loop/` を追記する
4. 耐久バックアップ用の issue を作成する（ローカル状態ファイルの消失に備え、教訓は issue コメントにミラーされる）:

```bash
gh issue create --title "GUARDRAILS: ループの教訓集（バックアップ）" --body "自律開発ループの教訓のバックアップ先。ループは .agent-loop/GUARDRAILS.md への追記時に同内容をこの issue にコメントする。ローカルファイル消失時はこの issue から再構築する。クローズしない。タスクではないため agent-ready を付けない。"
```

## Step 5: permission deny ルールの設置

対象リポジトリの `.claude/settings.json` に以下を**マージ**する（既存の permissions がある場合は
deny 配列に追記。既存エントリは消さない）。main ブランチ名が `main` 以外なら読み替える。

```json
{
  "permissions": {
    "deny": [
      "Bash(git push origin main:*)",
      "Bash(git push origin master:*)",
      "Bash(git push -f:*)",
      "Bash(git push --force:*)",
      "Bash(git push --force-with-lease:*)",
      "Bash(git push --no-verify:*)",
      "Bash(gh pr merge:*)"
    ]
  }
}
```

> これはプロンプトではなくハーネスが実行前にブロックする層であり、無課金 private リポジトリで
> branch protection が使えない場合の主防壁になる。branch protection が使えるリポジトリでは
> あわせて GitHub 側でも main を保護すること（required status checks + PR 必須）。
>
> **`git merge` / `git rebase` そのものは deny しない**: レビューモードの main 追従
> （`origin/main` を feature ブランチへマージ）や worktree 掃除の正当なローカルマージを
> 塞いでしまうため。main への統合は「push する瞬間」に pre-push フック（全形式を捕捉）と
> 上記 push deny で封鎖する設計とする。deny のプレフィックスマッチはよくあるコマンド形のみを
> 捕捉するので、網羅的な防壁は Step 6 の pre-push フックが担う。

## Step 6: pre-push フックの設置

`.githooks/pre-push` を以下の内容で作成し、実行権限を付け、`core.hooksPath` を設定する。
worktree は同一リポジトリの config を共有するため、全 worktree に効く。

```sh
#!/bin/sh
# agent-loop policy: 保護ブランチへの直接 push を拒否する
protected="main master"
while read local_ref local_sha remote_ref remote_sha; do
  for b in $protected; do
    if [ "$remote_ref" = "refs/heads/$b" ]; then
      echo "pre-push: $b への直接 push は agent-loop ポリシーで禁止されています" >&2
      echo "pre-push: feature ブランチに push して PR を作成してください" >&2
      exit 1
    fi
  done
done
exit 0
```

```bash
chmod +x .githooks/pre-push
git config core.hooksPath .githooks
```

## Step 7: 既存バックログの移行（任意）

`docs/` やリポジトリルートにバックログ md ファイル（チェックボックス形式のタスクリスト）が
見つかったら、issue への移行を提案する。ユーザーが承認したら **`/loops:issueify` のフロー**
（`skills/loops-issueify/SKILL.md`）でそのファイルを処理する:
原子化 → 受け入れ条件の機械検証可能化 → 不足だけヒアリング → 確認して起票。

- タグがある場合のラベルマップ: 【自律可】→ `agent-ready`、【承認待ち】→ `needs-approval`、
  【人間】→ `human-only`
- 元ファイルには「issue へ移行済み（#番号リスト）」の注記を追記し、削除はしない

## Step 8: 完了レポート

以下を報告して終了する:

1. 作成・変更したファイルとラベルの一覧
2. 起動コマンド（コピペ可能な形で）:
   ```
   /loop 1h docs/agent-loop.md を読み、そこに定義された1サイクルを厳密に実行して。結果（実行モード、対象の issue/PR 番号、スキップ・提案の場合はその理由）を必ず報告して
   ```
3. 人間側の日常運用: 「`agent-proposed` を見て良いものに `agent-ready` を付ける」
   「`agent-review:passed` の PR をマージする」の 2 点だけであること
   （タスクを追加したくなったら書き殴りを `/loops:issueify` に渡せば、原子化と
   測定可能な受け入れ条件の定義までスキルがフォローすること）
4. 初回はパイロット実行（1〜2 サイクルを見ている状態で回す）を推奨すること
5. 権限モードは acceptEdits 以上でループを起動すること
6. レビュー段階の効果測定: `.agent-loop/log.md` のレビュー検出率が数週間ほぼ 0% なら
   レビューモードを外す判断ができること

## してはならないこと

- ループを回すための常駐スクリプト・cron 登録・ラッパー CLI を作らない（実行系は `/loop` に委ねる）
- 対象リポジトリの main に commit を積んだまま push しない（このスキル自身も設置変更のコミットは
  リポジトリの運用ルールに従う。PR 運用のリポジトリなら feature ブランチ + PR で入れる）
- `.claude/settings.json` の既存設定を破壊しない（deny の追記のみ）
