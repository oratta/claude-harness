# dev-workflow-epic-state Specification

## Purpose
エピックの子の状態（起動済み・主の返事待ち・用が済んだ・止まった印）の正本を、起動部品（Orca・tmux・サブエージェント）に依存しないローカルの記録に置き、親の見張りがその記録だけで動く形を定める。別リポジトリの子は `<owner>/<repo>#<N>` で識別する。

## Requirements

### Requirement: エピックの状態は子ごと 1 ファイルのローカルの記録に置く

エピックの子の状態の正本は、`${EPIC_STATE_ROOT:-$HOME/.claude/epic-state}/<エピックの owner>.<エピックの repo>-<エピック番号>/<子の owner>.<子の repo>-<子の番号>.json` に子ごと 1 ファイルで置かなければならない（MUST）。`EPIC_STATE_ROOT` が相対パスなら、各サブコマンドの開始時の作業ディレクトリを基準に絶対パスにしてから使う。記録を `~/.claude/projects/` の配下に置いてはならない（MUST NOT）。記録は PC をまたいで共有しない。

エピックの `<owner>/<repo>` は、記録のディレクトリ名をエピックから組み立てるサブコマンド（`launch`・`adopt`・`clear`）だけが、親のワークツリーの `git remote get-url origin` から読む（MUST）。受け付ける形は、ホストが `github.com` の `git@github.com:<o>/<r>`・`ssh://git@github.com/<o>/<r>`・`https://github.com/<o>/<r>` の 3 つで、どれも末尾の `.git` と `/` は有っても無くてもよい。`<o>` と `<r>` は ASCII の小文字にそろえて記録とファイル名に使う（GitHub は owner と repo の大文字小文字を区別しないため）。origin が無い・この 3 つの形でない・ホストが `github.com` でないときは、記録を書かず何も消さずに、stderr に `cannot read the epic repository from origin: <URL か「no origin」>` を出して exit 1 で終わる（MUST）。親の見張り（`wait`・`pending-owner`・`reap`・`notify-closed`・`reply`）と子の側（`mark`・`route`）は origin を読まず、記録の中の `epic`・`repo` を使う。

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
| `launch_failed` | 文字列 | `launch` が記録を書いたあとで失敗した段（`create`: 作成の呼び出しは成功したが path を読めない／`terminal`／`ready`／`send`。成功なら空） |
| `status` | 文字列 | `running`・`waiting`・`done` のどれか |
| `stop` | 文字列 | 空・`stopped`・`stopped-seen`・`resumed` のどれか |
| `created_at` / `updated_at` | 文字列 | UTC の `YYYY-MM-DDTHH:MM:SSZ` |

`status` は今のボードの列（`running` は印なし、`waiting` は `in-review`、`done` は `completed`）に、`stop` は今のコメント欄（`stopped` は `epic-stopped`、`stopped-seen` は `epic-stopped-seen`、`resumed` は `epic-resumed`）に当たり、値の遷移は今の印と同じにしなければならない（MUST）。止まった理由の本文は記録に持たず、子 issue の `子の停止: 主の返事待ち` のコメントを正本のままにする。`session` はこの版では Orca の `launch` と、起動し直した `reply`（`notify-closed`・`wait --resolve` の起動し直しを含む）が端末のハンドルを書き、`adopt` は空のまま書く（見張りの判定には使わない）。

次のどれかに当たる記録は「読めない記録」とする: JSON のオブジェクトとして読めない／`schema` が `1` でない／`status` か `stop` が上の表に無い値／`epic`・`child`・`repo`・`number`・`parent_worktree`・`worktree` のどれかが無いか型が違う。読めない記録は書き換えも削除もしてはならず（MUST NOT）、サブコマンドごとに次のとおり扱わなければならない（MUST）。どの場合も stderr にその記録のパスを出す。

| サブコマンド | 読めない記録の扱い |
|---|---|
| `wait` | その子の印を読めなかったポーリングとして、今の「一覧を読めない」と同じく失敗したポーリングに数える（3 回続けば `gh` で失敗した子がいなければ `error workspaces`） |
| `reap` | `kept <N> state-unreadable`（何も消さない） |
| `pending-owner` | その子を飛ばす（`pending` を出さない） |
| `notify-closed`・`reply` | `failed <N> state-unreadable` |
| `launch` | その子自身の記録なら `failed <N> state-unreadable`（作り直さない）。枠の数では、ほかの子の読めない記録を使用中の 1 枠に数える |
| `adopt` | `failed <N> state-unreadable` |
| `clear` | 消す対象のエピックのディレクトリにある読めない記録は、stderr に `remaining state record: unreadable (<パス>)` と出してからディレクトリごと消す（ディレクトリ単位の削除で、個別の書き換え・削除はしない） |
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

### Requirement: Orca の部品は記録を書いたあとに Orca の印へ写す

`mark`・`wait --watch-stopped` は、記録を書いたあと、記録の `launcher` が `orca` のときは、Orca の部品の `mirror` を呼ばなければならない（MUST）。`mark` は `mirror current <done・waiting・stopped・resumed のどれか> <記録のパス>`、`wait --watch-stopped` が止まった印を受けたときは `mirror <子のワークツリー> stopped-seen <記録のパス>` で呼ぶ。Orca の部品は、`orca` が PATH にあるときだけ、今と同じ Orca の印（`done` / `waiting` は `--workspace-status completed` / `in-review`、`stopped` / `resumed` は `--comment epic-stopped` / `epic-resumed`、受けた印は `--comment epic-stopped-seen`）を写す（MUST）。写しに失敗しても記録の書き込みを成功として扱い、出力を変えずに stderr に写せなかったことを出さなければならない（MUST）。

#### Scenario: 写しに失敗しても mark は成功
- **WHEN** `orca worktree set` が非 0 で終わる環境で、子のワークツリーで `epic-dispatch.sh mark done 1123` を実行する
- **THEN** 記録の `status` は `done`、stdout は `marked 1123 done`、exit 0 で、stderr に写せなかったことが出る

#### Scenario: Orca 管理外では写さない
- **WHEN** `orca` が PATH に無い環境で、記録のある子のワークツリーで `epic-dispatch.sh mark stopped 1123` を実行する
- **THEN** 記録の `stop` は `stopped`、stdout は `marked 1123 stopped`、exit 0 である

#### Scenario: 写すのは Orca の部品
- **WHEN** 記録の `launcher` が `orca` の子のワークツリーで `epic-dispatch.sh mark waiting 1123` を実行する
- **THEN** `orca worktree set --worktree current --workspace-status in-review` が 1 回呼ばれ、stdout は `marked 1123 waiting`、exit 0 である（`epic-dispatch.sh` が `orca` を直接呼んでいないことは、dev-workflow-develop の要件「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」の照合で確かめる）

### Requirement: adopt は記録の無い Orca の子を記録に取り込む

`epic-dispatch.sh adopt <epic> <child>...` は、記録の無い子ごとに、`orca worktree list --json` の、`repoId` が今のワークツリーと同じ・`linkedIssue` が子・`isArchived` が true でない・`parentWorktreeId` が今のワークツリーの id のワークツリーを探さなければならない（MUST）。ちょうど 1 つなら、その `path`・`branch` と、`workspaceStatus`（`completed` → `done`、`in-review` → `waiting`、それ以外 → `running`）と `comment`（`epic-stopped` → `stopped`、`epic-stopped-seen` → `stopped-seen`、`epic-resumed` → `resumed`、それ以外 → 空）を写し、`base` を `EPIC_DISPATCH_BASE`（空なら `main`）、`launcher` を `orca`、`session` と `launch_failed` を空にした記録を作り、`adopted <N>` を出す。読める記録が既にあれば `skipped <N>`、読めない記録なら stderr にそのパスを出して `failed <N> state-unreadable`（記録は変えない）、該当が無ければ `none <N>`、2 つ以上なら `failed <N> ambiguous`、記録を書けなければ stderr にパスを出して理由の無い `failed <N>` を出す（MUST）。`orca`・`jq` が無い・Orca 管理外・一覧を読めない・origin からエピックのリポジトリを読めないときは、stdout に何も出さず記録を作らずに exit 1。`failed` があれば exit 1、無ければ exit 0。

