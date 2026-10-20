## Context

`plugins/dev-workflow/scripts/epic-dispatch.sh` は、エピックの子の起動（`launch`）・待ち受け（`wait`）・印（`mark`）・片付け（`reap`）・主の返事待ちの拾い直し（`pending-owner`）・閉じた子への通知（`notify-closed`）を 1 本で持ち、子の状態をすべて Orca のワークツリーのメタデータに置いている。

| 状態 | 今の置き場 |
|---|---|
| 起動済み・親子関係 | Orca のワークツリー（`linkedIssue`・`parentWorktreeId`・`repoId`） |
| 用が済んだ / 主の返事待ち（`mark done` / `mark waiting`） | ボードの列 `workspaceStatus`（`completed` / `in-review`） |
| 止まった・親が受けた・再開した | コメント欄 `comment`（`epic-stopped` / `epic-stopped-seen` / `epic-resumed`） |

このため (1) Orca の無い環境では親が子を見張れず（住人では常にサブエージェント方式になり、子の結果が本体 1 セッションに積もる）、(2) Orca 環境でも親と別のリポジトリの子は `repoId` の絞り込みから漏れ、`gh api repos/{owner}/{repo}/...` も親のリポジトリを指すので見張れない。

issue #1123 はこれを 3 層（状態の記録・親の見張り・起動部品）に分ける。受け入れ条件が多く、順序のある 3 つの change に割った（分割の理由は issue #1123 のコメント）。

| change | 中身 | 受け入れ条件 |
|---|---|---|
| 1. `epic-state-files`（これ） | 状態の記録と、記録だけで動く親の見張り。子の識別を `<owner>/<repo>#<N>` にする。Orca の起動部品は今の `epic-dispatch.sh` の中のまま記録を書く | 状態の記録の書式／Orca の部品で今までどおり動く／親の再起動からの再開／完了時の状態ディレクトリ削除 |
| 2. 別リポジトリの子 | `launch` が別リポジトリの子のワークツリーを作る。依存と子エピックの判定・コメントの書式・子の側の記録の置き場を別リポジトリに対応させる | 別リポジトリの子を launch に渡すと、そのリポジトリにワークツリーができ、親が見張れる／複数リポジトリの挙動が SKILL.md と spec に書かれている |
| 3. 起動部品の差し替え | 起動部品を Orca・tmux・サブエージェントの 3 つに分け、SKILL.md「エピックの扱い」を起動部品の差し替えとして書き直す | tmux の部品／SKILL.md の書き直し |

別リポジトリの子の挙動 7 項目と起動部品の境目は、実装より先にこの design.md の「Decisions」で決める。change 2・3 はここで決めた挙動を spec に起こして実装し、決め直すときはこの design.md の該当項目を指して理由を書く。

## Goals / Non-Goals

**Goals:**

- 子の状態の正本を、環境に依存しないローカルのファイルにする。親の見張り（`wait`・`pending-owner`・`reap`・`notify-closed`）は記録だけで状態を判定する
- 子を `<owner>/<repo>#<N>` で識別し、別リポジトリの子でも記録・見張りが同じに動く土台を作る
- 今の Orca 経路の動き（起動・止まった子の受け取り・`--resolve`・主の返事待ちの出し直し・`reap`・`notify-closed`・#1120 の上限）を変えない
- 親のセッションが起動し直しても、記録から続きを再開できる。エピックの完了時に記録を消す
- この変更より前に Orca で起動した子（記録が無い）を持つ実行中のエピックを、この変更のあとに再開できる

**Non-Goals:**

- 別リポジトリの子のワークツリーを作ること（change 2。この change の `launch` は別リポジトリの子を `failed <child> other-repo` で返す）
- tmux・サブエージェントの起動部品と、SKILL.md「エピックの扱い」の書き直し（change 3）
- 記録を PC をまたいで共有すること（親が子を起動するので同じ PC で動く。エピック #1122 の方針）
- 止まった理由の本文を記録に持つこと（本文は GitHub の `子の停止: 主の返事待ち` のコメントが正本のまま。記録は状態の値だけを持つ）

