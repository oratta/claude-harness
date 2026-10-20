## ADDED Requirements

### Requirement: Orca の印を正本にした既存要件を状態の記録の項目で読み替える

`epic-dispatch.sh` の既存要件のうち、子の状態を Orca のワークツリーのメタデータから読み書きすると書いた箇所は、capability `dev-workflow-epic-state` の状態の記録の項目を読み書きするものとして読まなければならない（MUST）。読み替えは次の表のとおりで、出力の行・exit code・失敗したポーリングの数え方・`--resolve` の判断と送り方・`reap` の安全確認の中身は、表の読み替えのほかは既存要件のまま変えない（MUST）。

| 既存要件の書き方 | 読み替え |
|---|---|
| ボードの列 `workspaceStatus` が `completed`（`mark done`） | 記録の `status` が `done` |
| ボードの列 `workspaceStatus` が `in-review`（`mark waiting`） | 記録の `status` が `waiting` |
| コメント欄 `comment` が `epic-stopped` / `epic-stopped-seen` / `epic-resumed` | 記録の `stop` が `stopped` / `stopped-seen` / `resumed` |
| `orca worktree set --worktree current ...` で印を付ける | 今いるワークツリーのパスで見つけた自分の記録を書き換え、そのあと Orca の印へ写す（写しの失敗は成功扱い） |
| `orca worktree set --worktree path:<子> --comment epic-stopped-seen` で受けた印を付ける | 子の記録の `stop` を排他つきで `stopped-seen` に書き換え、そのあと Orca の印へ写す |
| 一覧の `repoId` が同じ・`linkedIssue` が子・`isArchived` が true でない・`parentWorktreeId` が今のワークツリーのワークツリー | `parent_worktree` が今のワークツリーで `child` が子の記録 |
| 「同じ linkedIssue のワークツリーが 2 つ以上」 | 「同じ親のワークツリー・同じ子の記録が 2 件以上」 |
| ポーリングごとに `orca worktree list --json` を 1 回呼ぶ | ポーリングごとに渡された子の記録を 1 回ずつ読み、`orca worktree list` は呼ばない |
| `route` / `launch` の子の判定に使う `parentWorktreeId` と親のワークツリーの `linkedIssue` | 今いるワークツリーのパスを `worktree` に持つ記録と、その `epic`（環境変数 `EPIC_DISPATCH_PARENT_EPIC` を先に見る規則は変えない） |
| `gh api repos/{owner}/{repo}/issues/<N>` | 記録の `repo` がエピックと同じリポジトリの子と記録の無い子は今のまま。違うリポジトリの子だけ `gh api repos/<repo>/issues/<N>`。`reap` の `gh pr list`・`git ls-remote` の呼び出しの形はこの change では変えない |
| `reap` の `kept <N> not-child` | 出さない（親は自分の `parent_worktree` の記録しか見ない。記録の無い子は `gone <N>`） |
| `mark` の「`orca` が PATH に無いか `orca worktree current --json` が非 0 なら `skipped <issue> no-workspace`」と「印の代わりになるもの（ファイルなど）を作ってはならない」 | 今いるワークツリーのパスを `worktree` に持つ記録が無ければ `skipped <issue> no-workspace`。記録は印の代わりではなく正本で、`mark` は記録を作らない（作るのは `launch` と `adopt` だけ）。`orca` の有無は Orca の印へ写すかどうかだけを決める |
| 「Orca が無い環境のための代わりの実装を持ってはならない」 | 状態の記録は Orca の機能の代わりの実装ではない（Orca の有無によらず正本として書く）。記録を読み書きする新しいスクリプト `scripts/epic-state.sh` は `orca` の語を含まず、`orca` を呼ぶスクリプトは今のまま `scripts/epic-dispatch.sh` 1 本だけ |
| #1106（PR #1120）の、枠を使っている子を Orca の一覧から数える条件 | 同じ条件を記録の項目に置き換えて数える（capability `dev-workflow-epic-state` の要件「同時に枠を使う子は記録から数える」） |

