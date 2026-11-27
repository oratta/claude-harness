## MODIFIED Requirements

### Requirement: 親の見張りは記録だけで子の状態を判定する

`wait`・`pending-owner`・`reap`・`notify-closed`・`reply`・`dismiss` は、子の状態（完了の印・止まった印・受けた印）を記録の `status` と `stop` から読まなければならず、Orca のワークツリーの `workspaceStatus` と `comment` を判定に使ってはならない（MUST NOT）。例外として、`wait --watch-stopped` の止まりの検知と `owner-away` の判定（要件「主が打った返事待ちは時間がたったら親が主に知らせる」）と `wait`・`pending-owner` の再開の確かめは、記録の `worktree` の会話ログも読む（要件「wait は子の会話ログから止まった子を検知する」ほか。capability `dev-workflow-develop`）。子の記録は、要件「子を owner/repo#番号 で識別し、同じリポジトリの子は番号だけで書く」の親の見張りの照合で探す（MUST）。2 件以上なら、今の「同じ linkedIssue のワークツリーが 2 つ以上」と同じ扱い（`reap` は `kept <N> ambiguous`、`reply` / `notify-closed` / `dismiss` は `failed <N> ambiguous-worktree`、`wait` はその子の印を見ない）にする（MUST）。子 issue の state・`state_reason`・コメントを読む先も、同じ要件の `gh` の呼び出しの形に従う（MUST）。

- `wait --watch-done <N>`: 記録の `status` が `done` なら印が付いた子とする
- `wait --watch-stopped`: 閉じていない位置引数の子の記録の `stop` が `stopped`（会話ログを読めるときは要件「wait は印の付いた子をターンの終わりまで待って返す」の条件も満たす）か、会話ログの検知の条件を満たすなら、排他を取って `stopped-seen` に書き換え（`stop_uuid`・`stop_at` も同じ書き込みで書く）、書けたら止まった子とする。書けなければそのポーリングを失敗したポーリングに数える
- `pending-owner`: 記録の `stop` が `stopped-seen` の子を `pending <N>` で出す（`stop_uuid` があれば `pending <N> <uuid>`。会話ログが進んだ子は出さない）
- `notify-closed`: 記録が無ければ `skipped <N> no-worktree`、`status` が `done` なら `skipped <N> already-done`。`stop` の値（空・`stopped`・`stopped-seen`・`resumed`）と `status` が `running` か `waiting` かでは送るかを分けない（`skipped <N> not-stopped` は出さない。capability `dev-workflow-develop` の要件「Orca 経路の親は、止まった印のまま completed で閉じた子に完了を促す返事を送る」）
- `dismiss`: 記録の `stop` が `stopped-seen` で `stop_uuid` が空でない子を、排他を取って `resumed` に書き換える（`stop_uuid`・`stop_at` は変えない）。それ以外は `skipped <N> not-stopped`（要件「親は問いでない止まりを dismiss で再開に戻す」。capability `dev-workflow-develop`）
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

### Requirement: wait --watch-done は推定した完了を記録に書き、Orca の印へ写す

`wait --watch-done` が dev-workflow-develop の要件「epic-dispatch.sh wait は完了の印の無いまま記録先が閉じて動きの止まった子を完了と推定する」の条件を満たした子について記録を書くときは、要件「記録は一時ファイルから置き換え、親と子の書き込みを排他する」の排他の中で、`status` が `running` で `stop` が `stopped` でないことを確かめ直してから、`status` を `done` にし、次の 2 つの項目を足さなければならない（MUST）。`stop` が `stopped-seen` の子も書き込みの対象に含め、`stop`・`stop_uuid`・`stop_at`・`stop_turn` は変えてはならない（MUST NOT）。

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

#### Scenario: 親が受けた止まりのまま推定した完了は stop を変えない
- **WHEN** 子 11 の記録が `status` `running`・`stop` `stopped-seen`・`stop_uuid` `a-1` で、推定の条件を満たした状態で `wait --interval 0 --timeout 60 --watch-done 11` を実行する
- **THEN** 記録の `status` は `done` で `done_inferred_at` が付き、`stop` は `stopped-seen`・`stop_uuid` は `a-1` のまま残る

### Requirement: 主が打った返事待ちは時間がたったら親が主に知らせる