## Decisions

### 1. 置き場とファイル名

`${EPIC_STATE_ROOT:-$HOME/.claude/epic-state}/<エピックの owner>.<エピックの repo>-<エピック番号>/<子の owner>.<子の repo>-<子の番号>.json`。

- GitHub の owner 名には `.` が入らないので、最初の `.` で owner と repo を分けられる。番号は最後の `-` のあと。ファイル名から子を組み立て直せるが、読み手は記録の中の `child` を正とする
- `~/.claude/projects/` の配下には置かない（会話ログを読む hook が `projects/` の下を走査するため。issue #1123）
- 代案: (a) 今のまま Orca のメタデータ → Orca の無い環境で使えない。(b) GitHub のラベル・コメント → 子の `mark resumed` のたびに API を呼び、ポーリングごとに全子のコメントを読むことになる。止まった記録の本文は GitHub に置いたまま、状態の値だけをローカルに置く。(c) エピックごとに 1 ファイル → 親と複数の子が同じファイルを書き換えるので排他の待ちが増え、壊れたときに全子の状態を失う。子ごと 1 ファイルにする

### 2. 子 1 ファイルの項目

JSON のオブジェクト 1 つ。項目は次の表のとおりで、知らない項目は読み手が無視する（後の change が項目を足せるように）。

| 項目 | 型 | 中身 | 書く人 |
|---|---|---|---|
| `schema` | 数 | 書式の版。この change では `1` | 作る人 |
| `epic` | 文字列 | `<owner>/<repo>#<エピック番号>` | `launch` / `adopt` |
| `child` | 文字列 | `<owner>/<repo>#<子の番号>` | `launch` / `adopt` |
| `repo` | 文字列 | 子のリポジトリ `<owner>/<repo>`（`gh` を呼ぶ先） | `launch` / `adopt` |
| `number` | 数 | 子の issue 番号 | `launch` / `adopt` |
| `launcher` | 文字列 | 子を起動した起動部品（この change では `orca` だけ。change 3 で `tmux`・`subagent`） | `launch` / `adopt` |
| `parent_worktree` | 文字列 | 親のワークツリーの絶対パス | `launch` / `adopt` |
| `worktree` | 文字列 | 子のワークツリーの絶対パス。作る前は空 | `launch` / `adopt` |
| `branch` | 文字列 | 子のワークツリーのブランチ名（`refs/heads/` を除く）。読めなければ空 | `launch` / `adopt` |
| `base` | 文字列 | 子のワークツリーの起点ブランチ（`--base` / `EPIC_DISPATCH_BASE`、既定 `main`） | `launch` / `adopt` |
| `session` | 文字列 | 起動部品が子のセッションに届くための手がかり（Orca は端末のハンドル）。無ければ空。見張りの判定には使わない | `launch`・`reply` |
| `launch_failed` | 文字列 | `launch` が子のワークツリーを作ったあとで失敗した段（`terminal`・`ready`・`send` など）。成功したら空 | `launch` |
| `status` | 文字列 | `running`（起動済み）／`waiting`（`mark waiting`。今のボードの列 `in-review`）／`done`（`mark done`。用が済んだ） | `launch` / `mark` |
| `stop` | 文字列 | 空（止まっていない）／`stopped`（止まった。親はまだ受けていない）／`stopped-seen`（親の `wait` が受けた）／`resumed`（返事を受けて動いている） | `mark`（子）・`wait`（親） |
| `created_at` / `updated_at` | 文字列 | UTC の ISO 8601（`YYYY-MM-DDTHH:MM:SSZ`） | 書くたび |

`status` と `stop` を 2 つに分けるのは、今のボードの列とコメント欄を取り違えない規則（`mark stopped` が列に触れない）を保つため。値の遷移は今の印と同じで、`mark resumed` は `stop` が `stopped` か `stopped-seen` のときだけ `resumed` に書き換える。

### 3. 書き込みと排他

