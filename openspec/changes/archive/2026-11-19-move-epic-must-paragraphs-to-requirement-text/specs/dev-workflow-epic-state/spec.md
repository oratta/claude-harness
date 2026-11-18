## MODIFIED Requirements

### Requirement: 子を owner/repo#番号 で識別し、同じリポジトリの子は番号だけで書く

記録・ファイル名・状態ディレクトリ名は、子とエピックを `<owner>/<repo>#<N>` で識別しなければならない（MUST）。`epic-dispatch.sh` の子の引数は、番号だけ（エピックと同じリポジトリの子）か `<owner>/<repo>#<N>` を受け付け、出力は引数で受けた形のまま返さなければならない（MUST）。`<owner>/<repo>#<N>` がエピックと同じリポジトリを指すときは、番号だけと同じ子として扱う（MUST）。エピックへのコメントと完了報告では、エピックと同じリポジトリの子を今のまま `子 #N` と書き、別のリポジトリの子を `子 <owner>/<repo>#N` と書かなければならない（MUST）。

子の引数の形は `^[0-9]+$` か `^[A-Za-z0-9-]+/[A-Za-z0-9._-]+#[0-9]+$` のどちらかでなければならず、それ以外は何も呼ばずに stderr に使い方を出して exit 1 で終わる（MUST）。`<owner>/<repo>` は ASCII の小文字にそろえてから記録の `repo` と比べる（大文字小文字だけが違う `Oratta/Claude-Harness#5` は `oratta/claude-harness#5` と同じ子）。

親の見張り（`wait`・`pending-owner`・`reap`・`notify-closed`・`reply`）は origin を読まずに子の記録を探す（MUST）。番号だけの引数 `<N>` は、`parent_worktree` が今のワークツリーの最上位のパスで、`number` が `<N>` で、`repo` が記録の `epic` のリポジトリの部分と一致する記録に当てる。`<owner>/<repo>#<N>` の引数は、`parent_worktree` が今のワークツリーで `child` が一致する記録に当てる。子 issue を `gh` で読む先は、記録の `repo` が記録の `epic` のリポジトリと同じ子と番号だけで渡した記録の無い子は今のまま `gh api repos/{owner}/{repo}/issues/<N>`（`gh` が今のワークツリーのリポジトリに置き換える）、記録の `repo` が違う子は `gh api repos/<repo>/issues/<N>`、`<owner>/<repo>#<N>` で渡した記録の無い子は引数の `<owner>/<repo>` を小文字にそろえて `gh api repos/<owner>/<repo>/issues/<N>` にしなければならない（MUST。この change では同じリポジトリの子の呼び出しの形を変えない）。

`launch` は、エピックと別のリポジトリの子を受けたら、子のリポジトリのローカル clone にワークツリーを作る（要件「launch は別のリポジトリの子のワークツリーを、子のリポジトリの clone に作る」）。`other-repo` は返さない（MUST NOT）。

この要件の守備範囲で入力として扱うのは、develop の本体が `references/epic-loop.md` と `references/epic-multirepo.md` の手順どおりに渡す子の引数（依存グラフとエピックのコメントから組み立てた番号か `<owner>/<repo>#<N>`）である。拾いたい誤りは、`#12` のように番号に記号が付くこと、`oratta/claude-harness#` や `claude-harness#12` のように owner・repo・番号のどれかが欠けること、引数が空になることである。次は通してよく、この要件では止めない: GitHub に存在しない番号やリポジトリ（`gh` の呼び出しで `error gh` などとして表に出る）／大文字小文字だけが違う owner と repo（同じ子として扱う）／エピックと同じリポジトリを `<owner>/<repo>#<N>` で書いた引数（番号だけと同じ子として扱い、出力は受けた形のまま）。引数の書き間違いの形を見つけるたびに検査を足して塞ぎ切ることは、この要件の完了条件としない。

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
