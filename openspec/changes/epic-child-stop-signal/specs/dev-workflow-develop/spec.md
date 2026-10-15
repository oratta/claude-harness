## ADDED Requirements

### Requirement: epic-dispatch.sh は子が止まった印を付け、wait が止まった子を返す
`plugins/dev-workflow/scripts/epic-dispatch.sh` の `mark` は、種別 `done`・`waiting` に加えて `stopped` と `resumed` を受け付けなければならない（MUST）。`wait` はフラグ `--watch-stopped`（値なし）を受け付けなければならない（MUST）。どちらも LLM を呼んではならない（MUST NOT）。この要件は、要件「epic-dispatch.sh は完了の印を付け、印の付いた子のワークスペースを片付ける」のうち、次の 4 点に優先する。`mark` の種別を `done|waiting` とする規定と、それ以外の種別を引数の誤りとする規定／`wait` が `--watch-done` が 1 つも無いときは `orca` を呼ばないとする規定（`--watch-done` も `--watch-stopped` も無いときに読み替える）／`wait` が `closed` と `done` を 1 行か 2 行で出す規定（`stopped` を加えて 1〜3 行）／一覧の取得の失敗だけを「失敗したポーリング」に数える規定（止まった印の書き換えの失敗を加える）。

止まった印は Orca のワークツリーのコメント欄（`orca worktree set --comment`、`orca worktree list --json` の `comment`）に置き、ボードの列（`workspaceStatus`）には触れてはならない（MUST NOT。`mark waiting` の `in-review` と取り違えないため）。コメント欄の値は次の 3 つに固定し、完全一致で比べる（MUST）: `epic-stopped`（止まった。親はまだ受けていない）／`epic-stopped-seen`（親の `wait` が一度受けた）／`epic-resumed`（返事を受けて動いている）。

**`mark stopped <issue>`** は、今のワークスペースの linkedIssue が `<issue>` のときだけ、`orca worktree set --worktree current --comment epic-stopped` を 1 回呼ぶ（MUST）。exit 0 なら `marked <issue> stopped`、非 0 なら `failed <issue>`（exit 1）を出す。`orca` が無い・Orca 管理外・linkedIssue が違うときの出力と、`EPIC_DISPATCH_PARENT_EPIC` を見ないことは、`done` / `waiting` と同じとする（MUST）。

**`mark resumed <issue>`** は、linkedIssue が `<issue>` で、今のワークスペースの `comment` が `epic-stopped` か `epic-stopped-seen` のときだけ、`orca worktree set --worktree current --comment epic-resumed` を 1 回呼び、`marked <issue> resumed`（失敗なら `failed <issue>`、exit 1）を出す（MUST）。`comment` がそれ以外のときは `orca worktree set` を呼ばず、stdout に `skipped <issue> not-stopped` を出して exit 0 で終わる（MUST）。

**`wait --watch-stopped`** は次のとおり動かなければならない（MUST）。

- `--watch-stopped` は位置引数の子を対象にする。位置引数の子が 0 件なら、`--watch-done` があってもなくても `--watch-stopped` は何も見ない。`--watch-done` も位置引数の子も無ければ、`--watch-stopped` があっても stderr に使い方を出して exit 1 で終わる
- ポーリングを始める前の `orca worktree current --json` による `repoId` の取得と、取れないときの終わり方（stdout に何も出さず exit 1）は `--watch-done` と同じとする
- ポーリングごとの `orca worktree list --json` は、`--watch-done` と `--watch-stopped` の両方があっても 1 回だけ呼ぶ。ポーリング 1 回あたりの `gh` の呼び出しは位置引数の子の数と同じのままとする
- 位置引数の子 `<N>` のうち、そのポーリングで閉じていなかった子について、一覧に `repoId` が同じ・`linkedIssue` が `<N>`・`isArchived` が true でない・`comment` が `epic-stopped` のワークツリーがあれば、その全部に `orca worktree set --worktree path:<そのパス> --comment epic-stopped-seen` を呼ぶ。全部が exit 0 ならその子を「止まった子」とする。1 つでも非 0 ならその子を止まった子にせず、そのポーリングを「失敗したポーリング」に数える。`orca` 自身の出力は stderr に流す
- 閉じた子・印が付いた子・止まった子が 1 件以上あれば、`closed <N>...`・`done <N>...`・`stopped <N>...` を、該当するものだけこの順で 1 行ずつ出して exit 0 で終わる
- `comment` が `epic-stopped-seen`・`epic-resumed`・それ以外の値のワークツリーは止まった子に数えない
- `--watch-stopped` が無ければ、コメント欄を見てはならず、`orca worktree set` を呼んではならない（MUST NOT）

`plugins/dev-workflow/tests/epic-dispatch.bats` は、`orca`・`gh`・`sleep` を PATH 上のスタブにして、下の Scenario を確かめなければならない（MUST）。

