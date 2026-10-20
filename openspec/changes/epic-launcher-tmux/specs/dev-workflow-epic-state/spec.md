## MODIFIED Requirements

### Requirement: 起動部品は epic-launch-<名前>.sh の 1 本ずつで、同じサブコマンドと出力の契約を持つ

子のワークツリーを作る・セッションを開く・指示を送る・閉じる・消す・画面へ写す処理は、起動部品のスクリプト `plugins/dev-workflow/scripts/epic-launch-<名前>.sh` に置かなければならない（MUST）。起動部品は Orca の部品 `epic-launch-orca.sh` と tmux の部品 `epic-launch-tmux.sh`（要件「tmux の部品は…」）の 2 本で、サブエージェント方式は起動部品を持たない。`epic-dispatch.sh` は起動部品を `bash <epic-dispatch.sh と同じディレクトリ>/epic-launch-<名前>.sh <サブコマンド> <引数...>` で別のプロセスとして呼ばなければならない（MUST）。起動部品は状態の記録を読み書きしてはならず（MUST NOT）、記録・親の見張り・同時に枠を使う子の上限・`reap` の片付けの前の確認は `epic-dispatch.sh` に置く（MUST）。起動部品のスクリプトには、開発に固有の語（PR・マージ・ゲート）を入れてはならない（MUST NOT）。

起動部品は次のサブコマンドを持たなければならない（MUST）。stdout には各サブコマンドが決めた行だけを出さなければならない（MUST）。stderr に出すのは、切り出す前の `epic-dispatch.sh` が stderr に出していたもの（`orca worktree set`・`worktree create`・`terminal create`・`terminal send`・`terminal wait`・`terminal close` の出力、`reap` の閉じ直しのときの `terminal list` の出力、`worktree rm` の stderr、失敗の理由と手で続けるための案内の文）だけで、同じ順と同じ文で出す（MUST）。部品が中で読んで解釈するだけの出力（`orca worktree current`・`worktree list`・`repo list` の JSON と、閉じ直し以外の `terminal list` の JSON）は、stdout にも stderr にも出してはならない（MUST NOT）。

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
| `close` | `<ワークツリー> <子の呼び方>` | 何も出さない。セッションを閉じたら exit 0、閉じ直しても閉じられなければ exit 1（主の操作の案内は `epic-dispatch.sh` が出す）。`子の呼び方`（例: `11`・`o/r#5`）は閉じ直すときの stderr の文 `terminal close was incomplete for #<子の呼び方>; …` にだけ使う |
| `remove` | `<ワークツリー>` | 消せたら何も出さず exit 0。消せなければ理由の語を 1 行出して exit 1。未コミットの変更があるワークツリーを消してはならない（MUST NOT）。`orca worktree rm` の通常の stdout は部品の stdout に混ぜず、環境変数 `EPIC_LAUNCH_STDOUT_FD` で渡された FD（`epic-dispatch.sh` の reap は自分の stdout を保持した FD 3 を渡す）へ中継する。FD が渡されない・開いていないときは stderr へ回す |
| `mirror` | `<current か ワークツリー> <done・waiting・stopped・resumed・stopped-seen のどれか> <記録のパス>` | 何も出さず、常に exit 0。部品の画面へ状態を写し、写せなければ stderr に記録のパスと一緒に出す。画面を持たない部品と、部品が使えないときは何もしない |

知らないサブコマンドと引数の数の違う呼び出しには、stderr に使い方を出して exit 2 で終わらなければならない（MUST）。

この要件の検査（知らないサブコマンドと引数の数、`list`・`repos`・端末の一覧の読み取り、子のセッションの端末の選び方）の守備範囲は次のとおりである。入力の出どころは `epic-dispatch.sh`（同じプラグインの中の呼び出し元）と、`orca` が返す JSON の 2 つである。拾いたい誤りは、`epic-dispatch.sh` と部品のサブコマンドの名前か引数の並びが食い違うこと、`orca` の JSON の形が変わって読めないこと（読めないときは 0 件として扱わず失敗にする）、子のセッションの端末を 1 つに決められないのに送ることである。`epic-dispatch.sh` が検査済みの値（待ち時間・起動コマンド・指示と返事の文・子の呼び方・ワークツリーのパス）は、部品の中で検査し直さずにそのまま通してよい（MAY）。引数の中身の妥当性や、`orca` の JSON のあらゆる崩れ方を塞ぎ切ることは、この要件の完了条件としない。

