## MODIFIED Requirements

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

親が子を起動するとき、Orca/tmux の両起動部品は `claude` に渡る起動引数に `--prompt-suggestions false` を付けなければならない（MUST）。`start` と `deliver` の起動し直しのいずれにも適用する。Orca の画面と任意の `draft` では Claude Code の提案文と人の入力を常に区別できないためである。設定ファイルや別の識別の仕組みを作ってはならず（MUST NOT）、これより前に起動された子の非空の入力表示や `draft` も人の入力として扱わなければならない（MUST）。

`keepalive` は前景が空いた入力待ちで入力欄が空のときだけ送信し、初回と送信直前の観測に次の判定を適用しなければならない（MUST）。空の `❯` だけで入力待ちと判断してはならず（MUST NOT）、前景の状態と空欄の両方を確認する。

| 画面・入力の観測 | 判定 |
|---|---|
| 記号＋`…`＋`(Ns · …)` のスピナー行（例: `✢ Hullaballooing… (1s · thinking)`） | 空の `❯` と同居しても実行中として `skipped busy` |
| AskUserQuestion の `Enter to select · ↑/↓ to navigate` | `skipped dialog` |
| 許可画面の `Do you want to proceed?` または `Esc to cancel · Tab to amend` | `skipped dialog` |
| フォルダ信頼確認の `Enter to confirm · Esc to cancel` | `skipped dialog` |
| Orca の画面と任意の `draft` | `orca terminal read --terminal <handle> --screen --json` の `result.terminal.tail`（文字列の配列）と `result.terminal.source` を読む。source が screen でない場合（欠落を含む）は `skipped unknown-state`。`status: running` は入力待ちと実行中の区別に使わない。画面の一意な入力枠の領域全体が空のときだけ空欄とし、任意の `result.terminal.draft` が非空なら `skipped input-not-empty`。draft の欠落や空文字だけで空欄とは決めない。薄字の提案を含め文字があれば入力済みとする |
| tmux の画面 | `tmux capture-pane -p -e -t <pane>` で前景の入力待ちを確認し、`❯ ` の後が空なら空欄。薄字 `\e[2m` の提案文だけなら空欄とみなしてよい（MAY）。それ以外の文字は `skipped input-not-empty` |
| `· N shell still running` の表示 | バックグラウンドのシェルだけなら前景は空いているため、他の条件を満たせば送信可 |

Orca の入力枠は上罫線・`❯` から下罫線までの一意な領域と、既知の Claude Code フッターで確認しなければならない（MUST）。フッターは shortcuts・cycle・manual-mode の既知の表示に加え、末尾の `⏵⏵ bypass permissions on` と操作案内の表示を認め、後者の下罫線とフッターの間には複数のカスタム statusline を許す。入力領域内の改行・空行・プロンプトやフッターに似た入力を捨ててはならない（MUST NOT）。複数の開始枠やフッターの後にシェル表示がある画面では送ってはならない（MUST NOT）。

前景の入力待ち・空欄を確定できない場合は `skipped unknown-state` としなければならない（MUST）。上の実行中や選択画面を観測した場合は、空の入力欄が同居しても送信してはならない（MUST NOT）。

この要件の検査（知らないサブコマンドと引数の数、`list`・`repos`・端末の一覧の読み取り、子のセッションの端末の選び方、`keepalive` の対象状態と出力）の守備範囲は次のとおりである。入力の出どころは `epic-dispatch.sh`（同じプラグインの中の呼び出し元）と、`orca` が返す JSON・端末画面の CLI 出力である（tmux の観測は要件「tmux の部品は…」に従う）。拾いたい誤りは、`epic-dispatch.sh` と部品のサブコマンドの名前か引数の並びが食い違うこと、`orca` の JSON の形が変わって読めないこと（読めないときは 0 件として扱わず失敗にする）、子のセッションの端末を 1 つに決められないのに送ること、`keepalive` で実行中・入力済み・選択画面・観測不能な端末に送ること、送れないときに作成・終了・入力消去をすることである。`epic-dispatch.sh` が検査済みの値（待ち時間・起動コマンド・指示と返事の文・子の呼び方・ワークツリーのパス）は、部品の中で検査し直さずにそのまま通してよい（MAY）。`keepalive` で空欄を確認できない出力は送らない。CLI 観測と送信の間の主の並行入力を原子的に排除することや、引数の中身の妥当性、`orca` の JSON・画面のあらゆる崩れ方を塞ぎ切ることは、この要件の完了条件としない。