#### Scenario: 止まった印の Orca の子を取り込む
- **WHEN** 記録が無く、Orca の一覧に親が今のワークツリーで `linkedIssue` が 11・`comment` が `epic-stopped-seen` のワークツリーがある状態で `epic-dispatch.sh adopt 1122 11` を実行する
- **THEN** 記録の `stop` が `stopped-seen`、`status` が `running`、`worktree` が一覧の `path` で作られ、stdout は `adopted 11`、exit 0 である

#### Scenario: 読めない記録の子は取り込まず failed state-unreadable
- **WHEN** 子 11 の記録が JSON として読めない状態で `epic-dispatch.sh adopt 1122 11` を実行する
- **THEN** 記録は変わらず、stdout は `failed 11 state-unreadable`、exit 1 で、stderr にその記録のパスが出る

#### Scenario: 記録がある子は取り込まない
- **WHEN** 子 11 の記録がある状態で `epic-dispatch.sh adopt 1122 11` を実行する
- **THEN** 記録は変わらず、stdout は `skipped 11` である

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

### Requirement: launch は子のワークツリーを作る前に記録を書く

`launch` は、子ごとに、記録があれば（`worktree` が空でない）`skipped <N>` とし、`worktree` が空の記録が残っていれば（前の `launch` が書いたあとで殺された）、Orca の一覧にその子のワークツリーがちょうど 1 つあるときは記録の `worktree`・`branch` をその `path`・`branch` で埋めて `skipped <N>` とし（埋められなくても `skipped <N>`）、無いときは上書きして作成に進み（この記録は要件「同時に枠を使う子は記録から数える」の数えで使用中に入るので、その子は空き枠をもう 1 つ減らさず、空き枠の判定も行わない）、記録が無ければ（`deferred` の判定のあと）`status` が `running`・`worktree` が空の記録を書いてから子のワークツリーを作らなければならない（MUST）。ワークツリーの作成に失敗したら記録を消し（MUST）、作れたら `worktree`・`branch` を書き足す。ワークツリーを作ったあとで端末・起動待ち・送信に失敗したら、記録を残して `launch_failed` に段の名前を書く（MUST）。Orca の一覧に同じ子のワークツリーがあって記録が無いとき（この変更の前に起動した子）は、今と同じく `skipped <N>` とし、記録は作らない（取り込みは `adopt`）。

#### Scenario: 作成に失敗したら記録が残らない
- **WHEN** `orca worktree create` が非 0 で終わる環境で `epic-dispatch.sh launch 1122 11` を実行する
- **THEN** stdout は `failed 11` で、子 11 の記録は無い

#### Scenario: 送信に失敗したら記録が残り次の launch では skipped
- **WHEN** `orca terminal send` の stages に `turn_started` が無い環境で `epic-dispatch.sh launch 1122 11` を実行し、続けてもう一度実行する
- **THEN** 1 回目の stdout は `failed 11` で記録の `launch_failed` は `send`、2 回目の stdout は `skipped 11` である

### Requirement: 同時に枠を使う子は記録から数える

issue #1106（PR #1120）が `launch` に入れる同時に枠を使う子の上限について、枠を使っている子は、`EPIC_STATE_ROOT` の下の全エピックのディレクトリを横断して、今のワークツリーを `parent_worktree` に持つ記録のうち（#1120 が `parentWorktreeId` で数えるのと同じく、エピックを問わない）、`status` が `done` でなく、`stop` が `stopped` / `stopped-seen` でなく、記録の `repo` に対する issue の state が `closed` でないものとして数えなければならない（MUST）。state を読めない子は数える。上限の値の決め方（`max-parallel`）・`deferred <N>` の出し方・「`create` に進んだ子は結果によらず 1 枠を使う」は #1120 の要件のまま変えない（MUST。`worktree` が空の自分の記録は上の数えで使用中に入るので、その子が `create` に進むときは新しく 1 枠を足さず、その記録の 1 枠を使う）。起動部品は上限を知らず、上限は記録と見張りの側で決める。

#### Scenario: 記録で数えた使用中の数で後回しを決める
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=2` で、`status` が `running`・`stop` が空・issue が open の記録が 1 件、`status` が `done` の記録が 1 件、`stop` が `stopped-seen` の記録が 1 件ある状態で `epic-dispatch.sh launch 1122 21 22` を実行する
- **THEN** 使用中は 1 件で、stdout は `launched 21` と `deferred 22` である

#### Scenario: Orca の一覧の印は数え方に効かない
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=1` で、記録の無い Orca のワークツリー（親が今のワークツリー・印なし）が 1 つある状態で `epic-dispatch.sh launch 1122 21` を実行する
- **THEN** 使用中は 0 件で、stdout は `launched 21` である

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

### Requirement: 起動部品は epic-launch-<名前>.sh の 1 本ずつで、同じサブコマンドと出力の契約を持つ

子のワークツリーを作る・セッションを開く・指示を送る・閉じる・消す・画面へ写す処理は、起動部品のスクリプト `plugins/dev-workflow/scripts/epic-launch-<名前>.sh` に置かなければならない（MUST）。起動部品は Orca の部品 `epic-launch-orca.sh` と tmux の部品 `epic-launch-tmux.sh`（要件「tmux の部品は…」）の 2 本で、サブエージェント方式は起動部品を持たない。`epic-dispatch.sh` は起動部品を `bash <epic-dispatch.sh と同じディレクトリ>/epic-launch-<名前>.sh <サブコマンド> <引数...>` で別のプロセスとして呼ばなければならない（MUST）。起動部品は状態の記録を読み書きしてはならず（MUST NOT）、記録・親の見張り・同時に枠を使う子の上限・`reap` の片付けの前の確認は `epic-dispatch.sh` に置く（MUST）。起動部品のスクリプトには、開発に固有の語（PR・マージ・ゲート）を入れてはならない（MUST NOT）。

起動部品は次のサブコマンドを持たなければならない（MUST）。stdout には各サブコマンドが決めた行だけを出さなければならない（MUST）。stderr に出すのは、切り出す前の `epic-dispatch.sh` が stderr に出していたもの（`orca worktree set`・`worktree create`・`terminal create`・`terminal send`・`terminal wait`・`terminal close` の出力、`reap` の閉じ直しのときの `terminal list` の出力、`worktree rm` の stderr、失敗の理由と手で続けるための案内の文）だけで、同じ順と同じ文で出す（MUST）。追加する `keepalive` は送信出力と失敗理由を stderr に出してよい（MAY）。通常の skipped に成功通知を追加せず、一覧・画面の観測内容は stdout/stderr に丸ごと出さない（MUST NOT）。部品が中で読んで解釈するだけの出力（`orca worktree current`・`worktree list`・`repo list` の JSON と、閉じ直し以外の `terminal list` の JSON）は、stdout にも stderr にも出してはならない（MUST NOT）。