- 書き込みは、同じディレクトリの一時ファイル（`.<ファイル名>.tmp.<PID>`）に書いてから `mv` で置き換える。読み手は途中まで書かれたファイルを見ない
- 親（`wait` が `stopped` → `stopped-seen`）と子（`mark resumed` / `mark stopped`）が同じファイルを読んで書き換えるので、読む前から書き終えるまで `mkdir <ファイル>.lock` の排他を取る。取れなければ 0.2 秒ごとに `EPIC_STATE_LOCK_TIMEOUT`（秒・既定 10）まで取り直し、取れなければ書かずに失敗として返す（`mark` は `failed <N>`、`wait` はそのポーリングを失敗したポーリングに数える）。古いロックを自動で消さない（消してよいかを判定できない）。stderr に残ったロックのパスと、子も親も動いていないことを確かめてから `rmdir` するよう出す
- 代案: `flock` → macOS に標準で無い。排他なし → 親が `stopped` を読んでから `stopped-seen` を書くまでの間に子が `resumed` を書くと、子の再開が消えて `pending-owner` が動いている子を主の返事待ちとして出し直す。今の Orca の印では「通してよい」としていた競合だが、ファイルにすると排他で塞げるので塞ぐ

### 4. 子の呼び方（別リポジトリの挙動・項目 1）

- 記録・ファイル名・状態ディレクトリ名は常に `<owner>/<repo>#<N>` を元にする
- `epic-dispatch.sh` の引数は、エピックと同じリポジトリの子は番号だけ（今までどおり）、別リポジトリの子は `<owner>/<repo>#<N>` で渡す。出力（`launched`・`closed`・`stopped`・`pending` など）は引数で受けた形のまま返す（同じリポジトリの子の出力は今と同じ）
- エピックへのコメント・完了報告: 同じリポジトリの子は今のまま `子 #N マージ → 残り k 件` などと書き、別リポジトリの子は `子 <owner>/<repo>#N マージ → 残り k 件` と書く（GitHub はこの形を別リポジトリの issue へのリンクにする）。`stop-judge.sh` と親の手順の照合（`親の判断: 子 #N 通した`）は change 2 で両方の形を受けるようにする
- 子への返事の頭: 同じリポジトリでは今のまま `親エピック #<E> の判断（主の承認ではない）: `。別リポジトリのエピックでは `親エピック #<E>（<owner>/<repo>）の判断（主の承認ではない）: ` と、番号のあとに括弧でリポジトリを足す（`owner-reply-check.sh` の頭 `親エピック #` / `主の返事（親エピック #` の判定と、pr-review-gate の親経由の受領の照合を変えずに済む）。起動の指示も同じく `/develop #<N> （エピック #<E>（<owner>/<repo>）の子。…）`
- 代案: すべての子を常に `<owner>/<repo>#<N>` で書く → 今のコメント・判断のコマンド・bats の照合がすべて変わり、実行中のエピックの過去のコメントと形が揃わなくなる

### 5. 子の側が自分の記録を見つける方法

- 子のセッションの `mark` と `route` は、今いるワークツリーの最上位のパス（`git rev-parse --show-toplevel`）と `worktree` が一致する記録を、`EPIC_STATE_ROOT` の下の全エピックのディレクトリから探す。ちょうど 1 件ならそれが自分の記録。0 件なら「エピックの子ではない」（`mark` は `skipped <N> no-workspace`）、2 件以上なら `mark` は `failed <N>`（stderr に該当する記録のパス）
- `mark` は見つけた記録の `number`（と、別リポジトリの子では `repo`）が引数と一致するときだけ書き換え、違えば今と同じく `skipped <N> not-linked`
- `route` の `nested` の判定は、`EPIC_DISPATCH_PARENT_EPIC` が空でないか、自分の記録が見つかるとき。stderr の `parent epic:` は記録の `epic` から出す（同じリポジトリなら `#<E>`）。Orca の `parentWorktreeId` は見ない。Orca の画面で子を閉じて同じワークツリーで起動し直したセッションも、記録が残っているので `nested` になる（今の要件と同じ結果）
- 代案: 子の環境変数だけで見つける → 起動し直したセッションには環境変数が無い

### 6. 親の見張り（別リポジトリの挙動・項目 6）