`wait --watch-stopped` は、閉じていない位置引数の子の記録が、`status` が `done` でなく、有効な `turn_input` の `sender` が `owner`、同じ世代・セッションの有効な `turn_state` の値が `主の返事待ち`、`turn_state.recorded_at` から `EPIC_DISPATCH_OWNER_AWAY_SEC`（既定 3600 秒）以上たち、`owner_away_told` が今回のターンと違うときに、その子を `owner-away <N>...` の行で返さなければならない（MUST）。ただし、記録の `worktree` の会話ログ（`child-log-read.py` が選ぶ本体のログ 1 本）を読め、その `session` が空でなく `turn_state.session_id` と違い、その `last_input_at` が `turn_state.recorded_at` より新しいときは、子は新しいセッションで再開されていて古いセッションの返事待ちは終わっているので、返してはならず `owner_away_told` も書いてはならない（MUST NOT）。会話ログを読めない・`python3` が無い・`session` か `last_input_at` が空のときは、この除外を当てず今までどおり判定する（MUST）。時刻は秒の単位で比べる（`last_input_at` の小数秒は切り捨てる）。会話ログは `owner-away` の他の条件を満たした子についてだけ読む（MUST）。出力は `closed` / `done` / `stopped` と同じく該当する語の行を並べて exit 0 で終わる。`EPIC_DISPATCH_OWNER_AWAY_SEC` が非負整数でなければ、何も呼ばずに使い方を出して exit 1 で終わる（MUST）。

#### Scenario: 既定の時間を過ぎた主の返事待ちを知らせる
- **WHEN** 子 11 の `turn_input.sender` が `owner`、`turn_state` が有効な `主の返事待ち` で `recorded_at` が 3600 秒以上前の状態で `epic-dispatch.sh wait --interval 0 --timeout 0 --watch-stopped 11` を実行する
- **THEN** stdout は `owner-away 11`、exit 0 で、子への送信・`orca terminal close`・`--relaunch` は呼ばれず、記録の `stop` は変わらない

#### Scenario: 時間より前は知らせない
- **WHEN** 同じ記録の `recorded_at` が 3600 秒に満たない状態で同じコマンドを実行する
- **THEN** stdout は `timeout 11`、exit 2 である

#### Scenario: 環境変数で時間を変えられる
- **WHEN** `EPIC_DISPATCH_OWNER_AWAY_SEC=60` で `recorded_at` が 120 秒前の記録に同じコマンドを実行する
- **THEN** stdout は `owner-away 11` である。同じ記録で `EPIC_DISPATCH_OWNER_AWAY_SEC=7200` なら `timeout 11` である

#### Scenario: 主が新しく入力したら知らせない
- **WHEN** 主が新しく入力して `turn_input` の世代が `turn_state` と違う記録に同じコマンドを実行する
- **THEN** `owner-away` は返らない

#### Scenario: 新しいセッションで再開した子の古い返事待ちは知らせない
- **WHEN** 子 11 の `turn_input.sender` が `owner`、`turn_state` が有効な `主の返事待ち` で `session_id` が `s-old`・`recorded_at` が 3600 秒以上前、子のワークツリーの最新の会話ログの `sessionId` が `s-new` でその主の入力の `timestamp` が `recorded_at` より新しい状態で `epic-dispatch.sh wait --interval 0 --timeout 0 --watch-stopped 11` を実行する
- **THEN** stdout は `timeout 11`、exit 2 で、記録に `owner_away_told` は書かれない

#### Scenario: 会話ログが同じセッションなら今までどおり知らせる
- **WHEN** 同じ記録で、最新の会話ログの `sessionId` が `turn_state.session_id` と同じか、会話ログが読めない状態で同じコマンドを実行する
- **THEN** stdout は `owner-away 11`、exit 0 である

### Requirement: owner-away の守備範囲を限る

上の 2 つの要件（主が打った返事待ちの知らせ・owner-away の一度きりの記録）は、入力として扱うものを、子の記録の `turn_input` / `turn_state` / `owner_away_told` / `worktree`、その `worktree` の会話ログの `session` と `last_input_at`、`EPIC_DISPATCH_OWNER_AWAY_SEC` の値に限らなければならない（MUST）。拾いたい誤りは、主が話している最中の子への送信と端末の終了、同じ問いの繰り返しの知らせ、主が答えたあとの知らせ、子を新しいセッションで再開したあとに古いセッションの返事待ちを知らせることである。次は通してよく、止めない: 親や起動時の入力のターン（既存の停止の経路で扱う）・状態記録の無い古い子（知らせない）・別の経路で解決済みの問いへの余分な 1 回の知らせ・会話ログを読めない子の古いセッションの返事待ちの知らせ・新しいセッションに主の入力がまだ無い子の古い返事待ちの知らせ。穴が見つかるたびに塞ぎ切ることは完了条件にしない。

#### Scenario: 親が送った入力のターンと古い子は知らせの対象にしない
- **WHEN** `turn_input.sender` が `parent` の返事待ち、または `turn_input` / `turn_state` の無い記録に `wait --watch-stopped` を実行する
- **THEN** `owner-away` は返らない（前者は既存の `stopped` の経路、後者は何も返さない）
