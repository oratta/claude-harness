# cost-ledger

issue / PR ごとに、その作業が API 換算でいくらかかったかを出すプラグイン。
Claude Code が既に書いている会話ログ（`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/**/*.jsonl`）を
読んで集計する。会話ログは既定 30 日で消えるので、環境変数 `COST_LEDGER_PATH` を設定すると
リポジトリ外の台帳へ焼き付けて、そこから読む（下の「台帳」）。

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

### 単価表のずれの警告

`pricing.json` の単価が実際の単価から離れていないかを、Claude Code 本体が出すセッションコストと
比べて確かめる。比べるのは、コストを答えるとき（`cost`・`branch`・`issue`）に答えに行が含まれた
セッションのうち、statusline プラグインが `${CLAUDE_CONFIG_DIR:-~/.claude}/.session-cost/<セッション ID>`
に本体の値を書き残しているものだけ。記録が無いセッションは比べない（statusline プラグインを
入れて `/statusline:setup` を実行すると、それ以降のセッションで記録が始まる）。

- 本体の値: 記録の最初の観測から最後の観測までに増えた分
- 自前の計算: そのセッションの行のうち、同じ時間の範囲にあるものを `pricing.json` の単価で計算した合計。
  本体の値はセッション全体の値なので、ブランチやリポジトリでは絞らない

2 つの差が **$0.50 を超え、かつ大きい方の 10% を超えた**セッションがあると、出力の 2 行目以降に
`単価表のずれ:` で始まる行が 1 行出る（該当が複数でも 1 行。差が最大のセッションの値を示す）。
料金表に単価の無いモデルの行がその時間の範囲にあるときは、差の大きさにかかわらず別の 1 行が出る。
どちらかが出たら `pricing.json` の単価を確かめて直す。1 行目と終了コードは警告の有無で変わらない。
`issue` の経路を `--json` で出すと、結果が `price_drift` に入る（知らせることが無ければ `null`）。

ブランチの経路では、比べるためにそのセッションの行をブランチで絞らずに集め直す（台帳があれば台帳、
無ければ会話ログ）。この読み直しは **既定 1 秒で打ち切り**、打ち切ったときは判定をせずに
`単価表のずれ: 未確認` の行を 1 行出す。最後まで突き合わせるには上限を変えて実行し直す。

```bash
COST_LEDGER_DRIFT_BUDGET_SECONDS=inf python3 scripts/cost_ledger.py cost
```

`COST_LEDGER_DRIFT_BUDGET_SECONDS` は 0 以上の秒数か `inf`（打ち切らない）。未設定・数として
読めない値・負の値は既定の 1 秒になる。`cost` に `--no-drift-check` を付けると突き合わせそのものを
行わない（ゲート通過時の自動投稿はこの引数を付けて呼ぶ）。

この警告は、料金表が表現していない課金（200K を超えるコンテキストの割増など）や、会話ログに行が
残らない呼び出しでも出ることがある。逆に、差が閾値以内のずれや、記録の無いセッションのずれには
気づかない。

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

## 台帳（会話ログが消えたあとも残す）

環境変数 **`COST_LEDGER_PATH`** に台帳ファイルのパスを書くと（`~/.claude/settings.json` の `env`）、
次の 2 つが動く。未設定なら何も書かず、会話ログを直接読む従来の動きのまま。

- **`Stop` の hook**（`scripts/ledger-hook.sh`）が、応答が終わるたびに会話ログの増えた分を台帳へ追記する
- **集計**（`/cost` と `cost_ledger.py` の集計系サブコマンド）は、読む前に同じ追記を 1 回行ってから台帳だけを読む。
  会話ログが消えたあとも同じ値が返る

台帳の 1 行は会話ログの 1 応答から抽出した事実（`cost_ledger.py facts` の 1 行と同じ）で、帰属は書かない。
追記だけを行い、既存の行は書き換えない。

- **場所**: 既定のパスは持たない。このリポジトリ（プラグイン）の配下を指していると終了コード 2 で止まる
  （marketplace dir は自動更新や再 clone で消えるため）
- **重複排除**: `requestId` が台帳に既にある応答は書かない（同じファイル内の分割行も、resume・fork で
  別ファイルに複製された履歴も 1 行）
- **控え**: 台帳の隣の `<台帳>.state.sqlite` に、会話ログごとの読み終え位置と台帳に書いた `requestId` の
  索引を持つ。速さのためだけのもので、消しても壊れても台帳から作り直して同じ結果になる。
  `<台帳>.lock` は同時に動く hook を直列にするためのロック
- **手動の取り込み**: `python3 scripts/cost_ledger.py ledger-sync`（初回は全履歴を読むので数十秒かかる）

規則の正本は openspec の spec `cost-ledger-persistence`。