- `wait`・`pending-owner`・`reap`・`notify-closed` は、子の状態（完了の印・止まった印・受けた印）を記録の `status` と `stop` から読み、Orca の一覧を状態の判定に使わない。`wait` は 1 ポーリングにつき、渡された子の記録を 1 回ずつ読む（Orca の一覧の取得は無くなる）
- 子 issue の state・`state_reason`・コメントは、記録の `repo` のリポジトリに対して `gh api repos/<repo>/issues/<N>` で読む（`{owner}/{repo}` の置き換えに頼らない）。記録が無い子は、エピックと同じリポジトリの子として読む（今と同じ）
- 親の側のサブコマンド（`wait`・`pending-owner`・`reap`・`notify-closed`・`reply`）の引数は今のまま変えない（`reap` などはエピックの番号を受け取らない）。子の記録は、`EPIC_STATE_ROOT` の下の全エピックのディレクトリから、`parent_worktree` が今いるワークツリーの最上位のパスと一致し、`child` が引数の子（番号だけの引数はエピックと同じリポジトリの子）と一致するものを探す。ちょうど 1 件ならそれを使い、2 件以上（同じ親のワークツリーから 2 つのエピックで同じ子を起動した）なら、今の「同じ linkedIssue のワークツリーが 2 つ以上」と同じ扱い（`reap` は `kept <N> ambiguous`、`reply` / `notify-closed` は `failed <N> ambiguous-worktree`、`wait` は印を見ない）にする。今の「同じ `repoId`・`parentWorktreeId` が今のワークツリー」の絞り込みが、この「`parent_worktree` が今のワークツリー」の絞り込みに置き換わる
- `reap` は、記録の `worktree` の子のワークツリーで今と同じ安全確認（完了の印・`git status` がきれい・`LLM/` が無い・マージ済み PR の `headRefOid` か base の先端に含まれる）を行う。PR の照会は `gh pr list -R <repo>`、base の照会は子のワークツリーの `origin` に対して行う。記録が無い子と、記録の `worktree` がもう無い子は `gone <N>`（後者は記録を消す）。今の `kept <N> not-child`（親の launch が作っていないワークツリー）は、親の側が自分の `parent_worktree` の記録しか見ないので起きなくなり、出さない
- `--watch-stopped` の受けた印への書き換えは、記録の `stop` を `stopped` → `stopped-seen` に書き換える（排他つき）。書き換えに失敗したらそのポーリングを失敗したポーリングに数える（今と同じ）

### 7. Orca の画面への写しと、記録の無い子の取り込み

- 記録が正本。Orca の部品（この change では `launch` と `mark` の中の Orca の処理）は、記録を書いたあとに Orca のワークツリーの印へ写す（`mark done` / `waiting` は `--workspace-status`、`stopped` / `resumed` は `--comment`、`wait` の受けた印は `--comment epic-stopped-seen`）。写しに失敗しても記録の書き込みは成功として扱い、stderr に写せなかったことを出す（オーナーが Orca のボードで子の状態を見ているので、写しは残す。判定には使わない）
- `adopt <epic> <child>...`（新規）: 記録の無い子について、`orca worktree list --json` に同じ `repoId`・`linkedIssue` が子・`isArchived` が true でない・`parentWorktreeId` が今のワークツリーの id のワークツリーがちょうど 1 つあれば、その `path`・`branch` と、`workspaceStatus` / `comment` を `status` / `stop` に写した記録を作る（`adopted <N>`）。記録が既にあれば `skipped <N>`、該当が無ければ `none <N>`、2 つ以上なら `failed <N> ambiguous`。親の再開の手順で、`reap`・`pending-owner`・`launch` より前に 1 回呼ぶ。この変更の前に起動した子を持つエピックのための移行の手段で、記録を作るのは `adopt` と `launch` だけ
- 代案: すべてのサブコマンドで記録が無ければ Orca から取り込む → `wait` のポーリングごとに Orca の一覧を読むことになり、記録を正本にした意味が薄れる

### 8. 消し方

