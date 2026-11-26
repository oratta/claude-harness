## Context

issue #1123 を 3 つに割った 2 つ目の change。1 つ目の `epic-state-files`（PR #1148、`openspec/changes/archive/2026-10-20-epic-state-files/`）が、子を `<owner>/<repo>#<N>` で識別する記録（子ごと 1 ファイル）と、記録だけで動く親の見張りを入れた。その design.md の Decision 4・6（子の呼び方と親の見張り）は spec に入っている。Decision 11 に別リポジトリの挙動の残り 5 項目の決めた内容が置いてあり、この change はそれを spec と SKILL.md に起こす。Decision 12（起動部品の境目）は 3 つ目の change の範囲で、ここでは扱わない。

今の状態: `launch` はエピックと別のリポジトリの子を `failed <child> other-repo` で返す（記録も作らない）。`reap` の `gh pr list`・`git ls-remote` は今のワークツリーのリポジトリに向く。`stop-judge.sh` は子の引数を番号だけ受け、`repos/{owner}/{repo}` で読む。SKILL.md「エピックの扱い」は子が親と同じリポジトリにある前提で書かれている。

前例: flatmate #896 は別リポジトリの子（claude-harness #470）を含み、`回し方:` のコメントは「flatmate の #859・#738・#568 は epic-dispatch.sh launch、oratta/claude-harness#470 は harness の開発用 clone に Orca ワークツリーを切って起動」だった。別リポジトリの子だけ人が手で起動していた。この change でその手作業を `launch` に取り込む。手で起動した子（記録が無い）の取り込み（`adopt`）はこの change の範囲外（下の Non-Goals）。

## Goals / Non-Goals

**Goals:**

- 別リポジトリの子を `launch` に渡すと、子のリポジトリのローカル clone にワークツリーができ、子ごとの記録が作られ、親が `wait`・`pending-owner`・`reap`・`notify-closed` で同じように見張れる
- 依存と子エピックの判定・コメントの書式・マージ待ちの子の手順・子の側の記録の置き場を、別リポジトリの子に対応させて SKILL.md と spec に書く
- 並列起動数の上限（#1106 / PR #1120。`deferred <N>`・枠の数え方）の動きを変えない。別リポジトリの子も同じ上限の枠を 1 つ使う
- 同じリポジトリの子の呼び出しの形・出力・既存の bats の照合を変えない

**Non-Goals:**

- ハーネスが子のリポジトリを自動で clone すること（clone の置き場はオーナーのディスクの構成で決まる）
- fork から PR を出す経路
- 手で起動した別リポジトリの子（記録の無い子）を記録に取り込むこと。`adopt` は今のとおり別リポジトリの子に `none <child>` を返す。そのような子は、同じ子を `launch` に渡すと子のリポジトリの Orca の一覧に同じ issue のワークツリーがあれば `skipped` になり、記録は作られない（見張りの対象にならず、親は手で扱う）
- 起動部品の差し替え（tmux・サブエージェント）。別リポジトリの子を起動するのは、今の Orca の部品だけ
- サブエージェント方式での別リポジトリの子の起動。W は `isolation: "worktree"` で親のリポジトリに worktree を作るので、別リポジトリの子を渡すと親のリポジトリに PR を出してしまう。サブエージェント方式（unmanned・channel・Orca 管理外）では別リポジトリの子を W に渡さず、エピックに 1 行残し、その子と、それを前提にする子を起こさずに主に報告する（spec dev-workflow-develop に MUST で書いた）

## Decisions

change 1 の Decision 11 に従う。以下は、それを spec に起こす際に決めた具体と、Decision 11 に書かれていない点。Decision 11 を決め直す箇所はない。

### 1. 依存と子エピックの判定（Decision 11 の項目 1）

