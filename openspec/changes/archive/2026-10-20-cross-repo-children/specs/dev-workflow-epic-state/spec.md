## MODIFIED Requirements

### Requirement: 子を owner/repo#番号 で識別し、同じリポジトリの子は番号だけで書く

記録・ファイル名・状態ディレクトリ名は、子とエピックを `<owner>/<repo>#<N>` で識別しなければならない（MUST）。`epic-dispatch.sh` の子の引数は、番号だけ（エピックと同じリポジトリの子）か `<owner>/<repo>#<N>` を受け付け、出力は引数で受けた形のまま返さなければならない（MUST）。`<owner>/<repo>#<N>` がエピックと同じリポジトリを指すときは、番号だけと同じ子として扱う（MUST）。エピックへのコメントと完了報告では、エピックと同じリポジトリの子を今のまま `子 #N` と書き、別のリポジトリの子を `子 <owner>/<repo>#N` と書かなければならない（MUST）。

子の引数の形は `^[0-9]+$` か `^[A-Za-z0-9-]+/[A-Za-z0-9._-]+#[0-9]+$` のどちらかでなければならず、それ以外は何も呼ばずに stderr に使い方を出して exit 1 で終わる（MUST）。`<owner>/<repo>` は ASCII の小文字にそろえてから記録の `repo` と比べる（大文字小文字だけが違う `Oratta/Claude-Harness#5` は `oratta/claude-harness#5` と同じ子）。

親の見張り（`wait`・`pending-owner`・`reap`・`notify-closed`・`reply`）は origin を読まずに子の記録を探す（MUST）。番号だけの引数 `<N>` は、`parent_worktree` が今のワークツリーの最上位のパスで、`number` が `<N>` で、`repo` が記録の `epic` のリポジトリの部分と一致する記録に当てる。`<owner>/<repo>#<N>` の引数は、`parent_worktree` が今のワークツリーで `child` が一致する記録に当てる。子 issue を `gh` で読む先は、記録の `repo` が記録の `epic` のリポジトリと同じ子と番号だけで渡した記録の無い子は今のまま `gh api repos/{owner}/{repo}/issues/<N>`（`gh` が今のワークツリーのリポジトリに置き換える）、記録の `repo` が違う子は `gh api repos/<repo>/issues/<N>`、`<owner>/<repo>#<N>` で渡した記録の無い子は引数の `<owner>/<repo>` を小文字にそろえて `gh api repos/<owner>/<repo>/issues/<N>` にしなければならない（MUST。この change では同じリポジトリの子の呼び出しの形を変えない）。

`launch` は、エピックと別のリポジトリの子を受けたら、子のリポジトリのローカル clone にワークツリーを作る（要件「launch は別のリポジトリの子のワークツリーを、子のリポジトリの clone に作る」）。`other-repo` は返さない（MUST NOT）。

この要件の守備範囲で入力として扱うのは、develop の本体が SKILL.md の手順どおりに渡す子の引数（依存グラフとエピックのコメントから組み立てた番号か `<owner>/<repo>#<N>`）である。拾いたい誤りは、`#12` のように番号に記号が付くこと、`oratta/claude-harness#` や `claude-harness#12` のように owner・repo・番号のどれかが欠けること、引数が空になることである。次は通してよく、この要件では止めない: GitHub に存在しない番号やリポジトリ（`gh` の呼び出しで `error gh` などとして表に出る）／大文字小文字だけが違う owner と repo（同じ子として扱う）／エピックと同じリポジトリを `<owner>/<repo>#<N>` で書いた引数（番号だけと同じ子として扱い、出力は受けた形のまま）。引数の書き間違いの形を見つけるたびに検査を足して塞ぎ切ることは、この要件の完了条件としない。

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


### Requirement: 親の見張りは記録だけで子の状態を判定する

`wait`・`pending-owner`・`reap`・`notify-closed`・`reply` は、子の状態（完了の印・止まった印・受けた印）を記録の `status` と `stop` から読まなければならず、Orca のワークツリーの `workspaceStatus` と `comment` を判定に使ってはならない（MUST NOT）。子の記録は、要件「子を owner/repo#番号 で識別し、同じリポジトリの子は番号だけで書く」の親の見張りの照合で探す（MUST）。2 件以上なら、今の「同じ linkedIssue のワークツリーが 2 つ以上」と同じ扱い（`reap` は `kept <N> ambiguous`、`reply` / `notify-closed` は `failed <N> ambiguous-worktree`、`wait` はその子の印を見ない）にする（MUST）。子 issue の state・`state_reason`・コメントを読む先も、同じ要件の `gh` の呼び出しの形に従う（MUST）。

