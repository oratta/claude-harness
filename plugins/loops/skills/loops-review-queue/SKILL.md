---
name: loops-review-queue
description: プロジェクト横断の「人間待ち」（マージ判断待ち PR・トリアージ待ち/要介入 issue）をブロッカー優先で一覧する。読み取り専用。`/loops:review-queue`、「レビュー待ちPRを一覧して」「マージ待ちを横断で見せて」「レビューキュー」で起動。
allowed-tools: Read, Bash
---

# /loops:review-queue — プロジェクト横断の人間待ちキュー

複数リポジトリで並行する自律開発ループの「人間待ち」——マージ判断待ちの PR と、
トリアージ待ち（`agent-proposed` / `needs-approval`）・要介入（`agent-blocked`、および
`agent-wip` が残ったまま止まった孤児 = stale-wip）の issue——を
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

### stale-wip（`agent-wip` が残ったまま止まった孤児）の検出

`agent-wip` は**同一サイクル内の一時ラベル**で、サイクル終了時に必ず外れる想定
（`plugins/loops/templates/agent-loop-template.md`。PR 作成・分割・`needs-approval` のいずれかで解除）。
サイクル完了前にセッションが落ちるとこのラベルが残り続け、次の2つの穴に同時に落ちる:

- `templates/select-target.sh` の実装モード選定は `agent-ready ∧ ¬agent-wip` だけを候補にするため、
  ループの自動選定から永久に外れる
- 上のフォールバック検索は `agent-proposed` / `agent-blocked` / `needs-approval` しか見ないため、
  人間にも見えない

結果として issue は「着手中の体」のまま無言で放置される。これを拾うため、`agent-wip` が付いた
open issue のうち**紐づく open PR が無く、かつ滞留が閾値を超えたもの**を stale-wip として検出する:

```bash
# 滞留の閾値（時間）。ハードコードせず環境変数で上書きできるようにする
# （レートガードの RATE_5H_MAX / RATE_5H_HEADROOM と同じ流儀）。
#
# 既定 24h の根拠: agent-wip は 1 サイクル内の一時ラベルであり、loop-dev-agent の
# 実行間隔の既定は 1h（`plugins/loops/recipes/loop-dev-agent.md`）。正常系なら 1 サイクル
# = 1h で外れるので、24h は 24 サイクル分空振りしたことを意味する。同レシピの朝ダイジェストが
# 滞留を日次で可視化する周期とも一致する。短く詰めると実行中のサイクルを孤児と誤検出する。
STALE_WIP_HOURS="${STALE_WIP_HOURS:-24}"
STALE_WIP_LIMIT="${STALE_WIP_LIMIT:-50}"
NOW_EPOCH=$(date -u +%s)

# owner はこのブロック内で再導出する。未定義のまま `--owner ""` を渡すと gh はエラーにせず
# GitHub 全体の横断検索にフォールバックし、意図と違うスコープのまま結果が出てしまう。
OWNERS=$({ gh api user --jq '.login'; gh api user/orgs --jq '.[].login'; } | paste -sd, -)
[ -n "$OWNERS" ] || { echo 'stale-wip: owner の解決に失敗（gh 未認証の可能性）。判定を中止' >&2; return 1 2>/dev/null || exit 1; }

# updatedAt（ISO8601 UTC）を epoch 秒に変換する。BSD date（macOS）と GNU date の両対応。
iso_to_epoch() {
  date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s 2>/dev/null || date -u -d "$1" +%s
}

# 候補の取得は fail-closed。gh が失敗したら空リストを「孤児ゼロ」と読まずに中止する
# （認証切れ・rate limit・API 障害を「全部健全」と誤報しないため）。
# --sort updated --order asc: 既定の best-match だと上限打ち切りで最古の孤児が落ちうる。
if ! WIP_TSV=$(gh search issues --owner "$OWNERS" --state open --label agent-wip \
     --sort updated --order asc \
     --json repository,title,number,url,updatedAt --limit "$STALE_WIP_LIMIT" \
     --jq '.[] | [.repository.nameWithOwner, .number, .updatedAt, .url, .title] | @tsv'); then
  echo 'stale-wip: agent-wip issue の取得に失敗。stale-wip 判定は「不明」として表に注記する' >&2
  WIP_TSV=''
fi
# 上限に張り付いたら未走査が残っている。件数を黙って減らさず注意を出す
[ "$(printf '%s' "$WIP_TSV" | grep -c .)" -ge "$STALE_WIP_LIMIT" ] &&
  echo "stale-wip: 候補が上限 $STALE_WIP_LIMIT 件に達した。STALE_WIP_LIMIT を上げて再実行する" >&2

printf '%s\n' "$WIP_TSV" | grep . | while IFS=$'\t' read -r REPO ISSUE_NUM UPDATED URL TITLE; do
    # 紐づく open PR があれば実装は進行中。孤児ではないので除外する。
    # 取得に失敗したときは「PR なし」に倒さない（進行中の issue を要介入と誤報するため）
    if ! LINKED=$(gh pr list --repo "$REPO" --search "$ISSUE_NUM in:body" --state open --json number --jq 'length'); then
      printf 'stale-wip?\t%s#%s\t判定不能（PR 取得に失敗）\t%s\t%s\n' "$REPO" "$ISSUE_NUM" "$URL" "$TITLE"
      continue
    fi
    case "$LINKED" in ''|*[!0-9]*) LINKED=0 ;; esac   # 非数値は 0 に潰さず上で弾いた後の保険
    if [ "$LINKED" -gt 0 ]; then continue; fi
    AGE_H=$(( (NOW_EPOCH - $(iso_to_epoch "$UPDATED")) / 3600 ))
    if [ "$AGE_H" -ge "$STALE_WIP_HOURS" ]; then
      printf 'stale-wip\t%s#%s\t%sh\t%s\t%s\n' "$REPO" "$ISSUE_NUM" "$AGE_H" "$URL" "$TITLE"
    fi
  done
```