- 子の `blocked_by` と `sub_issues_summary.total` は、子のリポジトリ（`gh api repos/<子の owner>/<子の repo>/issues/<N>/dependencies/blocked_by`、`gh api repos/<子の owner>/<子の repo>/issues/<N> --jq .sub_issues_summary.total`）に対して読む。`blocked_by` の前提の issue のリポジトリは応答の `repository_url`（`https://api.github.com/repos/<o>/<r>`）から取り、前提の state もそのリポジトリで読む。前提が別リポジトリにあっても、その issue が閉じていれば解けている
- エピックの子の一覧は、エピックのリポジトリの sub-issue（`gh api repos/{owner}/{repo}/issues/<E>/sub_issues`。各要素の `repository_url` から子のリポジトリを取る）と、エピックの本文の子の表（`<owner>/<repo>#<N>` か `#<N>`）を合わせて組み立てる。同じ子は 1 件に数える（小文字にそろえた `<owner>/<repo>#<N>` で比べる）
- 別リポジトリというだけで「後で別に起動するエピック」に回さない。回すのは sub-issue を持つ子だけで、今の規則のまま。回した子は `後で別に起動するエピック: <owner>/<repo>#N`（別リポジトリの子）か `後で別に起動するエピック: #N`（同じリポジトリの子）と書く
- 代案: 別リポジトリの子は別エピックとして扱う → 実際のエピック（flatmate #1615 に積んだ claude-harness の子）が 1 つのストーリーの子を複数のリポジトリに積んでいるので、親が 1 つの依存グラフとして見張る必要がある

### 2. ワークツリーの作り先（項目 2）

clone を次の順に探す。各段で、候補ごとに `git -C <候補> remote get-url origin` を読み、change 1 の Decision 1 の 3 つの形（`git@github.com:o/r`・`ssh://git@github.com/o/r`・`https://github.com/o/r`、末尾の `.git`・`/` 任意、小文字にそろえる）で `<owner>/<repo>` が子のリポジトリと一致することを確かめる。一致しない候補は無かったことにして次へ進む。

1. 子のリポジトリがエピックと同じなら、親のワークツリーの clone（今の `launch` の動き。`git rev-parse --show-toplevel`）。この段は別リポジトリの子には当たらない
2. 環境変数 `EPIC_DISPATCH_CLONES`: `<owner>/<repo>=<絶対パス>` を改行か `;` で区切る。左辺は小文字にそろえて比べる。相対パスの値は無かったことにして stderr に出す
3. 起動部品が知っているリポジトリ: Orca は `orca repo list --json` の各リポジトリの `path`

- 見つからなければ、自動で clone せず、記録も作らず枠も使わずに `failed <child> no-clone` を stdout に出し、stderr に `EPIC_DISPATCH_CLONES` の書き方（`export EPIC_DISPATCH_CLONES='<o>/<r>=<clone の絶対パス>'`）と clone のコマンド（`git clone git@github.com:<o>/<r>.git <置きたい場所>`）を出す。clone の置き場はオーナーのディスクの構成で決まるので、ハーネスがパスを決めない。一度設定すれば以後は見つかる
- 同じ段に 2 つ以上の候補が一致したら `failed <child> ambiguous-clone`（記録も枠も使わない）。stderr に候補のパスを出す。段をまたいだ重複は先の段を取る（`EPIC_DISPATCH_CLONES` の指定が Orca の登録より優先）
- ワークツリーの起点は、`--base` / `EPIC_DISPATCH_BASE` があればそれ、無ければ子のリポジトリの既定ブランチ（`gh api repos/<o>/<r>` の 1 回の応答の `.default_branch`。`.permissions.push` と同じ応答で、判定順は Decision 3）。同じリポジトリの子は今までどおり無ければ `main`（呼び出しの形を変えない）。`--base` と `EPIC_DISPATCH_BASE` は 1 回の `launch` の全部の子に掛かるので、リポジトリごとに既定ブランチが違う子を渡すときは、`--base` を付けずに（既定ブランチを使わせる）か、`launch` をリポジトリごとに分けて呼ぶ（SKILL.md に書く）
- 子の clone の `origin` の取得は `git -C <clone> fetch origin <base>`。Orca の部品は `orca worktree create --repo <selector> ...`（Orca に登録されたリポジトリ）で作る。(2) で見つけた clone が Orca に登録されていないときは、`orca repo list --json` で当たらないので記録を書く前に `failed <child> not-in-orca`(記録も枠も使わない。stderr に `orca repo add` の案内を出す)。登録を `launch` が自動で行うことはしない（Orca のリポジトリの追加は画面の状態を変えるため）
- 1 回の `launch` の中で、同じリポジトリの clone の探索・書き込み権・既定ブランチの照会は 1 回にまとめる（子ごとに繰り返さない）

