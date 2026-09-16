---
name: cost
description: そのブランチ・PR・issue にかかった API 換算コストを、会話ログから集計して 1 行で返す。`/cost` は現在のブランチ、`/cost <番号>` は番号が PR か issue かを GitHub に問い合わせて振り分ける。「コストいくら」「この PR の費用」「issue のコスト」で起動。
allowed-tools: Bash
---

会話ログ（`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/**/*.jsonl`）を 1 パスで読み、API 換算のコストを集計する。集計・判別・書式のすべては `scripts/cost_ledger.py` の `cost` サブコマンドが持つ。**このコマンドは単価も換算レートも出力書式も自分では持たない**（単価と換算レートの正本は `pricing.json`、1 行目の書式の正本は `headline()`）。

## 実行

集計スクリプトの絶対パスを特定して、そのまま呼ぶ。

```bash
for dir in \
  "${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/scripts}" \
  ~/.claude/plugins/marketplaces/*/plugins/cost-ledger/scripts \
  ~/.claude/plugins/installed/*/cost-ledger/scripts; do
  [ -n "$dir" ] && [ -f "$dir/cost_ledger.py" ] && CL="$dir/cost_ledger.py" && break
done
python3 "$CL" cost $ARGUMENTS
```

引数の解釈はスクリプト側が行う。

| 呼び方 | 何が返るか |
|---|---|
| `/cost` | 作業ディレクトリの現在のブランチに帰属するコスト |
| `/cost <PR番号>` | その PR のヘッドブランチに帰属するコスト |
| `/cost <issue番号>` | その issue を触った区間のコスト合計（作業ディレクトリのリポジトリの行だけ） |

番号が PR か issue かは `gh api` で GitHub に問い合わせて判別する。**認証済みの `gh` と GitHub への到達性が要る**（コスト計算そのものはオフラインで完結するが、判別だけはネットワークに依存する）。どちらでもない番号は 0 円と表示せず、見つからないと伝えて終了コード 2 で終わる。

## 出力の扱い

1 行目が固定書式で、金額（USD と円）・換算レート・帰属先・帰属の種別をすべて含む。**PR に貼るときは 1 行目だけを取る**。2 行目以降は内訳で、issue 経路では区間ごとの寄せ先が並ぶ。

```
コスト: $108.23 / ¥16,235 @150 — PR #271 (oratta/token-optimize) 帰属: ブランチ
```

利用者にはこの 1 行目をそのまま見せ、内訳は聞かれたときだけ示す。issue 単位の数字は区間分割による推定なので、**断定せずに推定と伝える**。リポジトリ不明として別立てされた行があれば、その件数と金額も併せて伝える（`cwd` が削除済みでどのリポジトリの番号か絞れなかった行で、黙って落としても合算してもいない）。

円換算のレートは `pricing.json` の固定値で、環境変数 `COST_LEDGER_USD_JPY` で上書きできる。レートを変えたいと言われたら、この環境変数か `pricing.json` を案内する。