#### Scenario: 自分の issue のワークスペースに止まった印を付ける
- **WHEN** linkedIssue が 460 のワークスペースで `epic-dispatch.sh mark stopped 460` を実行する
- **THEN** `orca worktree set --worktree current --comment epic-stopped` が 1 回呼ばれ、`--workspace-status` を含む呼び出しは無く、stdout は `marked 460 stopped`、exit 0 である

#### Scenario: 別の issue のワークスペースには止まった印を付けない
- **WHEN** linkedIssue が 461 のワークスペースで `epic-dispatch.sh mark stopped 460` を実行する
- **THEN** `orca worktree set` は呼ばれず、stdout は `skipped 460 not-linked`、exit 0 である

#### Scenario: 止まった印があるときだけ再開の印に書き換える
- **WHEN** `comment` が `epic-stopped`、`epic-stopped-seen`、`メモ` のワークスペースで、それぞれ `epic-dispatch.sh mark resumed 460` を実行する
- **THEN** 前の 2 つでは `orca worktree set --worktree current --comment epic-resumed` が 1 回呼ばれて stdout は `marked 460 resumed`、`メモ` では `orca worktree set` が呼ばれず stdout は `skipped 460 not-stopped` で、どれも exit 0 である

#### Scenario: 止まった印を付けられなければ failed
- **WHEN** `orca worktree set` が非 0 で終わる環境で `epic-dispatch.sh mark stopped 460` を実行する
- **THEN** stdout は `failed 460`、exit 1 である

#### Scenario: 止まった子を受けた印に書き換えて stopped で終わる
- **WHEN** 子 11 が open のまま、一覧で 11 の `comment` が `epic-stopped` の環境で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-stopped 11` を実行する
- **THEN** `orca worktree set --worktree path:<11 のパス> --comment epic-stopped-seen` が 1 回呼ばれ、stdout は `stopped 11`、exit 0 である

#### Scenario: 受けた印と再開の印では起きない
- **WHEN** 一覧で 11 の `comment` が `epic-stopped-seen`、12 の `comment` が `epic-resumed` で、どちらも open の環境で `epic-dispatch.sh wait --interval 0 --timeout 0 --watch-stopped 11 12` を実行する
- **THEN** `orca worktree set` は呼ばれず、stdout は `timeout 11 12`、exit 2 である

#### Scenario: 閉じた子・印が付いた子・止まった子は 3 行で出す
- **WHEN** 子 12 が closed、`--watch-done` の子 11 が `completed`、子 13 が open で `comment` が `epic-stopped` の環境で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-done 11 --watch-stopped 12 13` を実行する
- **THEN** stdout は `closed 12`・`done 11`・`stopped 13` の 3 行がこの順で、exit 0、`orca worktree list --json` の呼び出しは 1 回である