Orca の部品は、各サブコマンドで次の `orca` のコマンドだけを呼び、Orca の機能を自前で作り直してはならない（MUST NOT）: `available` は `orca` が PATH にあるか（無ければ stderr に `orca is not on PATH`）、`here` は `orca worktree current --json`、`prepare` は `orca worktree set --worktree path:<親> --issue <E>`、`list` は `orca worktree list --json`（`isArchived` が true のものを除き、`workspaceStatus` の `completed` → `done`・`in-review` → `waiting`・それ以外 → `running`、`comment` の `epic-stopped` → `stopped`・`epic-stopped-seen` → `stopped-seen`・`epic-resumed` → `resumed`・それ以外 → 空に読み替える）、`repos` は `orca repo list --json`、`unregistered` は stdout に `not-in-orca`、`create` は `orca worktree create`（`repo_id` が空でなければ `--repo id:<repo_id>`、続けて `--name issue-<N> --issue <N> --base-branch origin/<起点> --parent-worktree path:<親> --json`）、`start`・`deliver` は `orca terminal list`・`send`・`create`・`wait --for tui-idle`・`close --all`、`keepalive` は `orca terminal list --worktree path:<wt> --json`・`orca terminal read --terminal <handle> --screen --json` による既存端末/画面/任意の draft の観測と、`orca terminal send --terminal <handle> --text <text> --enter --wait-submit <EPIC_DISPATCH_SUBMIT_WAIT> --json` だけ（送信が exit 0 で、send 応答の stages 配列の `turn_started` を確認したとき、または以下の送信後再観測で到達確認したときだけ `sent`。入力受付だけでは成功としない。実行中の子が idle になるのを待つ `terminal wait`、create/close、入力消去、再試行の送信は許さない）、`close` は `orca terminal close --worktree path:<wt> --all`（失敗したら端末の一覧を stderr に出し、`EPIC_DISPATCH_REAP_CLOSE_RETRY_WAIT` 秒待って 1 回だけ閉じ直す）、`remove` は `orca worktree rm --worktree path:<wt>`（`--force` を付けない。stderr に `terminal sweep failed` があれば `rm-failed-terminal-sweep`、それ以外の失敗は `rm-failed`）、`mirror` は `orca worktree set --worktree <current か path:<wt>>` に `done` → `--workspace-status completed`、`waiting` → `--workspace-status in-review`、`stopped` → `--comment epic-stopped`、`resumed` → `--comment epic-resumed`、`stopped-seen` → `--comment epic-stopped-seen` を付けたもの。

既存操作で Orca の部品を使うとき、`epic-dispatch.sh` の stdout・exit code・stderr の文言・記録の中身と、`orca`・`git`・`gh` の呼び出しの順と回数は、起動部品へ切り出す前と同じでなければならない（MUST）。新たな声かけの観測・送信と、子の起動引数への `--prompt-suggestions false` の追加をこの同一性の対象外とし、wait の既存の出力・終了理由を変えてはならない（MUST NOT）。`epic-dispatch.sh` は待ち時間の環境変数（`EPIC_DISPATCH_READY_TIMEOUT_MS`・`EPIC_DISPATCH_SUBMIT_WAIT`・`EPIC_DISPATCH_REAP_CLOSE_RETRY_WAIT`）を今と同じ位置で検査して既定を当て、その値を同じ名前の環境変数で起動部品に渡す（MUST）。`repos` は 1 回の `launch` で多くても 1 回だけ呼ぶ（MUST）。`launch` と `adopt` は、要件「記録の launcher ごとに起動部品を選ぶ」の順で部品を選び、`reply`・`notify-closed`・`wait --resolve`・`reap` は子の記録の `launcher` の部品を呼ぶ（MUST）。部品の `available` を呼ぶ相手は操作で分かれる（MUST。要件「記録の launcher ごとに起動部品を選ぶ」が正本）: `launch`・`adopt` は選んだ部品、`reply`・`notify-closed`・`wait --resolve`・`reap` は対象の子の記録の `launcher` の部品である。入口で別の部品（例: 使えない Orca）を先に探して全体を終えてはならない（MUST NOT）。Orca の部品の `available` が失敗したときの `orca is not on PATH` での exit 1 は、Orca の部品を呼ぶ操作（記録の `launcher` が `orca` の子、または部品を決める記録が無い場合）の挙動で、tmux の記録の子には掛からない。

