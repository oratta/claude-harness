## ADDED Requirements

### Requirement: エピックの状態は子ごと 1 ファイルのローカルの記録に置く

エピックの子の状態の正本は、`${EPIC_STATE_ROOT:-$HOME/.claude/epic-state}/<エピックの owner>.<エピックの repo>-<エピック番号>/<子の owner>.<子の repo>-<子の番号>.json` に子ごと 1 ファイルで置かなければならない（MUST）。`EPIC_STATE_ROOT` が相対パスなら、各サブコマンドの開始時の作業ディレクトリを基準に絶対パスにしてから使う。記録を `~/.claude/projects/` の配下に置いてはならない（MUST NOT）。記録は PC をまたいで共有しない。

エピックの `<owner>/<repo>` は、記録を新しく作るか消すサブコマンド（`launch`・`adopt`・`clear`）だけが、親のワークツリーの `git remote get-url origin` から読む（MUST）。受け付ける形は、ホストが `github.com` の `git@github.com:<o>/<r>`・`ssh://git@github.com/<o>/<r>`・`https://github.com/<o>/<r>` の 3 つで、どれも末尾の `.git` と `/` は有っても無くてもよい。`<o>` と `<r>` は ASCII の小文字にそろえて記録とファイル名に使う（GitHub は owner と repo の大文字小文字を区別しないため）。origin が無い・この 3 つの形でない・ホストが `github.com` でないときは、記録を書かず何も消さずに、stderr に `cannot read the epic repository from origin: <URL か「no origin」>` を出して exit 1 で終わる（MUST）。親の見張り（`wait`・`pending-owner`・`reap`・`notify-closed`・`reply`）と子の側（`mark`・`route`）は origin を読まず、記録の中の `epic`・`repo` を使う。

この要件の守備範囲で入力として扱うのは、親のワークツリーの origin の URL（ハーネスの作業 repo は GitHub の clone）と `EPIC_STATE_ROOT` の値である。拾いたい誤りは、origin を読み違えて別のエピックのディレクトリに記録を書くことと、GitHub 以外のリポジトリで記録を作ってしまうことである。次は通してよく、この要件では止めない: owner や repo が GitHub に実在しないこと（`gh` の呼び出しで別に失敗する）／origin が fork を指していること／`EPIC_STATE_ROOT` が書き込めない場所であること（書き込みの失敗として表に出る）。URL の形の揺れを見つけるたびに受け付ける形を足して塞ぎ切ることは、この要件の完了条件としない。

`plugins/dev-workflow/tests/epic-dispatch.bats` は `EPIC_STATE_ROOT` を一時ディレクトリに向け、実在のホームの下に書かずに下の Scenario を確かめなければならない（MUST）。

#### Scenario: launch が記録を決まった場所に作る
- **WHEN** origin が `git@github.com:oratta/claude-harness.git` の親のワークツリーで `epic-dispatch.sh launch 1122 1123` を実行し、子のワークツリーができる
- **THEN** `$EPIC_STATE_ROOT/oratta.claude-harness-1122/oratta.claude-harness-1123.json` があり、`~/.claude/projects/` の下には何も書かれていない

#### Scenario: origin を読めなければ記録を書かない
- **WHEN** origin の無いリポジトリで `epic-dispatch.sh launch 1122 1123` を実行する
- **THEN** 記録は作られず、子のワークツリーも作られず、exit 1 である

#### Scenario: origin の 3 つの形を同じエピックとして読む
- **WHEN** origin が `ssh://git@github.com/Oratta/claude-harness`・`git@github.com:oratta/claude-harness`・`https://github.com/oratta/claude-harness.git/` のそれぞれで `epic-dispatch.sh launch 1122 1123` を実行する
- **THEN** どれも記録は `$EPIC_STATE_ROOT/oratta.claude-harness-1122/oratta.claude-harness-1123.json` に作られる

