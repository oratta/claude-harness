## MODIFIED Requirements

### Requirement: Orca の印を正本にした既存要件を状態の記録の項目で読み替える

`epic-dispatch.sh` の既存要件のうち、子の状態を Orca のワークツリーのメタデータから読み書きすると書いた箇所は、capability `dev-workflow-epic-state` の状態の記録の項目を読み書きするものとして読まなければならない（MUST）。読み替えは次の表のとおりで、出力の行・exit code・失敗したポーリングの数え方・`--resolve` の判断と送り方・`reap` の安全確認の中身は、表の読み替えのほかは既存要件のまま変えない（MUST）。

| 既存要件の書き方 | 読み替え |
|---|---|
| ボードの列 `workspaceStatus` が `completed`（`mark done`） | 記録の `status` が `done` |
| ボードの列 `workspaceStatus` が `in-review`（`mark waiting`） | 記録の `status` が `waiting` |
| コメント欄 `comment` が `epic-stopped` / `epic-stopped-seen` / `epic-resumed` | 記録の `stop` が `stopped` / `stopped-seen` / `resumed` |
| `orca worktree set --worktree current ...` で印を付ける | 今いるワークツリーのパスで見つけた自分の記録を書き換え、そのあと Orca の印へ写す（写しの失敗は成功扱い） |
| `orca worktree set --worktree path:<子> --comment epic-stopped-seen` で受けた印を付ける | 子の記録の `stop` を排他つきで `stopped-seen` に書き換え、そのあと Orca の印へ写す |
| 一覧の `repoId` が同じ・`linkedIssue` が子・`isArchived` が true でない・`parentWorktreeId` が今のワークツリーのワークツリー | `parent_worktree` が今のワークツリーで `child` が子の記録 |
| 「同じ linkedIssue のワークツリーが 2 つ以上」 | 「同じ親のワークツリー・同じ子の記録が 2 件以上」 |
| ポーリングごとに `orca worktree list --json` を 1 回呼ぶ | ポーリングごとに渡された子の記録を 1 回ずつ読み、`orca worktree list` は呼ばない |
| `route` / `launch` の子の判定に使う `parentWorktreeId` と親のワークツリーの `linkedIssue` | 今いるワークツリーのパスを `worktree` に持つ記録と、その `epic`（環境変数 `EPIC_DISPATCH_PARENT_EPIC` を先に見る規則は変えない） |
| `gh api repos/{owner}/{repo}/issues/<N>` | 記録の `repo` がエピックと同じリポジトリの子と、番号だけで渡した記録の無い子は今のまま。違うリポジトリの子は `gh api repos/<repo>/issues/<N>`、`<owner>/<repo>#<N>` で渡した記録の無い子は引数の `<owner>/<repo>`（小文字）で `gh api repos/<owner>/<repo>/issues/<N>`。`reap` の `gh pr list`・`git ls-remote` などの呼び出しの形は、capability `dev-workflow-epic-state` の要件「親の見張りは記録だけで子の状態を判定する」の `reap` のとおり（同じリポジトリの子は今のまま、別のリポジトリの子は子のリポジトリと子のワークツリーに向ける） |
| `reap` の `kept <N> not-child` | 出さない（親は自分の `parent_worktree` の記録しか見ない。記録の無い子は `gone <N>`） |
| `mark` の「`orca` が PATH に無いか `orca worktree current --json` が非 0 なら `skipped <issue> no-workspace`」と「印の代わりになるもの（ファイルなど）を作ってはならない」 | 今いるワークツリーのパスを `worktree` に持つ記録が無ければ `skipped <issue> no-workspace`。記録は印の代わりではなく正本で、`mark` は記録を作らない（作るのは `launch` と `adopt` だけ）。`orca` の有無は Orca の印へ写すかどうかだけを決める |
| 「Orca が無い環境のための代わりの実装を持ってはならない」 | 状態の記録は Orca の機能の代わりの実装ではない（Orca の有無によらず正本として書く）。記録を読み書きする新しいスクリプト `scripts/epic-state.sh` は `orca` の語を含まず、`orca` を呼ぶスクリプトは今のまま `scripts/epic-dispatch.sh` 1 本だけ |
| #1106（PR #1120）の、枠を使っている子を Orca の一覧から数える条件 | 同じ条件を記録の項目に置き換えて数える（capability `dev-workflow-epic-state` の要件「同時に枠を使う子は記録から数える」） |