Orca の部品は、各サブコマンドで次の `orca` のコマンドだけを呼び、Orca の機能を自前で作り直してはならない（MUST NOT）: `available` は `orca` が PATH にあるか（無ければ stderr に `orca is not on PATH`）、`here` は `orca worktree current --json`、`prepare` は `orca worktree set --worktree path:<親> --issue <E>`、`list` は `orca worktree list --json`（`isArchived` が true のものを除き、`workspaceStatus` の `completed` → `done`・`in-review` → `waiting`・それ以外 → `running`、`comment` の `epic-stopped` → `stopped`・`epic-stopped-seen` → `stopped-seen`・`epic-resumed` → `resumed`・それ以外 → 空に読み替える）、`repos` は `orca repo list --json`、`unregistered` は stdout に `not-in-orca`、`create` は `orca worktree create`（`repo_id` が空でなければ `--repo id:<repo_id>`、続けて `--name issue-<N> --issue <N> --base-branch origin/<起点> --parent-worktree path:<親> --json`）、`start`・`deliver` は `orca terminal list`・`send`・`create`・`wait --for tui-idle`・`close --all`、`close` は `orca terminal close --worktree path:<wt> --all`（失敗したら端末の一覧を stderr に出し、`EPIC_DISPATCH_REAP_CLOSE_RETRY_WAIT` 秒待って 1 回だけ閉じ直す）、`remove` は `orca worktree rm --worktree path:<wt>`（`--force` を付けない。stderr に `terminal sweep failed` があれば `rm-failed-terminal-sweep`、それ以外の失敗は `rm-failed`）、`mirror` は `orca worktree set --worktree <current か path:<wt>>` に `done` → `--workspace-status completed`、`waiting` → `--workspace-status in-review`、`stopped` → `--comment epic-stopped`、`resumed` → `--comment epic-resumed`、`stopped-seen` → `--comment epic-stopped-seen` を付けたもの。

Orca の部品を使うとき、`epic-dispatch.sh` の stdout・exit code・stderr の文言・記録の中身と、`orca`・`git`・`gh` の呼び出しの順と回数は、起動部品へ切り出す前と同じでなければならない（MUST）。`epic-dispatch.sh` は待ち時間の環境変数（`EPIC_DISPATCH_READY_TIMEOUT_MS`・`EPIC_DISPATCH_SUBMIT_WAIT`・`EPIC_DISPATCH_REAP_CLOSE_RETRY_WAIT`）を今と同じ位置で検査して既定を当て、その値を同じ名前の環境変数で起動部品に渡す（MUST）。`repos` は 1 回の `launch` で多くても 1 回だけ呼ぶ（MUST）。`launch` と `adopt` は、要件「記録の launcher ごとに起動部品を選ぶ」の順で部品を選び、`reply`・`notify-closed`・`wait --resolve`・`reap` は子の記録の `launcher` の部品を呼ぶ（MUST）。部品の `available` を呼ぶ相手は操作で分かれる（MUST。要件「記録の launcher ごとに起動部品を選ぶ」が正本）: `launch`・`adopt` は選んだ部品、`reply`・`notify-closed`・`wait --resolve`・`reap` は対象の子の記録の `launcher` の部品である。入口で別の部品（例: 使えない Orca）を先に探して全体を終えてはならない（MUST NOT）。Orca の部品の `available` が失敗したときの `orca is not on PATH` での exit 1 は、Orca の部品を呼ぶ操作（記録の `launcher` が `orca` の子、または部品を決める記録が無い場合）の挙動で、tmux の記録の子には掛からない。

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

## ADDED Requirements

### Requirement: 記録の launcher ごとに起動部品を選ぶ

`epic-dispatch.sh` は、起動部品を操作の種類で次のとおり選ばなければならない（MUST）。

