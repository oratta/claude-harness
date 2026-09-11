## Context

cost-ledger は子1（#273、change `cost-ledger-aggregation`）で集計エンジン `plugins/cost-ledger/scripts/cost_ledger.py` と `/cost` コマンドを持った。`cost` サブコマンドは番号が PR か issue かを `gh api repos/{owner}/{repo}/pulls/<番号>` で判別し、PR ならヘッドブランチの全セッション合計を返す。出力の 1 行目は `headline()` だけが作る固定書式で、`openspec/specs/cost-ledger-cost-command/spec.md` が「後続のゲート連携が 1 行目だけを取って PR に貼る」前提で要件にしている。この change はその「後続のゲート連携」を作る。

ゲート通過は、pr-review-gate の手順 5 が合格ラベルを付けるコマンド（`plugins/dev-workflow/skills/pr-review-gate/SKILL.md:299` の `gh api -X POST repos/$R/issues/$N/labels -f 'labels[]=agent-review:passed'`）として Bash のツール呼び出しに現れる。PostToolUse hook はこの呼び出しの直後に、`tool_input.command` と `cwd` を JSON で stdin に受け取る。

設計の 7 点は issue #276 の本文で主の承認を得て確定している。この design はその 7 点を前提に、本文が決めていなかった点（主にラベル付与コマンドから対象 PR をどう取り出すか）を埋める。

既存 capability との関係:

| capability | この change での扱い |
|---|---|
| `cost-ledger-cost-command` | 変えない。hook は `cost` サブコマンドを呼び、その 1 行目をそのまま貼る利用者になる |
| `cost-ledger-attribution` | 区間の境界の根拠として `prototypes/per-post-cost.py` を名指ししている記述だけを直す（境界の集合は変えない）。hook が実行する `gh` はツール呼び出しではないので、区間の境界にも issue 帰属にも現れない |
| `cost-ledger-pricing` | プロトタイプの実行を前提にしたシナリオ 1 つを置き換える |
| `cost-ledger-gate-report`（新規） | ゲート通過時の投稿の規則すべて。独立の capability にするのは、発火条件と投稿先が既存 3 つのどれとも別の関心（いつ・どこに貼るか）だから |

## Goals / Non-Goals

**Goals:**

- `agent-review:passed` を付けた直後に、その PR へ `/cost <PR番号>` の 1 行目と同じ行を、LLM のトークンを使わずに貼る
- PR 1 本につきコメントは 1 本。再ゲートでは同じコメントを書き換える
- 全 Bash 呼び出しで起動しても、対象外の呼び出しには bash 1 回ぶんの費用しか乗せない（50 ms 未満）
- どんな失敗でもゲートを止めず、文脈にも何も入れない

**Non-Goals:**

- 区間コスト（自セッションの transcript 1 本から出す額）を貼ること。貼るのは PR 全体の合計（issue 本文の決定 6）
- 台帳（#274）の読み取り。#274 が `/cost` の読み取り元を台帳に切り替えれば、hook は変更なしでその値を貼る
- pr-review-gate のスキル本文の変更、ゲートの通過条件への関与
- 有効・無効の設定項目（緊急停止の環境変数だけを持つ）

## Decisions

### 1. event は PostToolUse / matcher `Bash`、fast path は stdin の文字列判定だけ

`gate-report.sh` は最初に `COST_LEDGER_GATE_REPORT=off` を見て抜け、次に stdin を `payload="$(cat)"` で読み、`case` で `*agent-review:passed*` に当たらなければ即 `exit 0` する。ここまで jq も python3 も起動しない（dev-workflow の `context-tripwire.sh` と同じ形）。fast path を通ったものだけを python3 で JSON としてパースし、`tool_input.command` に対して厳密な判定をする。payload は環境変数や引数に載せず stdin で渡す（長い出力で ARG_MAX を超えて hook が落ちるのを避ける。dev-workflow の hook と同じ理由）。

fast path の判定対象が payload 全体なのは、PostToolUse の payload には `tool_response`（コマンドの出力）も入るため。ラベル一覧を表示しただけの呼び出しも fast path を通るが、その先の厳密な判定で落ち、python3 を 1 回余計に起動して無音で終わるだけになる。逆向き（対象の呼び出しを fast path で落とすこと）は起きない。

**hooks.json の `if` フィールド（permission rule 構文）では絞らない。** issue 本文は「使えるなら絞る」としていたが、次の決定 2 の調査で、ラベル付与の多くは `R=...; N=...` で始まる・`for` で回す・`gh pr edit` を使う、のどれかの形だった。`Bash(gh api *)` のような前方一致の規則はこれらを落とす。fast path だけで 50 ms 未満に収まるので、取りこぼしの危険を増やしてまで絞る利点がない。

### 2. ラベル付与コマンドから対象 PR を取り出す規則