- `wait --watch-done <N>`: 記録の `status` が `done` なら印が付いた子とする
- `wait --watch-stopped`: 閉じていない位置引数の子の記録の `stop` が `stopped` なら、排他を取って `stopped-seen` に書き換え、書けたら止まった子とする。書けなければそのポーリングを失敗したポーリングに数える
- `pending-owner`: 記録の `stop` が `stopped-seen` の子を `pending <N>` で出す
- `notify-closed`: 記録が無ければ `skipped <N> no-worktree`、`status` が `done` なら `skipped <N> already-done`、`stop` が `stopped` / `stopped-seen` でなければ `skipped <N> not-stopped`
- `reap`: 記録が無い子と、記録の `worktree` のディレクトリが無い（`[ -d <worktree> ]` が偽）子は `gone <N>`（後者は記録を消す）。`status` が `done` でなければ `kept <N> not-done`。それ以外の安全確認の中身は今と同じにする。`gh pr list`・`git ls-remote`・`git fetch` などの呼び出しの形は、記録の `repo` が記録の `epic` のリポジトリと同じ子は今と同じにし（MUST）、違う子は次のとおりにする（MUST）。PR の照会に `-R <記録の repo>` を付ける。base の名前は記録の `base` を使う（同じリポジトリの子は今のまま `${EPIC_DISPATCH_BASE:-main}`）。base の照会（`git ls-remote origin refs/heads/<base>`・`git fetch origin <base>`）を子のワークツリーの origin（`git -C <記録の worktree> ...`）に向け、base の先端はリポジトリと base の組ごとに 1 回読む（同じリポジトリの子の照会は今のまま 1 回で、別のリポジトリの子の先端を使い回さない。混ぜて渡した `reap` で同じリポジトリの子が `kept <N> base-lookup-failed` に落ちない）。`git cat-file -e` は `git -C <記録の worktree>` で行う。ブランチの片付け（`git rev-parse refs/heads/<branch>`・`git worktree list --porcelain`・`git branch -D`）は子の clone に向け、`orca worktree rm` の前に `git -C <記録の worktree> rev-parse --path-format=absolute --git-common-dir` で clone を控えておき、rm のあとはそれを `git -C` に使う（rm のあとはワークツリーのディレクトリが無い）。`kept <N> not-child` は出さない
- 出力の行・exit code・失敗したポーリングの数え方・`--resolve` の判断と送り方は、上の読み替えのほかは今の要件のまま

#### Scenario: 記録の done で wait が起きる
- **WHEN** 子 12 の記録の `status` が `done` で、Orca の一覧には印が無い状態で `epic-dispatch.sh wait --interval 0 --timeout 0 --watch-done 12` を実行する
- **THEN** stdout は `done 12`、exit 0 で、`orca worktree list` は呼ばれない

#### Scenario: Orca の印だけでは wait は起きない
- **WHEN** 子 12 の記録の `status` が `running` で、Orca の一覧の `workspaceStatus` が `completed` の状態で `epic-dispatch.sh wait --interval 0 --timeout 0 --watch-done 12` を実行する
- **THEN** stdout は `timeout`、exit 2 である

