## Context

帰属の鍵は `scan_tool_calls` が実行された `Bash` の `command` に `ISSUE_RE.findall` を当てて拾う。拾った番号は台帳に「触った issue 番号の列」という事実として書かれ、帰属はその事実から後で導く。台帳は追記だけで、`ledger-sync --rescan` も既存の行を書き換えない（索引に無い行を足すだけ）。

## Goals / Non-Goals

- Goals: `gh issue reopen <番号>` と `gh api repos/<owner>/<repo>/issues/<番号>...` を鍵に足す。実行していない文字列では寄らない性質を、引用符の中とシェルのコメントの中の `;` `&` `|` `(` の直後に `gh api` が続く形（決定 4）を除いて保つ
- Non-Goals: `gate_report.py` の `gh api` 解析との共通化（別の子の範囲）／台帳の過去の行の書き換え／issue 番号が PR 番号かどうかの判別（`gh issue comment <PR 番号>` と同じく、番号をそのまま鍵にする）

## Decisions

1. **`reopen` は `ISSUE_RE` の選択肢に足す。** 同じ形（`gh issue <サブコマンド> <番号>`）なので他の変更は要らない。
2. **`gh api` も `ISSUE_RE` 1 本に並べる。変えるのは `ISSUE_RE` の定義の 1 行だけで、`scan_tool_calls` など `ISSUE_RE` 以外の行は変えない。** 親エピックの注意書き（触るのは `cost_ledger.py` の `ISSUE_RE` だけ）に従う。番号のキャプチャ群を 1 つに保ち、`gh issue <動詞>` の形と `gh api` の形を非キャプチャ群の選択肢で並べるので、`findall` は今までどおり番号の文字列のリストを返し、`scan_tool_calls` の `for number in ISSUE_RE.findall(command)` はそのまま動く。`^` を行頭として読ませるため、定義に `re.M` を付ける（`re.compile` の第 2 引数で、定義の中に収まる）。形は次のとおり（実装前に python3 で確かめた）。

   ```
   (?:gh issue (?:view|comment|edit|close|reopen|develop)\s+
      |(?:(?<!\\\n)^|(?<!\\)[;&|(])\s*(?:\w+=\S*\s+)*gh api[^\S\r\n]+(?:(?:-X|--method)[^\S\r\n]+\S+[^\S\r\n]+)?repos/[^/\s]+/[^/\s]+/issues/(?=\d+(?!\w)))(\d+)
   ```
   （実際は文字列を行ごとに分けて書き、`re.M` を付ける。定義の 1 文に収まる）。代案: 別の正規表現 `API_ISSUE_RE` を足して `scan_tool_calls` で当てる → 注意書きを超えるので採らない。代案: `gate_report.py` の解析を再利用する → 別の子の範囲なので採らない。代案: 先読み・後読みでコマンド位置を見る → Python の後読みは可変長を扱えず、`VAR=値` の代入を許せないので採らない（区切り文字を一致の中に含め、番号だけをキャプチャする）。固定長の後読みは区切りの直前の 1 文字（バックスラッシュ）と行頭の直前の 2 文字（バックスラッシュと改行）を見るためにだけ使う（PR #880 のゲート 1 周目の指摘 F1・F2 を受けて足した。`gh api`・`-X`/`--method`・その値の後ろの空白を `\s+` から改行を含まない `[^\S\r\n]+` に変えたのも同じ周）。
3. **`gh api` の形は狭くする。** 拾うのは、**コマンドの位置**にある `gh api` だけ。コマンドの位置とは、行頭、または `;` `&&` `||` `|` `(` の直後（空白可）で、前に `VAR=値` の代入が付く形（`GH_TOKEN=x gh api ...`）も許す。これは `-f body=...` など引数の値の中に書かれた、実行していない `gh api repos/.../issues/99` の文字列を鍵にしないため（引用符の中の文字列は前に区切りが無いので位置の条件に合わない）。位置の条件は `gh api` の側だけに付け、`gh issue <動詞>` の側は今までどおり（位置も番号の直後も見ない）にして、既存の読み方を変えない。`gh api` の後ろの、`-X`・`--method` とその値だけを飛ばした最初の語が `repos/<owner>/<repo>/issues/<番号>` で始まり、番号の直後が英数字・`_` でないもの（`/`・空白・`?`・引用符・行末）に限る。`<owner>` と `<repo>` は `{owner}`・`{repo}` の置き換え記号も含めて `/` と空白以外の 1 語として読む。確かめた結果は次のとおり。
   - 拾う: `gh api repos/a/b/issues/42`、`.../42/comments`、`.../42?per_page=1`、`-X POST`、`--method PATCH`、`cd x && gh api ...`、`cd x;gh api ...`、`false || gh api ...`、`echo hi | gh api ...`、`(gh api ...)`、`GH_TOKEN=x gh api ...`、`A=1 B=2 gh api ...`、改行の次の行頭、`gh api ... && gh api ...`（両方）、`gh issue view 5; gh api repos/a/b/issues/6`（両方）
   - 拾わない: `issues/comments/<id>`・`gh api graphql ...`・`issues/42abc`・`gh api -X POST repos/acme/app/issues/42/comments -f body="gh api repos/acme/app/issues/99"` の 99（42 だけ拾う）・`gh issue comment 42 --body "gh api repos/a/b/issues/99"` の 99・`echo "x gh api repos/a/b/issues/99"`・`echo x\; gh api repos/a/b/issues/99` と `echo x\| gh api ...`（直前がバックスラッシュの区切り）・行末のバックスラッシュで続けた次の行の `gh api ...`・`gh api` や `gh api -X POST` で終わる行の次の行の `repos/a/b/issues/42`
   - 既存の `gh issue` は変わらない: `gh issue view 42`・`reopen 43` は拾い、`gh issue view 45abc` は今までどおり 45 を拾う
