## ADDED Requirements

### Requirement: エピックの状態は子ごと 1 ファイルのローカルの記録に置く

エピックの子の状態の正本は、`${EPIC_STATE_ROOT:-$HOME/.claude/epic-state}/<エピックの owner>.<エピックの repo>-<エピック番号>/<子の owner>.<子の repo>-<子の番号>.json` に子ごと 1 ファイルで置かなければならない（MUST）。エピックの `<owner>/<repo>` は、親のワークツリーの `git remote get-url origin`（`git@github.com:<o>/<r>.git`・`https://github.com/<o>/<r>(.git)` の形）から読む。読めなければ記録を書かずに stderr に理由を出して exit 1 で終わる（MUST）。記録を `~/.claude/projects/` の配下に置いてはならない（MUST NOT）。記録は PC をまたいで共有しない。

`plugins/dev-workflow/tests/epic-dispatch.bats` は `EPIC_STATE_ROOT` を一時ディレクトリに向け、実在のホームの下に書かずに下の Scenario を確かめなければならない（MUST）。

#### Scenario: launch が記録を決まった場所に作る
- **WHEN** origin が `git@github.com:oratta/claude-harness.git` の親のワークツリーで `epic-dispatch.sh launch 1122 1123` を実行し、子のワークツリーができる
- **THEN** `$EPIC_STATE_ROOT/oratta.claude-harness-1122/oratta.claude-harness-1123.json` があり、`~/.claude/projects/` の下には何も書かれていない

#### Scenario: origin を読めなければ記録を書かない
- **WHEN** origin の無いリポジトリで `epic-dispatch.sh launch 1122 1123` を実行する
- **THEN** 記録は作られず、子のワークツリーも作られず、exit 1 である

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

`status` は今のボードの列（`running` は印なし、`waiting` は `in-review`、`done` は `completed`）に、`stop` は今のコメント欄（`stopped` は `epic-stopped`、`stopped-seen` は `epic-stopped-seen`、`resumed` は `epic-resumed`）に当たり、値の遷移は今の印と同じにしなければならない（MUST）。止まった理由の本文は記録に持たず、子 issue の `子の停止: 主の返事待ち` のコメントを正本のままにする。

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

この change の `launch` は、エピックと別のリポジトリの子を受けたら、記録もワークツリーも作らず、枠も使わずに `failed <owner>/<repo>#<N> other-repo` を出さなければならない（MUST）（別のリポジトリにワークツリーを作るのは後続の change）。

#### Scenario: 同じリポジトリの子の出力は今と同じ
- **WHEN** 子 11 が閉じている状態で `epic-dispatch.sh wait --interval 0 --timeout 0 11` を実行する
- **THEN** stdout は `closed 11` である

#### Scenario: owner/repo#番号 で渡した子はその形で返る
- **WHEN** エピックと別のリポジトリ `genetta-inc/flatmate` の子 1615 の記録があり、その issue が閉じている状態で `epic-dispatch.sh wait --interval 0 --timeout 0 genetta-inc/flatmate#1615` を実行する
- **THEN** `gh` は `repos/genetta-inc/flatmate/issues/1615` を読み、stdout は `closed genetta-inc/flatmate#1615` である

#### Scenario: launch は別のリポジトリの子を作らない
- **WHEN** origin が `oratta/claude-harness` の親のワークツリーで `epic-dispatch.sh launch 1122 genetta-inc/flatmate#1615` を実行する
- **THEN** stdout は `failed genetta-inc/flatmate#1615 other-repo` で、`orca worktree create` は呼ばれず、記録は作られず、exit 1 である

#### Scenario: 番号でも数字でも owner/repo#番号 でもない引数は使い方を出す
- **WHEN** `epic-dispatch.sh wait foo` を実行する
- **THEN** stderr に使い方が出て exit 1 である

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

`wait`・`pending-owner`・`reap`・`notify-closed`・`reply` は、子の状態（完了の印・止まった印・受けた印）を記録の `status` と `stop` から読まなければならず、Orca のワークツリーの `workspaceStatus` と `comment` を判定に使ってはならない（MUST NOT）。子の記録は、`parent_worktree` が今いるワークツリーの最上位のパスと一致し、`child` が引数の子と一致するものを探す（MUST）。2 件以上なら、今の「同じ linkedIssue のワークツリーが 2 つ以上」と同じ扱い（`reap` は `kept <N> ambiguous`、`reply` / `notify-closed` は `failed <N> ambiguous-worktree`、`wait` はその子の印を見ない）にする（MUST）。子 issue の state・`state_reason`・コメントは、記録の `repo`（記録が無ければエピックのリポジトリ）に対して `gh api repos/<owner>/<repo>/issues/<N>` で読まなければならない（MUST）。