#### Scenario: 止まった子を受けた印に書き換えて返す
- **WHEN** 子 11 が open で記録の `stop` が `stopped` の状態で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-stopped 11` を実行する
- **THEN** 記録の `stop` が `stopped-seen` になり、stdout は `stopped 11`、exit 0 である

#### Scenario: 受けた止まりでは再び起きない
- **WHEN** 子 11 が open で記録の `stop` が `stopped-seen` の状態で `epic-dispatch.sh wait --interval 0 --timeout 0 --watch-stopped 11` を実行する
- **THEN** stdout は `timeout 11`、exit 2 である

#### Scenario: pending-owner は受けた印の子を出す
- **WHEN** 子 11 の記録の `stop` が `stopped-seen`、子 12 の記録の `stop` が `resumed` の状態で `epic-dispatch.sh pending-owner 11 12` を実行する
- **THEN** stdout は `pending 11` の 1 行、exit 0 である

#### Scenario: 片付け済みの子を reap に渡すと gone
- **WHEN** 子 13 の記録が無い状態で `epic-dispatch.sh reap 13` を実行する
- **THEN** stdout は `gone 13`、exit 0 で、何も消されない

#### Scenario: 別のリポジトリの子の reap は子のリポジトリと子の origin に向ける
- **WHEN** 子 `genetta-inc/flatmate#1615` の記録（`repo` が `genetta-inc/flatmate`、`epic` が `oratta/claude-harness#1122`、`status` が `done`、`worktree` が存在するディレクトリ）があり、子のワークツリーがきれいで HEAD が子のリポジトリのマージ済み PR の `headRefOid` と同じ状態で `epic-dispatch.sh reap genetta-inc/flatmate#1615` を実行する
- **THEN** `gh pr list` は `-R genetta-inc/flatmate` 付きで呼ばれ、`git` は子のワークツリーを `-C` で指し、stdout は `reaped genetta-inc/flatmate#1615` である

#### Scenario: 別のリポジトリの子の base は記録の base を使う
- **WHEN** 子 `genetta-inc/flatmate#1615` の記録の `base` が `develop` で、ほかは直前の Scenario と同じ状態で `epic-dispatch.sh reap genetta-inc/flatmate#1615` を実行する
- **THEN** `git -C <子のワークツリー> ls-remote origin refs/heads/develop` が呼ばれ、`refs/heads/main` は読まれない

#### Scenario: 同じリポジトリの子と混ぜても照会は混ざらない
- **WHEN** 別のリポジトリの子 `genetta-inc/flatmate#1615` と同じリポジトリの子 12（どちらも `done`）を `epic-dispatch.sh reap genetta-inc/flatmate#1615 12` で渡す
- **THEN** 子 12 の base の照会は今と同じ `git ls-remote origin refs/heads/main` で、子 12 が `kept 12 base-lookup-failed` にならず、`git branch -D` は子 `genetta-inc/flatmate#1615` については子の clone（rm の前に控えた git-common-dir）に対して呼ばれる

#### Scenario: 別の親の記録は見ない
- **WHEN** 子 12 の記録の `parent_worktree` が今のワークツリーと違い、`status` が `done` の状態で `epic-dispatch.sh reap 12` を実行する
- **THEN** stdout は `gone 12` で、そのワークツリーは消されない


## ADDED Requirements

### Requirement: launch は別のリポジトリの子のワークツリーを、子のリポジトリの clone に作る

`launch` は、エピックと別のリポジトリの子（`<owner>/<repo>#<N>` で渡され、小文字にそろえた `<owner>/<repo>` がエピックのリポジトリと違う子）について、子のリポジトリのローカル clone を次の順に探し、見つけた clone にワークツリーを作らなければならない（MUST）。各段で、候補ごとに `git -C <候補> remote get-url origin` を読み、要件「エピックの状態は子ごと 1 ファイルのローカルの記録に置く」の 3 つの形で読んだ小文字の `<owner>/<repo>` が子のリポジトリと一致することを確かめ、一致しない候補は無かったことにして次へ進む（MUST）。

1. 環境変数 `EPIC_DISPATCH_CLONES`: `<owner>/<repo>=<絶対パス>` を改行か `;` で区切った値。左辺は小文字にそろえて比べる。値が絶対パスでない項目は無かったことにして stderr に出す
2. 起動部品が知っているリポジトリ: Orca の部品は `orca repo list --json` の各リポジトリの `path`

同じ段に一致する候補が 2 つ以上あれば `failed <child> ambiguous-clone`（stderr に候補のパス）、どの段にも無ければ `failed <child> no-clone` を stdout に出す（MUST）。どちらも exit 1 で、記録を作らず、枠を使わず、`orca worktree create` を呼ばない（MUST）。`no-clone` のときは stderr に `EPIC_DISPATCH_CLONES` の書き方と `git clone` のコマンドを出す（MUST）。自動で clone してはならない（MUST NOT。clone の置き場はオーナーのディスクの構成で決まる）。段をまたいで一致する候補があるときは先の段を取る（`EPIC_DISPATCH_CLONES` の指定が Orca の登録より優先）。

