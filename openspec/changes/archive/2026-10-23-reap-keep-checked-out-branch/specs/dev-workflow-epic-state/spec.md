## MODIFIED Requirements

### Requirement: 親の見張りは記録だけで子の状態を判定する

`wait`・`pending-owner`・`reap`・`notify-closed`・`reply` は、子の状態（完了の印・止まった印・受けた印）を記録の `status` と `stop` から読まなければならず、Orca のワークツリーの `workspaceStatus` と `comment` を判定に使ってはならない（MUST NOT）。子の記録は、要件「子を owner/repo#番号 で識別し、同じリポジトリの子は番号だけで書く」の親の見張りの照合で探す（MUST）。2 件以上なら、今の「同じ linkedIssue のワークツリーが 2 つ以上」と同じ扱い（`reap` は `kept <N> ambiguous`、`reply` / `notify-closed` は `failed <N> ambiguous-worktree`、`wait` はその子の印を見ない）にする（MUST）。子 issue の state・`state_reason`・コメントを読む先も、同じ要件の `gh` の呼び出しの形に従う（MUST）。

- `wait --watch-done <N>`: 記録の `status` が `done` なら印が付いた子とする
- `wait --watch-stopped`: 閉じていない位置引数の子の記録の `stop` が `stopped` なら、排他を取って `stopped-seen` に書き換え、書けたら止まった子とする。書けなければそのポーリングを失敗したポーリングに数える
- `pending-owner`: 記録の `stop` が `stopped-seen` の子を `pending <N>` で出す
- `notify-closed`: 記録が無ければ `skipped <N> no-worktree`、`status` が `done` なら `skipped <N> already-done`、`stop` が `stopped` / `stopped-seen` でなければ `skipped <N> not-stopped`
- `reap`: 記録が無い子と、記録の `worktree` のディレクトリが無い（`[ -d <worktree> ]` が偽）子は `gone <N>`（後者は記録を消す）。`status` が `done` でなければ `kept <N> not-done`。それ以外の安全確認の中身は今と同じにする。`gh pr list`・`git ls-remote`・`git fetch` などの呼び出しの形は、記録の `repo` が記録の `epic` のリポジトリと同じ子は今と同じにし（MUST）、違う子は次のとおりにする（MUST）。PR の照会に `-R <記録の repo>` を付ける。base の名前は記録の `base` を使う（同じリポジトリの子は今のまま `${EPIC_DISPATCH_BASE:-main}`）。base の照会（`git ls-remote origin refs/heads/<base>`・`git fetch origin <base>`）を子のワークツリーの origin（`git -C <記録の worktree> ...`）に向け、base の先端はリポジトリと base の組ごとに 1 回読む（同じリポジトリの子の照会は今のまま 1 回で、別のリポジトリの子の先端を使い回さない。混ぜて渡した `reap` で同じリポジトリの子が `kept <N> base-lookup-failed` に落ちない）。`git cat-file -e` は `git -C <記録の worktree>` で行う。ブランチの片付け（`git rev-parse refs/heads/<branch>`・`git worktree list --porcelain`・`git update-ref -d`）は子の clone に向け、`orca worktree rm` の前に `git -C <記録の worktree> rev-parse --path-format=absolute --git-common-dir` で clone を控えておき、rm のあとはそれを `git -C` に使う（rm のあとはワークツリーのディレクトリが無い）。`kept <N> not-child` は出さない
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
- **THEN** 子 12 の base の照会は今と同じ `git ls-remote origin refs/heads/main` で、子 12 が `kept 12 base-lookup-failed` にならず、`git update-ref -d` は子 `genetta-inc/flatmate#1615` については子の clone（rm の前に控えた git-common-dir）に対して呼ばれる

#### Scenario: 別の親の記録は見ない
- **WHEN** 子 12 の記録の `parent_worktree` が今のワークツリーと違い、`status` が `done` の状態で `epic-dispatch.sh reap 12` を実行する
- **THEN** stdout は `gone 12` で、そのワークツリーは消されない