#### Scenario: GitHub 以外の origin は落とす
- **WHEN** origin が `git@gitlab.com:oratta/claude-harness.git` のリポジトリで `epic-dispatch.sh launch 1122 1123` を実行する
- **THEN** 記録もワークツリーも作られず、stderr に `cannot read the epic repository from origin` と URL が出て、exit 1 である

### Requirement: 子 1 ファイルの記録は決まった項目を持つ

子 1 ファイルの記録は JSON のオブジェクト 1 つで、次の項目を持たなければならない（MUST）。読み手は知らない項目を無視しなければならない（MUST）。

| 項目 | 型 | 中身 |
|---|---|---|
| `schema` | 数 | 書式の版。`1` |
| `epic` | 文字列 | `<owner>/<repo>#<エピック番号>` |
| `child` | 文字列 | `<owner>/<repo>#<子の番号>` |
| `repo` | 文字列 | 子のリポジトリ `<owner>/<repo>` |
| `number` | 数 | 子の issue 番号 |
| `launcher` | 文字列 | 子を起動した起動部品（この版では `orca`） |
| `parent_worktree` | 文字列 | 親のワークツリーの絶対パス |
| `worktree` | 文字列 | 子のワークツリーの絶対パス（作る前は空） |
| `branch` | 文字列 | 子のワークツリーのブランチ名（`refs/heads/` を除く。読めなければ空） |
| `base` | 文字列 | 子のワークツリーの起点ブランチ |
| `session` | 文字列 | 起動部品が子のセッションに届く手がかり（Orca は端末のハンドル。無ければ空） |
| `launch_failed` | 文字列 | ワークツリーを作ったあとで `launch` が失敗した段（成功なら空） |
| `status` | 文字列 | `running`・`waiting`・`done` のどれか |
| `stop` | 文字列 | 空・`stopped`・`stopped-seen`・`resumed` のどれか |
| `created_at` / `updated_at` | 文字列 | UTC の `YYYY-MM-DDTHH:MM:SSZ` |

`status` は今のボードの列（`running` は印なし、`waiting` は `in-review`、`done` は `completed`）に、`stop` は今のコメント欄（`stopped` は `epic-stopped`、`stopped-seen` は `epic-stopped-seen`、`resumed` は `epic-resumed`）に当たり、値の遷移は今の印と同じにしなければならない（MUST）。止まった理由の本文は記録に持たず、子 issue の `子の停止: 主の返事待ち` のコメントを正本のままにする。`session` はこの版では Orca の `launch` が端末のハンドルを書き、`adopt` は空のまま書く（見張りの判定には使わない）。

次のどれかに当たる記録は「読めない記録」とする: JSON のオブジェクトとして読めない／`schema` が `1` でない／`status` か `stop` が上の表に無い値／`epic`・`child`・`repo`・`number`・`parent_worktree`・`worktree` のどれかが無いか型が違う。読めない記録は書き換えも削除もしてはならず（MUST NOT）、サブコマンドごとに次のとおり扱わなければならない（MUST）。どの場合も stderr にその記録のパスを出す。

| サブコマンド | 読めない記録の扱い |
|---|---|
| `wait` | その子の印を読めなかったポーリングとして、今の「一覧を読めない」と同じく失敗したポーリングに数える（3 回続けば `gh` で失敗した子がいなければ `error workspaces`） |
| `reap` | `kept <N> state-unreadable`（何も消さない） |
| `pending-owner` | その子を飛ばす（`pending` を出さない） |
| `notify-closed`・`reply` | `failed <N> state-unreadable` |
| `launch` | その子自身の記録なら `failed <N> state-unreadable`（作り直さない）。枠の数では、ほかの子の読めない記録を使用中の 1 枠に数える |
| `adopt` | `failed <N> state-unreadable` |
| `mark`・`route`（今のワークツリーのパスで探すとき） | その記録を候補から外す |