Orca の部品は、見つけた clone のパスに当たるリポジトリを `orca repo list --json` から引いて `repoId` と `--repo` に渡す selector を決める（MUST）。実機（Orca 1.4.232）で確かめた形: `orca repo list --json` は `.result.repos[]` の配列で、各要素の項目は `id`（リポジトリの識別子。`orca worktree list --json` の各ワークツリーの `repoId` と同じ値）と `path`（clone の絶対パス）で、`repoId` という項目名は無い。`--repo` の selector は `id:<id>`（`name:<name>` と `path:<path>` も受ける）で、`launch` は `id:<id>` を使う。clone のパスと一致する `path` を持つ要素の `id` が `repoId` になる。当たらなければ、記録を書く前に `failed <child> not-in-orca` を stdout に出し（exit 1。記録も枠も使わない）、stderr に `orca repo add` の案内を出す（MUST。`launch` が Orca にリポジトリを追加してはならない）。`orca worktree create` の失敗は、原因を問わず `failed <child>` とし、記録を消す。

`launch` は、別のリポジトリの子の記録を `repo` に子のリポジトリ、`child` に `<owner>/<repo>#<N>`、`number` に子の番号、`base` に起点（要件「別のリポジトリの子の起点は --base か子のリポジトリの既定ブランチ」）、`parent_worktree` に今のワークツリー、`launcher` に `orca` で作り、`worktree` に子のワークツリーのパスを書く。記録の置き場は要件「エピックの状態は子ごと 1 ファイルのローカルの記録に置く」のとおり、エピックのディレクトリの下の `<子の owner>.<子の repo>-<子の番号>.json`（MUST）。`orca worktree create` は `--repo <子の clone を指す selector>` を付け、`--parent-worktree path:<今のワークツリー>`・`--issue <N>`・`--base-branch origin/<base>` を付ける。

別のリポジトリの子の判定の順序は、記録の読み取り（記録があって `worktree` が空でなければ `skipped`、読めなければ `failed <child> state-unreadable`。ここまでは clone を探さない）→ clone の探索 → Orca のリポジトリの引き当て（`not-in-orca`）→ 書き込み権と既定ブランチ（要件「別のリポジトリの子の書き込み権は作る前に読む」。1 回の `gh api repos/<o>/<r>` の応答から読む）→ 子のリポジトリの `repoId` の Orca の一覧に同じ issue のワークツリーがあれば `skipped` → 空き枠の判定（`deferred <child>`）→ 記録を書く → `git -C <clone> fetch origin <base>` → `orca worktree create`、とする（MUST）。`git -C <clone> fetch origin <base>` が失敗したら、記録を消して `failed <child>` とし、`orca worktree create` を呼ばない。`worktree` が空のまま残った自分の記録は、clone の探索と書き込み権を通したあと、既存の要件どおりに子のリポジトリの `repoId` の Orca の一覧で埋めるか上書きして作成に進み、その記録の 1 枠を使う（枠を増やさない）。別のリポジトリの子も枠を 1 つ使い、同じ上限（`EPIC_DISPATCH_MAX_PARALLEL`・`deferred`）の中で数える（MUST。要件「同時に枠を使う子は記録から数える」の数え方は変えない）。1 回の `launch` の中で、同じリポジトリの clone の探索・書き込み権・既定ブランチの照会は 1 回にまとめる。親のワークツリーへのエピックの紐づけ（`orca worktree set --worktree path:<親> --issue <エピック>`）は、子が全部別のリポジトリでも `launch` の最初に 1 回行う（今のまま）。親の clone の `git fetch origin <base>` は、同じリポジトリの子が 1 件以上あるときだけ行う（MUST。別のリポジトリの子だけに `--base develop` を付けて呼んだとき、親のリポジトリに `develop` が無くても `launch` 全体が失敗しないため）。