この読み替えは、少なくとも次の既存要件に掛かる: 「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」（`launch` の記録の書き込みと、`route` の判定）・「エピックの並列起動は 1 段で止める」（子のセッションの判定）・「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」（`mark done` / `waiting`・`wait --watch-done`・`reap`）・「Orca 経路の本体は印が付いた子のワークスペースを片付ける」（`kept <N> not-child` の扱いは起きなくなる。`--watch-done` / `--watch-stopped` を付けた `wait` が stdout に何も出さず exit 1 で終わったときの規定は、`wait` が Orca を読まなくなるので、`launch` が exit 1 で子を 1 件も作らなかったときと `adopt` が stdout に何も出さず exit 1 で終わったときの規定として読む）・「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」（記録は代わりの実装に数えない）・「エピックの子への注意書きと子であることを、起動し直したセッションにも引き継ぐ」（`route` の `parentWorktreeId` の判定）・「epic-dispatch.sh は子が止まった印を付け、wait が止まった子を返す」・「epic-dispatch.sh の wait は止まった子を判断し、通すものには返事を送って待ちを続ける」・「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」（子のワークツリーの見つけ方）・「epic-dispatch.sh reap は PR が無く issue を閉じた子を、main に入っていない commit が無いときに片付ける」・「Orca 経路の親は、止まった印のまま completed で閉じた子に完了を促す返事を送る」・「起動し直した親は主の返事待ちの子を主に出し直す」（`pending-owner` は記録の `stop` が `stopped-seen` の子を出す）・「wait --resolve は通す返事を送る前に起動し直すかを表で決める」（子のワークツリーの `path` は記録の `worktree` から読む）、および #1120 がこの capability に足す上限の要件。

既存要件の Scenario のうち、スタブの Orca の一覧の `workspaceStatus` / `comment` を置いて状態を決めているものは、同じ値を記録の `status` / `stop` に置いたものとして確かめなければならない（MUST）。`plugins/dev-workflow/tests/epic-dispatch.bats` の該当するテストは、記録を一時ディレクトリ（`EPIC_STATE_ROOT`）に作って同じ出力を確かめる形に直す。

#### Scenario: 止まった子の受け取りは記録で起きる

