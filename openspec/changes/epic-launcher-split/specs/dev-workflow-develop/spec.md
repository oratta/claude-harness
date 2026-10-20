## MODIFIED Requirements

### Requirement: develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする
`plugins/dev-workflow/skills/develop/` 配下のファイルは、`orca` を実行する書き方（`orca worktree ...`・`orca terminal ...` など、`orca` の直後に半角英小文字のサブコマンドが続く書き方）を含んではならない（MUST NOT）。例外は 1 つだけで、要件「Orca 経路の本体は印が付いた子のワークスペースを片付ける」で本体が確かめて消すときの `orca worktree rm --worktree path:<path>` を、SKILL.md の「エピックの扱い」の回し方の手順 3 に 1 回だけ書いてよい（MAY。`reap` が残したワークツリーを消す判断は本体がその場で行うもので、`epic-dispatch.sh` のサブコマンドにすると `reap` の処理を変えることになるため）。この 1 件と同じ行に別の `orca` のコマンドを書くことと、この書き方を 2 回以上書くことは、例外に含めない（MUST NOT）。手順書には環境によらない動作（「このワークスペースに印を付ける」「印が付いた子のワークスペースを片付ける」）と、それを行う `epic-dispatch.sh` のサブコマンドだけを書く（MUST）。前提の表の `orca` の行、`route` が返す値 `orca`、その条件の説明（`orca` が PATH にある）は、`orca` を実行する書き方ではないので残してよい。指示が届かなかった子の確認は、`launch` が stderr に出した確認のコマンドを指す書き方にする（SHALL）。

`plugins/dev-workflow/` 配下のシェルスクリプト（`*.sh`）のうち、`orca` をコマンドとして書いた行（`orca` が行頭・`;`・`&`・`|`・`(`・`!`・`$(`・`if`/`then`/`do`/`else`/`while`/`until` のあとにあり、半角英小文字のサブコマンドが続く行。文字列とコメントの中の `orca` は数えない）を含むのは、Orca の起動部品 `scripts/epic-launch-orca.sh` だけでなければならない（MUST）。`epic-dispatch.sh` は `orca` のコマンドを直接呼ばず、Orca の起動部品のサブコマンドを呼ぶ（MUST。`launcher` の値・`route` の出力・stderr の文言としての `orca` の語は、コマンドとして書いた行ではないので含んでよい）。`epic-launch-orca.sh` の中では `orca` のコマンドをそのまま呼び、Orca の機能を自前で作り直してはならない（MUST NOT）。Orca が無い環境のための代わりの実装を持ってはならない（MUST NOT。`route` の `subagent` と `mark` の `skipped` のように、何もしないで終わる分岐は代わりの実装に数えない）。

`plugins/dev-workflow/tests/epic-dispatch.bats` は、この 2 つの検索の結果を確かめなければならない（MUST）。手順書の検索では、許可した 1 件を出現ごとに取り除いてから残りを探し、行ごと除外してはならない（MUST NOT。同じ行に置いた別の `orca` のコマンドを見逃すため）。この 2 つの検索で拾いたい誤りは、手順書に `orca` のサブコマンドを書き足すことと、`epic-launch-orca.sh` 以外のシェルスクリプトに `orca` の呼び出しを足すことである。変数やコマンド置換を介した呼び出し、`orca` の語を含まない別名など、検索をすり抜ける書き方が見つかるたびに塞ぐことは、この要件の完了条件としない。

#### Scenario: 手順書に orca を実行する書き方は許可した 1 件しか無い
- **WHEN** `grep -rnE 'orca [a-z]+' plugins/dev-workflow/skills/develop` の各行から `orca worktree rm --worktree path:<path>` を 1 回取り除き、残りを `grep -E 'orca [a-z]+'` で探す
- **THEN** 出力は 0 行であり、`grep -rhoF 'orca worktree rm --worktree path:<path>' plugins/dev-workflow/skills/develop` の出力は SKILL.md の手順 3 にある 1 行だけである

#### Scenario: 許可した 1 件と同じ行に別の orca のコマンドがあると落ちる
- **WHEN** 手順書の 1 行に `orca worktree rm --worktree path:<path>` と `orca terminal close --all` を並べて書く
- **THEN** 手順書の検索は `orca terminal close` を見つけ、`epic-dispatch.bats` のテストは失敗する

#### Scenario: orca を呼ぶスクリプトは Orca の起動部品 1 本だけ
- **WHEN** `grep -rlE '(^|[;&|(!]|(if|then|do|else|while|until) )[[:space:]]*orca [a-z]+' plugins/dev-workflow --include='*.sh'` を実行する
- **THEN** 出力は `plugins/dev-workflow/scripts/epic-launch-orca.sh` の 1 行だけである