| サブコマンド | 引数 | stdout と exit |
|---|---|---|
| `available` | なし | 何も出さない。部品が使えれば exit 0、使えなければ stderr に理由を出して exit 1 |
| `here` | なし | 今のワークツリーが部品の管理下なら `{"repo_id":<文字列>,"worktree_id":<文字列>}` の 1 行を出して exit 0。管理外か部品が使えなければ exit 1。管理下かの判定は識別子の読み取りと切り離す: Orca の部品は `orca worktree current --json` が exit 0 なら管理下とし、`jq` が無い・JSON を読めない・値が無いときは値を空の文字列にして exit 0 で出す（`route` は `jq` が無くても `orca` を返す。識別子が要る `launch`・`adopt` は、Orca の部品を使うときだけ、空の `repo_id` を今と同じ `orca worktree current --json has no repoId` で止める。登録の仕組みを持たない部品は空の `repo_id` を返してよい） |
| `prepare` | `<親のワークツリー> <エピックの番号>` | 何も出さない。親のワークツリーをエピックに紐づけたら exit 0、失敗したら exit 1 |
| `list` | なし | 部品が知っている子のワークツリーを、1 行 1 件の JSON `{"repo_id","issue","path","branch","parent_id","status","stop"}` で出して exit 0（片付け済みのものは出さない。`branch` は `refs/heads/` を付けない。`status` は `done`・`waiting`・`running` のどれか、`stop` は `stopped`・`stopped-seen`・`resumed`・空のどれか）。読めなければ exit 1 |
| `repos` | なし | 部品に登録された clone を、1 行 1 件の JSON `{"id","path"}`（`path` は末尾の `/` を付けない）で出して exit 0。読めなければ exit 1 |
| `unregistered` | `<clone>` | stdout に、clone が部品に登録されていないときの理由の語を 1 行出し、stderr に登録の仕方を出して exit 0。登録の仕組みを持たない部品（tmux）は `ok` を出して stderr に何も出さない。`epic-dispatch.sh` は `repos` に clone が無かったとき（`repo_id` が空のとき）だけ呼び、`ok` を「登録は要らない」と読んで `repo_id` を空のまま `create` に渡し、それ以外の語は今と同じく `failed <child> <語>` にする |
| `create` | `<clone> <repo_id> <子の番号> <起点> <親のワークツリー>` | 子を作るリポジトリは `clone` で決める: 空ならエピックと同じリポジトリ（親のワークツリーのリポジトリ）、空でなければ `clone` のリポジトリ。`repo_id` は Orca の部品だけが読む値で、空でなければ `--repo id:<repo_id>`、空なら `--repo` を付けず親と同じリポジトリに作る（tmux の部品は `repo_id` を読まず、`clone` と親のワークツリーだけで決める。別リポジトリの子は `clone` が空でなく `repo_id` が空で渡る）。子のワークツリーを作れたら `{"path","branch"}` の 1 行を出して exit 0。作れなかったら exit 1。作ったがパスを読めなければ exit 2 |
| `start` | `<ワークツリー> <起動コマンド> <最初の指示> <子の呼び方>` | 指示が届いたら `started <session>` を出して exit 0。届かなかったら `failed <段> <session>`（段は `terminal`・`ready`・`send`、`session` は分からなければ空）を出して exit 1 |
| `deliver` | `<ワークツリー> <relaunch 0か1> <送る文> <起動コマンド> <起動し直しの指示>` | セッション（端末）の一覧を 1 回だけ読む。`relaunch` が 0 で、一覧に端末があり、そのうち子のセッションがちょうど 1 つに決まればそこへ文を送って `sent` を出し exit 0。`relaunch` が 0 で、端末はあるが子のセッションに決められない（シェルの端末だけ、または候補が 2 つ以上）ときは、送りも起動し直しもせず `failed ambiguous-terminal` を出す。一覧が空か `relaunch` が 1 なら、ある端末をすべて閉じてから（空なら閉じずに）起動し直して指示を送り `relaunched <session>` を出し exit 0。失敗は `failed <理由>`（理由は `terminal-list`・`ambiguous-terminal`・`send`・`close`・`create`・`ready`）を出して exit 1 |
| `keepalive` | `<ワークツリー> <送る文>` | 既存・一意・入力待ち・空欄の子に送り到達確認できたら `sent`（exit 0）。対象外/状態不明は `skipped <理由>`（exit 0。理由は `no-terminal`・`ambiguous-terminal`・`busy`・`dialog`・`input-not-empty`・`unknown-state`）。一覧や観測コマンドが失敗/出力を読めないときは `failed terminal-list` または `failed observe`、送信コマンド失敗や到達確認不能は `failed send`（exit 1）。stdout はこの一行だけ。起動・終了・再起動・入力消去は行わない |
| `close` | `<ワークツリー> <子の呼び方>` | 何も出さない。セッションを閉じたら exit 0、閉じ直しても閉じられなければ exit 1（主の操作の案内は `epic-dispatch.sh` が出す）。`子の呼び方`（例: `11`・`o/r#5`）は閉じ直すときの stderr の文 `terminal close was incomplete for #<子の呼び方>; …` にだけ使う |
| `remove` | `<ワークツリー>` | 消せたら何も出さず exit 0。消せなければ理由の語を 1 行出して exit 1。未コミットの変更があるワークツリーを消してはならない（MUST NOT）。`orca worktree rm` の通常の stdout は部品の stdout に混ぜず、環境変数 `EPIC_LAUNCH_STDOUT_FD` で渡された FD（`epic-dispatch.sh` の reap は自分の stdout を保持した FD 3 を渡す）へ中継する。FD が渡されない・開いていないときは stderr へ回す |
| `mirror` | `<current か ワークツリー> <done・waiting・stopped・resumed・stopped-seen のどれか> <記録のパス>` | 何も出さず、常に exit 0。部品の画面へ状態を写し、写せなければ stderr に記録のパスと一緒に出す。画面を持たない部品と、部品が使えないときは何もしない |

知らないサブコマンドと引数の数の違う呼び出し（`keepalive` は引数がちょうど 2 個でない場合を含む）には、stdout を空にして stderr に使い方を出して exit 2 で終わらなければならない（MUST）。

親が子を起動するとき、Orca/tmux の両起動部品は `claude` に渡る起動引数に `--prompt-suggestions false` を付けなければならない（MUST）。`start` と `deliver` の起動し直しのいずれにも適用する。Orca の `draft` では Claude Code の提案文と人の入力を区別できないためである。設定ファイルや別の識別の仕組みを作ってはならず（MUST NOT）、これより前に起動された子の非空の `draft` も人の入力として扱わなければならない（MUST）。

`keepalive` は前景が空いた入力待ちで入力欄が空のときだけ送信し、初回と送信直前の観測に次の判定を適用しなければならない（MUST）。空の `❯` だけで入力待ちと判断してはならず（MUST NOT）、前景の状態と空欄の両方を確認する。

| 画面・入力の観測 | 判定 |
|---|---|
| 記号＋`…`＋`(Ns · …)` のスピナー行（例: `✢ Hullaballooing… (1s · thinking)`） | 空の `❯` と同居しても実行中として `skipped busy` |
| AskUserQuestion の `Enter to select · ↑/↓ to navigate` | `skipped dialog` |
| 許可画面の `Do you want to proceed?` または `Esc to cancel · Tab to amend` | `skipped dialog` |
| フォルダ信頼確認の `Enter to confirm · Esc to cancel` | `skipped dialog` |
| Orca の画面と `draft` | `orca terminal read --terminal <handle> --screen --json` を使う。`status: running` は入力待ちと実行中を分けないため判定に使わない。stream の tail だけでも判定しない。画面で前景の入力待ちを確認したうえで、`draft` のキーが無いか空なら空欄、非空なら `skipped input-not-empty` |
| tmux の画面 | `tmux capture-pane -p -e -t <pane>` で前景の入力待ちを確認し、`❯ ` の後が空なら空欄。薄字 `\e[2m` の提案文だけなら空欄とみなしてよい（MAY）。それ以外の文字は `skipped input-not-empty` |
| `· N shell still running` の表示 | バックグラウンドのシェルだけなら前景は空いているため、他の条件を満たせば送信可 |

