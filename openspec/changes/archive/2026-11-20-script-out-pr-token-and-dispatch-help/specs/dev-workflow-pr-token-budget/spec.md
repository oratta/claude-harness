## MODIFIED Requirements

### Requirement: 本体は spawn と再開の前に測り、上限超なら止まる
develop の本体は、その記録先のためにサブエージェントを spawn する直前、SendMessage で再開する直前、および executor が `codex` の役割へ委譲する直前に、役割と executor を問わず毎回 `scripts/pr-token-measure.sh --repo <owner>/<repo> <記録先番号> [PR 番号] --codex-home <dir>... [--cap <新上限>]` を MUST 実行する。このラッパーは、渡されたすべての記録先番号の `Codex 消費:` コメントを `scripts/codex-records.sh` で集めて記録ファイルを作り、`scripts/pr-token-budget.sh` を `--codex-records` 付きで呼んで、その stdout と exit code を返す（要件「計測は 1 コマンドのラッパーで呼ぶ」）。ラッパーが取得に失敗して exit 1（理由は「Codex 消費コメントを取得できなかった」）を返したら、`pr-token-budget.sh` の exit 1（計測できない）と同じ扱いにする。取得に失敗した記録を空の記録や前回のファイルで代えてはならない（MUST NOT）。`--codex-home` には codex-develop の account と CODEX_HOME の対応表にある全パスを渡す（本体の環境の `${CODEX_HOME:-$HOME/.codex}` はラッパーが足す）。計測の手順は `skills/develop/references/pr-token-budget.md`（本体の場面限定手順）に置き、SKILL.md は spawn・再開・Codex 委譲の前に同ファイルを必ず Read して測るよう指示し（MUST）、adapter（`references/codex-develop.md`）と `scripts/codex-worker.py` には置いてはならない（MUST NOT）。

本体は、その記録先のために Codex を呼んだら、そのたびに記録先へ 1 行目が `Codex 消費: <thread_id> <tokens>` のコメントを MUST 投稿する。executor が `codex` の役割へ委譲したときは codex-worker の結果 JSON の `thread_id` と `usage.total.totalTokens` を書く（`usage` が null か `usage.total.totalTokens` が読めないときは `<tokens>` を `-` と書く）。G が full レビューで Bash から Codex を呼んだときは、G が return に書いた thread_id（`codex exec` の出力ヘッダの `session id:`、companion の結果の `threadId`）を使い、`<tokens>` を `-` と書く。G は Codex を呼んだら thread_id を return に MUST 書く（`skills/develop/references/roles/gate-runner.md` に書く）。結果 JSON を受け取れず thread_id が分からない委譲と、G が thread_id を取れなかった Codex の呼び出しは記録できず、この上限の外になる。

exit 2 のときは spawn / SendMessage / Codex への委譲をしてはならず MUST NOT、`needs-approval` を付けて（付け先は PR があれば PR、無ければ記録先。`dev-workflow-develop` の「ラベルの付け先」と同じ）主に「続けるか、範囲外として閉じるか」の 2 択を出して止まる。2 択そのものは PR-A と同じだが、判断材料なしで出してはならず MUST NOT、問いには現在の合計・体数・上限・残工程（次に起こそうとした役割と、そのあと残る工程）・本体の推奨（どちらを選ぶかとその理由）を MUST 含める。unmanned でも同じく止まり、サイクルを終える。この手順は `skills/develop/references/pr-token-budget.md` に SHALL 書く。

主が「続ける」を選んだら、本体は記録先に 1 行目が `PR トークン上限: <新上限>` のコメントを投稿し、以後その記録先の計測に `--cap <新上限>` を MUST 渡す。新上限は「その時点の合計 ＋ 直前の計測で上限に使った値（`--cap`、無ければ環境変数 `DEV_WORKFLOW_PR_TOKEN_CAP`、無ければ 30000000 の順で決まった値）」とする。後任の本体は、記録先の最新の `PR トークン上限:` コメントの値を使う。主が「範囲外として閉じる」を選んだら、本体はその記録先について以後サブエージェントを起こさず Codex にも委譲せず、残作業を記録先にコメントしてサイクルを終える。