#### Scenario: epic-dispatch.sh に orca のコマンドを足すと落ちる
- **WHEN** `epic-dispatch.sh` を写した一時ファイルに `orca terminal list --json` の 1 行を足し、同じ検索をその写しのあるディレクトリに対して行う
- **THEN** 検索はその写しを出し、照合は失敗する

### Requirement: エピックの子は止まる前に記録と印を残し、親は stopped を受けて報告する
develop の SKILL.md は、エピックの子のセッションが主の返事を待って止まるときの手順と、Orca 経路の親が `stopped` を受けたときの手順を規定しなければならない（MUST）。この要件は、要件「エピックの条件・作り方・回し方・完了条件を規定する」のうち、子が自分のタブでユーザーに質問して止まっている場合は `timeout` の確認では気づけないと書く規定に優先する（記録を残さずに止まった子に限って気づけないと書く）。

**子の側**:

- 対象は `scripts/epic-dispatch.sh route`（子の番号なし）が `nested` を返すセッションに限る（MUST）。それ以外のセッションでは記録も印も付けない（MUST NOT）
- 主の返事を待って止まるときは、待ち方で順序を分ける（MUST）。どちらでも印を記録より先に付けてはならない（MUST NOT）
  - **本文で質問してターンを終えるとき**（`needs-approval` を付けた保留で、質問ツールを使わずにターンを終えるときを含む）: ターンを終える前に記録先の issue へ記録を 1 件投稿し、続けてそのターンの最後のツール呼び出しとして `scripts/epic-dispatch.sh mark stopped <記録先の issue 番号>` を呼ぶ。主の返事は次のターンで届くので、そのターンの最初のツール呼び出しとして `scripts/epic-dispatch.sh mark resumed <記録先の issue 番号>` を呼ぶ
  - **質問ツール（AskUserQuestion）の中で待つとき**: 質問ツールを呼ぶ前に記録を投稿し、続けて `mark stopped` を呼んでから質問ツールを呼ぶ。質問ツールは回答が来るまで同じターンの中で待つので、`mark stopped` は最後のツール呼び出しにならない。回答を受けたら、次のツール呼び出しとして `mark resumed` を呼ぶ
- 背景のタスクの終わりを待ってターンを終えるときは記録も印も付けない（MUST NOT）
- 記録は、1 行目を識別用の `^子の停止: 主の返事待ち$` に完全一致させ、2 行目以降は要件「エピックの子の停止の記録は、子の会話を読んでいない読み手が 1 通で読める形で書く」の項目名と並びで書く（MUST）。止まるたびに新しいコメントを投稿し、最新の 1 件を正とする（SHALL）
- 「保留で止まるときの引き継ぎ」を書く場面では、引き継ぎを先に投稿し、そのあとに記録を投稿して、再開に要る途中経過として引き継ぎのコメントの URL を書く（MUST）。引き継ぎの書式（1 行目 `引き継ぎ: 主の返事待ち`）は変えない
- `mark stopped` の出力が `marked` / `skipped` なら何もせず、`failed` なら主への質問に「親に止まったことが伝わっていない」と 1 行添える（SHALL）。`mark resumed` は出力によらず止まらない（SHALL）

**親の側（Orca 経路）**:

- 動いている子を待つ `wait` には `--watch-stopped` を付ける（MUST）
- `stopped <N>...` で起こされたら、止まった子ごとに子 issue の最新の `子の停止: 主の返事待ち` のコメントを読み、子の番号・止まった理由・推奨・コメントの URL をユーザーに報告し、残りの動いている子（止まった子を含む）で再び `wait` する（MUST）。止まった子を動いている子から外してはならない（MUST NOT。閉じたことを検知できなくなるため）。止まった子への返事の仕方は #1034 で決める
- `wait` の出力の説明を、`closed`・`done`・`stopped` の 1〜3 行とする（MUST）
- 記録を残さずに子のタブで質問して止まった子は、`timeout` の確認でも検知できないので、ユーザーに子のタブも見るよう伝えることを残す（SHALL）
- 端末の入力待ちが続いたことで子の止まりを推定する手順を書いてはならない（MUST NOT。誤検知が多いため。根拠は change `epic-child-stop-signal` の design.md）

develop の手順書（`skills/develop` 配下）に `orca` のサブコマンドを書いてはならない（MUST NOT。既存の規定どおり、`orca` を呼ぶのは Orca の起動部品 `epic-launch-orca.sh` だけ）。