この読み替えは、少なくとも次の既存要件に掛かる: 「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」（`launch` の記録の書き込みと、`route` の判定）・「エピックの並列起動は 1 段で止める」（子のセッションの判定）・「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」（`mark done` / `waiting`・`wait --watch-done`・`reap`）・「Orca 経路の本体は印が付いた子のワークスペースを片付ける」（`kept <N> not-child` の扱いは起きなくなる。`--watch-done` / `--watch-stopped` を付けた `wait` が stdout に何も出さず exit 1 で終わったときの規定は、`wait` が Orca を読まなくなるので、`launch` が exit 1 で子を 1 件も作らなかったときと `adopt` が stdout に何も出さず exit 1 で終わったときの規定として読む）・「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」（記録は代わりの実装に数えない）・「エピックの子への注意書きと子であることを、起動し直したセッションにも引き継ぐ」（`route` の `parentWorktreeId` の判定）・「epic-dispatch.sh は子が止まった印を付け、wait が止まった子を返す」・「epic-dispatch.sh の wait は止まった子を判断し、通すものには返事を送って待ちを続ける」・「epic-dispatch.sh reply は子の端末に送り手を付けた返事を届ける」（子のワークツリーの見つけ方）・「epic-dispatch.sh reap は PR が無く issue を閉じた子を、main に入っていない commit が無いときに片付ける」・「Orca 経路の親は、止まった印のまま completed で閉じた子に完了を促す返事を送る」・「起動し直した親は主の返事待ちの子を主に出し直す」（`pending-owner` は記録の `stop` が `stopped-seen` の子を出す）・「wait --resolve は通す返事を送る前に起動し直すかを表で決める」（子のワークツリーの `path` は記録の `worktree` から読む）、および #1120 がこの capability に足す上限の要件。

既存要件の Scenario のうち、スタブの Orca の一覧の `workspaceStatus` / `comment` を置いて状態を決めているものは、同じ値を記録の `status` / `stop` に置いたものとして確かめなければならない（MUST）。`plugins/dev-workflow/tests/epic-dispatch.bats` の該当するテストは、記録を一時ディレクトリ（`EPIC_STATE_ROOT`）に作って同じ出力を確かめる形に直す。

#### Scenario: 止まった子の受け取りは記録で起きる