- **WHEN** 既存要件「epic-dispatch.sh は子が止まった印を付け、wait が止まった子を返す」の Scenario のとおり、子 11 が open のまま止まった状態で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-stopped 11` を実行する。ただし止まった状態は記録の `stop` が `stopped` で表し、Orca の一覧の `comment` は空にする
- **THEN** stdout は `stopped 11`、exit 0 で、記録の `stop` は `stopped-seen` になり、`orca worktree list` は呼ばれない

#### Scenario: 片付けの安全確認は今と同じ

- **WHEN** 既存要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」の、安全確認を 1 点だけ変えた Scenario を、記録の `status` を `done` にして実行する
- **THEN** stdout は既存の Scenario と同じ `kept 11 <理由>` の行で、ワークツリーは消されず、記録も消されない

#### Scenario: 記録を読み書きするスクリプトは orca の語を含まない

- **WHEN** `epic-state.sh` を足したあとで `grep -rlw orca plugins/dev-workflow --include='*.sh'` を実行する
- **THEN** 出力は `plugins/dev-workflow/scripts/epic-dispatch.sh` の 1 行だけである

#### Scenario: 記録の無いワークツリーの mark は記録を作らない

- **WHEN** どの記録の `worktree` とも一致しないワークツリーで `epic-dispatch.sh mark done 11` を実行する
- **THEN** stdout は `skipped 11 no-workspace`、exit 0 で、`EPIC_STATE_ROOT` の下にファイルは増えていない

#### Scenario: 起動し直した親の出し直しは記録で決まる

- **WHEN** 子 11 の記録の `stop` が `stopped-seen`、子 12 が `resumed`、子 13 が `stopped` の状態で `epic-dispatch.sh pending-owner 11 12 13` を実行する
- **THEN** stdout は `pending 11` の 1 行で、`orca worktree list` も `orca worktree set` も呼ばれない


## ADDED Requirements

### Requirement: 別のリポジトリの子を含むエピックの回し方を SKILL.md に書く

develop の SKILL.md「エピックの扱い」は、エピックの子がエピックと別のリポジトリにあるときの挙動を、既存の要件（子エピックの外し方・マージ待ちの子・子の側の手順・コメントの書式）の読み替えとして書かなければならない（MUST）。読み替えは次の表のとおりで、同じリポジトリの子の呼び出しの形・書式・判定は表の外では変えない（MUST）。既存の要件の本文は書き直さず、この要件が読み替えを持つ。

| 既存の書き方 | 別のリポジトリの子での読み替え |
|---|---|
| 子の依存を `gh api repos/<owner>/<repo>/issues/<N>/dependencies/blocked_by` で読む | 子のリポジトリ（`repos/<子の owner>/<子の repo>/issues/<N>/dependencies/blocked_by`）で読む。前提の issue のリポジトリは応答の `repository_url` から取り、前提の state もそのリポジトリで読む。前提が別リポジトリにあっても閉じていれば解けている。前提の issue を `gh` が読めないときは、解けていないものとして待つ（この change で新しく決めた扱い。今の SKILL.md にこの記述は無い） |
| 子エピックの判定 `gh api repos/{owner}/{repo}/issues/<N> --jq .sub_issues_summary.total` | 子のリポジトリで読む（`repos/<子の owner>/<子の repo>/issues/<N>`）。別リポジトリというだけでは外さず、sub-issue を持つ子だけを外す |
| エピックの子の一覧 | エピックのリポジトリの sub-issue（`gh api repos/{owner}/{repo}/issues/<E>/sub_issues`。各要素の `repository_url` から子のリポジトリを取る）と、エピック本文の子の表（`<owner>/<repo>#<N>` か `#<N>`）を合わせて組み立てる。同じ子は小文字にそろえた `<owner>/<repo>#<N>` で 1 件に数える |
| エピックへのコメント `後で別に起動するエピック: #N` | 別のリポジトリの子は `後で別に起動するエピック: <owner>/<repo>#N` |
| エピックへのコメント `子 #N マージ → 残り k 件`・`子 #N 見送り（<state_reason>）→ 残り k 件`・`子 #N のワークツリーを残した`・`親の判断: 子 #N 通した — ...` | 別のリポジトリの子は `子 <owner>/<repo>#N` の同じ形（`親の判断: 子 <owner>/<repo>#N 通した — ...`）。完了報告も同じ呼び方 |
| 子の側が親エピックに残すコメント `gh issue comment <E> --body '後で別に起動するエピック: #<自分>'` | エピックが別のリポジトリにあるときは `gh issue comment <E> -R <エピックのリポジトリ> --body '後で別に起動するエピック: <自分の owner>/<自分の repo>#<自分>'`。`<E>` とエピックのリポジトリは `route` の stderr の `parent epic: <owner>/<repo>#<E>` から取る |
| マージ待ちの子の前提の `auto-merge.yml` の取得（`repos/<owner>/<repo>/contents/...`）、`親のマージ判断:` のコメント、`parent-merge-approved` のラベル、PR 本文の `Closes #N` の確認 | すべて子のリポジトリの PR に対して行う（`contents` は `repos/<子の owner>/<子の repo>/...`、コメントは `gh pr comment <PR> -R <子の repo>`、ラベルは `gh api repos/<子の repo>/issues/<PR番号>/labels`）。印が数えられるのは `gh` の認証アカウントが子のリポジトリの OWNER・MEMBER・COLLABORATOR のときだけで、そうでなければ決める役を起こさず手順 8 の形で主に上げる |
| 親から届く返事の頭 `親エピック #<E> の判断（主の承認ではない）: ` / `主の返事（親エピック #<E> 経由）: ` を受ける子の側の手順（`references/ci-watch.md` の 1 箇所を含む） | 番号のあとに `（<owner>/<repo>）` が付く形（要件「別のリポジトリの子の起動の指示・環境変数・注意書き・返事の頭にはエピックのリポジトリを足す」）でも同じ手順で受ける。先頭の `親エピック #` / `主の返事（親エピック #` で判定する |
| 手順 4 の `gh api repos/{owner}/{repo}/issues/<N> --jq .state_reason` | 別のリポジトリの子は `gh api repos/<子の owner>/<子の repo>/issues/<N> --jq .state_reason`（親のリポジトリの同じ番号を読んで `completed` と `not_planned` を取り違えない） |
| 手順 8 とマージ待ちの子の、子 issue の `子の停止: 主の返事待ち` と `親の判断:` のコメントの読み先（`author_association` を含む） | 別のリポジトリの子は子のリポジトリ（`repos/<子の owner>/<子の repo>/issues/<N>/comments`）から読む |
| 手順 3 (b) の起点ブランチ | その子の記録の `base`（別のリポジトリの子は子のリポジトリの既定ブランチか `--base` の値）。親のリポジトリの `main` ではない |
| `後で別に起動するエピック:` の行で子を外す照合（手順 2・`timeout` と `closed` の確認） | 別のリポジトリの子は `<owner>/<repo>#N` の形の行で照合する（同じリポジトリの子は `#N`） |
| 子を `route`・`launch`・`wait`（位置引数と `--watch-done`）・`reap`・`pending-owner`・`notify-closed`・`reply`・`adopt` に渡す | 別のリポジトリの子は `<owner>/<repo>#N` の形で渡す（同じリポジトリの子は番号だけ） |
| SKILL.md:487 の注意書き `親エピックからの注意書き: #<エピック番号>`、手順 1 の「起点は `origin/main`」 | 別のリポジトリの子は注意書きが `親エピックからの注意書き: <エピックの owner>/<repo>#<E>`（子のリポジトリの issue に残る）。起点は `--base` / `EPIC_DISPATCH_BASE`、無ければ子のリポジトリの既定ブランチ |
| `stop-judge.sh <epic> <child>` の `<child>` は番号 | 番号か `<owner>/<repo>#<N>`。後者は子の本文・コメントを `repos/<o>/<r>/issues/<N>` から読み、エピックのコメントの過去の判断を `親の判断: 子 <o>/<r>#<N> ` で始まる行から探す。同じリポジトリの子は今までどおり。入力文の見出しも同じ呼び方にする |