この要件の守備範囲で入力として扱うのは、`launch`・`adopt`・`mark`・`wait` 自身が書いた記録のファイルで、人が手で書く想定はしない。拾いたい誤りは、書き込みの途中で殺されたプロセスや版の違うスクリプトが残した記録を、正しい状態として読んで子を片付けたり見張りから落としたりすることである。次は通してよく、この要件では止めない: 項目の値どうしの矛盾（`child` の番号と `number` が違う・`worktree` が別のリポジトリを指す）／`created_at` と `updated_at` の形の崩れ／`mark`・`route` が読めない記録を候補から外したために、その子が自分を `no-workspace` と判定すること（一時ファイルからの置き換えで途中まで書かれた記録は生じないので、起きるのは人が手で壊したときだけ）。壊れ方を見つけるたびに検査を足して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 壊れた記録の子は reap で残す
- **WHEN** 子 12 の記録の中身が `{` だけの状態で `epic-dispatch.sh reap 12` を実行する
- **THEN** stdout は `kept 12 state-unreadable` で、記録もワークツリーも消されず、stderr に記録のパスが出る

#### Scenario: 読めない記録が続くと wait は error workspaces
- **WHEN** 子 11 が open で、記録の `stop` が `paused`（表に無い値）の状態で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-stopped 11` を実行する
- **THEN** 3 回のポーリングのあと stdout は `error workspaces` の 1 行で exit 1、記録は変わらない

#### Scenario: 起動した子の記録の項目
- **WHEN** `epic-dispatch.sh launch 1122 1123` が `launched 1123` を返す
- **THEN** 記録の `schema` は 1、`epic` は `oratta/claude-harness#1122`、`child` は `oratta/claude-harness#1123`、`repo` は `oratta/claude-harness`、`number` は 1123、`launcher` は `orca`、`worktree` は子のワークツリーのパス、`status` は `running`、`stop` は空、`launch_failed` は空で、`created_at` と `updated_at` が UTC の形である

#### Scenario: 知らない項目があっても読める
- **WHEN** 記録に `extra: 1` の項目を足してから `epic-dispatch.sh mark done 1123` を子のワークツリーで実行する
- **THEN** `status` が `done` になり、`extra` は残っている

### Requirement: 記録は一時ファイルから置き換え、親と子の書き込みを排他する

記録を書くときは、同じディレクトリの一時ファイルに書いてから `mv` で置き換えなければならない（MUST）。記録を読んで書き換えるときは、読む前から書き終えるまで `mkdir <記録のパス>.lock` の排他を取り、書き終えたら外さなければならない（MUST）。排他が取れなければ 0.2 秒ごとに `EPIC_STATE_LOCK_TIMEOUT`（秒・既定 10。空か数字でなければ使い方を出して exit 1）まで取り直し、取れなければ書かずに失敗として返さなければならない（MUST）。残ったロックを自動で消してはならない（MUST NOT）。失敗したときは stderr にロックのパスと、子も親も動いていないことを確かめてから `rmdir` で外すことを出す。

#### Scenario: 残ったロックがあると mark は書かずに failed
- **WHEN** 子の記録の `.lock` ディレクトリを先に作り、`EPIC_STATE_LOCK_TIMEOUT=0` で `epic-dispatch.sh mark stopped 1123` を実行する
- **THEN** 記録の `stop` は変わらず、stdout は `failed 1123`、exit 1 で、stderr にロックのパスが出て、`.lock` は残っている

#### Scenario: 書き込みの途中のファイルを読み手が見ない
- **WHEN** `mark done` が記録を書く
- **THEN** 書き込みは同じディレクトリの一時ファイルへの書き込みと `mv` で行われ、終わったあとに一時ファイルは残っていない

### Requirement: 子を owner/repo#番号 で識別し、同じリポジトリの子は番号だけで書く