- `wait --watch-done <N>`: 記録の `status` が `done` なら印が付いた子とする
- `wait --watch-stopped`: 閉じていない位置引数の子の記録の `stop` が `stopped` なら、排他を取って `stopped-seen` に書き換え、書けたら止まった子とする。書けなければそのポーリングを失敗したポーリングに数える
- `pending-owner`: 記録の `stop` が `stopped-seen` の子を `pending <N>` で出す
- `notify-closed`: 記録が無ければ `skipped <N> no-worktree`、`status` が `done` なら `skipped <N> already-done`、`stop` が `stopped` / `stopped-seen` でなければ `skipped <N> not-stopped`
- `reap`: 記録が無い子と、記録の `worktree` がもう無い子は `gone <N>`（後者は記録を消す）。`status` が `done` でなければ `kept <N> not-done`。それ以外の安全確認は今と同じで、PR の照会は `gh pr list -R <repo>`、base の照会は子のワークツリーの `origin` に対して行う。`kept <N> not-child` は出さない
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

`launch`・`mark`・`wait --watch-stopped` は、記録を書いたあと、子のワークツリーが Orca 管理のときは今と同じ Orca の印（`mark done` / `waiting` は `--workspace-status completed` / `in-review`、`stopped` / `resumed` は `--comment epic-stopped` / `epic-resumed`、受けた印は `--comment epic-stopped-seen`）を写さなければならない（MUST）。写しに失敗しても記録の書き込みを成功として扱い、出力を変えずに stderr に写せなかったことを出さなければならない（MUST）。

#### Scenario: 写しに失敗しても mark は成功
- **WHEN** `orca worktree set` が非 0 で終わる環境で、子のワークツリーで `epic-dispatch.sh mark done 1123` を実行する
- **THEN** 記録の `status` は `done`、stdout は `marked 1123 done`、exit 0 で、stderr に写せなかったことが出る

#### Scenario: Orca 管理外では写さない
- **WHEN** `orca` が PATH に無い環境で、記録のある子のワークツリーで `epic-dispatch.sh mark stopped 1123` を実行する
- **THEN** 記録の `stop` は `stopped`、stdout は `marked 1123 stopped`、exit 0 である

### Requirement: adopt は記録の無い Orca の子を記録に取り込む

`epic-dispatch.sh adopt <epic> <child>...` は、記録の無い子ごとに、`orca worktree list --json` の、`repoId` が今のワークツリーと同じ・`linkedIssue` が子・`isArchived` が true でない・`parentWorktreeId` が今のワークツリーの id のワークツリーを探さなければならない（MUST）。ちょうど 1 つなら、その `path`・`branch` と、`workspaceStatus`（`completed` → `done`、`in-review` → `waiting`、それ以外 → `running`）と `comment`（`epic-stopped` → `stopped`、`epic-stopped-seen` → `stopped-seen`、`epic-resumed` → `resumed`、それ以外 → 空）を写した記録を作り、`adopted <N>` を出す。記録が既にあれば `skipped <N>`、該当が無ければ `none <N>`、2 つ以上なら `failed <N> ambiguous` を出す（MUST）。`orca`・`jq` が無い・Orca 管理外・一覧を読めないときは記録を作らずに exit 1。`failed` があれば exit 1、無ければ exit 0。

#### Scenario: 止まった印の Orca の子を取り込む
- **WHEN** 記録が無く、Orca の一覧に親が今のワークツリーで `linkedIssue` が 11・`comment` が `epic-stopped-seen` のワークツリーがある状態で `epic-dispatch.sh adopt 1122 11` を実行する
- **THEN** 記録の `stop` が `stopped-seen`、`status` が `running`、`worktree` が一覧の `path` で作られ、stdout は `adopted 11`、exit 0 である

#### Scenario: 記録がある子は取り込まない
- **WHEN** 子 11 の記録がある状態で `epic-dispatch.sh adopt 1122 11` を実行する
- **THEN** 記録は変わらず、stdout は `skipped 11` である

### Requirement: 記録は片付けた子ごとに消し、エピックの完了時にディレクトリごと消す