- **新しい子を起こす操作（`launch`・`adopt`）**: 環境変数 `EPIC_DISPATCH_LAUNCHER` が `orca` か `tmux` ならその部品、空なら Orca の部品の `here` が exit 0 のとき `orca`、環境変数 `TMUX` が空でなく `tmux` が PATH にあるとき `tmux`。選んだ部品の `available` が失敗したら、stdout に何も出さず、その部品の理由を stderr に出して exit 1 で終わる。空でどれも当たらなければ Orca の部品の `available` を呼び、今と同じ `orca is not on PATH` で exit 1 で終わる。`EPIC_DISPATCH_LAUNCHER` がそれ以外の値なら使い方を出して exit 1 で終わる。選んだ部品の名前を記録の `launcher` に書く
- **記録に従う操作（`reply`・`notify-closed`・`wait --resolve`・`reap`・`mark` の画面への写し）**: 対象の子の記録の `launcher` が指す部品を先に決め、その部品の `available` で使えるかを判定する。環境変数 `EPIC_DISPATCH_LAUNCHER` と `TMUX` は見ない（記録が正本）。入口で 1 本の部品の `available` を全体に掛けて終えてはならない（MUST NOT）。対象の子の部品がすべて同じで使えないときは、stdout に何も出さず、その部品の理由を stderr に出して exit 1（記録の `launcher` が `orca` の子だけ、または記録が 1 件も無いときは今と同じ `orca is not on PATH`）。一部の子の部品だけが使えないときは、その子だけを `failed <N> launcher-unavailable`（`reply`・`notify-closed`）、`kept <N> launcher-unavailable`（`reap`）にして、ほかの子は進める
- `mirror` は記録の `launcher` が `orca` のときだけ呼ぶ（既存の要件のまま）
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

#### Scenario: 混在するエピックでは使えない部品の子だけが止まる
- **WHEN** 記録の `launcher` が `orca` の子 11 と `tmux` の子 12 がいて、`orca` が PATH に無く、tmux の部品が使える環境で `epic-dispatch.sh reap 11 12` を実行する
- **THEN** 子 12 は tmux の部品で片付けられ、子 11 は `kept 11 launcher-unavailable` になる。exit code は `reap` の既存の規則に従う

### Requirement: tmux の部品は子を独立した Claude Code のセッションとして tmux のウィンドウに起動する

`plugins/dev-workflow/scripts/epic-launch-tmux.sh` は、要件「起動部品は epic-launch-<名前>.sh の 1 本ずつで、同じサブコマンドと出力の契約を持つ」の 12 個のサブコマンドを、`tmux` と `git` だけで実装しなければならない（MUST）。親が tmux で常駐していること（環境変数 `TMUX` が空でなく、`tmux` が PATH にある）を前提とし、`orca` を呼んではならない（MUST NOT）。開発に固有の語を入れてはならない（MUST NOT）。

| サブコマンド | tmux の部品の動き |
|---|---|
| `available` | `tmux` が PATH にあり `TMUX` が空でなければ exit 0。使えなければ stderr に `tmux is not available (run inside a tmux session)` を出して exit 1 |
| `here` | `available` と同じ条件なら `{"repo_id":"","worktree_id":""}` を出して exit 0、そうでなければ exit 1 |
| `prepare` | 何もせず exit 0 |
| `list`・`repos` | 何も出さず exit 0（記録が正本で、部品は子を知らない） |
| `unregistered` | stdout に `ok` |
| `create` | `repo_id` は読まない。ワークツリーは `git -C <clone か親のワークツリー> worktree add -b worktree-issue-<N> <リポジトリの最上位>/.claude/worktrees/issue-<N> origin/<起点>`（worktree プラグインの置き場と名前の決まり `<repo>/.claude/worktrees/<name>`・`worktree-<name>` に合わせる）。同じ名前のブランチかワークツリーが既にあれば作らず exit 1。作れたら `{"path","branch"}` の 1 行 |
| `start` | 同じ tmux サーバーに `tmux new-window -d -P -F '#{pane_id}' -c <ワークツリー>` でシェルを開き（起動コマンドを `new-window` に直接渡さない。対話でないシェルでは `cld` のシェル関数が解けないため）、起動コマンドを `send-keys -l` で打ち込んで Enter を送る。画面（`capture-pane`）に Claude Code の入力待ちが出るまで `EPIC_DISPATCH_READY_TIMEOUT_MS` を上限に待ち、最初の指示を `send-keys -l` で送って Enter を送る。送信が届いたかは、子のワークツリーの会話ログ（`${CLAUDE_PROJECTS_DIR:-~/.claude/projects}/<パスの英数字以外を - にした名前>/*.jsonl`）に、送る直前に控えた時刻より後の user の行が現れ、その本文が送った文の先頭 40 文字（40 文字に満たなければ全体）を含むことを `EPIC_DISPATCH_SUBMIT_WAIT` 秒を上限に確かめる（時刻だけでなく本文と照合するので、別のセッションが同じログに書いた入力とは区別できる。検出できないのは、先頭 40 文字より後ろの欠けと、送った文と同じ先頭を持つ別の入力が同時に入ったときである）。届けば `started <ペイン ID>`、段ごとの失敗は `failed terminal|ready|send <ペイン ID>`（exit 1） |
| `deliver` | ウィンドウ（ペイン）の一覧を `tmux list-panes -a` で 1 回だけ読み、`#{pane_current_path}` が子のワークツリーのペインを探す。Claude Code が動いていること（`#{pane_current_command}` と画面の入力待ち）を確かめたペインがちょうど 1 つなら、同じ送り方で文を送り、会話ログで（`start` と同じ本文の照合で）届いたことを確かめて `sent`。ペインが無い、または `relaunch` が 1 なら、あるペインを `kill-pane` してから `start` と同じ手順で起動し直し、`relaunched <ペイン ID>`。シェルだけのペインしか無い・候補が 2 つ以上のときは `relaunch` が 0 なら `failed ambiguous-terminal` |
| `close` | 子のワークツリーのペインを `tmux kill-pane` で閉じる。ペインが無ければ成功。閉じられなければ 1 回だけ閉じ直して、駄目なら exit 1 |
| `remove` | 子のワークツリーが属するリポジトリの本体のワークツリー（`git -C <ワークツリー> rev-parse --git-common-dir` の親）で `git worktree remove <ワークツリー>`（`--force` を付けない。ワークツリーの中から自分自身を消さない）。消せなければ理由の語 `rm-failed` を 1 行出して exit 1。`close` の成功後に `reap` が呼ぶ（`close` が失敗した子は `reap` が `kept close-failed` にして `remove` を呼ばない）。`epic-dispatch.sh` の `kept` の子を本体が確かめて消す操作（要件「別セッション方式の既存要件は…」）も同じ形で、本体が `bash epic-launch-tmux.sh remove <path>` を呼ぶ |
| `mirror` | 何もせず exit 0 |