- **WHEN** 既存要件「epic-dispatch.sh は子が止まった印を付け、wait が止まった子を返す」の Scenario のとおり、子 11 が open のまま止まった状態で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-stopped 11` を実行する。ただし止まった状態は記録の `stop` が `stopped` で表し、Orca の一覧の `comment` は空にする
- **THEN** stdout は `stopped 11`、exit 0 で、記録の `stop` は `stopped-seen` になり、`orca worktree list` は呼ばれない

#### Scenario: 片付けの安全確認は今と同じ

- **WHEN** 既存要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」の、安全確認を 1 点だけ変えた Scenario を、記録の `status` を `done` にして実行する
- **THEN** stdout は既存の Scenario と同じ `kept 11 <理由>` の行で、ワークツリーは消されず、記録も消されない

#### Scenario: 記録を読み書きするスクリプトは orca の語を含まない

- **WHEN** `epic-state.sh` を足したあとで `grep -rlw orca plugins/dev-workflow --include='*.sh'` を実行する
- **THEN** 出力は `plugins/dev-workflow/scripts/epic-dispatch.sh` の 1 行だけである

#### Scenario: 記録の無いワークツリーの mark は記録を作らない

- **WHEN** どの記録の `worktree` とも一致しないワークツリーで `epic-dispatch.sh mark done 11` を実行する
- **THEN** stdout は `skipped 11 no-workspace`、exit 0 で、`EPIC_STATE_ROOT` の下にファイルは増えていない

#### Scenario: 起動し直した親の出し直しは記録で決まる

- **WHEN** 子 11 の記録の `stop` が `stopped-seen`、子 12 が `resumed`、子 13 が `stopped` の状態で `epic-dispatch.sh pending-owner 11 12 13` を実行する
- **THEN** stdout は `pending 11` の 1 行で、`orca worktree list` も `orca worktree set` も呼ばれない

### Requirement: SKILL.md の回し方は再開時に adopt を呼び、待ちを終えるときに clear を呼ぶ

develop の SKILL.md「エピックの扱い」→「回し方」の Orca 経路は、次を書かなければならない（MUST）。

- 手順 7（`回し方: Orca` を引き継いだ再開）は、`reap` より前に、`launch` に渡したことのある子（エピックの状態ディレクトリにある記録の子と、エピックのコメントから分かる子を合わせたもの）で `scripts/epic-dispatch.sh adopt <エピック番号> <子>...` を 1 回呼び、そのあと `reap` → `pending-owner` → `launch` の順に進むと書く。`adopted` / `skipped` / `none` は何もせず、`failed <N> ambiguous` は主に聞かずにその子を残して進み、エピックに `子 #N の記録を取り込めなかった（ambiguous）` と 1 行コメントすると書く。`adopt` が stdout に何も出さず exit 1 で終わったら（`orca` が無い・一覧を読めない・origin を読めない）、stderr を添えて主に報告して止まると書く（`failed <N> ambiguous` の行を出して exit 1 で終わったときは止まらない）
- 手順 3・4・7 の「動いている子と片付け待ちの子がどちらも 0 件なら `wait` を呼ばずに待ちを終える」箇所は、待ちを終える前に `scripts/epic-dispatch.sh clear <エピック番号>` を 1 回呼ぶと書く。`cleared` / `none` は何もせず、exit 1 は主に報告すると書く。`clear` は待ちを終えるときに 1 回だけ呼び、エピックを閉じるのを待たない
- 手順 3 の `kept` の扱いのうち「`ambiguous`・`not-child` は対象を特定できないので確かめず残す」から `not-child` を外す（`reap` が出さなくなる）。`kept <N> state-unreadable` は確かめず残し、`子 #N のワークツリーを残した（state-unreadable） — <reap の stderr の記録のパス>` と 1 行コメントすると書く
- 手順 6 の「`--watch-done` か `--watch-stopped` を付けた `wait` が stdout に何も出さず exit 1 で終わった（今のワークツリーを Orca から読めない）ときは親ワークツリーで開き直す」は、`wait` が Orca を読まなくなるので消し、`launch` が exit 1 で子を 1 件も作らなかったときと `adopt` が stdout に何も出さず exit 1 で終わったときの報告として書き直す
- 完了条件の節は、エピックの完了時に状態のディレクトリが `clear` で消えていることを、動いている子が無くなったときの報告の前に確かめると書く
- 子の状態の正本は状態の記録で、Orca のボードの列とコメント欄は記録の写しであること、オーナーが Orca の画面で印を手で変えても親の見張りには効かないことを書く
- 「エピックの子が主の返事を待って止まるとき」の印の説明は、`mark stopped` / `mark resumed` が自分の記録に印を付け、Orca の画面には写しが出ると書く（子の手順・呼ぶ順序・出力の扱いは変えない）

`references/reply-after-idle.md` のうち、主の返事待ちの子を Orca のコメント欄の `epic-stopped-seen` で見分けると書いた箇所は、記録の `stop` が `stopped-seen` で見分けると書き直さなければならない（MUST）。

#### Scenario: 手順 7 が adopt から始まる

- **WHEN** SKILL.md の回し方の手順 7 を読む
- **THEN** `adopt` を `reap`・`pending-owner`・`launch` より前に呼ぶと書いてあり、`failed <N> ambiguous` と、stdout に何も出さない exit 1 の扱いが書き分けてある

#### Scenario: 待ちを終えるときに clear を呼ぶ

- **WHEN** SKILL.md の回し方の手順 3・4・7 のうち、`wait` を呼ばずに待ちを終える箇所を読む
- **THEN** どの箇所も待ちを終える前に `clear <エピック番号>` を 1 回呼ぶと書いてある

#### Scenario: Orca の画面の印は写しだと書いてある

- **WHEN** SKILL.md「エピックの扱い」を読む
- **THEN** 子の状態の正本が状態の記録で、Orca の画面の印を手で変えても親の見張りに効かないと書いてある