この要件の守備範囲で入力として扱うのは、`EPIC_DISPATCH_CLONES` の値、各候補の clone の origin の URL、`orca repo list --json` の出力である。拾いたい誤りは、`EPIC_DISPATCH_CLONES` の誤ったパスや Orca に登録された別のリポジトリの clone に、子のワークツリーを作ってしまうことである。次は通してよく、この要件では止めない: origin が子のリポジトリの fork を指す clone（origin が `<owner>/<repo>` と一致しなければ無かったことになる。fork から PR を出す経路は作らない）／`EPIC_DISPATCH_CLONES` の書式の揺れ（空白を足す・末尾に `;`）の許容／clone が最新でないこと（`fetch` で起点を取るため）。受け付ける書式の揺れを見つけるたびに塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: EPIC_DISPATCH_CLONES の clone にワークツリーができる
- **WHEN** origin が `oratta/claude-harness` の親のワークツリーで、`EPIC_DISPATCH_CLONES` が `genetta-inc/flatmate=<clone のパス>`（その clone の origin は `git@github.com:genetta-inc/flatmate.git`）で、子 1615 の書き込み権があり、`epic-dispatch.sh launch 1122 genetta-inc/flatmate#1615` を実行する
- **THEN** `orca worktree create` は `--repo` にその clone を指す selector を付けて呼ばれ、`$EPIC_STATE_ROOT/oratta.claude-harness-1122/genetta-inc.flatmate-1615.json` が作られ（`repo` が `genetta-inc/flatmate`、`child` が `genetta-inc/flatmate#1615`、`worktree` が作ったパス）、stdout は `launched genetta-inc/flatmate#1615` である

#### Scenario: Orca に登録された clone も見つける
- **WHEN** `EPIC_DISPATCH_CLONES` が空で、`orca repo list --json` に origin が `genetta-inc/flatmate` を指すリポジトリが 1 つある状態で `epic-dispatch.sh launch 1122 genetta-inc/flatmate#1615` を実行する
- **THEN** `orca worktree create` はそのリポジトリを `--repo` に付けて呼ばれる

#### Scenario: clone が見つからなければ自動で clone せず止まる
- **WHEN** `EPIC_DISPATCH_CLONES` が空で、`orca repo list --json` に子のリポジトリを指すものが無い状態で `epic-dispatch.sh launch 1122 genetta-inc/flatmate#1615` を実行する
- **THEN** stdout は `failed genetta-inc/flatmate#1615 no-clone`、exit 1 で、`git clone` も `orca worktree create` も呼ばれず、記録は作られず、枠も使われず、stderr に `EPIC_DISPATCH_CLONES` の書き方が出る

#### Scenario: origin が子のリポジトリでない候補は使わない
- **WHEN** `EPIC_DISPATCH_CLONES` の `genetta-inc/flatmate` の clone の origin が `git@github.com:oratta/claude-harness.git` を指す状態で `epic-dispatch.sh launch 1122 genetta-inc/flatmate#1615` を実行する
- **THEN** その clone は使われず、ほかに候補が無ければ stdout は `failed genetta-inc/flatmate#1615 no-clone` である

#### Scenario: 同じ段に候補が 2 つあれば ambiguous-clone
- **WHEN** `orca repo list --json` に origin が `genetta-inc/flatmate` を指すリポジトリが 2 つある状態で、`EPIC_DISPATCH_CLONES` が空のまま `epic-dispatch.sh launch 1122 genetta-inc/flatmate#1615` を実行する
- **THEN** stdout は `failed genetta-inc/flatmate#1615 ambiguous-clone`、exit 1 で、`orca worktree create` は呼ばれず、記録は作られない

#### Scenario: 起動済みの子は clone を探さずに skipped
- **WHEN** `genetta-inc/flatmate#1615` の記録があり `worktree` が空でなく、`EPIC_DISPATCH_CLONES` が空で Orca にも clone が無い状態で `epic-dispatch.sh launch 1122 genetta-inc/flatmate#1615` を実行する
- **THEN** stdout は `skipped genetta-inc/flatmate#1615` で、`orca repo list` も `gh api repos/genetta-inc/flatmate` も呼ばれない

#### Scenario: 別のリポジトリの子も同じ上限で deferred になる
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=1` で、枠を使っている子の記録が 1 件あり、clone と書き込み権のある別のリポジトリの子 `genetta-inc/flatmate#1615` を `epic-dispatch.sh launch 1122 genetta-inc/flatmate#1615` で渡す
- **THEN** stdout は `deferred genetta-inc/flatmate#1615` で、記録は作られず、`orca worktree create` は呼ばれない