サブエージェント方式（unmanned・channel・Orca 管理外で選ばれる）では、別のリポジトリの子を W に渡してはならない（MUST。W は親のリポジトリに worktree を作るので、別のリポジトリの issue を親のリポジトリの PR として実装してしまう）。本体はエピックに `子 <owner>/<repo>#N は別のリポジトリなので Orca 経路でだけ起動する` と 1 行コメントし、その子と、その子を前提にする子を起こさずに、主に報告する（1 行目は `主がすること:` の規定に従う）。

SKILL.md の手順 1 には、`--base` と `EPIC_DISPATCH_BASE` が 1 回の `launch` の全部の子に掛かること、リポジトリごとに既定ブランチが違う子を混ぜるときは `--base` を付けないか `launch` をリポジトリごとに分けることを書かなければならない（MUST）。手順 6 の `failed` の報告には、`failed <child> no-clone`（`EPIC_DISPATCH_CLONES` の設定か clone を主に頼む）・`ambiguous-clone`（候補のパス）・`no-push`・`permission-lookup-failed`（stderr の `gh` の認証アカウントと子のリポジトリを添える）を足し、どれも主に報告して止まると書かなければならない（MUST。サブエージェント方式に自動で振り替えない）。

この要件の守備範囲で入力として扱うのは、SKILL.md の手順書の文面と `stop-judge.sh` の引数である。拾いたい誤りは、別のリポジトリの子の依存や子エピックの判定を親のリポジトリに対して読み、解けていない子を起動したり、子エピックを展開したりすることである。次は通してよく、この要件では止めない: 前提の issue を `gh` が読めないとき（読めない前提は解けていないとして待つ今の扱い）／エピック本文の子の表の書式の揺れ。表を手で直した結果の細かい食い違いを見つけるたびに検査を足すことは、この要件の完了条件としない。

#### Scenario: 依存と子エピックの判定を子のリポジトリで読むと書いてある
- **WHEN** SKILL.md の「回し方」の経路の決め方と「エピックである子を外す」を読む
- **THEN** 別のリポジトリの子の `blocked_by` と `sub_issues_summary.total` を子のリポジトリで読むこと、前提の issue のリポジトリを `repository_url` から取ることが書いてある

#### Scenario: 子の一覧の組み立てが書いてある
- **WHEN** SKILL.md の「エピックの扱い」を読む
- **THEN** sub-issue の `repository_url` とエピック本文の子の表から子の一覧を組み立て、同じ子を 1 件に数えることが書いてある

#### Scenario: 読み先が子のリポジトリだと書いてある
- **WHEN** SKILL.md の手順 3 (b)・手順 4・手順 8・マージ待ちの子・`後で別に起動するエピック:` の照合を読む
- **THEN** 手順 4 は別のリポジトリの子の `state_reason` を `repos/<子の owner>/<子の repo>/issues/<N>` で読むと書いてあり、手順 8 とマージ待ちの子は子 issue のコメントを子のリポジトリから読むと書いてあり、手順 3 (b) は起点を記録の `base` と書いてあり、`後で別に起動するエピック:` の照合は `<owner>/<repo>#N` の形と書いてある

#### Scenario: 各サブコマンドへの渡し方が書いてある
- **WHEN** SKILL.md の「エピックの扱い」を読む
- **THEN** 別のリポジトリの子を `route`・`launch`・`wait`・`reap`・`pending-owner`・`notify-closed`・`reply`・`adopt` に `<owner>/<repo>#N` で渡すと書いてある

#### Scenario: サブエージェント方式では別のリポジトリの子を起こさない
- **WHEN** SKILL.md の「サブエージェント方式」を読む
- **THEN** 別のリポジトリの子を W に渡さず、エピックに 1 行残して、その子とそれを前提にする子を起こさずに主に報告すると書いてある

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