この要件の守備範囲で入力として扱うのは、子のセッションでは `epic-dispatch.sh route`（子の番号なし）の出力と `mark` の出力、主の返事を待つかどうかの子自身の判断（本文で質問するか、質問ツールを使うか、背景のタスクを待つだけか）、記録先の issue 番号で、親のセッションでは `wait` の出力と子 issue のコメント（1 行目が `子の停止: 主の返事待ち` の最新の 1 件）である。拾いたい誤りは、エピックの子が主の返事を待っているのに記録も印も残さずに止まること、印が記録より先に付いて親が記録の無い止まりを読むこと、質問ツールで待つ子が回答を受けたあとも止まった印を残すこと、エピックの子でないセッションが読む者のいない記録を残すこと、親が止まった子を動いている子から外して閉じたことを検知できなくなることの 5 つである。次は通ってよく、この要件では止めない: 記録の項目の値の長さと改行の違い（値が複数行に続くこと）／止まるたびに記録が増えること（最新の 1 件を正とする）／保留の場面で引き継ぎと記録の 2 件のコメントが並ぶこと／主が子のタブで先に答えて、親が既に再開した子の `stopped` を受けること（親は記録を読んで報告するだけで、返事の仕方は #1034 で決める）／子が記録を書かずに止まり、親が `timeout` まで気づかないこと（入力待ちからの推定は入れない）。記録の中身（理由・推奨・リスクの正しさ）を確かめることと、手順を守らない子を見つけるたびに検査を足して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 子が止まるときの記録と印の手順が書かれている
- **WHEN** SKILL.md のエピックの子が止まるときの手順を読む
- **THEN** `route` が `nested` を返すセッションに限ること、1 行目 `子の停止: 主の返事待ち` の記録を投稿してから `mark stopped` を呼ぶこと、本文で質問してターンを終えるときは `mark stopped` をそのターンの最後のツール呼び出しにすること、質問ツールで待つときは記録・`mark stopped`・質問ツールの順に呼んで回答のあとに `mark resumed` を呼ぶこと、本文で質問したときは返事を受けたターンの最初に `mark resumed` を呼ぶこと、引き継ぎを書く場面では引き継ぎを先に投稿することが書かれている。記録の 2 行目以降の項目名と並びは要件「エピックの子の停止の記録は、子の会話を読んでいない読み手が 1 通で読める形で書く」のシナリオで確かめる

#### Scenario: 親が stopped を受けたときの手順が書かれている
- **WHEN** SKILL.md の Orca 経路の手順を読む
- **THEN** `wait` に `--watch-stopped` を付けること、出力が `closed`・`done`・`stopped` の 1〜3 行であること、`stopped` で起こされたら最新の `子の停止:` の記録を読んでユーザーに報告し、止まった子を外さずに再び `wait` することが書かれている

#### Scenario: 記録を残さずに止まった子は検知できないことが書かれている
- **WHEN** SKILL.md の Orca 経路の `timeout` の手順を読む
- **THEN** 記録を残さずに子のタブで質問して止まった子は検知できず、ユーザーに子のタブも見るよう伝えることが書かれている

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
| `gh api repos/{owner}/{repo}/issues/<N>` | 記録の `repo` がエピックと同じリポジトリの子と、番号だけで渡した記録の無い子は今のまま。違うリポジトリの子は `gh api repos/<repo>/issues/<N>`、`<owner>/<repo>#<N>` で渡した記録の無い子は引数の `<owner>/<repo>`（小文字）で `gh api repos/<owner>/<repo>/issues/<N>`。`reap` の `gh pr list`・`git ls-remote` などの呼び出しの形は、capability `dev-workflow-epic-state` の要件「親の見張りは記録だけで子の状態を判定する」の `reap` のとおり（同じリポジトリの子は今のまま、別のリポジトリの子は子のリポジトリと子のワークツリーに向ける） |
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

#### Scenario: 記録を読み書きするスクリプトは orca の語を含まず、orca のコマンドは起動部品だけが呼ぶ

- **WHEN** `grep -rlw orca plugins/dev-workflow --include='*.sh'` と `grep -rlE '(^|[;&|(!]|(if|then|do|else|while|until) )[[:space:]]*orca [a-z]+' plugins/dev-workflow --include='*.sh'` を実行する
- **THEN** 1 つ目の出力に `plugins/dev-workflow/scripts/epic-state.sh` は無く（`epic-dispatch.sh` と `epic-launch-orca.sh` は `launcher` の値として `orca` の語を含んでよい）、2 つ目の出力は `plugins/dev-workflow/scripts/epic-launch-orca.sh` の 1 行だけである

#### Scenario: 記録の無いワークツリーの mark は記録を作らない

- **WHEN** どの記録の `worktree` とも一致しないワークツリーで `epic-dispatch.sh mark done 11` を実行する
- **THEN** stdout は `skipped 11 no-workspace`、exit 0 で、`EPIC_STATE_ROOT` の下にファイルは増えていない

#### Scenario: 起動し直した親の出し直しは記録で決まる

- **WHEN** 子 11 の記録の `stop` が `stopped-seen`、子 12 が `resumed`、子 13 が `stopped` の状態で `epic-dispatch.sh pending-owner 11 12 13` を実行する
- **THEN** stdout は `pending 11` の 1 行で、`orca worktree list` も `orca worktree set` も呼ばれない