前景の入力待ち・空欄を確定できない場合は `skipped unknown-state` としなければならない（MUST）。上の実行中や選択画面を観測した場合は、空の入力欄が同居しても送信してはならない（MUST NOT）。

この要件の検査（知らないサブコマンドと引数の数、`list`・`repos`・端末の一覧の読み取り、子のセッションの端末の選び方、`keepalive` の対象状態と出力）の守備範囲は次のとおりである。入力の出どころは `epic-dispatch.sh`（同じプラグインの中の呼び出し元）と、`orca` が返す JSON・端末画面の CLI 出力である（tmux の観測は要件「tmux の部品は…」に従う）。拾いたい誤りは、`epic-dispatch.sh` と部品のサブコマンドの名前か引数の並びが食い違うこと、`orca` の JSON の形が変わって読めないこと（読めないときは 0 件として扱わず失敗にする）、子のセッションの端末を 1 つに決められないのに送ること、`keepalive` で実行中・入力済み・選択画面・観測不能な端末に送ること、送れないときに作成・終了・入力消去をすることである。`epic-dispatch.sh` が検査済みの値（待ち時間・起動コマンド・指示と返事の文・子の呼び方・ワークツリーのパス）は、部品の中で検査し直さずにそのまま通してよい（MAY）。`keepalive` で空欄を確認できない出力は送らない。CLI 観測と送信の間の主の並行入力を原子的に排除することや、引数の中身の妥当性、`orca` の JSON・画面のあらゆる崩れ方を塞ぎ切ることは、この要件の完了条件としない。

Orca の部品は、各サブコマンドで次の `orca` のコマンドだけを呼び、Orca の機能を自前で作り直してはならない（MUST NOT）: `available` は `orca` が PATH にあるか（無ければ stderr に `orca is not on PATH`）、`here` は `orca worktree current --json`、`prepare` は `orca worktree set --worktree path:<親> --issue <E>`、`list` は `orca worktree list --json`（`isArchived` が true のものを除き、`workspaceStatus` の `completed` → `done`・`in-review` → `waiting`・それ以外 → `running`、`comment` の `epic-stopped` → `stopped`・`epic-stopped-seen` → `stopped-seen`・`epic-resumed` → `resumed`・それ以外 → 空に読み替える）、`repos` は `orca repo list --json`、`unregistered` は stdout に `not-in-orca`、`create` は `orca worktree create`（`repo_id` が空でなければ `--repo id:<repo_id>`、続けて `--name issue-<N> --issue <N> --base-branch origin/<起点> --parent-worktree path:<親> --json`）、`start`・`deliver` は `orca terminal list`・`send`・`create`・`wait --for tui-idle`・`close --all`、`keepalive` は `orca terminal list --worktree path:<wt> --json`・`orca terminal read --terminal <handle> --screen --json` による既存端末/画面/draft の観測と、`orca terminal send --terminal <handle> --text <text> --enter --wait-submit <EPIC_DISPATCH_SUBMIT_WAIT> --json` だけ（`turn_started` を確認したときだけ `sent`。実行中の子が idle になるのを待つ `terminal wait`、create/close、入力消去、再試行の送信は許さない）、`close` は `orca terminal close --worktree path:<wt> --all`（失敗したら端末の一覧を stderr に出し、`EPIC_DISPATCH_REAP_CLOSE_RETRY_WAIT` 秒待って 1 回だけ閉じ直す）、`remove` は `orca worktree rm --worktree path:<wt>`（`--force` を付けない。stderr に `terminal sweep failed` があれば `rm-failed-terminal-sweep`、それ以外の失敗は `rm-failed`）、`mirror` は `orca worktree set --worktree <current か path:<wt>>` に `done` → `--workspace-status completed`、`waiting` → `--workspace-status in-review`、`stopped` → `--comment epic-stopped`、`resumed` → `--comment epic-resumed`、`stopped-seen` → `--comment epic-stopped-seen` を付けたもの。

既存操作で Orca の部品を使うとき、`epic-dispatch.sh` の stdout・exit code・stderr の文言・記録の中身と、`orca`・`git`・`gh` の呼び出しの順と回数は、起動部品へ切り出す前と同じでなければならない（MUST）。新たな声かけの観測・送信と、子の起動引数への `--prompt-suggestions false` の追加をこの同一性の対象外とし、wait の既存の出力・終了理由を変えてはならない（MUST NOT）。`epic-dispatch.sh` は待ち時間の環境変数（`EPIC_DISPATCH_READY_TIMEOUT_MS`・`EPIC_DISPATCH_SUBMIT_WAIT`・`EPIC_DISPATCH_REAP_CLOSE_RETRY_WAIT`）を今と同じ位置で検査して既定を当て、その値を同じ名前の環境変数で起動部品に渡す（MUST）。`repos` は 1 回の `launch` で多くても 1 回だけ呼ぶ（MUST）。`launch` と `adopt` は、要件「記録の launcher ごとに起動部品を選ぶ」の順で部品を選び、`reply`・`notify-closed`・`wait --resolve`・`reap` は子の記録の `launcher` の部品を呼ぶ（MUST）。部品の `available` を呼ぶ相手は操作で分かれる（MUST。要件「記録の launcher ごとに起動部品を選ぶ」が正本）: `launch`・`adopt` は選んだ部品、`reply`・`notify-closed`・`wait --resolve`・`reap` は対象の子の記録の `launcher` の部品である。入口で別の部品（例: 使えない Orca）を先に探して全体を終えてはならない（MUST NOT）。Orca の部品の `available` が失敗したときの `orca is not on PATH` での exit 1 は、Orca の部品を呼ぶ操作（記録の `launcher` が `orca` の子、または部品を決める記録が無い場合）の挙動で、tmux の記録の子には掛からない。

`keepalive` の送る文は dispatch が共通定義から生成した一つの引数で渡し、部品は展開・改変しない（MUST）。送信直前に既存セッション・入力待ち・空欄・選択画面でないことを再観測し、いずれか不明なら送らず `skipped unknown-state` とする（MUST）。読み取り自体の失敗や壊れた出力は `failed observe`（一覧なら `failed terminal-list`）とし、セッション無しとみなさない（MUST）。`keepalive` は記録の launcher の部品を選び、対象外・失敗でも別の部品へ切り替えない（MUST）。送信後の確認待ち以外に子が入力待ちになるまで待たず、同じ呼び出しで再送しない（MUST NOT）。

#### Scenario: 知らないサブコマンドは exit 2
- **WHEN** `bash plugins/dev-workflow/scripts/epic-launch-orca.sh nosuch` を実行する
- **THEN** stdout は空で、stderr に使い方が出て、exit 2 である

#### Scenario: create は orca の出力を stderr に回し、stdout はパスとブランチの 1 行だけ
- **WHEN** `orca worktree create --json` のスタブが `{"result":{"worktree":{"path":"/work/issue-5","branch":"refs/heads/oratta/issue-5"}}}` を出す環境で、`epic-launch-orca.sh create /work/parent '' 5 main /work/parent` を実行する
- **THEN** stdout は `{"path":"/work/issue-5","branch":"oratta/issue-5"}` を表す JSON の 1 行だけで、スタブの出力は stderr に出て、`orca worktree create` は `--repo` を付けずに 1 回呼ばれ、exit 0 である