#### Scenario: Orca に登録されていない clone は作る前に止まる
- **WHEN** `EPIC_DISPATCH_CLONES` の clone のパスが `orca repo list --json` のどのリポジトリにも当たらない状態で `epic-dispatch.sh launch 1122 genetta-inc/flatmate#1615` を実行する
- **THEN** stdout は `failed genetta-inc/flatmate#1615 not-in-orca`、exit 1 で、`orca worktree create` は呼ばれず、記録は作られず、枠は使われず、stderr に `orca repo add` の案内が出る

#### Scenario: 起点の fetch が失敗したら記録を消す
- **WHEN** `git -C <clone> fetch origin <base>` が非 0 で終わる状態で `epic-dispatch.sh launch 1122 genetta-inc/flatmate#1615` を実行する
- **THEN** stdout は `failed genetta-inc/flatmate#1615`、記録は残らず、`orca worktree create` は呼ばれない

#### Scenario: 別のリポジトリの子だけなら親の clone を fetch しない
- **WHEN** 子が `genetta-inc/flatmate#1615` だけで `--base develop` を付け、親のリポジトリに `develop` が無い状態で `epic-dispatch.sh launch --base develop 1122 genetta-inc/flatmate#1615` を実行する
- **THEN** 親の clone の `git fetch origin develop` は呼ばれず、`orca worktree set --worktree path:<親> --issue 1122` は呼ばれる

#### Scenario: worktree が空の記録は上書きして作成に進み、枠を増やさない
- **WHEN** `genetta-inc/flatmate#1615` の記録の `worktree` が空で、子のリポジトリの Orca の一覧に同じ issue のワークツリーが無い状態で `epic-dispatch.sh launch 1122 genetta-inc/flatmate#1615` を実行する
- **THEN** 記録は上書きされて `orca worktree create` が呼ばれ、枠を使っている子の数はその記録の分の 1 のまま増えない

### Requirement: 別のリポジトリの子の書き込み権は作る前に読む

`launch` は、別のリポジトリの子について、ワークツリーを作る前（clone の探索と Orca のリポジトリの引き当てのあと、空き枠の判定と記録を書くより前）に `gh api repos/<o>/<r>` の応答から `.permissions.push` と `.default_branch` を 1 回で読まなければならない（MUST。要件「別のリポジトリの子の起点は --base か子のリポジトリの既定ブランチ」）。1 回の応答の判定は次の順に 1 本だけ行い、最初に当たったものを stdout に出す（MUST）。(1) `gh` が失敗した、または応答に `permissions` が無い → `failed <child> permission-lookup-failed`。(2) `.permissions.push` が `true` でない → `failed <child> no-push`。(3) (1)(2) を通ったあとで `.default_branch` が空 → `failed <child> base-lookup-failed`（`--base` / `EPIC_DISPATCH_BASE` があっても止める）。どれも exit 1 で、記録を作らず、枠を使わず、`orca worktree create` を呼ばず、stderr に `gh` の認証アカウントと子のリポジトリを出す。fork から PR を出す経路を作ってはならない（MUST NOT）。エピックと同じリポジトリの子にはこの読み出しをしない（呼び出しの形を変えない）。

この要件の守備範囲で入力として扱うのは、`gh api repos/<o>/<r>` の応答の `permissions.push` である。拾いたい誤りは、書き込み権の無いリポジトリにワークツリーと記録を作り、子が PR を出せずに止まることである。次は通してよく、この要件では止めない: `permissions.push` が `true` でもブランチ保護で push が拒まれること（子の側で表に出る）／リポジトリのチーム設定の細かい差。ほかの通り方を見つけるたびに検査を足して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: push 権が無ければ作らない
- **WHEN** `gh api repos/genetta-inc/flatmate` の応答の `permissions.push` が `false` の状態で `epic-dispatch.sh launch 1122 genetta-inc/flatmate#1615` を実行する
- **THEN** stdout は `failed genetta-inc/flatmate#1615 no-push`、exit 1 で、記録は作られず、`orca worktree create` は呼ばれず、枠は使われない

#### Scenario: 権限を読めなければ作らない
- **WHEN** `gh api repos/genetta-inc/flatmate` が失敗する状態で `epic-dispatch.sh launch 1122 genetta-inc/flatmate#1615` を実行する
- **THEN** stdout は `failed genetta-inc/flatmate#1615 permission-lookup-failed`、exit 1 で、記録は作られない

