---
name: loops-review-queue
description: プロジェクト横断の「人間待ち」キューを優先順位付きで表示する。複数リポジトリで並行稼働する自律開発ループ（loop-dev-agent）のマージ判断待ち PR と、トリアージ待ち・要介入 issue を、GitHub Project「Review Queue」と gh search を突き合わせて「今どれから捌くべきか」（ブロッカー優先）の順に一覧する。`/loops:review-queue` で起動するほか、「レビュー待ちPRを一覧して」「マージ待ちを横断で見せて」「確認待ちタスクを見せて」「レビューキュー」でも起動。
allowed-tools: Read, Bash
---

# /loops:review-queue — プロジェクト横断の人間待ちキュー

複数リポジトリで並行する自律開発ループの「人間待ち」——マージ判断待ちの PR と、
トリアージ待ち（`agent-proposed` / `needs-approval`）・要介入（`agent-blocked`）の issue——を
1つのビューに集約し、**次にどれを捌くべきか**をブロッカー優先で提示する。読み取り専用であり、
PR・issue・ラベル・Project の状態は一切変更しない。

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

JSON から open なアイテム（PR と issue の両方）を対象に、以下を抽出する:
リポジトリ名 / タイトル / URL / `State` / `Blocked count` / `Updated`。

## Step 3: フォールバック検索（Project 未登録の拾い漏れ防止）

Project に登録されていない「人間待ち」も横断で拾う:

**owner は個人アカウントだけでなく所属組織も含める**（組織リポジトリのループを取りこぼさない。
`--owner` はカンマ区切りで複数指定できる）:

```bash
# 検索対象 owner = 自分 + 所属組織（カンマ区切りに連結）
OWNERS=$({ echo "$LOGIN"; gh api user/orgs --jq '.[].login'; } | paste -sd, -)
# 自分の open PR（手動作業分や連携導入前のループ PR。author 指定なので owner 不要）
gh search prs --author "@me" --state open --json repository,title,number,url,labels,isDraft,updatedAt --limit 100
# 人間の判断を待っている issue（組織リポジトリを含めて横断検索）
for label in agent-proposed agent-blocked needs-approval; do
  gh search issues --owner "$OWNERS" --state open --label "$label" --json repository,title,number,url,updatedAt --limit 50
done
```

Step 2 の結果と URL で突き合わせ、未登録のものは State をラベルから推定して表に混ぜ、`未登録` マークを付ける:
`agent-review:passed` → マージ判断 / `agent-review:failed` → 修正中 / `agent-review:pending` → レビュー中 /
`agent-proposed`・`needs-approval` → トリアージ / `agent-ready` → 着手可能 / `agent-blocked` → 要介入 /
それ以外の PR → `-`。

`needs-approval` がここに残っているものは、憲法の3軸ゲート（①止められるか ②決められるか ③取り消せるか）を
通らなかった issue である。落ちた軸と「人間が何を決めれば通るか」は issue のコメントに書かれているので、
トリアージの実体は**その1点を決めること**に絞られる。

## Step 4: 優先順位付けと表示

**人間のアクションが必要なもの**（マージ判断 / トリアージ / 要介入）だけを本表に載せ、
以下の順でソートした1枚のテーブルを表示する:

1. **Blocked count 降順**（他のタスクのブロッカーになっているものが最優先。ブロッカーを放置すると
   後続タスク全体が止まる）
2. 同率内は State の優先度: **マージ判断 → 要介入 → トリアージ**（マージ判断は放置すると main が進んで
   コンフリクトし再レビューコストが発生する。要介入はその issue のラインが完全停止している。
   トリアージは将来の仕事の供給なので相対的に緩い）
3. 次いで **更新が古い順**（滞留が長いものを先に）

レビュー中 / 修正中 / 着手可能（ループが処理中・実行待ち）は本表に載せず、末尾に件数のみ添える。

表の後に必ず添えるもの:

- **推奨アクション 1 行**: 「まず `<repo>#<番号>` を<マージ判断|トリアージ|介入>（Blocked count N・M 日滞留）」の形式
- Project の URL（ボードで見たい場合のリンク）
- ネイティブ dependencies で blocked 状態の issue には GitHub がボード上に「Blocked」アイコンを出すこと
  （ブロックされている側は着手対象でないことの注意）

## してはならないこと

- PR・issue・ラベル・Project アイテムの作成・変更・削除（このスキルは読み取り専用）
- `gh pr merge` の実行や提案コマンドへの含め込み（マージ判断は人間の仕事）
- Project が無いからといって勝手に作成しない（作成は `/loops:dev-agent-install` の責務）