記録・ファイル名・状態ディレクトリ名は、子とエピックを `<owner>/<repo>#<N>` で識別しなければならない（MUST）。`epic-dispatch.sh` の子の引数は、番号だけ（エピックと同じリポジトリの子）か `<owner>/<repo>#<N>` を受け付け、出力は引数で受けた形のまま返さなければならない（MUST）。`<owner>/<repo>#<N>` がエピックと同じリポジトリを指すときは、番号だけと同じ子として扱う（MUST）。エピックへのコメントと完了報告では、エピックと同じリポジトリの子を今のまま `子 #N` と書き、別のリポジトリの子を `子 <owner>/<repo>#N` と書かなければならない（MUST）。

子の引数の形は `^[0-9]+$` か `^[A-Za-z0-9-]+/[A-Za-z0-9._-]+#[0-9]+$` のどちらかでなければならず、それ以外は何も呼ばずに stderr に使い方を出して exit 1 で終わる（MUST）。`<owner>/<repo>` は ASCII の小文字にそろえてから記録の `repo` と比べる（大文字小文字だけが違う `Oratta/Claude-Harness#5` は `oratta/claude-harness#5` と同じ子）。

親の見張り（`wait`・`pending-owner`・`reap`・`notify-closed`・`reply`）は origin を読まずに子の記録を探す（MUST）。番号だけの引数 `<N>` は、`parent_worktree` が今のワークツリーの最上位のパスで、`number` が `<N>` で、`repo` が記録の `epic` のリポジトリの部分と一致する記録に当てる。`<owner>/<repo>#<N>` の引数は、`parent_worktree` が今のワークツリーで `child` が一致する記録に当てる。子 issue を `gh` で読む先は、記録の `repo` が記録の `epic` のリポジトリと同じ子と記録の無い子は今のまま `gh api repos/{owner}/{repo}/issues/<N>`（`gh` が今のワークツリーのリポジトリに置き換える）、違う子は `gh api repos/<repo>/issues/<N>` にしなければならない（MUST。この change では同じリポジトリの子の呼び出しの形を変えない）。

この change の `launch` は、エピックと別のリポジトリの子を受けたら、記録もワークツリーも作らず、枠も使わずに `failed <owner>/<repo>#<N> other-repo` を出さなければならない（MUST）（別のリポジトリにワークツリーを作るのは後続の change）。

この要件の守備範囲で入力として扱うのは、develop の本体が SKILL.md の手順どおりに渡す子の引数（依存グラフとエピックのコメントから組み立てた番号か `<owner>/<repo>#<N>`）である。拾いたい誤りは、`#12` のように番号に記号が付くこと、`oratta/claude-harness#` や `claude-harness#12` のように owner・repo・番号のどれかが欠けること、引数が空になることである。次は通してよく、この要件では止めない: GitHub に存在しない番号やリポジトリ（`gh` の呼び出しで `error gh` などとして表に出る）／大文字小文字だけが違う owner と repo（同じ子として扱う）／エピックと同じリポジトリを `<owner>/<repo>#<N>` で書いた引数（番号だけと同じ子として扱い、出力は受けた形のまま）。引数の書き間違いの形を見つけるたびに検査を足して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 同じリポジトリの子の出力は今と同じ
- **WHEN** 子 11 が閉じている状態で `epic-dispatch.sh wait --interval 0 --timeout 0 11` を実行する
- **THEN** stdout は `closed 11` である

#### Scenario: owner/repo#番号 で渡した子はその形で返る
- **WHEN** エピックと別のリポジトリ `genetta-inc/flatmate` の子 1615 の記録があり、その issue が閉じている状態で `epic-dispatch.sh wait --interval 0 --timeout 0 genetta-inc/flatmate#1615` を実行する
- **THEN** `gh` は `repos/genetta-inc/flatmate/issues/1615` を読み、stdout は `closed genetta-inc/flatmate#1615` である

