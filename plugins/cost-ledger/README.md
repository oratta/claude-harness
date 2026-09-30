# cost-ledger

issue / PR ごとに、その作業が API 換算でいくらかかったかを出すプラグイン。追加の記録を仕込まず、
Claude Code が既に書いている会話ログ（`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/**/*.jsonl`）を
読んで集計する。

## 実行時に必要なもの

| 依存 | 用途 |
|---|---|
| **python3**（3.8 以上） | 集計エンジン本体。JSONL の 1 パス処理と辞書集計に使う |
| **git 2.31 以上** | `rev-parse --path-format=absolute --git-common-dir` で worktree を親リポジトリに畳む |
| **gh**（認証済み） | 渡された番号が PR か issue かの判別。コスト計算そのものはオフラインで完結する |

## 帰属の考え方

帰属の鍵は 2 本立てで、互いに独立している。同じ行が両方に帰属することがあるので、
`/cost <PR番号>` と `/cost <issue番号>` の値を足して総額としては**ならない**。

1. **ブランチ**（`gitBranch`）。サブエージェント（`isSidechain: true`）の行にも入るので、
   サブエージェントの消費も同じブランチへ寄る。
2. **（リポジトリ識別子, issue 番号）の組**。issue 番号は `gh issue view/comment/edit/close/develop`
   に渡された番号をツール呼び出しから拾う。issue 番号はリポジトリ内でしか一意でないので、
   番号だけを鍵にはしない。

issue への帰属は、投稿（`gh pr comment` / `gh issue comment` / `gh pr create` / `gh pr ready`）から
投稿までを 1 区間として、区間ごとに直近に触った issue へ寄せる。区間は `sessionId` ごとに切る。
1 セッションが複数 issue を触り、かつ複数セッションが同じブランチで並行するため。
**issue 単位の数字は区間分割による推定**で、PR 単位の数字ほど確かではない。

## 料金表と円換算

単価（$/MTok）と USD から円への換算レートは `pricing.json` **だけ**が持つ。集計の実装は自前の単価を
持たない。単価はモデル名の**最長一致の前方一致**で引くので、`claude-haiku-4-5-20251001` は
`claude-haiku-4-5` の行に当たり、`claude-fable-5-1` は `claude-fable-5` ではなく `claude-fable-5-1`
に当たる（表の並び順に依存しない）。

円換算は固定レート。実行のたびに外部から取りにいかないので、同じログなら何度実行しても同じ円が出る。
実勢に合わせたいときは環境変数 **`COST_LEDGER_USD_JPY`** で上書きする（名前は `pricing.json` の
`usd_jpy_rate_env` にも書いてある）。出力には必ず用いたレートが添えられる。

```bash
COST_LEDGER_USD_JPY=155 python3 scripts/cost_ledger.py branch oratta/issue-cost
```

料金表のどの鍵にも前方一致しないモデルは**未知モデル**として、名前と行数が出力に出る。黙って 0 円に
落とさない。同じく、`cwd` が削除済みでリポジトリ識別子が導けなかった行は「リポジトリ不明」として
件数と金額が別立てで出る。

## ゲート通過時の自動投稿

pr-review-gate が合格ラベル `agent-review:passed` を付けた直後に、その PR へ `/cost <PR番号>` の
1 行目と同じ行をコメントで貼る。PostToolUse（matcher `Bash`）の hook `scripts/gate-report.sh` が、
付与のコマンド（`gh api .../issues/<番号>/labels -f 'labels[]=agent-review:passed'`、または
`gh pr edit` / `gh issue edit` の `--add-label agent-review:passed`）を見て動く。LLM のトークンは使わない。

- **何を**: `scripts/cost_ledger.py cost <PR番号>` の出力の 1 行目と、時点の行（`YYYY-MM-DD HH:MM 時点・ゲート通過時に自動投稿`）。
  最終行に目印 `<!-- cost-ledger:gate-report -->` を置く
- **どこに**: ラベルを付けた PR。貼る前にラベルが実際に付いたことを API で確かめ、付いていなければ貼らない
- **1 本だけ**: 目印付きのコメントが既にあれば、新しく作らずにそれを書き換える。再ゲートでもコメントは増えない
- **数字の範囲**: ラベルを付けたターンより前の分しか含まない（hook はそのターンの途中で動くため）
- **止め方**: 環境変数 `COST_LEDGER_GATE_REPORT=off`（settings.json の `env` に置く）

どの失敗でもゲートは止めず、何も出力しない。コメントが付かなかったときは再ゲートか手動の `/cost` で
取り返せる。規則の正本は openspec の spec `cost-ledger-gate-report`。