記録先がエピックの子のときは、主の返事を待つ前に、エピックの親が持つ「子 1 件あたりの PR トークンの権限」（エピックの 1 行目 `子の PR トークン権限: <値>` のコメント。既定 60000000）の内かが照らされる（MUST）。別セッション方式の子は今までどおり止まって最後の発言に見込みを書き、起こされた親が照らす。サブエージェント方式では親を兼ねる本体が、主に聞く前に自分で照らす（MUST。権限の置き場・照らす担い手・通す条件の正本は `dev-workflow-develop` の要件「エピックの親は子 1 件あたりの PR トークンの権限をエピックのコメントに置く」「親は権限のコメントが無ければ既定値で投稿して主に伝える」「親は PR トークン上限の止まりを権限に照らして続けさせる」「権限の内でない止まりは主に上げ、主が権限を広げたら照らし直す」「親の権限で続けた上限は子の本体が記録先に書く」「サブエージェント方式では親を兼ねる本体が権限に照らす」）。権限との照合の守備範囲（入力・拾いたい誤り・止めないもの）は `dev-workflow-develop` の要件「親は PR トークン上限の止まりを権限に照らして続けさせる」に置き、この要件には置かない。止まる上限そのもの（既定 30000000）は変えない（MUST NOT 変える）。親の権限の内として続けるときの新上限は、上の「合計 ＋ 直前の上限」ではなく権限の値とする（MUST）。本体は記録先に、1 行目が `PR トークン上限: <権限>` で、2 行目以降に `決めた人:`（親の判断か、サブエージェント方式で親を兼ねる本体か）・`権限:`（権限のコメントの URL）・`停止の記録:`（子の停止の記録の URL か `なし`。記録を残さない止まりは `なし`）を書いたコメントを投稿し、以後 `--cap <権限>` を渡す（MUST）。権限の内でなければ、上の手順どおり主に問う。エピックの子でない記録先の扱いは変えない。

exit 1 のとき（`codex-records.sh` が失敗して集計を呼ばなかったときを含む）は止まらずに進み、計測できなかったことと理由を記録先にコメントする。コメントは同じ記録先・同じ理由について 1 サイクルに 1 回までと SHALL する（spawn のたびに同じコメントを増やさない）。1 サイクルは、interactive では本体の 1 セッション、unmanned では loop-dev-agent の 1 サイクルを指す。

#### Scenario: 上限超で次の役割を起こさない
- **WHEN** 本体が G を spawn しようとして `pr-token-budget.sh` が exit 2 を返す
- **THEN** 本体は G を spawn せず、`needs-approval` を PR があれば PR に、無ければ記録先に付け、合計（Claude 分と Codex 分の内訳を含む）・体数・上限・残工程・推奨を添えて主に「続けるか、範囲外として閉じるか」を出す

#### Scenario: Codex への委譲の前にも測る
- **WHEN** executor が `codex` の W へ次の工程を委譲しようとして、それまでの Codex 委譲の `Codex 消費:` 記録を含めた合計が上限を超えており `pr-token-budget.sh` が exit 2 を返す
- **THEN** 本体は委譲せずに止まり、主に上げる

#### Scenario: Codex に委譲したら消費を記録する
- **WHEN** 本体が executor `codex` の W に委譲し、codex-worker が `thread_id` が `t1`・`usage.total.totalTokens` が 1200000 の結果 JSON を返す
- **THEN** 本体は記録先に 1 行目が `Codex 消費: t1 1200000` のコメントを投稿し、次の計測の `--codex-records` にその行が入る

#### Scenario: pr-token-budget.md に手順が書かれている
- **WHEN** `skills/develop/SKILL.md` の spawn・再開・Codex 委譲の前の必読指示から `skills/develop/references/pr-token-budget.md` を読む
- **THEN** 「計測が exit 2 なら spawn / SendMessage / Codex への委譲をせず主に上げる」手順、description に記録先番号 `#N` を入れる規約、Codex を呼んだら `Codex 消費:` コメントを投稿する手順、計測を `pr-token-measure.sh` の 1 コマンドで呼ぶ手順、ラッパーが exit 1 を返したら計測できない扱いにする手順が書かれ、`codex-records.sh` と `pr-token-budget.sh` を直接つなぐ bash は書かれていない

#### Scenario: コメントの取得に失敗したら計測できない扱いにする
- **WHEN** 計測の `pr-token-measure.sh` が取得の失敗で exit 1 を返す（例: 記録先に `Codex 消費: t1 30000001` があり上限 30000000 だが、`gh api` が認証エラーで失敗した）
- **THEN** 上限以内として扱わない。止まらずに進み、「Codex 消費コメントを取得できなかった」ことを記録先にコメントする（同じサイクルで 2 回目以降は投稿しない）

#### Scenario: 続けたあとの計測は引き上げた上限を使う
- **WHEN** 上限 30000000 で止まり、その時点の合計が 30500000 で、主が「続ける」を選ぶ
- **THEN** 本体は記録先に `PR トークン上限: 60500000` をコメントし、次の spawn の前の計測に `--cap 60500000` を付ける