#### Scenario: launch は別のリポジトリの子を作らない
- **WHEN** origin が `oratta/claude-harness` の親のワークツリーで `epic-dispatch.sh launch 1122 genetta-inc/flatmate#1615` を実行する
- **THEN** stdout は `failed genetta-inc/flatmate#1615 other-repo` で、`orca worktree create` は呼ばれず、記録は作られず、exit 1 である

#### Scenario: 番号でも owner/repo#番号 でもない引数は使い方を出す
- **WHEN** `epic-dispatch.sh wait foo`・`epic-dispatch.sh wait '#12'`・`epic-dispatch.sh wait oratta/claude-harness#`・`epic-dispatch.sh wait claude-harness#12` をそれぞれ実行する
- **THEN** どれも `gh` は呼ばれず、stderr に使い方が出て exit 1 である

#### Scenario: 同じリポジトリの子は今と同じ形で gh を呼ぶ
- **WHEN** 子 11 の記録の `repo` が `oratta/claude-harness`、`epic` が `oratta/claude-harness#1122` で、`epic-dispatch.sh wait --interval 0 --timeout 60 11` を実行する
- **THEN** `gh api repos/{owner}/{repo}/issues/11 --jq .state` が呼ばれ、`git remote get-url origin` は呼ばれない

### Requirement: 子の側は今いるワークツリーのパスで自分の記録を探す

`mark` と `route` は、`git rev-parse --show-toplevel` のパスと記録の `worktree` が一致する記録を、`EPIC_STATE_ROOT` の下の全エピックのディレクトリから探さなければならない（MUST）。

- `mark <kind> <N>`: 一致する記録が 0 件なら書かずに `skipped <N> no-workspace`（exit 0）、2 件以上なら書かずに `failed <N>`（exit 1。stderr に該当する記録のパス）、1 件で `number`（と `<owner>/<repo>#<N>` で渡したときは `repo`）が引数と違えば `skipped <N> not-linked`（exit 0）。一致すれば `done` は `status` を `done`、`waiting` は `waiting`、`stopped` は `stop` を `stopped`、`resumed` は `stop` が `stopped` か `stopped-seen` のときだけ `resumed`（それ以外は書かずに `skipped <N> not-stopped`）に書き換えて `marked <N> <kind>`（exit 0）を出す。`mark stopped` / `resumed` は `status` を変えず、`done` / `waiting` は `stop` を変えない（MUST）。`EPIC_DISPATCH_PARENT_EPIC` は見ない
- `route`: `EPIC_DISPATCH_PARENT_EPIC` が空でないか、一致する記録が 1 件以上あれば `nested` を返し、stderr に `parent epic: #<E>`（環境変数の値か、記録の `epic`。エピックが今のリポジトリと別なら `parent epic: <owner>/<repo>#<E>`）を出す。Orca の `parentWorktreeId` を親子の判定に使ってはならない（MUST NOT）。それ以外の判定（`orca` / `subagent`）は今のまま
- `launch`: 一致する記録があれば（起動し直した子のセッション）、子ワークツリーを作らず、stderr に `child epics are not expanded here` を含む理由を出して exit 1（今と同じ文言）

#### Scenario: 自分の記録に止まった印を付ける
- **WHEN** 子のワークツリーで記録の `worktree` が一致し `number` が 1123 のとき `epic-dispatch.sh mark stopped 1123` を実行する
- **THEN** 記録の `stop` が `stopped` になり、`status` は変わらず、stdout は `marked 1123 stopped`、exit 0 である

#### Scenario: 止まっていなければ再開の印を付けない
- **WHEN** 記録の `stop` が空のとき `epic-dispatch.sh mark resumed 1123` を実行する
- **THEN** 記録は変わらず、stdout は `skipped 1123 not-stopped`、exit 0 である