- `reap` は `reaped <N>`（`branch-kept` を含む）と `gone <N>`（記録はあるが子のワークツリーがもう無い）を返した子の記録を消す。消したあとにもう一度 `reap` に渡された子は、記録が無いので `gone <N>` になる（再開の手順 7 が、閉じた子を含めて `launch` に渡したことのある子を全部 `reap` に渡すのと合う）
- `clear <epic>`（新規）は、そのエピックの状態ディレクトリを丸ごと消して `cleared <epic>` を出す（無ければ `none <epic>`）。消す前に残っている記録の子を stderr に出す。消す対象は `EPIC_STATE_ROOT` の直下の、エピックの番号から組み立てたディレクトリ名に一致するものだけで、`..` や `/` を含む名前を組み立てたら消さずに exit 1
- 親は、動いている子と片付け待ちの子がどちらも 0 件になって待ちを終えるときに `clear` を 1 回呼ぶ（SKILL.md の手順 3・4・7 の「`wait` を呼ばずに待ちを終える」箇所）。エピックに `子 #N のワークツリーを残した` の行がある子の記録も一緒に消える（その子は以後の片付け待ちに入らない今の規則と同じ）
- 代案: エピックを閉じたときに消す → エピックはオーナーの実機確認のあとに閉じるので、親のセッションが閉じる時点にいるとは限らない

### 9. 親の再起動からの再開

- `回し方:` を引き継いで再開した親は、`adopt` → `reap` → `pending-owner` → `launch` の順に呼ぶ。「`launch` に渡したことのある子」は、エピックの状態ディレクトリにある記録の子と、エピックのコメントから分かる子（今の手順）を合わせたものにする（記録を消したあとの子と、`adopt` で取り込めなかった子を落とさないため）
- 状態ディレクトリから、各子の `status`・`stop` が読めるので、親は Orca の画面を見ずに動いている子・片付け待ちの子・主の返事待ちの子を組み立て直せる

### 10. #1106（PR #1120）の上限との関係

#1120 は `launch` に同時に枠を使う子の上限を入れる（上限は `EPIC_DISPATCH_MAX_PARALLEL` か物理メモリから決め、空き枠を超える子は `deferred <N>` で返し、親は枠が空いたら後回しの子を `launch` に渡し直す）。#1120 は枠を使っている子を Orca の一覧（同じ `repoId`・`parentWorktreeId` が今のワークツリー・完了の印でない・止まった印でない）と issue の state から数える。

層の分担は次のとおりにし、上限の動き（値の決め方・`deferred` の出し方・「create に進んだ子は結果によらず 1 枠」・止まった子と完了の印の子を数えない・state を読めない子は数える）を変えない。

| 層 | 上限についての役目 |
|---|---|
| 状態の記録 | 枠を使っている子の数の正本。このエピックの状態ディレクトリの記録のうち、`status` が `done` でなく、`stop` が `stopped` / `stopped-seen` でなく、記録の `repo` に対する issue の state が `closed` でないものを数える（#1120 の Orca の一覧の条件を記録の項目に置き換えたもの） |
| 親の見張り | 上限の値を決め（`max-parallel` は変えない）、空き枠を計算し、`deferred` を出す。起動部品より手前で決めるので、change 3 の tmux・サブエージェントでも同じ上限が掛かる |
| 起動部品 | 枠を知らない。渡された子を起動するだけ |

- 記録は「子のワークツリーを作る前」に書くので、`create` に進んだ子は記録で数えられる。`create` が失敗したら記録を消す（ワークツリーが無いので、次の `launch` で作り直す。今の Orca の一覧で数えない動きと同じ）。ワークツリーを作ったあとの失敗は記録を残し、`launch_failed` に段を書く（次の `launch` では `skipped`。今と同じ）
- 実装は #1120 がマージされてから origin/main に rebase して始める（同じ `epic-dispatch.sh` の `cmd_launch` を変えるため）。#1120 がマージされる前に実装に入るときは、#1120 の差分を取り込まず、この表の分担を保てる形で `launch` の記録の書き込みだけを入れ、#1120 のマージ後に枠の数え方を記録に置き換える

### 11. change 2（別リポジトリの子）に渡す決定