issue 本文は「リポジトリと PR 番号がコマンド文字列に含まれる」としていたが、会話ログ全体（2026-09-11 時点）から `agent-review:passed` を付けた Bash 呼び出しを分類すると、そのままは成り立たなかった。

| 形 | 件数 | 例 |
|---|---|---|
| `repos/<owner>/<repo>/issues/<番号>/labels` がリテラル | 64 | `gh api -X POST repos/oratta/claude-harness/issues/238/labels -f 'labels[]=agent-review:passed'` |
| 同じコマンド内で代入したシェル変数 | 160 | `R=oratta/claude-harness; N=189` のあとに `repos/$R/issues/$N/labels` |
| `for N in <番号...>; do ... done` で複数 PR | 14 | `R=oratta/kg-recruit` / `for N in 96 97; do` |
| `gh pr edit <番号> --add-label agent-review:passed` | 9 | `gh pr edit 313 --remove-label ... --add-label agent-review:passed` |

件数は正規表現で分類した概数（ほかに `-X POST` を書かない `gh api ... -f 'labels[]=...'` の形が数件あった）。Bash ツールはシェル変数を呼び出し間で持ち越さないので、変数の形はすべて同じコマンドの中で代入している。

したがって厳密な判定は次の順で行う。

1. **付与の形かどうか**: `gh api` の呼び出しで、パスが `repos/<A>/issues/<B>/labels`（`<A>` は `owner/repo` か変数）であり、同じ呼び出しに `labels[]=agent-review:passed` があり、`-X DELETE` / `--method DELETE` が無いもの。または `gh pr edit` / `gh issue edit` で `--add-label` の値に `agent-review:passed` を含むもの。`gh api` は `-f` を渡すと既定で POST になるので `-X POST` の有無は問わない。手順 2 の「stale な passed を外す」`gh api -X DELETE repos/$R/issues/$N/labels/agent-review:passed` は付与ではないので当たらない
2. **変数の解決**: 同じコマンドの中の単純な代入（`NAME=値`。値は引用符付きでもよいが、`$(...)`・バッククォート・他の変数展開を含む値は解決しない）と、`for NAME in <リテラルの並び>; do` を集め、`$NAME` / `${NAME}` を展開する。`for` は並びの各値を対象にする
3. **リポジトリ**: `gh api` の形は展開後のパスから `owner/repo` を取る。`gh pr edit` の形は `-R` / `--repo` の値、無ければ hook の `cwd` のリポジトリ
4. **解決できなかった対象は黙って飛ばす**。コマンドの評価（`eval` やシェルでの再実行）は決してしない。任意のコマンドを 2 回実行することになるから

飛ばした場合に失われるのはコストのコメント 1 本だけで、ゲートの結果には影響しない。再ゲートか手動の `/cost` で取り返せる。

**代替案**: (a) リテラルの形だけを扱う — 付与の約 7 割を取りこぼし、受け入れ条件の実機確認（この PR 自身のゲート）も変数の形で書かれる見込みが高いので採らない。(b) pr-review-gate のスキル本文をリテラルの形に書き換える — スキル本文に手を入れない方針（proposal）に反し、エージェントが書く形を強制できないので採らない。(c) 解決できないときは `cwd` の現在のブランチの PR に貼る — ラベルを付けた PR と `cwd` のブランチが一致する保証がなく、別の PR に誤って貼る危険があるので採らない。

### 3. 貼る前にラベルが実際に付いたことを確かめる

対象ごとに `gh api repos/<owner>/<repo>/issues/<番号> --jq '.labels[].name'` を 1 回叩き、`agent-review:passed` が無ければ貼らない。PostToolUse はツールが終わったことを知らせるだけで、複合コマンドの中の付与が成功したかは分からない（`gh` は静かに失敗することがあると pr-review-gate 自身が書いている）。付与に失敗したゲートに「ゲート通過時に自動投稿」と書かれたコメントが付くと、記録として誤りになる。費用は fast path を通った対象 1 件あたり API 1 回。

### 4. 数字は `cost_ledger.py cost <番号>` から取り、`GH_REPO` で問い合わせ先を揃える

hook は `python3 <プラグイン>/scripts/cost_ledger.py cost <番号> --repo <cwd>` を、環境変数 `GH_REPO=<owner/repo>` を付けて実行し、終了コード 0 で 1 行目が `コスト: ` で始まるときだけその 1 行目を使う。`cost` の中の判別は `gh api repos/{owner}/{repo}/pulls/<番号>` で、`{owner}/{repo}` の置換は `GH_REPO` があればそれに従う（2026-09-11 に実機で確認）。これで、ラベルを付けたリポジトリと `cwd` のリポジトリが違っても、ラベルを付けた PR の番号として判別される。PR の経路はヘッドブランチ名だけで集計するので、`cwd` がどこでも合計は変わらない。