#### Scenario: 記録の無いワークツリーでは何もしない
- **WHEN** どの記録の `worktree` とも一致しないワークツリーで `epic-dispatch.sh mark done 1123` を実行する
- **THEN** stdout は `skipped 1123 no-workspace`、exit 0 である

#### Scenario: 起動し直した子のセッションは記録で nested になる
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC` の無いセッションで、今のワークツリーと `worktree` が一致し `epic` が `oratta/claude-harness#1122` の記録があり、`epic-dispatch.sh route 5` を実行する
- **THEN** stdout は `nested`、stderr に `parent epic: #1122` が出て、`orca worktree list` は呼ばれない

### Requirement: 親の見張りは記録だけで子の状態を判定する

`wait`・`pending-owner`・`reap`・`notify-closed`・`reply` は、子の状態（完了の印・止まった印・受けた印）を記録の `status` と `stop` から読まなければならず、Orca のワークツリーの `workspaceStatus` と `comment` を判定に使ってはならない（MUST NOT）。子の記録は、要件「子を owner/repo#番号 で識別し、同じリポジトリの子は番号だけで書く」の親の見張りの照合で探す（MUST）。2 件以上なら、今の「同じ linkedIssue のワークツリーが 2 つ以上」と同じ扱い（`reap` は `kept <N> ambiguous`、`reply` / `notify-closed` は `failed <N> ambiguous-worktree`、`wait` はその子の印を見ない）にする（MUST）。子 issue の state・`state_reason`・コメントを読む先も、同じ要件の `gh` の呼び出しの形に従う（MUST）。

- `wait --watch-done <N>`: 記録の `status` が `done` なら印が付いた子とする
- `wait --watch-stopped`: 閉じていない位置引数の子の記録の `stop` が `stopped` なら、排他を取って `stopped-seen` に書き換え、書けたら止まった子とする。書けなければそのポーリングを失敗したポーリングに数える
- `pending-owner`: 記録の `stop` が `stopped-seen` の子を `pending <N>` で出す
- `notify-closed`: 記録が無ければ `skipped <N> no-worktree`、`status` が `done` なら `skipped <N> already-done`、`stop` が `stopped` / `stopped-seen` でなければ `skipped <N> not-stopped`
- `reap`: 記録が無い子と、記録の `worktree` のディレクトリが無い（`[ -d <worktree> ]` が偽）子は `gone <N>`（後者は記録を消す）。`status` が `done` でなければ `kept <N> not-done`。それ以外の安全確認は中身も `gh pr list`・`git ls-remote` などの呼び出しの形も今と同じにする（MUST。別のリポジトリの子に `-R <repo>` を付ける・子のワークツリーの origin に向けるのは後続の change）。`kept <N> not-child` は出さない
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

#### Scenario: 別の親の記録は見ない
- **WHEN** 子 12 の記録の `parent_worktree` が今のワークツリーと違い、`status` が `done` の状態で `epic-dispatch.sh reap 12` を実行する
- **THEN** stdout は `gone 12` で、そのワークツリーは消されない

### Requirement: Orca の部品は記録を書いたあとに Orca の印へ写す

`launch`・`mark`・`wait --watch-stopped` は、記録を書いたあと、記録の `launcher` が `orca` で `orca` が PATH にあるときは、今と同じ Orca の印（`mark done` / `waiting` は `--workspace-status completed` / `in-review`、`stopped` / `resumed` は `--comment epic-stopped` / `epic-resumed`、受けた印は `--comment epic-stopped-seen`）を写さなければならない（MUST）。写しに失敗しても記録の書き込みを成功として扱い、出力を変えずに stderr に写せなかったことを出さなければならない（MUST）。

#### Scenario: 写しに失敗しても mark は成功
- **WHEN** `orca worktree set` が非 0 で終わる環境で、子のワークツリーで `epic-dispatch.sh mark done 1123` を実行する
- **THEN** 記録の `status` は `done`、stdout は `marked 1123 done`、exit 0 で、stderr に写せなかったことが出る