#### Scenario: list は Orca の印を記録の語に読み替える
- **WHEN** `orca worktree list --json` のスタブが、`linkedIssue` 5・`workspaceStatus` `completed`・`comment` `epic-stopped` のワークツリーと、`isArchived` が true のワークツリーを出す環境で、`epic-launch-orca.sh list` を実行する
- **THEN** stdout は 1 行だけで、その `issue` は `5`、`status` は `done`、`stop` は `stopped` であり、exit 0 である

#### Scenario: deliver はセッションの一覧を 1 回だけ読む
- **WHEN** 子のワークツリーに端末が無い環境で、`epic-launch-orca.sh deliver /work/issue-5 0 返事 cld 指示` を実行する
- **THEN** `orca terminal list` は 1 回だけ呼ばれ、`orca terminal create`・`wait`・`send` が呼ばれ、ターンが始まったら stdout は `relaunched <handle>` である

#### Scenario: 切り出したあとも launch の orca の呼び出しは変わらない
- **WHEN** 同じリポジトリの子 1 件を `epic-dispatch.sh launch 1122 1123` で起動する
- **THEN** `orca worktree current`・`orca worktree set`・`orca worktree list`・`orca worktree create` はそれぞれ 1 回ずつ呼ばれ、stdout は `launched 1123` で、記録の `launcher` は `orca` である

#### Scenario: orca が無ければ、記録の launcher が orca の子の reap は何も出さずに exit 1
- **WHEN** `orca` が PATH に無い環境で、記録の `launcher` が `orca` の子 1123 に `epic-dispatch.sh reap 1123` を実行する（記録の無い子だけを渡した場合も同じ）
- **THEN** stdout は空で、stderr に `orca is not on PATH` が出て、exit 1 である

#### Scenario: orca が無くても、記録の launcher が tmux の子の reap は進む
- **WHEN** `orca` が PATH に無く、`tmux` の部品が使える環境で、記録の `launcher` が `tmux` の子 1123 に `epic-dispatch.sh reap 1123` を実行する
- **THEN** `orca` は呼ばれず、`orca is not on PATH` は出ず、tmux の部品の `close`・`remove` の結果で `reaped 1123` か `kept 1123 <理由>` を出す

#### Scenario: keepalive は共通の出力と終了コードを持つ
- **WHEN** 両起動部品の `keepalive /work/issue-5 '<固定文>'` について、既存の一意・入力待ち・空欄で送信確認成功、端末無し、入力済み、送信確認失敗をそれぞれ用意する
- **THEN** stdout は順に `sent` / `skipped no-terminal` / `skipped input-not-empty` / `failed send`、exit は順に 0 / 0 / 0 / 1 となる。いずれも作成・終了・再起動・入力消去を行わない

#### Scenario: keepalive の引数数違いは exit 2
- **WHEN** 両起動部品の keepalive に引数を 1 個または 3 個渡す
- **THEN** stdout は空、stderr に使い方、exit 2 となり、観測も送信も行わない

#### Scenario: 子の起動時に提案文を無効にする
- **WHEN** Orca/tmux の各部品で start または deliver の起動し直しにより子を起動する
- **THEN** `claude` に `--prompt-suggestions false` が渡り、設定ファイルや別の識別の仕組みを作らない

#### Scenario: Orca の空欄は画面だけでなく draft で確認する
- **WHEN** 前景の入力待ちで `status: running`、画面の `❯` は空で、draft が無い場合・空文字の場合・人の入力が入った場合・変更前に起動した子の提案文が入った場合を用意し、他の送信条件を満たす
- **THEN** 前の二つだけ送信可能とし、後の二つは `skipped input-not-empty`（exit 0）で入力を保持する

#### Scenario: 空のプロンプトと同居する実行中や選択画面には送らない
- **WHEN** 両部品で空の `❯` と共に、スピナー行、`Enter to select · ↑/↓ to navigate`、`Do you want to proceed?`、`Esc to cancel · Tab to amend`、`Enter to confirm · Esc to cancel` をそれぞれ観測する
- **THEN** スピナーは `skipped busy`、残りは `skipped dialog`（全て exit 0）となり、文字列も Enter も送らない

#### Scenario: バックグラウンドシェルは前景の入力待ちを妨げない
- **WHEN** 両部品で前景の入力待ち・空欄が確認でき、`· 1 shell still running` だけが残り、スピナーや選択画面が無く他の送信条件も満たす
- **THEN** 送信可能とし、送信確認に成功したときだけ `sent` を返す

#### Scenario: Orca の観測と送信の限定を守る
- **WHEN** Orca の keepalive を実行し、一覧が壊れている場合、画面が読めない場合、一意だが入力状態を決定できない場合、または送信直前の再観測で入力済みに変わった場合をそれぞれ用意する
- **THEN** 順に `failed terminal-list`（exit 1）/ `failed observe`（exit 1）/ `skipped unknown-state`（exit 0）/ `skipped input-not-empty`（exit 0）となり、send/create/close/wait は呼ばれない。送信可能な場合も許す呼び出しは list/read/send だけである

### Requirement: 記録の launcher ごとに起動部品を選ぶ

`epic-dispatch.sh` は、起動部品を操作の種類で次のとおり選ばなければならない（MUST）。

- **新しい子を起こす操作（`launch`・`adopt`）**: 環境変数 `EPIC_DISPATCH_LAUNCHER` が `orca` か `tmux` ならその部品、空なら Orca の部品の `here` が exit 0 のとき `orca`、環境変数 `TMUX` が空でなく `tmux` が PATH にあるとき `tmux`。選んだ部品の `available` が失敗したら、stdout に何も出さず、その部品の理由を stderr に出して exit 1 で終わる。空でどれも当たらなければ Orca の部品の `available` を呼び、今と同じ `orca is not on PATH` で exit 1 で終わる。`EPIC_DISPATCH_LAUNCHER` がそれ以外の値なら使い方を出して exit 1 で終わる。選んだ部品の名前を記録の `launcher` に書く
- **記録に従う操作（`reply`・`notify-closed`・`wait --resolve`・`reap`）**: 対象の子の記録の `launcher` が指す部品を先に決め、その部品の `available` で使えるかを判定する。環境変数 `EPIC_DISPATCH_LAUNCHER` と `TMUX` は見ない（記録が正本）。入口で 1 本の部品の `available` を全体に掛けて終えてはならない（MUST NOT）。対象の子の部品がすべて同じで使えないときは、stdout に何も出さず、その部品の理由を stderr に出して exit 1（記録の `launcher` が `orca` の子だけのときは今と同じ `orca is not on PATH`）。対象に記録の無い子しかないときは、Orca の部品の `available` を呼び、それが失敗したときに限って、stdout 空・旧 stderr（`orca is not on PATH`）・exit 1 で終わる。成功したら既存の結果を変えない（記録の無い子の `reap` は `gone <N>`・exit 0、`launch` の `skipped` など）。一部の子の部品だけが使えないときは、その子だけを `failed <N> launcher-unavailable`（`reply`・`notify-closed`）、`kept <N> launcher-unavailable`（`reap`）にして、ほかの子は進める
- `mark`・`wait --watch-stopped` の画面への写し（`mirror`）は、記録の `launcher` が `orca` のときだけ呼ぶ（既存の要件のまま）。部品の `available` で全体を止める規則は掛けない。記録の更新が成功すれば、部品が使えなくても（Orca 不在でも）次の既存の出力と終了規則のまま終わり、写せなければ既存どおり stderr に出すだけである: `mark` は `marked <N> <状態>`・exit 0、`wait --watch-stopped` は止まった子を受けたとき `stopped <N>`・exit 0（記録の `stop` は `stopped-seen` になる）
- 記録の `launcher` が `orca`・`tmux` のどちらでもない記録は、読めない記録と同じ扱いにする