#### Scenario: エピックの子が親の権限で続けたあとの計測は権限を上限に使う
- **WHEN** エピックの子の記録先が上限 30000000 で止まり（合計 31000000）、親の権限が 60000000 で、子の合計の見込みが 45000000 のため親が続けさせる
- **THEN** 子の本体は記録先に 1 行目 `PR トークン上限: 60000000`、2 行目以降に `決めた人:`・`権限:`・`停止の記録:` のコメントを投稿し、次の spawn の前の計測に `--cap 60000000` を付ける。既定の上限 30000000 は変わらない

#### Scenario: pr-token-budget.md の exit 2 にエピックの子の分岐が書かれている
- **WHEN** `skills/develop/references/pr-token-budget.md` の exit 2 を読む
- **THEN** 記録先がエピックの子なら主に聞く前に親の権限の内かを照らすこと、権限の内なら新上限は権限で、`PR トークン上限: <権限>` に `決めた人:`・`権限:`・`停止の記録:` を添えて投稿すること、照らし方の正本が `references/epic-stop.md` にあることが書かれている

#### Scenario: 計測できないコメントを重ねない
- **WHEN** 同じサイクルで 2 回続けて `pr-token-budget.sh` が同じ理由で exit 1 を返す
- **THEN** 本体が記録先に投稿する「計測できなかった」コメントは 1 件だけ

## ADDED Requirements

### Requirement: 計測は 1 コマンドのラッパーで呼ぶ
`plugins/dev-workflow/scripts/pr-token-measure.sh --repo <owner>/<repo> [--cap <tokens>] [--codex-home <dir>]... <記録先番号>...` を持たなければならない（MUST）。`codex-records.sh` を呼び、exit 0 のときだけ `pr-token-budget.sh <番号>... --codex-records <file>` を呼ぶ。`--codex-home` には渡されたものに加えて `${CODEX_HOME:-$HOME/.codex}` を渡し、`--cap` は渡されたときだけ渡す。`pr-token-budget.sh` の stdout と exit code（0 / 2 / 1）をそのまま返す。
#### Scenario: 記録の取得と集計を 1 回の呼び出しでつなぐ
- **WHEN** `pr-token-measure.sh --repo o/r 288` を呼び、`codex-records.sh` が exit 0 で記録を書く
- **THEN** `pr-token-budget.sh 288 --codex-records <その記録>` が呼ばれ、その stdout と exit code がそのまま返る

#### Scenario: 上限超過は exit 2 のまま返す
- **WHEN** `pr-token-budget.sh` が exit 2 を返す
- **THEN** ラッパーも exit 2 で終わり、stdout は `pr-token-budget.sh` の 1 行 JSON と同じである

#### Scenario: --cap は渡されたときだけ渡す
- **WHEN** `--cap 60000000` を付けて呼ぶ場合と、付けずに呼ぶ場合
- **THEN** 前者は `pr-token-budget.sh` に `--cap 60000000` が渡り、後者は `--cap` が渡らない

#### Scenario: 本体の環境の CODEX_HOME を渡す
- **WHEN** `--codex-home /x` を付けて呼ぶ
- **THEN** `pr-token-budget.sh` には `--codex-home /x` と `--codex-home ${CODEX_HOME:-$HOME/.codex}` の両方が渡る

### Requirement: ラッパーは取得に失敗したら集計を呼ばず exit 1 で終わる
`pr-token-measure.sh` は、`codex-records.sh` が exit 0 以外のときは `pr-token-budget.sh` を呼ばず、stdout を空にして stderr に理由を出し exit 1 で終わらなければならない（MUST）。`--repo` の欠落と、番号が 0 件か数字でない場合も exit 1 とする。一時ディレクトリは終わるときに消す。LLM を呼ばず、GitHub に書き込まない（MUST NOT）。

守備範囲: 拾いたい誤りは、取得に失敗したのに前回のファイルや空の記録で集計し、Codex 分が抜けた合計を上限以内と読み違えることと、2 つのスクリプトの exit code がラッパーで書き換わることである。一時ディレクトリの置き場の選び方と、`pr-token-budget.sh` の出力の整形（しない）は検査しない。

#### Scenario: 取得に失敗したら集計を呼ばない
- **WHEN** `codex-records.sh` が exit 1 で終わる
- **THEN** `pr-token-budget.sh` は呼ばれず、stdout は空で、stderr に理由が出て exit 1 である

#### Scenario: 引数が足りないか不正なら何も呼ばず exit 1
- **WHEN** `--repo` が無い、記録先番号が 0 件、または番号が数字でない（`28a`）で呼ぶ
- **THEN** `codex-records.sh` も `pr-token-budget.sh` も呼ばれず、stdout は空で exit 1 である

#### Scenario: 一時ディレクトリを消す
- **WHEN** 成功・取得失敗・上限超過のどれで終わったあとでも
- **THEN** ラッパーが作った一時ディレクトリは残らない