#### Scenario: Orca 管理外では写さない
- **WHEN** `orca` が PATH に無い環境で、記録のある子のワークツリーで `epic-dispatch.sh mark stopped 1123` を実行する
- **THEN** 記録の `stop` は `stopped`、stdout は `marked 1123 stopped`、exit 0 である

### Requirement: adopt は記録の無い Orca の子を記録に取り込む

`epic-dispatch.sh adopt <epic> <child>...` は、記録の無い子ごとに、`orca worktree list --json` の、`repoId` が今のワークツリーと同じ・`linkedIssue` が子・`isArchived` が true でない・`parentWorktreeId` が今のワークツリーの id のワークツリーを探さなければならない（MUST）。ちょうど 1 つなら、その `path`・`branch` と、`workspaceStatus`（`completed` → `done`、`in-review` → `waiting`、それ以外 → `running`）と `comment`（`epic-stopped` → `stopped`、`epic-stopped-seen` → `stopped-seen`、`epic-resumed` → `resumed`、それ以外 → 空）を写し、`base` を `EPIC_DISPATCH_BASE`（空なら `main`）、`launcher` を `orca`、`session` と `launch_failed` を空にした記録を作り、`adopted <N>` を出す。記録が既にあれば `skipped <N>`、該当が無ければ `none <N>`、2 つ以上なら `failed <N> ambiguous` を出す（MUST）。`orca`・`jq` が無い・Orca 管理外・一覧を読めない・origin からエピックのリポジトリを読めないときは、stdout に何も出さず記録を作らずに exit 1。`failed` があれば exit 1、無ければ exit 0。

#### Scenario: 止まった印の Orca の子を取り込む
- **WHEN** 記録が無く、Orca の一覧に親が今のワークツリーで `linkedIssue` が 11・`comment` が `epic-stopped-seen` のワークツリーがある状態で `epic-dispatch.sh adopt 1122 11` を実行する
- **THEN** 記録の `stop` が `stopped-seen`、`status` が `running`、`worktree` が一覧の `path` で作られ、stdout は `adopted 11`、exit 0 である

#### Scenario: 記録がある子は取り込まない
- **WHEN** 子 11 の記録がある状態で `epic-dispatch.sh adopt 1122 11` を実行する
- **THEN** 記録は変わらず、stdout は `skipped 11` である

### Requirement: 記録は片付けた子ごとに消し、エピックの完了時にディレクトリごと消す

`reap` は `reaped <N>`（`branch-kept` を含む）と、記録はあるが子のワークツリーがもう無いときの `gone <N>` を出した子の記録を消さなければならない（MUST）。`epic-dispatch.sh clear <epic>` は、エピックの `<owner>/<repo>#<E>` から組み立てたディレクトリ名が `EPIC_STATE_ROOT` 直下にあれば、残っている記録の子を stderr に出してからディレクトリを消し、`cleared <epic>` を出して exit 0、無ければ `none <epic>` を出して exit 0 で終わらなければならない（MUST）。`<epic>` は `^[0-9]+$` でなければならず、エピックの `<owner>/<repo>` は要件「エピックの状態は子ごと 1 ファイルのローカルの記録に置く」のとおり origin から読む（読めなければ何も消さずに exit 1）。組み立てた名前が `/` か `..` を含むとき、`EPIC_STATE_ROOT` が空のとき、`EPIC_STATE_ROOT` を絶対パスにした結果が `/` か `$HOME` そのもののときは、何も消さずに stderr に理由を出して exit 1 で終わる（MUST）。消すのは `EPIC_STATE_ROOT` 直下のその 1 ディレクトリだけで、シンボリックリンクならリンク先をたどらずに exit 1 で終わる（MUST）。

