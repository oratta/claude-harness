## ADDED Requirements

### Requirement: issue の合計は、閉じた PR の分と、PR のブランチ上に無い区間の分の和である
システムは「issue の合計」を、次の 2 つの和と SHALL 定める。

- **PR の分**: 渡された PR 1 件ごとに、行のブランチ名がその PR のヘッドブランチと一致する行の合計。`/cost <PR番号>` と同じ引き方で、リポジトリでは絞らない
- **PR の外の分**: その issue に帰属した区間の行（「issue による帰属（第 2 の鍵）」が数える行）のうち、行のブランチ名が、渡された PR のどのヘッドブランチとも一致しない行の合計

システムは同じ行を 2 回数えてはなら MUST NOT ない。同じヘッドブランチを持つ PR が複数渡されたときは、番号のいちばん小さい PR だけを数え、残りは PR の分にも内訳にも入れてはなら MUST NOT ない。PR が 1 件も渡されないとき、issue の合計は `/cost <issue番号>` の値（区間の合計）と同じで MUST ある。入出力トークンとキャッシュトークンの合計も、金額と同じ行の集合から数え SHALL る。

`cost_ledger.py issue <番号>` は `--closing-pr <PR番号>:<ヘッドブランチ>`（繰り返し可）を受け、JSON 出力に次の鍵を足 MUST す。既存の鍵（`total_usd`・`intervals` など）の値と、表示の 1 行目は変えてはなら MUST NOT ない。

- `closing_prs`: 数えた PR の `{"number", "branch", "usd"}` の配列。番号の昇順。`--closing-pr` が無ければ空の配列
- `outside_pr_usd`: PR の外の分。`--closing-pr` が無ければ `total_usd` と同じ値
- `combined_total_usd`: issue の合計。`closing_prs` の `usd` の和と `outside_pr_usd` の和に等しい

`--closing-pr` を渡した表示（`--json` 無し）では、1 行目の下に、合計と内訳（PR ごとの額と、PR の外の額）を 1 行で SHALL 出す。`--closing-pr` の値は最初の `:` で 2 つに分け、前が 1 以上の整数、後ろが空でない文字列のときだけ受け、それ以外は標準エラーに理由を書いて終了コード 2 を返 MUST す。

守備範囲: この計算が受け取る入力は、台帳または会話ログの行と、`--closing-pr` の引数（hook の裏のプロセスが GitHub の応答から組み立てたもの、または人が手で打ったもの）に限る。拾いたい誤りは、同じ行を PR の分と区間の分の両方で数えること・同じブランチの行を 2 件の PR で 2 回数えること・形の崩れた `--closing-pr`（`704`・`:feat`・`x:feat`・`704:`）を黙って読み飛ばして、PR を数えていない値を合計として返すことの 3 つ。次の入力は誤ったまま通ることを許す: 実在しない PR 番号や、その PR のものではないブランチ名を渡した `--closing-pr`（`999:main` など）は、そのブランチの行の合計がその番号の PR の分として出る（PR とブランチの対応は `gh` を呼ばないと確かめられない）／同じ名前のブランチを別の作業や別のリポジトリで使い回しているときは、その行も PR の分に入る（`/cost <PR番号>` と同じ）／手元の台帳に無い作業（別の PC や別の人の作業）は数えられず、その PR の分は 0 になる／1 本の PR が複数の issue を閉じるときは、その PR の分が各 issue の合計に全額入る。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 重なった行を二重に数えない
- **WHEN** issue #12 に帰属する区間の行が 3 行（各 $1.00。2 行はブランチ `main`、1 行はブランチ `feat/a`）あり、ブランチ `feat/a` の行が全部で 3 行（各 $1.00。うち 1 行が前述の区間の行）ある会話ログで、`cost_ledger.py issue 12 --closing-pr 300:feat/a --json` を実行する
- **THEN** `total_usd` は 3.0、`closing_prs` は `[{"number": 300, "branch": "feat/a", "usd": 3.0}]`、`outside_pr_usd` は 2.0、`combined_total_usd` は 5.0（6.0 ではない）

