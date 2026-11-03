## MODIFIED Requirements

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
| `stop_uuid` | 文字列 | 親の `wait` が止まりとして受けた最後の子の発言の uuid（任意。無ければ空として読む） |
| `stop_at` | 文字列 | 親の `wait` が止まりとして受けた UTC の時刻（任意。無ければ空として読む） |
| `created_at` / `updated_at` | 文字列 | UTC の `YYYY-MM-DDTHH:MM:SSZ` |

`status` は今のボードの列（`running` は印なし、`waiting` は `in-review`、`done` は `completed`）に、`stop` は今のコメント欄（`stopped` は `epic-stopped`、`stopped-seen` は `epic-stopped-seen`、`resumed` は `epic-resumed`）に当たり、値の遷移は今の印と同じにしなければならない（MUST）。ただし `stop` は子の `mark` に加えて親の `wait` と `dismiss` も書き（`wait` は空・`resumed` から `stopped-seen`、`stopped-seen` から `resumed`。`dismiss` は `stopped-seen` から `resumed`）、`resumed` への書き換えも Orca の印へ写す（MUST）。`stop_uuid` と `stop_at` は親の `wait` だけが書き（MUST）、子の `mark` と `dismiss` は変えない（MUST NOT）。止まった理由の本文は記録に持たず、子 issue の `子の停止: 主の返事待ち` のコメントを正本のままにする。そのコメントを持たない止まりでは、子の最後の発言を正本とする。`session` はこの版では Orca の `launch` と、起動し直した `reply`（`notify-closed`・`wait --resolve` の起動し直しを含む）が端末のハンドルを書き、`adopt` は空のまま書く（見張りの判定には使わない）。

次のどれかに当たる記録は「読めない記録」とする: JSON のオブジェクトとして読めない／`schema` が `1` でない／`status` か `stop` が上の表に無い値／`epic`・`child`・`repo`・`number`・`parent_worktree`・`worktree` のどれかが無いか型が違う／`stop_uuid`・`stop_at` があって文字列でない。読めない記録は書き換えも削除もしてはならず（MUST NOT）、サブコマンドごとに次のとおり扱わなければならない（MUST）。どの場合も stderr にその記録のパスを出す。

| サブコマンド | 読めない記録の扱い |
|---|---|
| `wait` | その子の印を読めなかったポーリングとして、今の「一覧を読めない」と同じく失敗したポーリングに数える（3 回続けば `gh` で失敗した子がいなければ `error workspaces`） |
| `reap` | `kept <N> state-unreadable`（何も消さない） |
| `pending-owner` | その子を飛ばす（`pending` を出さない） |
| `notify-closed`・`reply`・`dismiss` | `failed <N> state-unreadable` |
| `launch` | その子自身の記録なら `failed <N> state-unreadable`（作り直さない）。枠の数では、ほかの子の読めない記録を使用中の 1 枠に数える |
| `adopt` | `failed <N> state-unreadable` |
| `clear` | 消す対象のエピックのディレクトリにある読めない記録は、stderr に `remaining state record: unreadable (<パス>)` と出してからディレクトリごと消す（ディレクトリ単位の削除で、個別の書き換え・削除はしない） |
| `mark`・`route`（今のワークツリーのパスで探すとき） | その記録を候補から外す |

この要件の守備範囲で入力として扱うのは、`launch`・`adopt`・`mark`・`wait`・`dismiss` 自身が書いた記録のファイルで、人が手で書く想定はしない。拾いたい誤りは、書き込みの途中で殺されたプロセスや版の違うスクリプトが残した記録を、正しい状態として読んで子を片付けたり見張りから落としたりすることである。次は通してよく、この要件では止めない: 項目の値どうしの矛盾（`child` の番号と `number` が違う・`worktree` が別のリポジトリを指す）／`created_at` と `updated_at` の形の崩れ／`mark`・`route` が読めない記録を候補から外したために、その子が自分を `no-workspace` と判定すること（一時ファイルからの置き換えで途中まで書かれた記録は生じないので、起きるのは人が手で壊したときだけ）。壊れ方を見つけるたびに検査を足して塞ぎ切ることは、この要件の完了条件としない。

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

#### Scenario: 止まりの項目が無い記録も読める
- **WHEN** `stop_uuid` と `stop_at` の無い以前の記録を `wait` と `pending-owner` が読む
- **THEN** 読めない記録にならず、どちらも空として扱う
