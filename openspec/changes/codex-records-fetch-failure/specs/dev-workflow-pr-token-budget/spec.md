## ADDED Requirements

### Requirement: Codex 消費コメントの収集は全番号で成功したときだけ記録ファイルを作る
`scripts/codex-records.sh --repo <owner>/<repo> --out <file> <番号>...` は、渡されたすべての番号について記録先のコメントを全ページ取得し（`gh api --paginate --slurp repos/<owner>/<repo>/issues/<番号>/comments`）、1 行目が `^Codex 消費: ` に一致するコメントだけから、その接頭辞を除いた `<thread_id> <tokens>` を 1 行ずつ抜き出す。番号ごとに取得（`gh api`）と抽出（`jq`）の終了コードを MUST 検査する。すべての番号で取得と抽出に成功したときだけ、抜き出した行を `<file>` に書いて exit 0 を SHALL 返す（該当コメントが 1 件も無ければ空のファイルを作る）。取得・抽出・一時ファイルの作成や書き込みのどれかが 1 つでも失敗したら exit 1 を MUST 返し、`<file>` を残してはならない（MUST NOT。途中まで取れた記録も、前回の計測で作った同名のファイルも残さない）。引数が足りない・不正なとき、`gh` か `jq` が無いときも exit 1 を返す。

守備範囲: 拾いたい誤りは「GitHub からの取得が失敗したのに、空または途中までの記録が成功した記録として集計に渡ること」だけである。通ることを許す入力は、取得には成功したがコメントの書式が崩れている行（そのまま書き出し、`pr-token-budget.sh` の `skipped_lines` で扱う）と、`gh` が失敗を exit 0 で返す場合（検出できない）である。

#### Scenario: 全番号の取得に成功する
- **WHEN** 番号 419 と 450 を渡し、`gh api` がどちらも成功して、419 に `Codex 消費: t1 1000` と無関係なコメント、450 に `Codex 消費: t2 -` のコメントを返す
- **THEN** exit 0 で、`<file>` の中身は `t1 1000` と `t2 -` の 2 行になる

#### Scenario: 最初の番号の取得に失敗する
- **WHEN** 最初の番号で `gh api` が非 0 で終わる
- **THEN** exit 1 で、`<file>` は存在しない

#### Scenario: 途中のページで失敗する
- **WHEN** `gh api` が 1 ページ目の JSON を出力したあと非 0 で終わる
- **THEN** exit 1 で、`<file>` は存在しない

#### Scenario: 次の番号の取得に失敗する
- **WHEN** 最初の番号の取得に成功し、2 つ目の番号で `gh api` が非 0 で終わる
- **THEN** exit 1 で、`<file>` は存在しない（最初の番号の記録だけのファイルも残らない）

#### Scenario: 取得結果が JSON として読めない
- **WHEN** `gh api` が exit 0 で JSON でない出力を返す
- **THEN** exit 1 で、`<file>` は存在しない

#### Scenario: 前回のファイルを残さない
- **WHEN** `<file>` に前回の記録が残っている状態で、取得に失敗する
- **THEN** exit 1 で、`<file>` は存在しない

## MODIFIED Requirements

### Requirement: 本体は spawn と再開の前に測り、上限超なら止まる
develop の本体は、その記録先のためにサブエージェントを spawn する直前、SendMessage で再開する直前、および executor が `codex` の役割へ委譲する直前に、役割と executor を問わず毎回 `scripts/pr-token-budget.sh <記録先番号> [PR 番号] --codex-records <file> --codex-home <dir>...` を MUST 実行する。`<file>` は、本体が計測の直前に `scripts/codex-records.sh --repo <owner>/<repo> --out <file> <記録先番号> [PR 番号]` で作る（渡すすべての記録先番号のコメントを全ページ取得し、1 行目が `^Codex 消費: ` に一致するものだけから `<thread_id> <tokens>` を 1 行ずつ書いたもの）。`codex-records.sh` が exit 0 以外を返したら、本体は `pr-token-budget.sh` を呼んではならず MUST NOT、`pr-token-budget.sh` の exit 1（計測できない）と同じ扱いにする（理由は「Codex 消費コメントを取得できなかった」）。取得に失敗した記録を空の記録や前回のファイルで代えてはならない（MUST NOT）。`--codex-home` には codex-develop の account と CODEX_HOME の対応表にある全パスと、本体の環境の `${CODEX_HOME:-$HOME/.codex}` を渡す。計測の手順は `skills/develop/SKILL.md`（本体手順）に置き、adapter（`references/codex-develop.md`）と `scripts/codex-worker.py` には置いてはならない（MUST NOT）。

本体は、その記録先のために Codex を呼んだら、そのたびに記録先へ 1 行目が `Codex 消費: <thread_id> <tokens>` のコメントを MUST 投稿する。executor が `codex` の役割へ委譲したときは codex-worker の結果 JSON の `thread_id` と `usage.total.totalTokens` を書く（`usage` が null か `usage.total.totalTokens` が読めないときは `<tokens>` を `-` と書く）。G が full レビューで Bash から Codex を呼んだときは、G が return に書いた thread_id（`codex exec` の出力ヘッダの `session id:`、companion の結果の `threadId`）を使い、`<tokens>` を `-` と書く。G は Codex を呼んだら thread_id を return に MUST 書く（`skills/develop/references/roles/gate-runner.md` に書く）。結果 JSON を受け取れず thread_id が分からない委譲と、G が thread_id を取れなかった Codex の呼び出しは記録できず、この上限の外になる。

