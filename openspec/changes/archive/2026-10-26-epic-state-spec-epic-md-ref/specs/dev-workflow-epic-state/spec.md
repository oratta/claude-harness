## MODIFIED Requirements

### Requirement: 子を owner/repo#番号 で識別し、同じリポジトリの子は番号だけで書く

記録・ファイル名・状態ディレクトリ名は、子とエピックを `<owner>/<repo>#<N>` で識別しなければならない（MUST）。`epic-dispatch.sh` の子の引数は、番号だけ（エピックと同じリポジトリの子）か `<owner>/<repo>#<N>` を受け付け、出力は引数で受けた形のまま返さなければならない（MUST）。`<owner>/<repo>#<N>` がエピックと同じリポジトリを指すときは、番号だけと同じ子として扱う（MUST）。エピックへのコメントと完了報告では、エピックと同じリポジトリの子を今のまま `子 #N` と書き、別のリポジトリの子を `子 <owner>/<repo>#N` と書かなければならない（MUST）。

子の引数の形は `^[0-9]+$` か `^[A-Za-z0-9-]+/[A-Za-z0-9._-]+#[0-9]+$` のどちらかでなければならず、それ以外は何も呼ばずに stderr に使い方を出して exit 1 で終わる（MUST）。`<owner>/<repo>` は ASCII の小文字にそろえてから記録の `repo` と比べる（大文字小文字だけが違う `Oratta/Claude-Harness#5` は `oratta/claude-harness#5` と同じ子）。

親の見張り（`wait`・`pending-owner`・`reap`・`notify-closed`・`reply`）は origin を読まずに子の記録を探す（MUST）。番号だけの引数 `<N>` は、`parent_worktree` が今のワークツリーの最上位のパスで、`number` が `<N>` で、`repo` が記録の `epic` のリポジトリの部分と一致する記録に当てる。`<owner>/<repo>#<N>` の引数は、`parent_worktree` が今のワークツリーで `child` が一致する記録に当てる。子 issue を `gh` で読む先は、記録の `repo` が記録の `epic` のリポジトリと同じ子と番号だけで渡した記録の無い子は今のまま `gh api repos/{owner}/{repo}/issues/<N>`（`gh` が今のワークツリーのリポジトリに置き換える）、記録の `repo` が違う子は `gh api repos/<repo>/issues/<N>`、`<owner>/<repo>#<N>` で渡した記録の無い子は引数の `<owner>/<repo>` を小文字にそろえて `gh api repos/<owner>/<repo>/issues/<N>` にしなければならない（MUST。この change では同じリポジトリの子の呼び出しの形を変えない）。

`launch` は、エピックと別のリポジトリの子を受けたら、子のリポジトリのローカル clone にワークツリーを作る（要件「launch は別のリポジトリの子のワークツリーを、子のリポジトリの clone に作る」）。`other-repo` は返さない（MUST NOT）。

この要件の守備範囲で入力として扱うのは、develop の本体が `references/epic.md` の手順どおりに渡す子の引数（依存グラフとエピックのコメントから組み立てた番号か `<owner>/<repo>#<N>`）である。拾いたい誤りは、`#12` のように番号に記号が付くこと、`oratta/claude-harness#` や `claude-harness#12` のように owner・repo・番号のどれかが欠けること、引数が空になることである。次は通してよく、この要件では止めない: GitHub に存在しない番号やリポジトリ（`gh` の呼び出しで `error gh` などとして表に出る）／大文字小文字だけが違う owner と repo（同じ子として扱う）／エピックと同じリポジトリを `<owner>/<repo>#<N>` で書いた引数（番号だけと同じ子として扱い、出力は受けた形のまま）。引数の書き間違いの形を見つけるたびに検査を足して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 同じリポジトリの子の出力は今と同じ
- **WHEN** 子 11 が閉じている状態で `epic-dispatch.sh wait --interval 0 --timeout 0 11` を実行する
- **THEN** stdout は `closed 11` である

#### Scenario: owner/repo#番号 で渡した子はその形で返る
- **WHEN** エピックと別のリポジトリ `genetta-inc/flatmate` の子 1615 の記録があり、その issue が閉じている状態で `epic-dispatch.sh wait --interval 0 --timeout 0 genetta-inc/flatmate#1615` を実行する
- **THEN** `gh` は `repos/genetta-inc/flatmate/issues/1615` を読み、stdout は `closed genetta-inc/flatmate#1615` である

#### Scenario: launch は別のリポジトリの子に other-repo を返さない
- **WHEN** origin が `oratta/claude-harness` の親のワークツリーで、`EPIC_DISPATCH_CLONES` に `genetta-inc/flatmate` の clone を書き、`epic-dispatch.sh launch 1122 genetta-inc/flatmate#1615` を実行する
- **THEN** stdout に `other-repo` を含む行は無い（結果は要件「launch は別のリポジトリの子のワークツリーを、子のリポジトリの clone に作る」の Scenario のとおり）

#### Scenario: 番号でも owner/repo#番号 でもない引数は使い方を出す
- **WHEN** `epic-dispatch.sh wait foo`・`epic-dispatch.sh wait '#12'`・`epic-dispatch.sh wait oratta/claude-harness#`・`epic-dispatch.sh wait claude-harness#12` をそれぞれ実行する
- **THEN** どれも `gh` は呼ばれず、stderr に使い方が出て exit 1 である