`keepalive` の送る文は dispatch が共通定義から生成した一つの引数で渡し、部品は展開・改変しない（MUST）。送信直前に既存セッション・入力待ち・空欄・選択画面でないことを再観測し、いずれか不明なら送らず `skipped unknown-state` とする（MUST）。読み取り自体の失敗や壊れた出力は `failed observe`（一覧なら `failed terminal-list`）とし、セッション無しとみなさない（MUST）。`keepalive` は記録の launcher の部品を選び、対象外・失敗でも別の部品へ切り替えない（MUST）。送信後の確認待ち以外に子が入力待ちになるまで待たず、同じ呼び出しで再送しない（MUST NOT）。send が exit 0 でも `turn_started` を確認できなければ、同じ構造の read で 1 回だけ再観測してよい（MAY）。このときは送信前には無かった前景の実行中表示と、入力枠全体および任意の draft が空であることの両方を確認した場合だけ `sent` とし、未確認なら `failed send` / exit 1 としなければならない（MUST）。busy という分類結果だけで空欄を確認したことにしてはならない（MUST NOT）。

Orca の画面 read が JSON として壊れている、`result.terminal` が object でない、tail が欠落または文字列配列でない、任意の draft が文字列でない場合は、stderr に `failed observe shape` と期待するフィールドを出さなければならない（MUST）。送信前は stdout `failed observe` / exit 1、送信後の再観測なら stdout `failed send` / exit 1 とし、画面や JSON 全体を診断に複写してはならない（MUST NOT）。

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
- **WHEN** `result.terminal.source` が screen で、tail の一意な入力枠全体が空、`status: running`、`result.terminal.draft` が無い場合・空文字の場合・人の入力が入った場合・変更前に起動した子の提案文が入った場合を用意し、他の送信条件を満たす
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

#### Scenario: 実測の Orca 画面と statusline で入力待ちを認識する
- **WHEN** Orca 1.4.263 の実測 read を元にした fixture が `result.terminal` に source=screen、tail、tailRows、cursor 類を持ち draft は無く、tail に一意な上罫線・空の `❯`・下罫線・複数の statusline・末尾の `⏵⏵ bypass permissions on · 1 shell · ← 3 agents · ↓ to manage` があり、他の送信条件を満たす
- **THEN** 空欄の入力待ちとして送信可能とし、send の到達を確認した場合だけ `sent` / exit 0 を返す。statusline のパスや数値に依存しない

#### Scenario: draft が無くても入力領域全体を調べる
- **WHEN** 現行構造で draft が無く、入力枠の `❯` の後、折り返し行、空行の後、または薄字に文字がある場合を用意する
- **THEN** 全て `skipped input-not-empty` / exit 0 となり、send は呼ばれず入力を保持する。複数の開始枠で一意に決まらない場合は `skipped unknown-state` とする

#### Scenario: 観測構造の不一致を診断する
- **WHEN** 送信前の read が不正 JSON、result.terminal の欠落、terminal の配列、tail の欠落、tail の文字列、tail の非文字列要素、または draft の非文字列のいずれかである
- **THEN** stdout は `failed observe` / exit 1、stderr に `failed observe shape` と期待するフィールドが出て、send は呼ばれない。観測全体は出力しない

#### Scenario: source が画面でなければ送らない
- **WHEN** 現行構造の tail は文字列配列だが source が欠落、stream、screen-unavailable のいずれかである
- **THEN** `skipped unknown-state` / exit 0 となり send は呼ばれない

#### Scenario: 現行 send receipt のターン開始を認識する
- **WHEN** 二度の送信前観測が ready で、send が exit 0、実測した現行 send 応答の stages 配列に turn_started がある（配列が receipt の内側にある場合を含む）
- **THEN** send は 1 回、stdout は `sent` / exit 0 となる。input_accepted だけの応答ではこの条件を満たさない

#### Scenario: ターン開始が未確認でも画面の実行開始と空欄で到達確認する
- **WHEN** 二度の送信前観測が ready で、send は exit 0 だが turn_started が無く、1 回の送信後 read で新しい前景の実行中表示と、一意な入力枠全体および任意の draft の空欄を確認する
- **THEN** `sent` / exit 0 とし、read は合計 3 回、send は合計 1 回で、wait/create/close/再送/入力消去を行わない

#### Scenario: 送信後の busy だけでは到達確認しない
- **WHEN** turn_started が無い send の後に、busy 表示だけで入力枠が見えない画面、busy だが入力済みの枠、非空の draft、idle のままの画面、または構造が壊れた read を再観測する
- **THEN** いずれも `failed send` / exit 1 で再送しない。構造が壊れた場合は stderr に `failed observe shape` も出す