この要件の検査（`EPIC_DISPATCH_LAUNCHER` と `TMUX` の分類、記録の `launcher` の分類、部品の `available` の判定）の守備範囲は次のとおりである。入力の出どころは、人が設定する環境変数 `EPIC_DISPATCH_LAUNCHER`・`TMUX`、`epic-state.sh` が書いた状態の記録の `launcher`、各部品の `available` の結果の 3 つである。拾いたい誤りは、`EPIC_DISPATCH_LAUNCHER` の打ち間違い（`zellij`・大文字の `TMUX` など。使い方を出して止める）、記録の `launcher` が知らない値であること（読めない記録にする）、使えない部品に子の操作を送ってしまうこと、別の部品で動く子まで巻き込んで全体を止めることである。次は通してよく、この要件では止めない: `TMUX` の中身（ソケットが生きているか）は確かめない／記録の `launcher` と今の環境が食い違う（Orca 管理下で `tmux` の記録の子を扱う、など）／Orca と tmux の子が混在するエピック。環境の崩れ方をすべて塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: tmux の中の launch は記録の launcher に tmux を書く
- **WHEN** `orca` が PATH に無く、`TMUX` が空でない環境で、同じリポジトリの子 1 件を `epic-dispatch.sh launch 1122 1123` で起動する
- **THEN** stdout は `launched 1123` で、記録の `launcher` は `tmux`、`session` は tmux のペイン ID である

#### Scenario: 記録の launcher の部品で閉じる
- **WHEN** 記録の `launcher` が `tmux` の子に `epic-dispatch.sh reap 1123` を実行する
- **THEN** `orca` のコマンドは 1 回も呼ばれず、tmux の部品の `close`・`remove` が呼ばれる

#### Scenario: 環境変数で部品を固定する
- **WHEN** Orca 管理のワークツリーかつ `TMUX` が空でない環境で、`EPIC_DISPATCH_LAUNCHER=tmux` を付けて `launch` する
- **THEN** 記録の `launcher` は `tmux` である

#### Scenario: 固定した部品が使えなければ launch は別の部品に振り替えず止まる
- **WHEN** Orca 管理のワークツリーで `TMUX` が空の環境で、`EPIC_DISPATCH_LAUNCHER=tmux` を付けて `launch 1122 1123` を実行する
- **THEN** stdout は空で、stderr に `tmux is not available` が出て、exit 1 である。`orca worktree create` は呼ばれない

#### Scenario: 使えない部品を環境変数で指しても、利用可能な部品の記録の子は扱える
- **WHEN** `EPIC_DISPATCH_LAUNCHER=orca` が置かれ、`orca` が PATH に無く、`TMUX` が空でない環境で、記録の `launcher` が `tmux` の子 1123 に `epic-dispatch.sh reap 1123` を実行する
- **THEN** `orca is not on PATH` で終わらず、tmux の部品の `close`・`remove` が呼ばれる

#### Scenario: 記録の無い子の reap は Orca が使えれば gone
- **WHEN** `orca` が PATH にあり、記録の無い（片付け済みの）子 1123 に `epic-dispatch.sh reap 1123` を実行する
- **THEN** stdout は `gone 1123`、exit 0 である。`orca` が PATH に無ければ stdout 空・stderr に `orca is not on PATH`・exit 1 である

#### Scenario: orca が無くても tmux の記録の子の mark は成功する
- **WHEN** `orca` が PATH に無く、記録の `launcher` が `tmux` の子のワークツリーで `epic-dispatch.sh mark stopped 1123` を実行する
- **THEN** 記録の `stop` は `stopped`、stdout は `marked 1123 stopped`、exit 0 である

#### Scenario: 混在するエピックでは使えない部品の子だけが止まる
- **WHEN** 記録の `launcher` が `orca` の子 11 と `tmux` の子 12 がいて、`orca` が PATH に無く、tmux の部品が使える環境で `epic-dispatch.sh reap 11 12` を実行する
- **THEN** 子 12 は tmux の部品で片付けられ、子 11 は `kept 11 launcher-unavailable` になる。exit code は `reap` の既存の規則に従う

### Requirement: tmux の部品は子を独立した Claude Code のセッションとして tmux のウィンドウに起動する

`plugins/dev-workflow/scripts/epic-launch-tmux.sh` は、要件「起動部品は epic-launch-<名前>.sh の 1 本ずつで、同じサブコマンドと出力の契約を持つ」の 13 個のサブコマンドを、`tmux` と `git` だけで実装しなければならない（MUST）。親が tmux で常駐していること（環境変数 `TMUX` が空でなく、`tmux` が PATH にある）を前提とし、`orca` を呼んではならない（MUST NOT）。開発に固有の語を入れてはならない（MUST NOT）。