#### Scenario: 同じリポジトリの子は書き込み権を読まない
- **WHEN** `epic-dispatch.sh launch 1122 11`（子 11 がエピックと同じリポジトリ）を実行する
- **THEN** `gh api repos/<o>/<r>`（後ろに `/issues` などのパスが続かない形）の呼び出しは無い

### Requirement: 別のリポジトリの子の起点は --base か子のリポジトリの既定ブランチ

`launch` は、別のリポジトリの子のワークツリーの起点を、`--base` か環境変数 `EPIC_DISPATCH_BASE` があればそれ、無ければ子のリポジトリの既定ブランチ（書き込み権と同じ `gh api repos/<o>/<r>` の応答の `.default_branch`。空き枠の判定より前に読む）にしなければならない（MUST）。既定ブランチを読めなければ `failed <child> base-lookup-failed` とし、記録も枠も使わない（MUST。応答の判定順は要件「別のリポジトリの子の書き込み権は作る前に読む」の (1)〜(3) に従い、`gh` の失敗は `permission-lookup-failed` が先に当たる）。エピックと同じリポジトリの子は今までどおり、無ければ `main` とする（MUST。呼び出しの形を変えない）。`--base` と `EPIC_DISPATCH_BASE` は 1 回の `launch` の全部の子に掛かる。起点は記録の `base` に書く。

#### Scenario: 起点の指定が無ければ子のリポジトリの既定ブランチ
- **WHEN** `--base` も `EPIC_DISPATCH_BASE` も無く、`gh api repos/genetta-inc/flatmate` の応答の `default_branch` が `develop` の状態で `epic-dispatch.sh launch 1122 genetta-inc/flatmate#1615` を実行する
- **THEN** `git -C <clone> fetch origin develop` が呼ばれ、`orca worktree create` の `--base-branch` は `origin/develop` で、記録の `base` は `develop` である

#### Scenario: 既定ブランチを読めなければ枠を使わず止まる
- **WHEN** `gh api repos/genetta-inc/flatmate` の応答の `permissions.push` が `true` で `default_branch` が無い状態で `epic-dispatch.sh launch 1122 genetta-inc/flatmate#1615` を実行する
- **THEN** stdout は `failed genetta-inc/flatmate#1615 base-lookup-failed`、exit 1 で、記録は作られず、枠は使われない

#### Scenario: --base があればそれを使う
- **WHEN** `gh api repos/genetta-inc/flatmate` の応答の `permissions.push` が `true` で `default_branch` が `develop` の状態で、`--base staging` を付けて `epic-dispatch.sh launch --base staging 1122 genetta-inc/flatmate#1615` を実行する
- **THEN** `--base-branch` は `origin/staging` である（書き込み権の応答は読むが、既定ブランチは使われない）

### Requirement: 別のリポジトリの子の起動の指示・環境変数・注意書き・返事の頭にはエピックのリポジトリを足す

`launch` は、記録の `repo` が記録の `epic` のリポジトリと違う子について、次の形にしなければならない（MUST）。エピックと同じリポジトリの子は今のまま変えない（MUST）。

- 子の最初の入力: `/develop #<N> （エピック #<E> の子。エピックのリポジトリ <エピックの owner>/<repo>。親ワークツリー <親> から Orca で起動）`。`<N>` は子のリポジトリの番号で、先頭の `#<N> （エピック #<E> の子。` は同じリポジトリの子と同じ形のままにする（MUST。`owner-reply-check.sh` の `DISPATCH_ARGS` が、親の打ち込みを主の発言から外す判定にこの先頭の形を使うため。リポジトリは後ろに置く）
- 子の起動コマンドの前置き: `EPIC_DISPATCH_PARENT_EPIC=<エピックの owner>/<repo>#<E>`（同じリポジトリの子は `<E>` だけ）。この前置きは `launch` だけでなく、子の端末を作るすべての経路（`reply`・`notify-closed`・`wait --resolve` の起動し直し）に付ける（MUST）。値は子の記録の `epic` と `repo` から決める（記録の `repo` がエピックのリポジトリと違えば `<owner>/<repo>#<E>`、同じなら `<E>`）。付けないと起動し直した子の `route` が `parent epic: #<E>` を出し、子が無関係の issue にコメントしてしまう
- 起動し直しの指示（`reply` の `--relaunch` と端末が 0 個のときの起動し直し、`notify-closed --relaunch`、`wait --resolve` の起動し直し）: 最初の入力と同じく先頭を `/develop #<N> （エピック #<E> の子。` にし、別のリポジトリの子では `エピックのリポジトリ <owner>/<repo>。` を続ける。`<N>` は子の番号だけで書く（`child_label` の `<o>/<r>#<N>` は使わない。`DISPATCH_ARGS` の `#\d+` に当たらないため）
- `--note` の注意書き: 子 issue（子のリポジトリ）に `gh issue comment <N> -R <子のリポジトリ> --body '親エピックからの注意書き: <エピックの owner>/<repo>#<E>\n\n<注意書き>'` で残す。失敗時の投稿し直しのコマンドも `-R` を含む。先頭の `親エピックからの注意書き:` は同じ