閾値未満のものは実行中のサイクルとみなし、本表には載せない（末尾の件数にも数えない）。

**`in:body` は「リンク関係」ではなく本文テキスト検索であることに注意する。** GitHub の
Development 欄の紐づけは見ておらず、番号が本文に現れるだけの無関係な PR にも当たる
（実測例: `#89` がテスト出力行 `Test Files 89 passed` や「30〜89日=2倍」にヒットする）。
誤ヒットは**孤児を取りこぼす側**に倒れるので既存の見え方より悪くはならないが、
取りこぼしが疑わしいときは `--search "\"Closes #$ISSUE_NUM\" in:body"` のように
closing キーワードごと照合して絞り込む。逆に、本文に番号を書かず Development 欄だけで
リンクした PR は stale-wip として出るので、表の行を人間が見て判断する。

Step 2 の結果と URL で突き合わせ、未登録のものは State をラベルから推定して表に混ぜ、`未登録` マークを付ける:
`agent-review:passed` → マージ判断 / `agent-review:failed` → 修正中 / `agent-review:pending` → レビュー中 /
`agent-proposed`・`needs-approval` → トリアージ / `agent-ready` → 着手可能 / `agent-blocked` → 要介入 /
上で検出した stale-wip（`agent-wip` 単独・open PR 無し・閾値超え） → 要介入（stale-wip） /
上の `stale-wip?` 行（gh の取得に失敗して判定できなかったもの） → 要介入（stale-wip 判定不能） /
それ以外の PR → `-`。

**取得に失敗したものを「該当なし」に丸めない。** `gh` が認証切れ・rate limit・API 障害で
落ちたときに空結果を「孤児ゼロ」と読むと、このスキルは黙って何も報告しなくなる
（元の issue #155 が問題にした「見えない停止」を、検出側が自分で再生産することになる）。
失敗は必ず `判定不能` として表に出し、件数からも隠さない。

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
   トリアージは将来の仕事の供給なので相対的に緩い）。
   **stale-wip は要介入と同格**として扱う（`agent-blocked` は「止まったことが宣言されている」のに対し、
   stale-wip は「止まったことすら宣言されていない」ので、放置期間は同等かそれ以上に長い）
3. 次いで **更新が古い順**（滞留が長いものを先に）

レビュー中 / 修正中 / 着手可能（ループが処理中・実行待ち）は本表に載せず、末尾に件数のみ添える。

表の後に必ず添えるもの:

- **推奨アクション 1 行**: 「まず `<repo>#<番号>` を<マージ判断|トリアージ|介入>（Blocked count N・M 日滞留）」の形式
- stale-wip の行には State 欄に `要介入（stale-wip）` と書き、**何をすれば直るか**を 1 行添える:
  「サイクルが途中で落ちて `agent-wip` が残っている。再開するか `agent-wip` を外して
  `agent-ready` に戻すと、ループの選定対象に復帰する」（このスキルは読み取り専用なので操作はしない）
- Project の URL（ボードで見たい場合のリンク）
- ネイティブ dependencies で blocked 状態の issue には GitHub がボード上に「Blocked」アイコンを出すこと
  （ブロックされている側は着手対象でないことの注意）

## してはならないこと

- PR・issue・ラベル・Project アイテムの作成・変更・削除（このスキルは読み取り専用）
- 検出した stale-wip の `agent-wip` を自動で外す・`agent-ready` へ付け替える（表示までが責務。
  解除は人間か、該当ループ自身の再判断に委ねる）
- `gh pr merge` の実行や提案コマンドへの含め込み（マージ判断は人間の仕事）
- Project が無いからといって勝手に作成しない（作成は `/loops:dev-agent-install` の責務）