| サブコマンド | tmux の部品の動き |
|---|---|
| `available` | `tmux` が PATH にあり `TMUX` が空でなければ exit 0。使えなければ stderr に `tmux is not available (run inside a tmux session)` を出して exit 1 |
| `here` | `available` と同じ条件なら `{"repo_id":"","worktree_id":""}` を出して exit 0、そうでなければ exit 1 |
| `prepare` | 何もせず exit 0 |
| `list`・`repos` | 何も出さず exit 0（記録が正本で、部品は子を知らない） |
| `unregistered` | stdout に `ok` |
| `create` | `repo_id` は読まない。ワークツリーは `git -C <clone か親のワークツリー> worktree add -b worktree-issue-<N> <リポジトリの最上位>/.claude/worktrees/issue-<N> origin/<起点>`（worktree プラグインの置き場と名前の決まり `<repo>/.claude/worktrees/<name>`・`worktree-<name>` に合わせる）。同じ名前のブランチかワークツリーが既にあれば作らず exit 1。作れたら `{"path","branch"}` の 1 行 |
| `start` | 同じ tmux サーバーに `tmux new-window -d -P -F '#{pane_id}' -c <ワークツリー>` でシェルを開き（起動コマンドを `new-window` に直接渡さない。対話でないシェルでは `cld` のシェル関数が解けないため）、起動コマンドを `send-keys -l` で打ち込んで Enter を送る。画面（`capture-pane`）の最下部（空行を除いた末尾の数行。行数は部品の先頭の定数）に Claude Code の入力待ちの印が出て、同じ最下部に許可・選択・信頼の確認画面の印が出ていない状態になるまで `EPIC_DISPATCH_READY_TIMEOUT_MS` を上限に待ち、最初の指示を `send-keys -l` で送って Enter（`send-keys` の `C-m`）を送る。起動して間もない Claude Code は最初の Enter を取りこぼすことがあるので、届くまで 4 秒ごとに Enter だけを重ねる（文は打ち直さない）。重ねる前に毎回画面の最下部を読み、入力待ちの印があり、確認画面の印が無く、送った文の先頭がまだ入力欄に残っているときだけ重ね、一度でも満たさなければ重ね送りをやめる（会話ログの確認は続ける。確認画面に Enter が選択として届くのを避けるため）。最初の指示を打つ前にも、最下部が入力待ちで確認画面が出ていないことを確かめ、そうでなければ何も打たずに `failed send` とする。印の文言（入力待ち・確認画面とも）は Claude Code 2.1.305 の画面で決めた定数で、版で変わると、入力待ちの印が当たらず `failed ready` で止まる（誤送信しない側）か、確認画面の印を見逃す（守る範囲の外）。送信が届いたかは、子のワークツリーの会話ログ（`${CLAUDE_PROJECTS_DIR:-~/.claude/projects}/<パスの英数字以外を - にした名前>/*.jsonl`）に、送る直前に控えた時刻より後の user の行が現れ、その本文が送った文の先頭 40 文字（40 文字に満たなければ全体。送った文が `/<コマンド>` で始まるときは、会話ログでコマンド名が `<command-name>` に展開されるので、コマンド名のうしろの引数の先頭 40 文字）を含むことを `EPIC_DISPATCH_SUBMIT_WAIT` 秒を上限に確かめる（時刻だけでなく本文と照合するので、別のセッションが同じログに書いた入力とは区別できる。検出できないのは、先頭 40 文字より後ろの欠けと、送った文と同じ先頭を持つ別の入力が同時に入ったときである）。届けば `started <ペイン ID>`、段ごとの失敗は `failed terminal|ready|send <ペイン ID>`（exit 1） |
| `deliver` | ウィンドウ（ペイン）の一覧を `tmux list-panes -a` で 1 回だけ読み、`#{pane_current_path}` が子のワークツリーのペインを探す。Claude Code が動いていること（`#{pane_current_command}` と画面の入力待ち）を確かめたペインがちょうど 1 つなら、同じ送り方で文を送り、会話ログで（`start` と同じ本文の照合で）届いたことを確かめて `sent`。ペインが無い、または `relaunch` が 1 なら、あるペインを `kill-pane` してから `start` と同じ手順で起動し直し、`relaunched <ペイン ID>`。シェルだけのペインしか無い・候補が 2 つ以上のときは `relaunch` が 0 なら `failed ambiguous-terminal` |
| `keepalive` | 引数・stdout/exit は共通の契約に従う。`tmux list-panes -a` の `pane_current_path`・`pane_current_command` と `tmux capture-pane -p -e -t <ペイン ID>` で既存の一意の Claude Code のペイン、前景の入力待ち、空欄、選択画面でないことを共通の画面判定に従って観測し、送信直前にも再確認する。`pane_current_command` が `bash` 等でも Claude Code の画面を確認できれば候補とし、シェル名だけでは除外しない。文字列は `tmux send-keys -t <ペイン ID> -l -- <text>`、Enter は `tmux send-keys -t <ペイン ID> C-m` で一度だけ送る。子の会話ログで `start` と同じ時刻・本文照合を `EPIC_DISPATCH_SUBMIT_WAIT` 秒の範囲で行い、到達すれば `sent`、未確認は `failed send`。観測は list-panes/capture-pane と会話ログの読み取りだけ、変更操作は既存ペインへのこの文字列と Enter の送信だけとし、new-window/kill-pane/git worktree/入力消去/Enter の再送は行わない |
| `close` | 子のワークツリーのペインを `tmux kill-pane` で閉じる。ペインが無ければ成功。閉じられなければ 1 回だけ閉じ直して、駄目なら exit 1 |
| `remove` | 子のワークツリーが属するリポジトリの本体のワークツリー（`git -C <ワークツリー> rev-parse --git-common-dir` の親）で `git worktree remove <ワークツリー>`（`--force` を付けない。ワークツリーの中から自分自身を消さない）。消せなければ理由の語 `rm-failed` を 1 行出して exit 1。`close` の成功後に `reap` が呼ぶ（`close` が失敗した子は `reap` が `kept close-failed` にして `remove` を呼ばない）。`epic-dispatch.sh` の `kept` の子を本体が確かめて消す操作（要件「別セッション方式の既存要件は…」）も同じ形で、本体が `bash epic-launch-tmux.sh remove <path>` を呼ぶ |
| `mirror` | 何もせず exit 0 |

この要件の検査（ペイン・画面・会話ログ・`git` の出力の分類）の守備範囲は次のとおりである。入力の出どころは、`epic-dispatch.sh` が検査済みで渡す引数と、`tmux`（`list-panes`・`capture-pane`・`new-window -P`）・`git`・子の会話ログの出力である。拾いたい誤りは、シェルのペインに指示を打ち込んで実行してしまうこと、Claude Code の入力待ちの表示が変わって黙って誤送信すること（`failed ready` にする）、送信が届いていないのに `started`・`sent` と言うこと、同じ名前のブランチ・ワークツリーを上書きすること、未コミットの変更があるワークツリーを消すことである。次は通してよく、この要件では止めない: 入力待ちの判定が画面の末尾の部分一致であること／`list-panes` の出力に改行を含むパスは無いと信じること／会話ログの user 行以外の形／送った文の先頭 40 文字より後ろの欠けと、同じ先頭を持つ別の入力が同時に入った場合（検出できない範囲として上の `start` の行に書いた）。`keepalive` は入力待ち・空欄の両方を観測できなければ送らず、画面の判定が未対応なら `skipped unknown-state`、読み取り失敗や壊れた出力なら `failed observe`（一覧なら `failed terminal-list`）とする。観測と送信の間の並行入力までは排除できない。tmux・画面・ログの崩れ方をすべて塞ぎ切ることは、この要件の完了条件としない。

送信の前に、送り先のペインで Claude Code が動いていることを確かめなければならない（MUST。シェルに指示を打ち込んで実行してしまう事故を避けるため）。送った文字列は `send-keys -l`（リテラル）で渡し、キー名として解釈させてはならない（MUST NOT）。

`start`・`deliver` が失敗したとき（`failed terminal`・`failed ready`・`failed send`）は、Orca の部品と同じく、共通手順が参照する作り直しか送り直しのコマンドを stderr に出さなければならない（MUST）。出す順は、先に確かめるコマンド、次にやり直すコマンドとする（確かめる前にやり直すと、動いている子を二重に起動する・届いている指示を二重に送る）。`failed send` は、ペインの入力欄を見る `tmux capture-pane -p -t <ペイン ID>` を先に出し、そのあとに `epic-launch-tmux.sh deliver <ワークツリー> 0 <送る文> <起動コマンド> <起動し直しの指示>` を `resend:` として出す。`failed terminal`・`failed ready` は、ワークツリーのペインを一覧する `tmux list-panes -a` を先に出し、残ったペインがあればそれを閉じる `tmux kill-pane -t <ペイン ID>`、次に `epic-launch-tmux.sh start <ワークツリー> <起動コマンド> <最初の指示> <子の呼び方>` を `create:` として出す。記録とワークツリーは残るので `launch` の再実行は `skipped` になることも添える。引数は単一引用符で囲む（MUST）。

#### Scenario: tmux の部品の送信失敗は確認のコマンドを先に、送り直しのコマンドを後に出す
- **WHEN** `epic-launch-tmux.sh start` が最初の指示を送ったが会話ログに現れず `failed send` で終わる
- **THEN** stderr に `tmux capture-pane -p -t <ペイン ID>` の行があり、そのあとの行に `deliver <ワークツリー> 0 <送る文> ...` を含む `resend:` の行がある

#### Scenario: tmux の部品は orca を呼ばない
- **WHEN** `orca` のスタブが呼ばれたら失敗する環境で、tmux の部品の全サブコマンドを実行する
- **THEN** `orca` は 1 回も呼ばれない

#### Scenario: start は起動コマンドをシェルに打ち込む
- **WHEN** tmux のスタブがある環境で `epic-launch-tmux.sh start /work/issue-5 'cld --model opus' '/develop #5' 5` を実行する
- **THEN** `tmux new-window -d -P -F '#{pane_id}' -c /work/issue-5` が引数にコマンドを付けずに 1 回呼ばれ、起動コマンドと最初の指示が `send-keys -l` で順に送られ、会話ログに送信後の user の行が現れたら stdout は `started <ペイン ID>`、exit 0 である

#### Scenario: シェルだけのペインには送らない
- **WHEN** 子のワークツリーのペインの `#{pane_current_command}` が `zsh` で、`relaunch` が 0 の環境で `deliver` を実行する
- **THEN** 何も送らず、stdout は `failed ambiguous-terminal`、exit 1 である

#### Scenario: remove は --force を付けない
- **WHEN** `epic-launch-tmux.sh remove /work/issue-5` を実行する
- **THEN** `git worktree remove /work/issue-5` が `--force` なしで 1 回呼ばれる