`reap` は `reaped <N>`（`branch-kept` を含む）と、記録はあるが子のワークツリーがもう無いときの `gone <N>` を出した子の記録を消さなければならない（MUST）。`epic-dispatch.sh clear <epic>` は、エピックの `<owner>/<repo>#<E>` から組み立てたディレクトリ名が `EPIC_STATE_ROOT` 直下にあれば、残っている記録の子を stderr に出してからディレクトリを消し、`cleared <epic>` を出して exit 0、無ければ `none <epic>` を出して exit 0 で終わらなければならない（MUST）。組み立てた名前が `/` か `..` を含むときと、`EPIC_STATE_ROOT` が空のときは何も消さずに exit 1。

#### Scenario: reap で片付けた子の記録が消える
- **WHEN** 安全確認を全部通る子 12 で `epic-dispatch.sh reap 12` が `reaped 12` を出す
- **THEN** 子 12 の記録のファイルは無い

#### Scenario: clear で状態のディレクトリが消える
- **WHEN** エピック 1122 の状態ディレクトリに記録が 1 件残っている状態で `epic-dispatch.sh clear 1122` を実行する
- **THEN** ディレクトリは無く、stdout は `cleared 1122`、stderr に残っていた子が出て、ほかのエピックのディレクトリは残っている

#### Scenario: 無いディレクトリの clear
- **WHEN** エピック 1122 の状態ディレクトリが無い状態で `epic-dispatch.sh clear 1122` を実行する
- **THEN** stdout は `none 1122`、exit 0 である

### Requirement: launch は子のワークツリーを作る前に記録を書く

`launch` は、子ごとに、記録があれば（`worktree` が空でない）`skipped <N>` とし、無ければ（`deferred` の判定のあと）`status` が `running`・`worktree` が空の記録を書いてから子のワークツリーを作らなければならない（MUST）。ワークツリーの作成に失敗したら記録を消し（MUST）、作れたら `worktree`・`branch` を書き足す。ワークツリーを作ったあとで端末・起動待ち・送信に失敗したら、記録を残して `launch_failed` に段の名前を書く（MUST）。Orca の一覧に同じ子のワークツリーがあって記録が無いとき（この変更の前に起動した子）は、今と同じく `skipped <N>` とし、記録は作らない（取り込みは `adopt`）。

#### Scenario: 作成に失敗したら記録が残らない
- **WHEN** `orca worktree create` が非 0 で終わる環境で `epic-dispatch.sh launch 1122 11` を実行する
- **THEN** stdout は `failed 11` で、子 11 の記録は無い

#### Scenario: 送信に失敗したら記録が残り次の launch では skipped
- **WHEN** `orca terminal send` の stages に `turn_started` が無い環境で `epic-dispatch.sh launch 1122 11` を実行し、続けてもう一度実行する
- **THEN** 1 回目の stdout は `failed 11` で記録の `launch_failed` は `send`、2 回目の stdout は `skipped 11` である

### Requirement: 同時に枠を使う子は記録から数える

#1106（PR #1120）が `launch` に入れる同時に枠を使う子の上限について、枠を使っている子は、今のワークツリーを `parent_worktree` に持つ記録のうち、`status` が `done` でなく、`stop` が `stopped` / `stopped-seen` でなく、記録の `repo` に対する issue の state が `closed` でないものとして数えなければならない（MUST）。state を読めない子は数える。上限の値の決め方（`max-parallel`）・`deferred <N>` の出し方・「`create` に進んだ子は結果によらず 1 枠を使う」は #1120 の要件のまま変えない（MUST）。起動部品は上限を知らず、上限は記録と見張りの側で決める。

#### Scenario: 記録で数えた使用中の数で後回しを決める
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=2` で、`status` が `running`・`stop` が空・issue が open の記録が 1 件、`status` が `done` の記録が 1 件、`stop` が `stopped-seen` の記録が 1 件ある状態で `epic-dispatch.sh launch 1122 21 22` を実行する
- **THEN** 使用中は 1 件で、stdout は `launched 21` と `deferred 22` である

#### Scenario: Orca の一覧の印は数え方に効かない
- **WHEN** `EPIC_DISPATCH_MAX_PARALLEL=1` で、記録の無い Orca のワークツリー（親が今のワークツリー・印なし）が 1 つある状態で `epic-dispatch.sh launch 1122 21` を実行する
- **THEN** 使用中は 0 件で、stdout は `launched 21` である