exit 2 のときは spawn / SendMessage / Codex への委譲をしてはならず MUST NOT、記録先に `needs-approval` を付けて主に「続けるか、範囲外として閉じるか」の 2 択を出して止まる。2 択そのものは PR-A と同じだが、判断材料なしで出してはならず MUST NOT、問いには現在の合計・体数・上限・残工程（次に起こそうとした役割と、そのあと残る工程）・本体の推奨（どちらを選ぶかとその理由）を MUST 含める。unmanned でも同じく止まり、サイクルを終える。この手順は `skills/develop/SKILL.md` に SHALL 書く。

主が「続ける」を選んだら、本体は記録先に 1 行目が `PR トークン上限: <新上限>` のコメントを投稿し、以後その記録先の計測に `--cap <新上限>` を MUST 渡す。新上限は「その時点の合計 ＋ 直前の計測で上限に使った値（`--cap`、無ければ環境変数 `DEV_WORKFLOW_PR_TOKEN_CAP`、無ければ 30000000 の順で決まった値）」とする。後任の本体は、記録先の最新の `PR トークン上限:` コメントの値を使う。主が「範囲外として閉じる」を選んだら、本体はその記録先について以後サブエージェントを起こさず Codex にも委譲せず、残作業を記録先にコメントしてサイクルを終える。

exit 1 のとき（`codex-records.sh` が失敗して集計を呼ばなかったときを含む）は止まらずに進み、計測できなかったことと理由を記録先にコメントする。コメントは同じ記録先・同じ理由について 1 サイクルに 1 回までと SHALL する（spawn のたびに同じコメントを増やさない）。1 サイクルは、interactive では本体の 1 セッション、unmanned では loop-dev-agent の 1 サイクルを指す。

#### Scenario: 上限超で次の役割を起こさない
- **WHEN** 本体が G を spawn しようとして `pr-token-budget.sh` が exit 2 を返す
- **THEN** 本体は G を spawn せず、`needs-approval` を付け、合計（Claude 分と Codex 分の内訳を含む）・体数・上限・残工程・推奨を添えて主に「続けるか、範囲外として閉じるか」を出す

#### Scenario: Codex への委譲の前にも測る
- **WHEN** executor が `codex` の W へ次の工程を委譲しようとして、それまでの Codex 委譲の `Codex 消費:` 記録を含めた合計が上限を超えており `pr-token-budget.sh` が exit 2 を返す
- **THEN** 本体は委譲せずに止まり、主に上げる

#### Scenario: Codex に委譲したら消費を記録する
- **WHEN** 本体が executor `codex` の W に委譲し、codex-worker が `thread_id` が `t1`・`usage.total.totalTokens` が 1200000 の結果 JSON を返す
- **THEN** 本体は記録先に 1 行目が `Codex 消費: t1 1200000` のコメントを投稿し、次の計測の `--codex-records` にその行が入る

#### Scenario: SKILL.md に手順が書かれている
- **WHEN** `skills/develop/SKILL.md` を読む
- **THEN** 「`pr-token-budget.sh` が exit 2 なら spawn / SendMessage / Codex への委譲をせず主に上げる」手順、description に記録先番号 `#N` を入れる規約、Codex を呼んだら `Codex 消費:` コメントを投稿する手順、計測の前に `codex-records.sh` で `Codex 消費:` コメントを集めて `--codex-records` で渡す手順、`codex-records.sh` が失敗したら集計を呼ばず exit 1 と同じ扱いにする手順が書かれている

#### Scenario: コメントの取得に失敗したら計測できない扱いにする
- **WHEN** 計測の直前に `codex-records.sh` が exit 1 を返す（例: 記録先に `Codex 消費: t1 30000001` があり上限 30000000 だが、`gh api` が認証エラーで失敗した）
- **THEN** 本体は `pr-token-budget.sh` を呼ばず、上限以内として扱わない。止まらずに進み、「Codex 消費コメントを取得できなかった」ことを記録先にコメントする（同じサイクルで 2 回目以降は投稿しない）

#### Scenario: 続けたあとの計測は引き上げた上限を使う
- **WHEN** 上限 30000000 で止まり、その時点の合計が 30500000 で、主が「続ける」を選ぶ
- **THEN** 本体は記録先に `PR トークン上限: 60500000` をコメントし、次の spawn の前の計測に `--cap 60500000` を付ける

#### Scenario: 計測できないコメントを重ねない
- **WHEN** 同じサイクルで 2 回続けて `pr-token-budget.sh` が同じ理由で exit 1 を返す
- **THEN** 本体が記録先に投稿する「計測できなかった」コメントは 1 件だけ