### 3. 書き込み権（項目 3）

- 別リポジトリの子について、ワークツリーを作る前に `gh api repos/<o>/<r>` の 1 回の応答を次の順に判定する。(1) `gh` の失敗・`permissions` が応答に無い → `failed <child> permission-lookup-failed`、(2) `.permissions.push` が `true` でない → `failed <child> no-push`、(3) (1)(2) を通ったあとで `.default_branch` が空 → `failed <child> base-lookup-failed`（`--base` があっても止める）。どれも記録を作らず、枠を使わない。stderr に `gh` の認証アカウントと子のリポジトリを出す
- 親は他の `failed` と同じく主に報告して止まる（SKILL.md の手順 6）。サブエージェント方式に自動で振り替えない（今の `failed` と同じ）。fork から PR を出す経路は作らない
- 同じリポジトリの子には、この読み出しをしない（呼び出しの形を変えない）

### 4. PR・ゲート・マージ（項目 4）

- 子のセッションは子のリポジトリのワークツリーで動くので、`gh` の既定のリポジトリは子のリポジトリになる。PR は子のリポジトリに立ち、本文の `Closes #N` は子のリポジトリの issue を指す。pr-review-gate・auto-merge の有無・`human-merge` の扱いは子のリポジトリの設定に従う（ハーネス側で何も変えない）
- 親の「マージ待ちの子」の手順は、PR の base ブランチの `auto-merge.yml` を子のリポジトリから読み（`gh api "repos/<子の o>/<子の r>/contents/.github/workflows/auto-merge.yml?ref=<base>"`）、`親のマージ判断:` のコメントと `parent-merge-approved` のラベルを子のリポジトリの PR に付ける（`gh pr comment <PR> -R <子の repo>`、ラベルは `gh api repos/<子の repo>/issues/<PR番号>/labels`）。PR の本文の `Closes #N` の `N` が子の番号であることの確認も、子のリポジトリの PR で行う。同じリポジトリの子は今のまま
- 印が数えられるのは、`gh` の認証アカウントが子のリポジトリの OWNER・MEMBER・COLLABORATOR のときだけ（今の規則の対象リポを子のリポジトリと読む）。別リポジトリの子の PR の判断の印を付けるアカウントが子のリポジトリで権限を持たないときは、決める役を起こさず手順 8 の形で主に上げる
- 代案: 別リポジトリの子の PR は親が一律に主に上げる → 子のリポジトリが auto-merge を配備していれば、同じ基準で親が判断できる。配備していなければ前提（`auto-merge.yml` に `parent-merge-approved` の語がある）が満たされず、決める役を起こさずに主に上げる今の規則のまま落ちる

### 5. 親の見張りの残り（項目 6 の残り。Decision 6）

- `reap` の PR の照会を別リポジトリの子では `gh pr list -R <子のリポジトリ> --head <branch> --state merged ...` に向け（`--search` の形も `-R` を足す）、base の照会は子のワークツリーの origin に向ける（`git -C <子のワークツリー> ls-remote origin refs/heads/<base>`、`git -C <子のワークツリー> fetch origin <base>`）。同じリポジトリの子は呼び出しの形を変えない（既存の bats の照合をそのまま通す）。別リポジトリの子の issue の state は、change 1 の `issue_api` が記録の `repo` で読む形のまま
- `wait`・`pending-owner`・`notify-closed`・`reply` は change 1 で記録の `repo` を使うように作られているので、追加の変更は書式だけ（下の 6）。`reap` はそのほかに、base の名前を記録の `base` に、base の先端をリポジトリと base の組ごとに 1 回に、`git cat-file -e` を子のワークツリーに、ブランチの片付け(`rev-parse`・`worktree list`・`branch -D`)を子の clone に向ける(`orca worktree rm` の前に `git-common-dir` で clone を控える)

### 6. 書式（Decision 4 の続き）

change 1 の Decision 4 は、同じリポジトリの書式を変えず、別リポジトリの子とエピックに足す形を決めた。この change で次の箇所に具体化する。