#### Scenario: 閉じた PR が 0 件なら `/cost` と同じ値
- **WHEN** issue #12 に帰属する区間がある会話ログで、`--closing-pr` を付けずに `cost_ledger.py issue 12 --json` と `cost_ledger.py cost 12` を実行する
- **THEN** `closing_prs` は空の配列で、`combined_total_usd` と `outside_pr_usd` は `total_usd` と同じ値であり、その金額は `cost 12` の 1 行目の金額と一致する

#### Scenario: PR が 2 件
- **WHEN** 重なった行を二重に数えない Scenario の会話ログに、ブランチ `feat/b` の行が 2 行（各 $1.00。どれも issue #12 の区間の外）あり、`cost_ledger.py issue 12 --closing-pr 301:feat/b --closing-pr 300:feat/a --json` を実行する
- **THEN** `closing_prs` は番号 300・301 の順で `usd` が 3.0・2.0、`outside_pr_usd` は 2.0、`combined_total_usd` は 7.0

#### Scenario: 同じヘッドブランチの PR が 2 件
- **WHEN** 重なった行を二重に数えない Scenario の会話ログで、`cost_ledger.py issue 12 --closing-pr 305:feat/a --closing-pr 300:feat/a --json` を実行する
- **THEN** `closing_prs` は番号 300 の 1 件だけで、`combined_total_usd` は 5.0

#### Scenario: 手元に行が無い PR
- **WHEN** 重なった行を二重に数えない Scenario の会話ログで、どの行にも無いブランチ名を渡して `cost_ledger.py issue 12 --closing-pr 300:feat/none --json` を実行する
- **THEN** `closing_prs` は `usd` が 0 の 1 件で、`outside_pr_usd` と `combined_total_usd` は 3.0

#### Scenario: 表示に合計と内訳が出る
- **WHEN** 重なった行を二重に数えない Scenario の会話ログで、`cost_ledger.py issue 12 --closing-pr 300:feat/a` を実行する
- **THEN** 1 行目は `--closing-pr` を付けない場合と同じで、出力に `$5.00`・`PR #300 $3.00`・`PR 外 $2.00` を含む行が 1 行ある

#### Scenario: 形の崩れた `--closing-pr`
- **WHEN** `cost_ledger.py issue 12 --closing-pr 300` を実行する（`:` とブランチ名が無い）
- **THEN** 終了コードは 2 で、標準出力は空

## MODIFIED Requirements

### Requirement: 2 つの鍵は独立である
第 1 の鍵（ブランチ）と第 2 の鍵（リポジトリ識別子と issue 番号の組）は独立で、同じ行が両方に帰属すること SHALL がある。feature ブランチ上で `gh issue view 273` を実行した行は、そのブランチにも issue 273 にも帰属する。したがって `/cost <PR番号>` と `/cost <issue番号>` の値は重なることがあり、足し合わせて総額としてはなら MUST NOT ない。2 つの鍵の値を合わせた額を出してよいのは、「issue の合計は、閉じた PR の分と、PR のブランチ上に無い区間の分の和である」が定める issue の合計だけと MUST する（重なる行を区間の側から除いてから足す）。

#### Scenario: feature ブランチ上で issue を触る
- **WHEN** feature ブランチ上のセッションで `gh issue view 273` が実行されている
- **THEN** その行のコストはブランチの合計にも issue 273 の合計にも含まれる

#### Scenario: 単純な和は issue の合計と一致しない
- **WHEN** issue #12 に帰属する区間の行が 3 行（各 $1.00）あり、そのうち 1 行がブランチ `feat/a` の行で、ブランチ `feat/a` の行が全部で 3 行（各 $1.00）ある会話ログで、`cost_ledger.py issue 12 --closing-pr 300:feat/a --json` を実行する
- **THEN** `combined_total_usd` は 5.0 で、`total_usd`（3.0）と PR の分（3.0）の和 6.0 より、重なった 1 行の $1.00 だけ小さい
