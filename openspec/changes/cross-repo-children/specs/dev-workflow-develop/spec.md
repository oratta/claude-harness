## ADDED Requirements

### Requirement: 別のリポジトリの子を含むエピックの回し方を SKILL.md に書く

develop の SKILL.md「エピックの扱い」は、エピックの子がエピックと別のリポジトリにあるときの挙動を、既存の要件（子エピックの外し方・マージ待ちの子・子の側の手順・コメントの書式）の読み替えとして書かなければならない（MUST）。読み替えは次の表のとおりで、同じリポジトリの子の呼び出しの形・書式・判定は表の外では変えない（MUST）。既存の要件の本文は書き直さず、この要件が読み替えを持つ。

| 既存の書き方 | 別のリポジトリの子での読み替え |
|---|---|
| 子の依存を `gh api repos/<owner>/<repo>/issues/<N>/dependencies/blocked_by` で読む | 子のリポジトリ（`repos/<子の owner>/<子の repo>/issues/<N>/dependencies/blocked_by`）で読む。前提の issue のリポジトリは応答の `repository_url` から取り、前提の state もそのリポジトリで読む。前提が別リポジトリにあっても閉じていれば解けている |
| 子エピックの判定 `gh api repos/{owner}/{repo}/issues/<N> --jq .sub_issues_summary.total` | 子のリポジトリで読む（`repos/<子の owner>/<子の repo>/issues/<N>`）。別リポジトリというだけでは外さず、sub-issue を持つ子だけを外す |
| エピックの子の一覧 | エピックのリポジトリの sub-issue（`gh api repos/{owner}/{repo}/issues/<E>/sub_issues`。各要素の `repository_url` から子のリポジトリを取る）と、エピック本文の子の表（`<owner>/<repo>#<N>` か `#<N>`）を合わせて組み立てる。同じ子は小文字にそろえた `<owner>/<repo>#<N>` で 1 件に数える |
| エピックへのコメント `後で別に起動するエピック: #N` | 別のリポジトリの子は `後で別に起動するエピック: <owner>/<repo>#N` |
| エピックへのコメント `子 #N マージ → 残り k 件`・`子 #N 見送り（<state_reason>）→ 残り k 件`・`子 #N のワークツリーを残した`・`親の判断: 子 #N 通した — ...` | 別のリポジトリの子は `子 <owner>/<repo>#N` の同じ形（`親の判断: 子 <owner>/<repo>#N 通した — ...`）。完了報告も同じ呼び方 |
| 子の側が親エピックに残すコメント `gh issue comment <E> --body '後で別に起動するエピック: #<自分>'` | エピックが別のリポジトリにあるときは `gh issue comment <E> -R <エピックのリポジトリ> --body '後で別に起動するエピック: <自分の owner>/<自分の repo>#<自分>'`。`<E>` とエピックのリポジトリは `route` の stderr の `parent epic: <owner>/<repo>#<E>` から取る |
| マージ待ちの子の前提の `auto-merge.yml` の取得（`repos/<owner>/<repo>/contents/...`）、`親のマージ判断:` のコメント、`parent-merge-approved` のラベル、PR 本文の `Closes #N` の確認 | すべて子のリポジトリの PR に対して行う（`contents` は `repos/<子の owner>/<子の repo>/...`、コメントは `gh pr comment <PR> -R <子の repo>`、ラベルは `gh api repos/<子の repo>/issues/<PR番号>/labels`）。印が数えられるのは `gh` の認証アカウントが子のリポジトリの OWNER・MEMBER・COLLABORATOR のときだけで、そうでなければ決める役を起こさず手順 8 の形で主に上げる |
| 親から届く返事の頭 `親エピック #<E> の判断（主の承認ではない）: ` / `主の返事（親エピック #<E> 経由）: ` を受ける子の側の手順（`references/ci-watch.md` の 1 箇所を含む） | 番号のあとに `（<owner>/<repo>）` が付く形（要件「別のリポジトリの子の起動の指示・環境変数・注意書き・返事の頭にはエピックのリポジトリを足す」）でも同じ手順で受ける。先頭の `親エピック #` / `主の返事（親エピック #` で判定する |
| `stop-judge.sh <epic> <child>` の `<child>` は番号 | 番号か `<owner>/<repo>#<N>`。後者は子の本文・コメントを `repos/<o>/<r>/issues/<N>` から読み、エピックのコメントの過去の判断を `親の判断: 子 <o>/<r>#<N> ` で始まる行から探す。同じリポジトリの子は今までどおり。入力文の見出しも同じ呼び方にする |