| 項目 | 決めた挙動 |
|---|---|
| 依存と子エピックの判定 | 子の `blocked_by` と `sub_issues_summary.total` は子のリポジトリ（`gh api repos/<子の owner>/<子の repo>/issues/<N>/...`）に対して読む。`blocked_by` の前提の issue のリポジトリは応答の `repository_url` から取る。エピックの子の一覧は、エピックのリポジトリの sub-issue（応答の `repository_url`）とエピックの本文の表から組み立てる。別リポジトリというだけで「後で別に起動するエピック」に回さない（回すのは sub-issue を持つ子だけで、今の規則のまま） |
| ワークツリーの作り先 | 子のリポジトリのローカル clone を次の順に探し、候補ごとに `git -C <候補> remote get-url origin` が `<owner>/<repo>` を指すことを確かめる。(1) 子のリポジトリがエピックと同じなら親のワークツリーの clone。(2) 環境変数 `EPIC_DISPATCH_CLONES`（`<owner>/<repo>=<絶対パス>` を改行か `;` で区切る）。(3) 起動部品が知っているリポジトリ（Orca は `orca repo list --json` に登録されたリポジトリ）。見つからなければ自動で clone せず、記録も作らず枠も使わずに `failed <child> no-clone` を返し、stderr に `EPIC_DISPATCH_CLONES` の書き方と clone のコマンドを出す（clone の置き場はオーナーのディスクの構成で決まり、ハーネスがパスを決めない。一度設定すれば以後は見つかる）。同じ段に候補が 2 つ以上あれば `failed <child> ambiguous-clone`。ワークツリーの起点は `--base` / `EPIC_DISPATCH_BASE` があればそれ、無ければ子のリポジトリの既定ブランチ（`gh api repos/<o>/<r> --jq .default_branch`） |
| 書き込み権 | ワークツリーを作る前に `gh api repos/<o>/<r> --jq .permissions.push` を読み、`true` でなければ記録を作らずに `failed <child> no-push`、読めなければ `failed <child> permission-lookup-failed` を返す。親はほかの `failed` と同じく主に報告して止まる（手順 6）。fork から PR を出す経路は作らない |
| PR・ゲート・マージ | 子のセッションは子のリポジトリのワークツリーで動くので、`gh` の既定のリポジトリは子のリポジトリになり、PR は子のリポジトリに立つ（本文の `Closes #N` は子のリポジトリの issue）。pr-review-gate・auto-merge の有無・`human-merge` の扱いは子のリポジトリの設定に従う。親の「マージ待ちの子」の手順は `auto-merge.yml` を子のリポジトリから読み、`親のマージ判断:` のコメントと `parent-merge-approved` のラベルを子のリポジトリの PR に付ける（`gh -R <repo>`）。印が数えられるのは、`gh` の認証アカウントが子のリポジトリの OWNER・MEMBER・COLLABORATOR のときだけ（今の規則の対象リポを子のリポジトリと読む） |
| 子の側 | 子の起動コマンドの `EPIC_DISPATCH_PARENT_EPIC` は、同じリポジトリのエピックでは番号のまま、別リポジトリのエピックでは `<owner>/<repo>#<E>`。子の記録（`子の停止: 主の返事待ち`）と印（`mark`）は今のまま自分の issue と自分の記録に残す。親エピックへのコメント（`後で別に起動するエピック: #<自分>` など）は `gh issue comment <E> -R <エピックのリポジトリ>` で残し、自分の issue の番号は `<owner>/<repo>#<N>` で書く。親エピックからの注意書きは子の issue（子のリポジトリ）に残す（今と同じ置き場） |

### 12. change 3（起動部品の差し替え）に渡す決定