`reply`（`--as parent` / `--as owner`）と `notify-closed` と `wait --resolve` が子に送る返事の頭は、別のリポジトリの子では `親エピック #<E>（<エピックの owner>/<repo>）の判断（主の承認ではない）: ` と `主の返事（親エピック #<E>（<エピックの owner>/<repo>）経由）: ` にする（MUST。先頭の `親エピック #` / `主の返事（親エピック #` は変えない）。エピックへのコメント（`親の判断: 子 <o>/<r>#N 通した — ...` など）の子の呼び方は、要件「子を owner/repo#番号 で識別し、同じリポジトリの子は番号だけで書く」のとおり。

#### Scenario: 別のリポジトリの子の起動コマンドと指示
- **WHEN** origin が `oratta/claude-harness` の親のワークツリーで `epic-dispatch.sh launch 1122 genetta-inc/flatmate#1615` が成功する
- **THEN** 子の端末のコマンドは `EPIC_DISPATCH_PARENT_EPIC=oratta/claude-harness#1122 ` で始まり、最初の入力は `/develop #1615 （エピック #1122 の子。エピックのリポジトリ oratta/claude-harness。` で始まる

#### Scenario: 起動し直した別のリポジトリの子にもエピックのリポジトリを渡す
- **WHEN** 子 `genetta-inc/flatmate#1615` の記録（`epic` が `oratta/claude-harness#1122`、`repo` が `genetta-inc/flatmate`）がある状態で `epic-dispatch.sh reply --relaunch --as parent 1122 genetta-inc/flatmate#1615 続けてよい` を実行する
- **THEN** `orca terminal create --command` は `EPIC_DISPATCH_PARENT_EPIC=oratta/claude-harness#1122 ` で始まり、送る指示は `/develop #1615 （エピック #1122 の子。エピックのリポジトリ oratta/claude-harness。` で始まる

#### Scenario: 別のリポジトリの子の起動の指示は主の発言として数えられない
- **WHEN** 別のリポジトリの子の `launch` の指示と起動し直しの指示が `<command-args>` に入ったセッションの記録を `owner-reply-check.sh` に渡す
- **THEN** どちらも主の発言として数えられない（`owner-reply-check.bats` で確かめる）

#### Scenario: 別のリポジトリの子の注意書きは子のリポジトリに投稿する
- **WHEN** `--note 範囲を守る` を付けて同じ `launch` が成功する
- **THEN** `gh issue comment 1615 -R genetta-inc/flatmate --body` が呼ばれ、本文は `親エピックからの注意書き: oratta/claude-harness#1122` で始まる

#### Scenario: 別のリポジトリの子への返事の頭
- **WHEN** 子 `genetta-inc/flatmate#1615` の記録があり、`epic-dispatch.sh reply --as parent 1122 genetta-inc/flatmate#1615 続けてよい` が子の端末に届ける
- **THEN** 送る文は `親エピック #1122（oratta/claude-harness）の判断（主の承認ではない）: 続けてよい` である

#### Scenario: 同じリポジトリの子の書式は変わらない
- **WHEN** `epic-dispatch.sh launch --note 範囲を守る 1122 11`（子 11 がエピックと同じリポジトリ）を実行する
- **THEN** 起動コマンドは `EPIC_DISPATCH_PARENT_EPIC=1122 ` で始まり、最初の入力は `/develop #11 （エピック #1122 の子。` で始まり、注意書きは `gh issue comment 11 --body` で `親エピックからの注意書き: #1122` で始まる