SKILL.md の手順 1 には、`--base` と `EPIC_DISPATCH_BASE` が 1 回の `launch` の全部の子に掛かること、リポジトリごとに既定ブランチが違う子を混ぜるときは `--base` を付けないか `launch` をリポジトリごとに分けることを書かなければならない（MUST）。手順 6 の `failed` の報告には、`failed <child> no-clone`（`EPIC_DISPATCH_CLONES` の設定か clone を主に頼む）・`ambiguous-clone`（候補のパス）・`no-push`・`permission-lookup-failed`（stderr の `gh` の認証アカウントと子のリポジトリを添える）を足し、どれも主に報告して止まると書かなければならない（MUST。サブエージェント方式に自動で振り替えない）。

この要件の守備範囲で入力として扱うのは、SKILL.md の手順書の文面と `stop-judge.sh` の引数である。拾いたい誤りは、別のリポジトリの子の依存や子エピックの判定を親のリポジトリに対して読み、解けていない子を起動したり、子エピックを展開したりすることである。次は通してよく、この要件では止めない: 前提の issue を `gh` が読めないとき（読めない前提は解けていないとして待つ今の扱い）／エピック本文の子の表の書式の揺れ。表を手で直した結果の細かい食い違いを見つけるたびに検査を足すことは、この要件の完了条件としない。

#### Scenario: 依存と子エピックの判定を子のリポジトリで読むと書いてある
- **WHEN** SKILL.md の「回し方」の経路の決め方と「エピックである子を外す」を読む
- **THEN** 別のリポジトリの子の `blocked_by` と `sub_issues_summary.total` を子のリポジトリで読むこと、前提の issue のリポジトリを `repository_url` から取ることが書いてある

#### Scenario: 子の一覧の組み立てが書いてある
- **WHEN** SKILL.md の「エピックの扱い」を読む
- **THEN** sub-issue の `repository_url` とエピック本文の子の表から子の一覧を組み立て、同じ子を 1 件に数えることが書いてある

#### Scenario: コメントの書式が書いてある
- **WHEN** SKILL.md の「エピックの扱い」を読む
- **THEN** 別のリポジトリの子は `子 <owner>/<repo>#N`・`後で別に起動するエピック: <owner>/<repo>#N`・`親の判断: 子 <owner>/<repo>#N 通した` と書くことが書いてあり、同じリポジトリの子は今のままの書式で残っている

#### Scenario: マージ待ちの子を子のリポジトリで扱うと書いてある
- **WHEN** SKILL.md の「マージ待ちの子」を読む
- **THEN** `auto-merge.yml` の取得・`親のマージ判断:` のコメント・`parent-merge-approved` のラベルを子のリポジトリの PR に付けること、認証アカウントが子のリポジトリで権限を持たないときは主に上げることが書いてある

#### Scenario: 子の側が親エピックのリポジトリにコメントする
- **WHEN** SKILL.md の「`nested` を受けたセッション」を読む
- **THEN** エピックが別のリポジトリにあるときは `gh issue comment <E> -R <エピックのリポジトリ>` で `後で別に起動するエピック: <owner>/<repo>#<自分>` を残すと書いてあり、`<E>` とリポジトリを `route` の stderr の `parent epic: <owner>/<repo>#<E>` から取ると書いてある

#### Scenario: 親から届く返事の頭の新しい形を受ける
- **WHEN** SKILL.md の「エピックの子が主の返事を待って止まるとき」と `references/ci-watch.md` の親から届く返事の頭の照合を読む
- **THEN** どちらも `親エピック #<E>（<owner>/<repo>）の判断（主の承認ではない）: ` と `主の返事（親エピック #<E>（<owner>/<repo>）経由）: ` を受けると書いてある

#### Scenario: failed の新しい理由の報告が書いてある
- **WHEN** SKILL.md の手順 6 を読む
- **THEN** `no-clone`・`ambiguous-clone`・`no-push`・`permission-lookup-failed` を主に報告して止まると書いてある

#### Scenario: stop-judge.sh は owner/repo#番号 の子を受ける
- **WHEN** 子 `genetta-inc/flatmate#1615` を指定して `stop-judge.sh 1122 genetta-inc/flatmate#1615` を実行する（`gh` はスタブ）
- **THEN** 子の本文は `repos/genetta-inc/flatmate/issues/1615` から読まれ、エピックのコメントの過去の判断は `親の判断: 子 genetta-inc/flatmate#1615 ` で始まる行から探される

#### Scenario: 同じリポジトリの子の stop-judge.sh は今と同じ
- **WHEN** 子 `11` を指定して `stop-judge.sh 1122 11` を実行する
- **THEN** 子の本文は今までと同じ `repos/{owner}/{repo}/issues/11` から読まれ、過去の判断は `親の判断: 子 #11 ` で探される