4. **受け入れるリスク: コマンドの位置以外の `gh api` は読み落とす。** `xargs gh api ...`・`time gh api ...`・`if gh api ...; then` などは拾わない。その区間はその issue に寄らない（小さく出る方向）。「コマンドの位置以外の読み落とし」だけでは、別の issue へ誤って寄ることは起きない。例外が一つある。引用符の中に `;` `&` `|` `(` があり、その直後に `gh api repos/.../issues/<番号>` と続く文字列（`-f body="x; gh api repos/a/b/issues/99"`）は、正規表現では引用符の内外を区別できないので拾う。この形は実行していない文字列が別の issue（99）にも寄る例外で、区間は最後に拾った番号に帰属するため 99 に寄りうる。`; gh api repos/.../issues/<番号>` を値の中に書く場面はまれ。塞ぐには引用符を読む解析器が要り、この change の範囲を超えるので、子 issue #879 で扱う（https://github.com/oratta/claude-harness/issues/879）。
   もう一つの例外は、シェルのコメントの中の区切りの直後の `gh api`（`echo ok #; gh api repos/a/b/issues/99` の 99）で、これも拾う。塞ぐには「同じ行のそれより前に、語の先頭の `#` があるか」を見る必要があるが、Python の `re` の後読みは固定長で見られない。行頭から読ませる形（`^(?:[^\n#]*?[;&|(])?...`）にすると、`findall` の一致が重ならないため同じ行の 2 つ目以降のコマンドを読み落とす（python3 で確かめた: `gh issue view 5; gh api repos/a/b/issues/6` が 5 だけ、`gh api .../1 && gh api .../2` が 2 だけになる）。`#` が引用符の中か外かも区別できない。塞ぐには行を読む解析器が要り範囲外。
   反対向き（拾うべきものを読み落とす側）の残りとして、エスケープしたバックスラッシュの直後の本当の区切り（`echo x\\; gh api ...`）と、`gh api \` の行継続で endpoint を次の行に書いた形は読まない。どちらもその区間が寄らないだけで、別の issue へは寄らない。
5. **範囲外: `gh issue` の側の同じ誤り。** `gh issue comment 42 --body "gh issue view 99"` が 99 にも寄る件は、今ある `gh issue <動詞>` の読み方の問題で、この change では直さない。子 issue #879 で扱う（https://github.com/oratta/claude-harness/issues/879）。
6. **鍵は（リポジトリ識別子, 番号）のまま。** リポジトリ識別子は `cwd` から導くので、endpoint の `<owner>/<repo>` が `cwd` のリポジトリと違う場合（`gh issue view --repo` と同じ）でも、`cwd` のリポジトリの番号として拾う。今の `gh issue ...` の扱いと同じで、新しい誤りの種類は増やさない。
7. **過去の行は直さない。** 台帳には導いた帰属でなく事実が書かれている。過去の行には再オープンや `gh api` の番号が入っておらず、書き換えない運用（追記のみ・`--rescan` も既存行を書き換えない）なので、直すには台帳を作り直すしかない。過去分の欠けは数字が小さく出るだけで、費用が大きい割に得るものが小さい。新しい行から効く。

## Risks / Trade-offs

- [過去に `reopen` や `gh api` だけで操作した区間は、これまでどおり帰属しない] → 過去分は直さないと spec に書く。数字は小さく出る方向にしかずれない
- [PR の番号を `gh api repos/.../issues/<PR 番号>/comments` で触ると、その番号が issue の鍵としても拾われる] → `gh issue comment <PR 番号>` と同じ扱い。PR の行はブランチで帰属するので、issue の合計は PR の分を二重に数えない（既存の「issue の合計」の規則）
- [`gh api` の語順の違い（`-H` など他のオプションが先に来る形）や、コマンドの位置以外の `gh api`（`xargs`・`time`・`if` の後ろ）を読み落とす] → 読み落としは許す（その区間は寄らないだけ）。範囲外の形を見つけたら別 issue にする

## Migration Plan

反映に再起動や台帳の変換は要らない（スクリプトは実行のたびに読まれる）。戻すときは該当の変更を revert する。台帳には事実の列が書かれるだけなので、revert 後も既存の行は読める。

## 計測（PR 本文に書く作業項目）

エピック #272 の全体の制約として、変更の前後で次を測り、PR 本文に書く。LLM のトークンは使わない。

- 待ち時間: hook 1 回の同期部分の壁時計時間（`ledger-sync` を既存の会話ログで 20 回実行した中央値）。正規表現が 1 本増えるだけなので差はほぼ無い見込みだが、測って書く
- `gh` の呼び出し回数: 変更の前後で同じ入力に対して数える（この変更は `gh` を呼ばないので 0 回のまま、のはず。測って書く）
