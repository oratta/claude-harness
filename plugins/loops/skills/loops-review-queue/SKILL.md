---
name: loops-review-queue
description: プロジェクト横断のレビューキューを優先順位付きで表示する。複数リポジトリで並行稼働する自律開発ループ（loop-dev-agent）が出した PR を、GitHub Project「Review Queue」と gh search を突き合わせて「今どの PR から捌くべきか」の順に一覧する。`/loops:review-queue` で起動するほか、「レビュー待ちPRを一覧して」「マージ待ちを横断で見せて」「レビューキュー」でも起動。
allowed-tools: Read, Bash
---

# /loops:review-queue — プロジェクト横断レビューキュー

複数リポジトリで並行する自律開発ループのレビュー待ち PR を1つのビューに集約し、
**人間が次にどの PR を捌くべきか**を優先順位付きで提示する。読み取り専用であり、
PR やラベル、Project の状態は一切変更しない。

## Step 1: Review Queue Project の解決

```bash
LOGIN=$(gh api user --jq .login)
NUM=$(gh project list --owner "$LOGIN" --format json \
  --jq '.projects[] | select(.title == "Review Queue") | .number')
```

- 見つからない場合は Project 連携なしと判断し、Step 3（フォールバック検索）のみで表を作る。
- `project` scope が無いエラーが出た場合も同様にフォールバックし、
  有効化には `gh auth refresh -s project` が必要なことを最後に案内する。

## Step 2: Project アイテムの取得

```bash
gh project item-list "$NUM" --owner "$LOGIN" --format json --limit 200
```

JSON から open な PR アイテムだけを対象に、以下を抽出する:
リポジトリ名 / PR タイトル / URL / `Review state` / `Blocked count` / `Updated`。

## Step 3: フォールバック検索（Project 未登録 PR の拾い漏れ防止）

Project に登録されていない自分の open PR（手動作業分や連携導入前のループ PR）も横断で拾う:

```bash
gh search prs --author "@me" --state open --json repository,title,number,url,labels,isDraft,updatedAt --limit 100
```

Step 2 の結果と URL で突き合わせ、未登録のものは Review state をラベル
（`agent-review:passed` → Approved / `agent-review:failed` → Changes Requested /
`agent-review:pending` → Needs Review / それ以外 → `-`）から推定して表に混ぜ、
`未登録` マークを付ける。

## Step 4: 優先順位付けと表示

以下の順でソートした1枚のテーブルを表示する:

1. **Review state = Approved が最上位**（人間のマージ判断だけで前進する。放置すると main が進んでコンフリクトし、ループが再レビューをやり直すコストが発生する）
2. 同率内は **Blocked count 降順**（塞いでいる後続タスクが多い PR ほど先）
3. 次いで **更新が古い順**（滞留が長いものを先に）

表の後に必ず添えるもの:

- **推奨アクション 1 行**: 「まず `<repo>#<番号>` をマージ判断（Approved・Blocked count N・M 日滞留）」の形式
- Project の URL（ボードで見たい場合のリンク）
- Changes Requested / Needs Review はループが処理中であり人間の対応不要であること
  （2回失敗して `agent-blocked` になった issue がある場合のみ人間の判断が要る旨）

## してはならないこと

- PR・issue・ラベル・Project アイテムの作成・変更・削除（このスキルは読み取り専用）
- `gh pr merge` の実行や提案コマンドへの含め込み（マージ判断は人間の仕事）
- Project が無いからといって勝手に作成しない（作成は `/loops:dev-agent-install` の責務）