#### Scenario: 同じリポジトリの子は今と同じ形で gh を呼ぶ
- **WHEN** 子 11 の記録の `repo` が `oratta/claude-harness`、`epic` が `oratta/claude-harness#1122` で、`epic-dispatch.sh wait --interval 0 --timeout 60 11` を実行する
- **THEN** `gh api repos/{owner}/{repo}/issues/11 --jq .state` が呼ばれ、`git remote get-url origin` は呼ばれない

### Requirement: 記録は片付けた子ごとに消し、エピックの完了時にディレクトリごと消す

`reap` は `reaped <N>`（`branch-kept` を含む）と、記録はあるが子のワークツリーがもう無いときの `gone <N>` を出した子の記録を消さなければならない（MUST）。`epic-dispatch.sh clear <epic>` は、エピックの `<owner>/<repo>#<E>` から組み立てたディレクトリ名が `EPIC_STATE_ROOT` 直下にあれば、残っている記録の子を stderr に出してからディレクトリを消し、`cleared <epic>` を出して exit 0、無ければ `none <epic>` を出して exit 0 で終わらなければならない（MUST）。`<epic>` は `^[0-9]+$` でなければならず、エピックの `<owner>/<repo>` は要件「エピックの状態は子ごと 1 ファイルのローカルの記録に置く」のとおり origin から読む（読めなければ何も消さずに exit 1）。組み立てた名前が `/` か `..` を含むとき、`EPIC_STATE_ROOT` が空のとき、`EPIC_STATE_ROOT` を絶対パスにした結果が `/` か `$HOME` そのもののときは、何も消さずに stderr に理由を出して exit 1 で終わる（MUST）。消すのは `EPIC_STATE_ROOT` 直下のその 1 ディレクトリだけで、シンボリックリンクならリンク先をたどらずに exit 1 で終わる（MUST）。

この要件の守備範囲で入力として扱うのは、develop の本体が `references/epic.md` の手順どおりに渡すエピックの番号と、親のワークツリーの origin と `EPIC_STATE_ROOT` の値である。拾いたい誤りは、別のエピックのディレクトリや `EPIC_STATE_ROOT` の外（ホームの全体など）を消すことである。次は通してよく、この要件では止めない: `EPIC_STATE_ROOT` が相対パスであること（開始時の作業ディレクトリを基準に絶対パスにしてから消す）／エピックの番号の取り違えで、同じリポジトリの別のエピックの状態ディレクトリを消すこと（そのエピックの親は再開の手順の `adopt` で Orca の印から記録を組み立て直せる）／ディレクトリの中に記録以外のファイルがあること（一緒に消す）。消す対象の取り違えを見つけるたびに検査を足して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: reap で片付けた子の記録が消える
- **WHEN** 安全確認を全部通る子 12 で `epic-dispatch.sh reap 12` が `reaped 12` を出す
- **THEN** 子 12 の記録のファイルは無い

#### Scenario: clear で状態のディレクトリが消える
- **WHEN** エピック 1122 の状態ディレクトリに記録が 1 件残っている状態で `epic-dispatch.sh clear 1122` を実行する
- **THEN** ディレクトリは無く、stdout は `cleared 1122`、stderr に残っていた子が出て、ほかのエピックのディレクトリは残っている

#### Scenario: 無いディレクトリの clear
- **WHEN** エピック 1122 の状態ディレクトリが無い状態で `epic-dispatch.sh clear 1122` を実行する
- **THEN** stdout は `none 1122`、exit 0 である

#### Scenario: 番号でないエピックと空の置き場では何も消さない
- **WHEN** `epic-dispatch.sh clear ../1122` と、`EPIC_STATE_ROOT=` を空にした `epic-dispatch.sh clear 1122` をそれぞれ実行する
- **THEN** どちらも何も消されず、exit 1 である

#### Scenario: 相対パスの置き場は作業ディレクトリから解決する
- **WHEN** 作業ディレクトリの下に `state/oratta.claude-harness-1122/` がある状態で `EPIC_STATE_ROOT=state epic-dispatch.sh clear 1122` を実行する
- **THEN** `state/oratta.claude-harness-1122/` は無く、stdout は `cleared 1122` である

### Requirement: サブエージェント方式は状態の記録を書かない

サブエージェント方式（本体が W を `isolation: "worktree"` で起こして回す方式）は、状態の記録（`epic-state.sh` の書き込みと `epic-dispatch.sh` の `launch`・`mark`・`adopt`・`clear`）を使ってはならない（MUST NOT）。子の結果は本体が W の return で受ける。理由: W は親のセッションが終わると一緒に消えるので、記録があっても再開に使えず、独立したセッションを見張る目的（記録を読んで止まった子・終わった子を拾う）に当たらない。channel の挙動もこの要件では変えない。

#### Scenario: サブエージェント方式で記録のディレクトリができない
- **WHEN** `route` が `subagent` を返したエピックをサブエージェント方式で回す
- **THEN** `references/epic.md` の手順は `epic-dispatch.sh launch`・`mark`・`adopt` を呼ばず、`${EPIC_STATE_ROOT:-~/.claude/epic-state}` にそのエピックのディレクトリを作らない