集計・書式を hook 側に持たないので、1 行目は同時点の `/cost <PR番号>` の 1 行目と一致する（受け入れ条件の実機確認はこれを見る）。

### 5. 貼る形: マーカー付きコメント 1 本を書き換える

本文は次の 3 行。1 行目が `headline()` の出力そのものであることが、`/cost` との突き合わせと、「1 行目だけを取れば貼れる」という `cost-ledger-cost-command` の要件の使い方になる。マーカーは 1 行目を汚さないよう最終行に置く。

```
コスト: $108.23 / ¥16,235 @150 — PR #271 (oratta/token-optimize) 帰属: ブランチ
2026-09-11 16:05 時点・ゲート通過時に自動投稿
<!-- cost-ledger:gate-report -->
```

時刻は hook を実行したマシンのローカル時刻。既存コメントの検索は `gh api --paginate repos/<owner>/<repo>/issues/<番号>/comments` で本文にマーカーを含む最初の 1 件を取り、あれば `gh api -X PATCH repos/<owner>/<repo>/issues/comments/<id> -f body=...`、無ければ `gh api -X POST repos/<owner>/<repo>/issues/<番号>/comments -f body=...`。PATCH が失敗したときに新規作成へ切り替えない（コメントを増やさないことを優先する）。

このコメントは pr-review-gate が照合するコメント（1 行目が `仕様化判断:` / `仕様レビュー:`、本文に `対象 HEAD:` を含むもの）のどれにも当たらない。

### 6. 同期実行・`timeout: 60`・出力なし

`async: true` は使わない。完了を保証できず、bats で結果を確かめにくくなる。全履歴の走査は実測 7.8 秒（3,028 ファイル・1.8GB、2026-09-11）で、ゲート通過は PR あたり 1〜数回なので待てる。`for` で複数 PR を付与した場合は順に処理し、60 秒で打ち切られたら残りは貼られない（再ゲートで埋まる）。

stdout にも stderr にも何も出さず、どの経路でも終了コードは 0。hook の stdout が空なら文脈に何も入らない。

### 7. 実装の置き場所と形

`plugins/cost-ledger/hooks/hooks.json` と `plugins/cost-ledger/scripts/gate-report.sh` の 2 ファイル。`gate-report.sh` は bash の fast path のあと、判定と投稿を fd 3 のヒアドキュメントで渡す python3 に任せる（`context-tripwire.sh` / `agent-model-guard.sh` と同じ形）。python3 は cost-ledger の既存の実行時依存なので、依存は増えない。`cost_ledger.py` の場所は `${CLAUDE_PLUGIN_ROOT}` からではなく、スクリプト自身の位置（`$(dirname "$0")`）から引く。hook の起動時に `CLAUDE_PLUGIN_ROOT` が入る保証を bats で再現しにくく、同じディレクトリにあることは配布物の構造で決まっているため。

## Risks / Trade-offs

- [変数や `for` の書き方が想定外の形だと取りこぼす] → 取りこぼしはコメントが付かないだけでゲートに影響しない。bats に実ログで見た 4 つの形をそれぞれ入れ、実機確認で実際のゲートの書き方を確かめる
- [全 Bash 呼び出しで bash が 1 回起動する] → fast path で python3 を起動しない。対象外の呼び出しでの実測（50 ms 未満）を PR に貼る
- [同じ PR で 2 つのゲートがほぼ同時に通ると、どちらも既存コメントを見つけられず 2 本できる] → 起きるのはゲートの並走時だけで、次の再ゲートは最初の 1 本を書き換える。発生頻度が低く、ロックを持つ費用に見合わないので受け入れる
- [数字はラベル付与のターンより前の分しか含まない] → issue 本文の決定 7 のとおり許容し、コメントに時点を書く
- [`^plugins/[^/]+/hooks/` が聖域なので人間マージになる] → 主は承知済み
- [プロトタイプを消すと、設計の根拠になった数字をそのスクリプトで再現できなくなる] → 数字と測り方は archive 済みの `cost-ledger-aggregation` の design とエピック #272 に残っている。本番実装との突き合わせは子1 の tasks 9.1・9.2 で済んでいる。必要なら git の履歴から取り出せる

## Migration Plan

新規の hook なので移行は無い。マージ後、`/plugin marketplace update oratta-claude-harness` → `/reload-plugins` で cost-ledger を入れている環境に hook が入る。止めたいときは `COST_LEDGER_GATE_REPORT=off` を settings.json の `env` に置く。戻すときは hooks.json を消す PR を出す（これも聖域なので人間マージ）。

## Open Questions

なし。hooks.json の `if` フィールドの可否は、決定 1 のとおり使わないので確かめる必要がなくなった。
