# Spec Delta

## MODIFIED Requirements

### Requirement: 本体は spawn と再開の前に測り、上限超なら止まる
develop の本体は、その記録先のためにサブエージェントを spawn する直前、SendMessage で再開する直前、および executor が `codex` の役割へ委譲する直前に、役割と executor を問わず毎回 `scripts/pr-token-budget.sh <記録先番号> [PR 番号] --codex-records <file> --codex-home <dir>...` を MUST 実行する。`<file>` は、本体が計測の直前に `scripts/codex-records.sh --repo <owner>/<repo> --out <file> <記録先番号> [PR 番号]` で作る（渡すすべての記録先番号のコメントを全ページ取得し、1 行目が `^Codex 消費: ` に一致するものだけから `<thread_id> <tokens>` を 1 行ずつ書いたもの）。`codex-records.sh` が exit 0 以外を返したら、本体は `pr-token-budget.sh` を呼んではならず MUST NOT、`pr-token-budget.sh` の exit 1（計測できない）と同じ扱いにする（理由は「Codex 消費コメントを取得できなかった」）。取得に失敗した記録を空の記録や前回のファイルで代えてはならない（MUST NOT）。`--codex-home` には codex-develop の account と CODEX_HOME の対応表にある全パスと、本体の環境の `${CODEX_HOME:-$HOME/.codex}` を渡す。計測の手順は `skills/develop/references/pr-token-budget.md`（本体の場面限定手順）に置き、SKILL.md は spawn・再開・Codex 委譲の前に同ファイルを必ず Read して測るよう指示し（MUST）、adapter（`references/codex-develop.md`）と `scripts/codex-worker.py` には置いてはならない（MUST NOT）。

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

#### Scenario: SKILL.md に手順が書かれている
- **WHEN** `skills/develop/SKILL.md` の spawn・再開・Codex 委譲の前の必読指示から `skills/develop/references/pr-token-budget.md` を読む
- **THEN** 「`pr-token-budget.sh` が exit 2 なら spawn / SendMessage / Codex への委譲をせず主に上げる」手順、description に記録先番号 `#N` を入れる規約、Codex を呼んだら `Codex 消費:` コメントを投稿する手順、計測の前に `codex-records.sh` で `Codex 消費:` コメントを集めて `--codex-records` で渡す手順、`codex-records.sh` が失敗したら集計を呼ばず exit 1 と同じ扱いにする手順が書かれている

#### Scenario: コメントの取得に失敗したら計測できない扱いにする
- **WHEN** 計測の直前に `codex-records.sh` が exit 1 を返す（例: 記録先に `Codex 消費: t1 30000001` があり上限 30000000 だが、`gh api` が認証エラーで失敗した）
- **THEN** 本体は `pr-token-budget.sh` を呼ばず、上限以内として扱わない。止まらずに進み、「Codex 消費コメントを取得できなかった」ことを記録先にコメントする（同じサイクルで 2 回目以降は投稿しない）

#### Scenario: 続けたあとの計測は引き上げた上限を使う
- **WHEN** 上限 30000000 で止まり、その時点の合計が 30500000 で、主が「続ける」を選ぶ
- **THEN** 本体は記録先に `PR トークン上限: 60500000` をコメントし、次の spawn の前の計測に `--cap 60500000` を付ける

#### Scenario: エピックの子が親の権限で続けたあとの計測は権限を上限に使う
- **WHEN** エピックの子の記録先が上限 30000000 で止まり（合計 31000000）、親の権限が 60000000 で、子の合計の見込みが 45000000 のため親が続けさせる
- **THEN** 子の本体は記録先に 1 行目 `PR トークン上限: 60000000`、2 行目以降に `決めた人:`・`権限:`・`停止の記録:` のコメントを投稿し、次の spawn の前の計測に `--cap 60000000` を付ける。既定の上限 30000000 は変わらない

#### Scenario: SKILL.md の exit 2 にエピックの子の分岐が書かれている
- **WHEN** `skills/develop/references/pr-token-budget.md` の exit 2 を読む
- **THEN** 記録先がエピックの子なら主に聞く前に親の権限の内かを照らすこと、権限の内なら新上限は権限で、`PR トークン上限: <権限>` に `決めた人:`・`権限:`・`停止の記録:` を添えて投稿すること、照らし方の正本が `references/epic-stop.md` にあることが書かれている

#### Scenario: 計測できないコメントを重ねない
- **WHEN** 同じサイクルで 2 回続けて `pr-token-budget.sh` が同じ理由で exit 1 を返す
- **THEN** 本体が記録先に投稿する「計測できなかった」コメントは 1 件だけ

