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

検出できなかった項目と以下の**契約項目**を AskUserQuestion でまとめて確認する（デフォルトを推奨選択肢にする）:

| 項目 | デフォルト |
|---|---|
| ブラウザ実機検証（Web アプリか否か） | あり（Web アプリなら） |
| 提案ストック上限 | 3 件 |
| worktree 置き場 | `~/orca/workspaces/<プロジェクト名>`（orca 標準） |
| Review Queue 連携 | あり（`project` scope があれば） |

**レート閾値・ヘッドルーム・朝ダイジェスト時刻は install では聞かない**（憲法テンプレから運用値プレースホルダを廃止済み）。
これらは実行時の環境変数で解決する: レートは配線側の `RATE_5H_MAX` / `RATE_5H_HEADROOM` / `RATE_7D_MAX` /
`RATE_7D_HEADROOM`（デフォルト 70/20/85/10）、朝ダイジェスト時刻は `AGENT_DIGEST_HOUR`（デフォルト 7）。
flatmate 常駐運転ではレート判定を配線側 hook が肩代わりするため、閾値の設定先も配線側になる（レシピ
`recipes/loop-dev-agent.md` の「起動コマンド」参照）。

**Review Queue 連携の扱い**: `gh auth status` のトークン scope に `project` が含まれていれば「あり」を推奨する。
含まれていなければ「なし」をデフォルトにし、有効化したい場合は `gh auth refresh -s project` を
ユーザー自身が実行する必要があることを伝える（対話認証のためスキルからは実行しない）。

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

## Step 2.5: Review Queue Project の準備（連携「あり」の場合のみ）

ユーザーレベルの GitHub Project「Review Queue」とカスタムフィールドを**冪等に**用意する。
既存があれば再利用し、無いものだけ作る:

```bash
LOGIN=$(gh api user --jq .login)
# 1. タイトル "Review Queue" の user project を探す。無ければ作成
gh project list --owner "$LOGIN" --format json --jq '.projects[] | select(.title == "Review Queue") | .number'
gh project create --owner "$LOGIN" --title "Review Queue" --format json --jq .number   # 見つからなかった場合のみ

# 2. カスタムフィールド（field-list で存在確認してから、無いものだけ作成）
gh project field-list <番号> --owner "$LOGIN" --format json --jq '.fields[].name'
gh project field-create <番号> --owner "$LOGIN" --name "State" \
  --data-type SINGLE_SELECT --single-select-options "レビュー中,修正中,着手可能,マージ判断,トリアージ,要介入"
gh project field-create <番号> --owner "$LOGIN" --name "Blocked count" --data-type NUMBER
```

State は PR の待ち（レビュー中 / 修正中 / マージ判断）と issue の待ち（着手可能 / トリアージ / 要介入）の
両方を1フィールドで扱う（対応表は憲法テンプレートの「Review Queue 連携」参照）。
**トリアージ → 着手可能 へのカードドラッグが承認操作**になり、ループが毎サイクル冒頭（Step 0.8）で
ラベル（`agent-ready`）に同期する。既存 Project のフィールドが
旧仕様（`Review state` 3値）の場合は、GraphQL の `updateProjectV2Field` ミューテーションで
フィールド名とオプションを上書き更新できる（field id は維持されるためビュー設定は壊れない。
ただしオプション id は変わるので既存 item の値は再設定が必要）。

確定した `<owner>/<番号>` を Step 4 の `{{REVIEW_QUEUE}}` に使う（連携「なし」の場合は `なし`）。

ビューと built-in workflow は API 非対応のため、初回作成時のみ以下の手動設定（2 分）を完了レポートで案内する:

1. ボードビューを追加し、列（グルーピング）を `State` に、カード並び順を `Blocked count` 降順、
   フィルタを `is:open` にする。Fields で `Blocked count` と `Repository` をカード表示に加える
2. Workflows → 「Auto-archive items」を有効化し、フィルタを `is:issue,pr is:closed updated:<@today-2w` にする

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
`{{DEV_URL}}` `{{BROWSER_VERIFY}}` `{{WORKTREE_BASE}}` `{{PROPOSAL_CAP}}`
`{{REVIEW_QUEUE}}`（Step 2.5 の `<owner>/<番号>`、連携なしなら `なし`）

レート閾値・ヘッドルーム・朝ダイジェスト時刻のプレースホルダは新テンプレには存在しない（実行時の環境変数で解決するため。Step 1 参照）。置換不要。

該当しない項目（例: CLI ツールで dev サーバーが無い）は値を `なし` にする。

あわせて**対象選定スクリプト**を設置する。`${CLAUDE_PLUGIN_ROOT}/templates/select-target.sh` を読み、
`{{PROPOSAL_CAP}}` を Step 1 の値で置換して対象リポジトリの `scripts/agent-loop-select.sh` に書き出し、実行権限を付ける:

```bash
mkdir -p scripts
# {{PROPOSAL_CAP}} を置換して書き出す（他のプレースホルダは無い）
sed "s/{{PROPOSAL_CAP}}/<提案ストック上限>/g" "${CLAUDE_PLUGIN_ROOT}/templates/select-target.sh" > scripts/agent-loop-select.sh
chmod +x scripts/agent-loop-select.sh
```

このスクリプトは Step 1〜4 のモード選定（どのモードで・どの issue/PR 番号を対象にするか）を決定論的に行い、
JSON 1 オブジェクトを出力する。憲法の「Step 0.9: 対象選定」がこれを必須で呼び、LLM が一覧を目視して
対象番号を捏造する事故を構造的に防ぐ。`.agent-loop/`（git 管理外）ではなく `scripts/`（追跡対象）に置く
——選定ロジックはインフラであり、状態キャッシュではないため。

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
2. 起動コマンド: `/loops:dev-agent-start`（デフォルト間隔 1h。`/loops:dev-agent-start 2h` で変更可）。
   手動で `/loop` に貼る場合の正規文字列も併記する:
   ```
   /loop 1h docs/agent-loop.md を読み、そこに定義された1サイクルを厳密に実行して。結果（実行モード、対象の issue/PR 番号、スキップ・提案の場合はその理由）を必ず報告して
   ```
3. 人間側の日常運用: 「`agent-proposed` を見て良いものに `agent-ready` を付ける」
   「`agent-review:passed` の PR をマージする」の 2 点だけであること
   （Review Queue 連携ありの場合はマージ判断を Project ボードの Approved 列で横断確認できること、
   Project の URL、初回のみ必要なビュー・workflow の手動設定（Step 2.5）、
   ターミナルからは `/loops:review-queue` で同じキューを一覧できることも添える）
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