この要件の検査（ペイン・画面・会話ログ・`git` の出力の分類）の守備範囲は次のとおりである。入力の出どころは、`epic-dispatch.sh` が検査済みで渡す引数と、`tmux`（`list-panes`・`capture-pane`・`new-window -P`）・`git`・子の会話ログの出力である。拾いたい誤りは、シェルのペインに指示を打ち込んで実行してしまうこと、Claude Code の入力待ちの表示が変わって黙って誤送信すること（`failed ready` にする）、送信が届いていないのに `started`・`sent` と言うこと、同じ名前のブランチ・ワークツリーを上書きすること、未コミットの変更があるワークツリーを消すことである。次は通してよく、この要件では止めない: 入力待ちの判定が画面の末尾の部分一致であること／`list-panes` の出力に改行を含むパスは無いと信じること／会話ログの user 行以外の形／送った文の先頭 40 文字より後ろの欠けと、同じ先頭を持つ別の入力が同時に入った場合（検出できない範囲として上の `start` の行に書いた）。tmux・画面・ログの崩れ方をすべて塞ぎ切ることは、この要件の完了条件としない。

送信の前に、送り先のペインで Claude Code が動いていることを確かめなければならない（MUST。シェルに指示を打ち込んで実行してしまう事故を避けるため）。送った文字列は `send-keys -l`（リテラル）で渡し、キー名として解釈させてはならない（MUST NOT）。

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

### Requirement: サブエージェント方式は状態の記録を書かない

サブエージェント方式（本体が W を `isolation: "worktree"` で起こして回す方式）は、状態の記録（`epic-state.sh` の書き込みと `epic-dispatch.sh` の `launch`・`mark`・`adopt`・`clear`）を使ってはならない（MUST NOT）。子の結果は本体が W の return で受ける。理由: W は親のセッションが終わると一緒に消えるので、記録があっても再開に使えず、独立したセッションを見張る目的（記録を読んで止まった子・終わった子を拾う）に当たらない。channel の挙動もこの要件では変えない。

#### Scenario: サブエージェント方式で記録のディレクトリができない
- **WHEN** `route` が `subagent` を返したエピックをサブエージェント方式で回す
- **THEN** SKILL.md の手順は `epic-dispatch.sh launch`・`mark`・`adopt` を呼ばず、`${EPIC_STATE_ROOT:-~/.claude/epic-state}` にそのエピックのディレクトリを作らない