| 箇所 | 同じリポジトリの子 | 別リポジトリの子（子の記録の `repo` がエピックのリポジトリと違う） |
|---|---|---|
| 子の起動の指示（`launch` の最初の入力） | `/develop #<N> （エピック #<E> の子。親ワークツリー <親> から Orca で起動）` | `/develop #<N> （エピック #<E> の子。エピックのリポジトリ <エピックの owner>/<repo>。親ワークツリー <親> から Orca で起動）`。先頭 `#<N> （エピック #<E> の子。` は同じリポジトリの子と同じ形のままにする（`owner-reply-check.sh:127` の `DISPATCH_ARGS` が親の打ち込みを主の発言から外す判定に使う。リポジトリは後ろに置く）。起動し直しの指示も同じ形で、`<N>` は番号だけで書く |
| `EPIC_DISPATCH_PARENT_EPIC` | `<エピック番号>` | `<エピックの owner>/<repo>#<エピック番号>`（`route` が `*#*` を既に受ける）。`launch` だけでなく `agent_setup` を呼ぶ全経路（`reply`・`notify-closed`・`wait --resolve` の起動し直し）に付け、値は記録の `epic` と `repo` から決める |
| 注意書きの投稿 | `gh issue comment <N> --body '親エピックからの注意書き: #<E>...'` | `gh issue comment <N> -R <子のリポジトリ> --body '親エピックからの注意書き: <エピックの owner>/<repo>#<E>...'`（子の側が従う条件は先頭が `親エピックからの注意書き:` であること。番号の書き方は条件に入れない）。失敗時の投稿し直しのコマンドも `-R` 付き |
| 親から子への返事の頭 | `親エピック #<E> の判断（主の承認ではない）: ` / `主の返事（親エピック #<E> 経由）: ` | `親エピック #<E>（<エピックの owner>/<repo>）の判断（主の承認ではない）: ` / `主の返事（親エピック #<E>（<エピックの owner>/<repo>）経由）: `（先頭の `親エピック #` / `主の返事（親エピック #` は同じなので、`owner-reply-check.sh` の判定と pr-review-gate の親経由の受領の照合は変えない） |
| エピックへのコメント | `子 #N マージ → 残り k 件`／`子 #N 見送り（<state_reason>）→ 残り k 件`／`親の判断: 子 #N 通した — ...`／`子 #N のワークツリーを残した` | `子 <o>/<r>#N ...` の同じ形（GitHub は別リポジトリの issue へのリンクにする） |
| 子の側が親エピックに残すコメント | `後で別に起動するエピック: #<自分>` を `gh issue comment <E>` に | `後で別に起動するエピック: <o>/<r>#<自分>` を `gh issue comment <E> -R <エピックのリポジトリ>` に（`<E>` と エピックのリポジトリは `route` の stderr の `parent epic: <owner>/<repo>#<E>` から取る） |

- `stop-judge.sh <epic> <child>` は、`<child>` に番号だけか `<owner>/<repo>#<N>` を受ける。後者のとき、子の本文・コメントは `repos/<o>/<r>/issues/<N>` から読み、エピックのコメントの過去の判断は `親の判断: 子 <o>/<r>#<N> ` で始まる行を探す（同じリポジトリの子は今までどおり `親の判断: 子 #<N> `）。エピックの本文・コメントは `repos/{owner}/{repo}` のまま（親のワークツリーで呼ぶので親のリポジトリ）。入力文の見出しも同じ呼び方にする
- 子の側の手順（SKILL.md「エピックの子が主の返事を待って止まるとき」）は、親から届く返事の頭を、番号のあとに `（<owner>/<repo>）` が付く形でも受ける。`references/ci-watch.md` の 1 箇所（親から届く返事の頭の照合）も同じ
- 代案: 常に `<owner>/<repo>#<N>` で書く → Decision 4 の代案と同じ理由で採らない

### 7. launch の手順の順序（別リポジトリの子）

1 件の子について、次の順で進める。`seen`（同じ呼び出しで重複した子）と、記録があって `worktree` が空でないときの `skipped` は今のまま先に判定し、clone の探索や `gh` の呼び出しをしない。