### Requirement: 消費の記録に工程・試行・アカウントの印を書く
develop の本体は、記録先の消費の記録に、1 行の印 `[消費記録 工程=<工程> 試行=<n> アカウント=<provider>:<登録名> 引継ぎ=<k>]` を MUST 書く。キーの順は問わない。`引継ぎ=` は、同じ工程と試行で手渡しにより起こし直した k 番目の担当のときだけ書き、最初の担当には書かない。読み取り側（flatmate の `burn_consumption.py`）の契約に合わせ、この印以外の書き方（自由文）で工程・試行・アカウントを表してはならない（MUST NOT）。
- 置き場は次の 3 か所とする: (1) `Codex 消費:` コメントの 2 行目以降（1 行目の `Codex 消費: <thread_id> <tokens>` の形は変えない）、(2) サブエージェントの `description`（`#N` と同じ文字列の中）、(3) `develop 開始` コメント（本体の起動アカウント。`工程=` と `試行=` は省いてよい）

#### Scenario: Codex 消費コメントの 2 行目に印を書く
- **WHEN** 本体が executor `codex` の W の implement 工程の 2 回目の試行の結果を記録する（thread_id `t1`・totalTokens 1200000・Codex の登録名 `current`・結果 JSON に `started_at` と `ended_at` が無い）
- **THEN** 本体は 1 行目が `Codex 消費: t1 1200000` で、2 行目が `[消費記録 工程=implement 試行=2 アカウント=codex:current]` のコメントを投稿する

#### Scenario: 1 つの工程・試行にしか使わないサブエージェントの description に印を入れる
- **GIVEN** Claude の登録名が `a` と取れていて、記録先 #288 の implement 工程のレビュアー（`impl-review`）の初回（試行 1・手渡しなし）を、再開しない 1 体として起こす
- **WHEN** 本体が spawn する
- **THEN** `description` は `#288` と `[消費記録 工程=impl-review 試行=1 アカウント=claude:a]` を同じ文字列の中に含む

#### Scenario: SKILL.md に規約が書かれている
- **WHEN** 本体が SKILL.md と `plugins/dev-workflow/references/codex-develop.md` の必読参照から、印を書く前に `skills/develop/references/pr-token-budget.md` を読む
- **THEN** 同 reference の消費の記録の規約に、印の形・置き場・工程名の語彙・試行と引継ぎの数え方・再開される W の扱い・G とレビュアーの工程の決め方が書かれている

#### Scenario: 手渡しで起こし直した W に引継ぎを書く
- **GIVEN** 登録名 `a` が取れていて、implement 工程の 2 回目の試行を、前任から手渡しで起こし直した 1 番目の担当の W に担わせる（再開しない）
- **WHEN** 本体が記録先 #288 のために spawn する
- **THEN** `description` の印は `工程=implement 試行=2 アカウント=claude:a 引継ぎ=1` を含む

#### Scenario: develop 開始コメントに起動アカウントを書く
- **GIVEN** Claude の起動アカウントの登録名 `a` が取れている
- **WHEN** 本体が `develop 開始` コメントを投稿する
- **THEN** コメントに `[消費記録 アカウント=claude:a]` の行がある（`工程=` と `試行=` は無くてよい）

### Requirement: Codex 消費コメントの印に実行の時刻を書く
develop の本体は、executor が `codex` の役割へ委譲した分の `Codex 消費:` コメントの印に、codex-worker の結果 JSON の `started_at` を `開始=`、`ended_at` を `終了=` の値として MUST 書く（値は結果 JSON の文字列をそのまま写す）。結果 JSON にそのキーが無いか値が `null` なら、そのキーを印から省き、別の時刻（本体が委譲した時刻・コメントを投稿した時刻など）で埋めてはならない（MUST NOT）。G が full レビューで Bash から呼んだ Codex の分は時刻が取れないので、`開始=` `終了=` を書かない。

#### Scenario: Codex の委譲の時刻を印に書く
- **WHEN** 本体が executor `codex` の W の implement 工程の 1 回目の試行の結果を記録する（thread_id `t1`・totalTokens 1200000・Codex の登録名 `current`・結果 JSON の `started_at` が `2026-10-19T23:50:00Z`、`ended_at` が `2026-10-20T00:10:00Z`）
- **THEN** 本体は 1 行目が `Codex 消費: t1 1200000` で、2 行目が `[消費記録 工程=implement 試行=1 アカウント=codex:current 開始=2026-10-19T23:50:00Z 終了=2026-10-20T00:10:00Z]` のコメントを投稿する

#### Scenario: 結果 JSON に時刻が無ければ省く
- **WHEN** 本体が受け取った結果 JSON に `started_at` が無く、`ended_at` が `null` である
- **THEN** `Codex 消費:` コメントの印は `開始=` も `終了=` も含まない

#### Scenario: G の full レビューの分には時刻を書かない
- **WHEN** 本体が G の return に書かれた thread_id で、G が full レビューで呼んだ Codex の消費を記録する
- **THEN** `Codex 消費:` コメントの印は `工程=impl-review` を含み、`開始=` も `終了=` も含まない

#### Scenario: SKILL.md に時刻の書き方が書かれている
- **WHEN** `skills/develop/references/pr-token-budget.md` を読む
- **THEN** Codex の消費の記録に、結果 JSON の `started_at` / `ended_at` から `開始=` / `終了=` を書くこと、取れなければキーごと省くこと、G の full レビューの分には書かないことが書かれ、「消費の記録の印」の時刻の行は `Codex 消費:` コメントの印にだけ書くことを示している