#### Scenario: 送信確認は本文と照合する
- **WHEN** 送った時刻より後に会話ログへ現れた user の行の本文が、送った指示の先頭 40 文字を含まない環境で `start` を実行する
- **THEN** `EPIC_DISPATCH_SUBMIT_WAIT` 秒待ったあと stdout は `failed send <ペイン ID>`、exit 1 である

#### Scenario: 別リポジトリの子は空の repo_id と clone で作られる
- **WHEN** `epic-launch-tmux.sh create /other/clone '' 5 main /work/parent` を実行する
- **THEN** `git -C /other/clone worktree add -b worktree-issue-5 /other/clone/.claude/worktrees/issue-5 origin/main` が呼ばれ（親のリポジトリには作らない）、stdout は `{"path","branch"}` の 1 行、exit 0 である。同じ引数で Orca の部品の `create` は呼ばれない

#### Scenario: 登録の無い別リポジトリの clone でも別リポジトリの子を起動できる
- **WHEN** `TMUX` が空でない環境で、`EPIC_DISPATCH_CLONES` に clone を書いた別リポジトリの子を `launch` に渡す
- **THEN** `unregistered` の `ok` で `not-in-orca` にならず、clone にワークツリーができて `launched <child>` になる

#### Scenario: keepalive は既存ペイン以外を変更しない
- **WHEN** tmux の keepalive で、ペイン無し・シェルだけ・複数候補・実行中・入力済み・選択画面・状態不明をそれぞれ観測する
- **THEN** `skipped <共通契約の理由>` と exit 0 を返し、send-keys/new-window/kill-pane/git worktree を呼ばない。送信可能な場合は list-panes/capture-pane・リテラル送信と C-m 一回・会話ログの確認だけで完結し、Orca は呼ばない

#### Scenario: tmux の薄字の提案文は空欄とみなせる
- **WHEN** `capture-pane -p -e` で前景の入力待ちを確認し、`❯ ` の後に薄字 `\e[2m` の提案文だけがある場合と、人が入力した文字がある場合をそれぞれ観測する
- **THEN** 提案文だけなら空欄とみなして送信してよい。人の入力があれば `skipped input-not-empty`（exit 0）で文字列も Enter も送らない

#### Scenario: シェル名だけで Claude Code の画面を除外しない
- **WHEN** keepalive の候補ペインの pane_current_command が bash だが、画面では Claude Code の前景の入力待ち・空欄を確認でき、他の送信条件を満たす
- **THEN** コマンド名だけでシェルのみと判断せず送信可能とする。Claude Code の画面を確認できないシェルだけのペインには送らない

#### Scenario: keepalive の送信直前に状態が変わる
- **WHEN** 初回は入力待ち・空欄だったが、送信直前の再観測では入力済みまたは選択画面になっている
- **THEN** `skipped input-not-empty` または `skipped dialog`（exit 0）となり、文字列も Enter も送らず入力を保持する

### Requirement: サブエージェント方式は状態の記録を書かない

サブエージェント方式（本体が W を `isolation: "worktree"` で起こして回す方式）は、状態の記録（`epic-state.sh` の書き込みと `epic-dispatch.sh` の `launch`・`mark`・`adopt`・`clear`）を使ってはならない（MUST NOT）。子の結果は本体が W の return で受ける。理由: W は親のセッションが終わると一緒に消えるので、記録があっても再開に使えず、独立したセッションを見張る目的（記録を読んで止まった子・終わった子を拾う）に当たらない。channel の挙動もこの要件では変えない。

#### Scenario: サブエージェント方式で記録のディレクトリができない
- **WHEN** `route` が `subagent` を返したエピックをサブエージェント方式で回す
- **THEN** `references/epic.md` の手順は `epic-dispatch.sh launch`・`mark`・`adopt` を呼ばず、`${EPIC_STATE_ROOT:-~/.claude/epic-state}` にそのエピックのディレクトリを作らない

### Requirement: wait --watch-done は推定した完了を記録に書き、Orca の印へ写す

`wait --watch-done` が dev-workflow-develop の要件「epic-dispatch.sh wait は完了の印の無いまま記録先が閉じて動きの止まった子を完了と推定する」の条件を満たした子について記録を書くときは、要件「記録は一時ファイルから置き換え、親と子の書き込みを排他する」の排他の中で、`status` が `running` で `stop` が `stopped` / `stopped-seen` でないことを確かめ直してから、`status` を `done` にし、次の 2 つの項目を足さなければならない（MUST）。

| 項目 | 型 | 中身 |
|---|---|---|
| `done_inferred_at` | 文字列 | 親が推定して書いた時刻。UTC の `YYYY-MM-DDTHH:MM:SSZ` |
| `done_inferred_last_activity` | 文字列 | 推定の根拠にした、子のトランスクリプトの最後の活動の `timestamp`（そのままの文字列） |

この 2 つは親が推定したときだけ書く項目で、子の `mark done` は書かない（MUST NOT）。読み手は知らない項目として無視してよく、記録の `schema` は `1` のままとする（MUST）。要件「子 1 ファイルの記録は決まった項目を持つ」の「読めない記録」の判定に、この 2 つの有無や形を加えてはならない（MUST NOT）。

確かめ直しで外れたとき（その間に子が `mark done`・`mark waiting`・`mark stopped` を付けた）は書かず、そのポーリングではその子を推定しない（MUST）。排他が取れない・書けないときは、`--watch-stopped` の書き換えと同じく、そのポーリングを失敗したポーリングに数える（MUST）。

書けたら、要件「Orca の部品は記録を書いたあとに Orca の印へ写す」に加えて、記録の `launcher` が `orca` のときは Orca の部品の `mirror <記録の worktree> done <記録のパス>` を呼ばなければならない（MUST。子の `mark done` と同じ `--workspace-status completed` の印になる）。写しに失敗しても書き込みを成功として扱う（MUST）。

#### Scenario: 推定した完了は排他つきで書かれ、推定の項目が付く
- **WHEN** 子 11 の記録が `status` `running`・`stop` 空・`extra: 1` を持ち、推定の条件を満たした状態で `wait --interval 0 --timeout 60 --watch-done 11` を実行する
- **THEN** 記録の `status` は `done`、`done_inferred_at` は UTC の形、`done_inferred_last_activity` はトランスクリプトの最後の `timestamp` で、`extra` と `schema` 1 は残り、`.lock` も一時ファイルも残っていない

#### Scenario: 確かめ直しで外れたら書かない
- **WHEN** 推定の条件を満たした子 11 で、推定の `gh` の呼び出しの間に記録の `status` が `waiting` に書き換わる状態で `wait --interval 0 --timeout 0 --watch-done 11` を実行する
- **THEN** stdout は `timeout`、記録の `status` は `waiting` のまま `done_inferred_at` は無く、`orca worktree set` は呼ばれない

#### Scenario: 残ったロックがあると推定は書かずに失敗したポーリングに数える
- **WHEN** 子 11 の記録の `.lock` ディレクトリを先に作り、`EPIC_STATE_LOCK_TIMEOUT=0` で、推定の条件を満たした状態で `wait --interval 0 --timeout 60 --watch-done 11` を実行する
- **THEN** 記録の `status` は `running` のまま、3 回のポーリングのあと stdout は `error workspaces` で exit 1 である

#### Scenario: Orca の部品の子は completed の印へ写す
- **WHEN** 記録の `launcher` が `orca` の子 11 の完了を推定する
- **THEN** `orca worktree set --worktree path:<子のワークツリー> --workspace-status completed` が 1 回呼ばれる（`epic-dispatch.sh` からは Orca の部品の `mirror` を通す）