この要件の守備範囲で入力として扱うのは、develop の本体が SKILL.md の手順どおりに渡すエピックの番号と、親のワークツリーの origin と `EPIC_STATE_ROOT` の値である。拾いたい誤りは、別のエピックのディレクトリや `EPIC_STATE_ROOT` の外（ホームの全体など）を消すことである。次は通してよく、この要件では止めない: `EPIC_STATE_ROOT` が相対パスであること（開始時の作業ディレクトリを基準に絶対パスにしてから消す）／エピックの番号の取り違えで、同じリポジトリの別のエピックの状態ディレクトリを消すこと（そのエピックの親は再開の手順の `adopt` で Orca の印から記録を組み立て直せる）／ディレクトリの中に記録以外のファイルがあること（一緒に消す）。消す対象の取り違えを見つけるたびに検査を足して塞ぎ切ることは、この要件の完了条件としない。

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

### Requirement: launch は子のワークツリーを作る前に記録を書く

`launch` は、子ごとに、記録があれば（`worktree` が空でない）`skipped <N>` とし、`worktree` が空の記録が残っていれば（前の `launch` が書いたあとで殺された）上書きして作成に進み、無ければ（`deferred` の判定のあと）`status` が `running`・`worktree` が空の記録を書いてから子のワークツリーを作らなければならない（MUST）。ワークツリーの作成に失敗したら記録を消し（MUST）、作れたら `worktree`・`branch` を書き足す。ワークツリーを作ったあとで端末・起動待ち・送信に失敗したら、記録を残して `launch_failed` に段の名前を書く（MUST）。Orca の一覧に同じ子のワークツリーがあって記録が無いとき（この変更の前に起動した子）は、今と同じく `skipped <N>` とし、記録は作らない（取り込みは `adopt`）。

#### Scenario: 作成に失敗したら記録が残らない
- **WHEN** `orca worktree create` が非 0 で終わる環境で `epic-dispatch.sh launch 1122 11` を実行する
- **THEN** stdout は `failed 11` で、子 11 の記録は無い

#### Scenario: 送信に失敗したら記録が残り次の launch では skipped
- **WHEN** `orca terminal send` の stages に `turn_started` が無い環境で `epic-dispatch.sh launch 1122 11` を実行し、続けてもう一度実行する
- **THEN** 1 回目の stdout は `failed 11` で記録の `launch_failed` は `send`、2 回目の stdout は `skipped 11` である

### Requirement: 同時に枠を使う子は記録から数える

issue #1106（PR #1120）が `launch` に入れる同時に枠を使う子の上限について、枠を使っている子は、`EPIC_STATE_ROOT` の下の全エピックのディレクトリを横断して、今のワークツリーを `parent_worktree` に持つ記録のうち（#1120 が `parentWorktreeId` で数えるのと同じく、エピックを問わない）、`status` が `done` でなく、`stop` が `stopped` / `stopped-seen` でなく、記録の `repo` に対する issue の state が `closed` でないものとして数えなければならない（MUST）。state を読めない子は数える。上限の値の決め方（`max-parallel`）・`deferred <N>` の出し方・「`create` に進んだ子は結果によらず 1 枠を使う」は #1120 の要件のまま変えない（MUST）。起動部品は上限を知らず、上限は記録と見張りの側で決める。

#### Scenario: 記録で数えた使用中の数で後回しを決める
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=2` で、`status` が `running`・`stop` が空・issue が open の記録が 1 件、`status` が `done` の記録が 1 件、`stop` が `stopped-seen` の記録が 1 件ある状態で `epic-dispatch.sh launch 1122 21 22` を実行する
- **THEN** 使用中は 1 件で、stdout は `launched 21` と `deferred 22` である

#### Scenario: Orca の一覧の印は数え方に効かない
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=1` で、記録の無い Orca のワークツリー（親が今のワークツリー・印なし）が 1 つある状態で `epic-dispatch.sh launch 1122 21` を実行する
- **THEN** 使用中は 0 件で、stdout は `launched 21` である