- 起動部品は `scripts/epic-launch-<名前>.sh`（`orca`・`tmux`）の 1 本ずつに分け、同じサブコマンドを持つ: `create <clone> <child> <base> <親のワークツリー>`（子のワークツリーを作り、パスを出す）／`start <ワークツリー> <起動コマンド> <最初の指示>`（セッションを開いて指示を送り、`session` の値を出す）／`send <ワークツリー> <文>`（動いている子のセッションに文を送る。`reply` が使う）／`restart <ワークツリー> <起動コマンド> <指示>`（セッションを閉じて起動し直す。`reply --relaunch` が使う）／`close <ワークツリー>`（セッションを閉じる）／`remove <ワークツリー>`（ワークツリーを消す）／`mirror <ワークツリー> <status> <stop>`（画面への写し。無い部品は何もしない）
- 記録・見張り・上限・`reap` の安全確認は `epic-dispatch.sh` に残し、起動部品は状態を持たない。どの部品で起動したかは記録の `launcher` に残し、`reply`・`reap` はその部品を呼ぶ
- tmux の部品: ワークツリーは `git -C <clone> worktree add`、セッションは親と同じ tmux サーバーの新しいウィンドウ（`tmux new-window -d -c <ワークツリー>`）で `EPIC_DISPATCH_CLAUDE_CMD` の起動コマンドを走らせ、`tmux send-keys` で指示を送る。起動完了は `tmux capture-pane` の画面で待つ
- サブエージェント方式も記録を書く（本体が W を `isolation: "worktree"` で起こすときに `epic-dispatch.sh` の記録の書き込みを呼ぶ）。子のセッションが独立していないので `start` / `send` は無く、`wait` の代わりに本体が W の return を受ける
- `route` の結果は `orca`・`tmux`・`subagent`・`nested` の 4 つにし、Orca 管理のワークツリーなら `orca`、そうでなく `TMUX` が空でなく `tmux` が PATH にあれば `tmux`、それ以外は `subagent`
- 既存要件「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」は、Orca のコマンドを呼ぶのは Orca の部品 1 本だけ、と読み替える

## Risks / Trade-offs

- [記録と Orca の画面の印がずれる（写しの失敗・オーナーが Orca の画面で印を手で変える）] → 判定は記録だけで行い、画面の手での変更は見張りに効かない。写しの失敗は stderr に出す。オーナーが画面で印を変えて子の状態を直す使い方は無くなる（SKILL.md に書く）
- [残ったロックで `mark` / `wait` が失敗し続ける（書き込みの途中でプロセスが殺された）] → 起きるのは書き込みの数ミリ秒の間に殺されたときだけ。失敗は `failed` / 失敗したポーリング（3 回続けば `error`）として表に出るので、黙って止まりはしない。stderr にロックのパスと消し方を出す
- [実行中のエピックで、`adopt` を呼ぶ前の古い親や、この変更の前の版の子が Orca の印だけを付ける] → 子が古い版のまま `mark done` すると記録が `done` にならず、親の `wait` が気づかない。plugin の更新は全セッション同じ版を読む（`~/.claude/plugins/cache/` の同じ SHA）ので、混在は更新の瞬間に動いていたセッションだけ。親の再開の手順で `adopt` が Orca の印を記録に写すので、親を起動し直せば拾える。SKILL.md の再開手順に書く
- [`clear` が別のエピックのディレクトリを消す] → ディレクトリ名はエピックの `<owner>/<repo>#<E>` からだけ組み立て、`EPIC_STATE_ROOT` 直下の 1 段だけを消す。名前の検査に通らなければ消さない
- [`EPIC_STATE_ROOT` の既定が `~/.claude/` の下で、bats が実在のホームを汚す] → bats はすべて `EPIC_STATE_ROOT` を一時ディレクトリに向ける。テストの共通の setup で設定する

## Migration Plan

1. #1120 のマージを待ち、origin/main に rebase する（Decision 10）
2. マージ後、実行中のエピックの親は再開の手順で `adopt` を呼ぶ。記録の無い子は Orca の印から記録に写る
3. 戻し方: この change の PR を revert すれば、Orca の印を正本にした今の動きに戻る。記録のファイルは残っても読まれない（`clear` を手で呼ぶか `~/.claude/epic-state/` を消す）

## Open Questions

なし（別リポジトリの子・起動部品の境目は Decisions 11・12 で決めた。change 2・3 で決め直すときはこの design.md の項目を指して理由を書く）。