1. 記録の読み取り（読めなければ `failed <child> state-unreadable`。今のまま）
2. 別リポジトリの子なら、clone の探索（`no-clone` / `ambiguous-clone`）→ `orca repo list --json` での引き当て（`not-in-orca`。`repoId` と selector もここで決める）→ `gh api repos/<o>/<r>` の 1 回の応答から書き込み権と既定ブランチを、判定順 `permission-lookup-failed` → `no-push` → `base-lookup-failed` で読む(Decision 3)。ここまでの失敗は記録を作らず、枠を使わない。`worktree` が空のまま残った自分の記録は、ここを通したあと子の `repoId` の一覧で埋めるか上書きし、枠は増やさない
3. 子のリポジトリの Orca の一覧（`orca worktree list --json` を子のリポジトリの `repoId` で絞る）に同じ issue のワークツリーがあれば `skipped`（今の「記録の無い Orca のワークツリーは起動済み」を子のリポジトリで見る形）
4. 空き枠の判定（`deferred <child>`）。別リポジトリの子も 1 枠を使い、同じ上限の中で数える（記録の `parent_worktree` が今のワークツリーの記録を数える今の数え方のまま。別リポジトリの子の記録も数える）
5. 記録を書く（`repo` に子のリポジトリ、`child` に `<o>/<r>#<N>`、`base` に決めた起点）→ `git -C <clone> fetch origin <base>` → `orca worktree create --repo <selector> --name issue-<N> --issue <N> --base-branch origin/<base> --parent-worktree path:<親> --json`。作成に失敗したら記録を消す（今のまま）
6. 注意書き → 端末 → 起動待ち → 送信（今のまま。子のワークツリーのパスは `orca worktree create` の応答から取る）

`orca worktree set --worktree path:<親> --issue <エピック>`（親のワークツリーにエピックを結ぶ）は `launch` の最初に 1 回だけ行う。子が全部別リポジトリでも行う(Orca の画面で親のエピックが分かる)。`git fetch origin <base>`(親の clone)は、同じリポジトリの子が 1 件以上あるときだけ行う(別リポジトリの子だけに `--base develop` を付けたとき、親に `develop` が無くても `launch` 全体が失敗しないため)。子の clone の `git -C <clone> fetch origin <base>` が失敗したら、記録を消して `failed <child>` とする。

## Risks / Trade-offs

- [`--parent-worktree path:<親>` が別リポジトリの親子を Orca が受け付けるか、実機で未確認] → 状態の正本は記録（`parent_worktree`）で、Orca の親子の線は画面の写しにすぎない。Orca が別リポジトリの親を拒んだら、`--parent-worktree` を外して作る（親子は記録だけが持つ）。実装の最初に実機で確かめ、結果を tasks の実施欄に残す。拒んだ場合の分岐は spec に書かない（記録が正本の規則から導かれる）
- [`EPIC_DISPATCH_CLONES` に誤ったパスを書く] → 候補ごとに origin を照合するので、別のリポジトリの clone に子のワークツリーを作らない。一致しなければ無かったことにして `no-clone` になる
- [`gh` の認証アカウントに push 権があっても、子のリポジトリのブランチ保護や required checks で子の PR が詰まる] → 子のリポジトリの設定に従う（4）。親の見張りは子の `stop` / `status` と issue の state で動くので、詰まった子は `timeout` か `stopped` として親に見える
- [`--base` / `EPIC_DISPATCH_BASE` が全部の子に掛かる] → 別リポジトリの子の既定ブランチが違うリポジトリを混ぜるときは、`launch` をリポジトリごとに分ける（SKILL.md に書く）。気づかずに混ぜると、起点が存在しない `fetch` の失敗として、その子が `failed <child>` になる(記録は消え、誤った起点でワークツリーができることはない。親の clone の fetch は同じリポジトリの子があるときだけなので、`launch` 全体は止まらない)

## Migration Plan

記録の書式（schema 1）は変えない。既に動いているエピックの同じリポジトリの子の動きは変わらない。戻し方: この change の PR を revert すれば、別リポジトリの子は `other-repo` で返る動きに戻る（作られた別リポジトリの子のワークツリーと記録は残るので、`reap` / `clear` で片付ける）。

## Open Questions

なし（`--parent-worktree` の件は Risks に、確かめ方と外す分岐を書いた）。