#### Scenario: 閉じた子は止まった子に数えない
- **WHEN** 子 11 が closed で、一覧の 11 の `comment` が `epic-stopped` の環境で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-stopped 11` を実行する
- **THEN** stdout は `closed 11` の 1 行だけで、`orca worktree set` は呼ばれない

#### Scenario: 別の repo や archive されたワークツリーの止まった印は数えない
- **WHEN** 一覧で 11 の `comment` が `epic-stopped` のワークツリーが、`repoId` の違うものと `isArchived` が true のものだけの環境で `--watch-stopped 11` の `wait` を `--timeout 0` で実行する
- **THEN** `orca worktree set` は呼ばれず、stdout は `timeout 11`、exit 2 である

#### Scenario: 受けた印に書き換えられないポーリングが 3 回続いたら error で終わる
- **WHEN** 一覧で 11 の `comment` が `epic-stopped` のまま、`orca worktree set` が常に非 0 で終わる環境で `epic-dispatch.sh wait --interval 0 --timeout 60 --watch-stopped 11` を実行する
- **THEN** stdout は `error workspaces` の 1 行、exit 1 で、`stopped` の行は出ない

#### Scenario: --watch-stopped が無ければコメント欄を見ない
- **WHEN** 一覧で 11 の `comment` が `epic-stopped` の環境で `epic-dispatch.sh wait --interval 0 --timeout 0 11` を実行する
- **THEN** `orca` は呼ばれず、stdout は `timeout 11`、exit 2 である

#### Scenario: --watch-stopped だけで子が無ければ使い方を出す
- **WHEN** `epic-dispatch.sh wait --watch-stopped` を子なしで実行する
- **THEN** stderr に使い方が出て exit 1 で、`orca` も `gh` も呼ばれない

### Requirement: エピックの子は止まる前に記録と印を残し、親は stopped を受けて報告する
develop の SKILL.md は、エピックの子のセッションが主の返事を待って止まるときの手順と、Orca 経路の親が `stopped` を受けたときの手順を規定しなければならない（MUST）。この要件は、要件「エピックの条件・作り方・回し方・完了条件を規定する」のうち、子が自分のタブでユーザーに質問して止まっている場合は `timeout` の確認では気づけないと書く規定に優先する（記録を残さずに止まった子に限って気づけないと書く）。

**子の側**:

- 対象は `scripts/epic-dispatch.sh route`（子の番号なし）が `nested` を返すセッションに限る（MUST）。それ以外のセッションでは記録も印も付けない（MUST NOT）
- 主の返事を待ってターンを終えるとき（本文での質問・AskUserQuestion・`needs-approval` を付けた保留のどれでも）は、ターンを終える前に記録先の issue へ記録を 1 件投稿し、続けてそのターンの最後のツール呼び出しとして `scripts/epic-dispatch.sh mark stopped <記録先の issue 番号>` を呼ぶ（MUST）。印を記録より先に付けてはならない（MUST NOT）。背景のタスクの終わりを待ってターンを終えるときは記録も印も付けない（MUST NOT）
- 記録の 1 行目は `^子の停止: 主の返事待ち$` に完全一致させ、2 行目以降に `止まった理由:`・`推奨:`・`根拠:`・`受け入れるリスク:`・`途中経過:` を 1 行ずつ書く（MUST）。止まるたびに新しいコメントを投稿し、最新の 1 件を正とする（SHALL）。書式の細部は #1036 で決める
- 「保留で止まるときの引き継ぎ」を書く場面では、引き継ぎを先に投稿し、そのあとに記録を投稿して `途中経過:` に引き継ぎのコメントの URL を書く（MUST）。引き継ぎの書式（1 行目 `引き継ぎ: 主の返事待ち`）は変えない
- `mark stopped` の出力が `marked` / `skipped` なら何もせず、`failed` なら主への質問に「親に止まったことが伝わっていない」と 1 行添える（SHALL）
- 止まったあとに主の返事を受けたら、最初のツール呼び出しとして `scripts/epic-dispatch.sh mark resumed <記録先の issue 番号>` を呼ぶ（MUST）。出力によらず止まらない（SHALL）

**親の側（Orca 経路）**:

- 動いている子を待つ `wait` には `--watch-stopped` を付ける（MUST）
- `stopped <N>...` で起こされたら、止まった子ごとに子 issue の最新の `子の停止: 主の返事待ち` のコメントを読み、子の番号・止まった理由・推奨・コメントの URL をユーザーに報告し、残りの動いている子（止まった子を含む）で再び `wait` する（MUST）。止まった子を動いている子から外してはならない（MUST NOT。閉じたことを検知できなくなるため）。止まった子への返事の仕方は #1034 で決める
- `wait` の出力の説明を、`closed`・`done`・`stopped` の 1〜3 行とする（MUST）
- 記録を残さずに子のタブで質問して止まった子は、`timeout` の確認でも検知できないので、ユーザーに子のタブも見るよう伝えることを残す（SHALL）
- 端末の入力待ちが続いたことで子の止まりを推定する手順を書いてはならない（MUST NOT。誤検知が多いため。根拠は change `epic-child-stop-signal` の design.md）

develop の手順書（`skills/develop` 配下）に `orca` のサブコマンドを書いてはならない（MUST NOT。既存の規定どおり、`orca` を呼ぶのは `epic-dispatch.sh` だけ）。

#### Scenario: 子が止まるときの記録と印の手順が書かれている
- **WHEN** SKILL.md のエピックの子が止まるときの手順を読む
- **THEN** `route` が `nested` を返すセッションに限ること、ターンを終える前に 1 行目 `子の停止: 主の返事待ち` の記録を投稿すること、記録の項目（`止まった理由:`・`推奨:`・`根拠:`・`受け入れるリスク:`・`途中経過:`）、記録のあとに最後のツール呼び出しとして `mark stopped` を呼ぶこと、引き継ぎを書く場面では引き継ぎの URL を `途中経過:` に書くこと、返事を受けたら最初に `mark resumed` を呼ぶことが書かれている

#### Scenario: 親が stopped を受けたときの手順が書かれている
- **WHEN** SKILL.md の Orca 経路の手順を読む
- **THEN** `wait` に `--watch-stopped` を付けること、出力が `closed`・`done`・`stopped` の 1〜3 行であること、`stopped` で起こされたら最新の `子の停止:` の記録を読んでユーザーに報告し、止まった子を外さずに再び `wait` することが書かれている

#### Scenario: 記録を残さずに止まった子は検知できないことが書かれている
- **WHEN** SKILL.md の Orca 経路の `timeout` の手順を読む
- **THEN** 記録を残さずに子のタブで質問して止まった子は検知できず、ユーザーに子のタブも見るよう伝えることが書かれている
