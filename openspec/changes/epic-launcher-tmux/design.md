## Context

3a の design.md（`openspec/changes/archive/2026-10-20-epic-launcher-split/design.md`）が起動部品の 12 個のサブコマンドの契約を決めた。元の出発点は `2026-10-20-epic-state-files/design.md` の Decision 12。3b はその上に tmux の部品を載せる。tmux の部品が埋めるサブコマンドの表は spec 差分の要件「tmux の部品は…」にあり、ここでは決めた理由だけを書く。

## Decisions

### 1. 登録の仕組みを持たない部品は、`unregistered` が `ok` を返して「登録は要らない」と伝える（3a の Open Questions への答え）

`xrepo_resolve` は `repos` に clone が無いと `unregistered` を呼び、返った語をそのまま `failed <child> <語>` にする。tmux の部品の `repos` は空なので、このままでは別リポジトリの子がすべて失敗する。
- 案 A（採用）: `unregistered` が `ok` を返したら `XR_CODE=ok`、`XR_ID` は空のまま通す。契約の変更は `unregistered` の戻り値に 1 語足すだけで、Orca の部品の動きは変わらない
- 案 B: 新しいサブコマンド（`needs_registration` など）を足す。サブコマンドが 13 個になり、3a の「12 個」と bats の照合を変える
- 案 C: tmux の `repos` に `EPIC_DISPATCH_CLONES` の clone を返させる。部品が `epic-dispatch.sh` の環境変数を読むことになり、境目（渡したものだけが部品に届く）を壊す
`create` が子を作るリポジトリは `clone` で決める。別リポジトリの子は `xrepo_resolve` が見つけたパスが `clone` に入り、同じリポジトリの子は今のまま空。空なら親のワークツリーのリポジトリ（worktree は同じリポジトリのどのワークツリーからでも作れる）。`repo_id` を読むのは Orca の部品だけ（空なら `--repo` を付けず親と同じリポジトリ）で、tmux の部品は読まない。つまり別リポジトリの子は tmux では「`clone` が空でなく `repo_id` が空」で届き、これが正常な組み合わせである（Orca の部品にはこの組み合わせは届かない。`repo_id` が空で `clone` が空でないのは `unregistered` が `ok` を返した部品だけ）。`here` の `repo_id` が空であることは、tmux では正常なので、`launch`・`adopt` の `has no repoId` の停止は Orca の部品を選んだときだけにする。`list` は空なので「記録の無い既存の子」は拾えず、記録が正本のまま `adopt` は全員 `none`。

### 2. tmux の部品のワークツリーの置き場とブランチ名は worktree プラグインに合わせる

`plugins/worktree/scripts/wt-create-hook.sh` の決まり（`<repo>/.claude/worktrees/<name>`、ブランチ `worktree-<name>`、`git worktree add -b`）に合わせ、`<name>` は Orca の部品と同じ `issue-<N>` にする。Claude Code 側の後片付けと食い違わず、`/wt-clean` でも見つかる。`--lock` は付けない（`remove` が `--force` なしで消せるようにするため。`git worktree remove` はロックされたワークツリーを `--force` 2 回でないと消さない）。起点は `origin/<起点>`（Orca の `--base-branch origin/<base>` と同じ。`epic-dispatch.sh` が先に fetch する）。

### 3. セッションは `new-window -d` でシェルを開き、起動コマンドを `send-keys -l` で打ち込む

`new-window` にコマンドを直接渡すと対話でないシェルで走り、`cld`（シェル関数）が解決されない。シェルを開いてから打ち込めば、Orca の部品が空のシェルへ起動コマンドを送る今の形と揃う。`session` の値は `-P -F '#{pane_id}'` で受けたペイン ID（ウィンドウの番号は並べ替えで変わるため）。

- 起動待ち: `capture-pane -p` の画面に Claude Code の入力待ちの文字列が出るまで（`EPIC_DISPATCH_READY_TIMEOUT_MS` を上限に）ポーリングする。入力待ちの文字列は実機で確かめて部品の定数にする（tasks 5.1）。文字列が将来変わったときは `failed ready` になり黙って誤送信しない
- 送信の確かめ: `send-keys` が成功しても入力欄に入っただけで送信されたとは限らない。Orca の `--wait-submit` に当たるものとして、子のワークツリーの会話ログ（`CLAUDE_PROJECTS_DIR` の下）に、送る直前に控えた時刻より後の user の行が現れ、その本文が送った文の先頭 40 文字（短ければ全体）を含むことを `EPIC_DISPATCH_SUBMIT_WAIT` 秒まで待つ。時刻だけだと別のセッションが同じログに書いた入力を送信と取り違えるため、本文も照合する。検出できないのは、先頭 40 文字より後ろの欠けと、同じ先頭の別の入力が同時に入った場合。全文を照合しないのは、Claude Code がログに書く本文が入力と完全には一致しない（空白や貼り付けの扱い）ことがあり、全文一致だと正常な送信を `failed send` にしてしまうため
- 送る前の確認: `#{pane_current_command}` が Claude Code（`node` か `claude` など、実機で確かめる）を示し、画面が入力待ちであること。シェルが前面なら送らない（指示がシェルコマンドとして実行される事故を避ける）
- 閉じるのは `kill-pane`、消すのはワークツリーが属するリポジトリの本体のワークツリーで `git worktree remove`（`--force` なし。`git -C <ワークツリー> rev-parse --git-common-dir` の親を使うので、別リポジトリの子でも記録に clone を持たずに消せる）。`mirror` は何もしない

### 4. `route` の判定順と、素の tmux の人への影響

判定順: `nested` → `EPIC_DISPATCH_LAUNCHER` → Orca 管理なら `orca` → tmux の中なら `tmux` → `subagent`。Orca を先にするのは、今 Orca 管理下の人（tmux の中で Orca を使う人を含む）の `route` の結果を変えないため。`EPIC_DISPATCH_LAUNCHER` を足したのは、素の tmux で interactive を使っている人が `route` で自動的に `tmux` 経路に変わるのを避けられるようにするため（`subagent` に固定する値は作らない。固定したい人は `回し方: サブエージェント` を残すか、子の件数 0 で呼ぶ。unmanned と channel は今も `route` を呼ばない）。`EPIC_DISPATCH_LAUNCHER` の値が使えない部品のときは `subagent` に落とし、stderr に理由を出す。
- 受け入れること: 素の tmux で interactive の `/develop <エピック>` を使っている人は、この変更のあと、blocked されていない子が 1 件以上あるエピックで `tmux` 経路になる。親が長く待つ間に子が別ウィンドウで動き、主の返事待ちが親に積もる点が今のサブエージェント方式と違う。気になる人は `EPIC_DISPATCH_LAUNCHER=orca`（Orca 管理外なら `subagent` になる）を置く

### 5. サブエージェント方式に記録を書かせない（Decision 12 の決め直し）

Decision 12 は「サブエージェント方式も記録を書く」だった。決め直す。記録の目的は、独立したセッションの状態（止まった・終わった）を親が再起動をまたいで読むこと。W は親のセッションが終わると一緒に消えるので、記録があっても再開に使えない。書かせると `launch`／`mark` の呼び出しを本体の手順に足すことになり、channel の挙動（`route` を呼ばない・別セッションを起こさない）にも触れる。書かせない。SKILL.md は共通の手順（起動・待ち・閉じた子・止まった子・片付け・完了）を 1 本にし、各段に部品ごとの欄を置く。Orca と tmux は手順 1〜8 を共有し、サブエージェント方式は「起動は W を起こす」「待ちは W の return」「片付けは本体が `/wt-clean` 相当」の欄を持つ。

### 6. channel の住人は tmux の部品を使えない（範囲外として残す）

channel は `route` を呼ばず、別のセッションを起こさない（#1126 の範囲で、SKILL.md の規定の意味は変えない）。issue 本文の「住人が tmux で常駐している前提」は、interactive／unmanned でない常駐セッションが tmux の部品を使う場面を指すが、channel の規定とは両立しない。この change は規定を変えず、channel で再開したエピックの最新の `回し方:` が Orca か tmux のとき、報告して止まる（今 Orca について書いてある規定を tmux にも広げただけ。意味は「channel は別セッション方式を引き継がない」のまま）。channel の住人が tmux の部品を使うようにするかは #1126 で決める。

### 7. 部品が選べないときの失敗

操作の種類で、部品を決める元が違う。新しい子を起こす `launch`・`adopt` は環境から選び、選んだ部品が使えなければ exit 1 で stderr に理由を出す（環境から選べる部品が無いときは Orca の部品の `available` を呼び、今と同じ `orca is not on PATH`）。記録に従う `reply`・`notify-closed`・`wait --resolve`・`reap` は、入口で 1 本の部品を探さず、対象の子の記録の `launcher` の部品を先に決めてその `available` を呼ぶ。理由: 入口で Orca を探すと、使えない Orca を `EPIC_DISPATCH_LAUNCHER=orca` で指した環境から、使える tmux の記録の子に届かなくなる。対象の子の部品がすべて同じで使えなければ今の挙動（stdout 空・stderr に理由・exit 1。Orca なら `orca is not on PATH`）、部品が混在して一部だけ使えなければその子だけ `launcher-unavailable`。旧 stderr（stdout 空・`orca is not on PATH`・exit 1）の維持が掛かるのは、記録の `launcher` が `orca` の子だけの場合と、記録の無い子だけを渡して Orca の部品の `available` が失敗した場合である。記録の無い子だけでも Orca が使えれば既存の結果（`reap` は `gone <N>`・exit 0 など）を変えない。`mark`・`wait --watch-stopped` の画面への写しはこの規則から外す: 記録の更新が成功すれば Orca 不在でも、`mark` は `marked …`・exit 0、`wait --watch-stopped` は `stopped <N>`・exit 0 のまま（既存 epic-state spec の「Orca 管理外では写さない」と止まった子の受け取りの規則のまま）。

### 8. 既存の「Orca 経路」の要件は共通手順として読み、部品固有の操作だけ表で分ける

既存要件のうち片付け・停止解決・マージ待ち判断・完了促進の 5 本は、見出しが「Orca 経路」だが中身は記録（`status`・`stop`）から状態を読む共通手順で、Orca 固有なのは本体が `kept` を解消したあとの `orca worktree rm`、`wait` の失敗時の「Orca の親ワークツリーで開き直す」案内、端末への送信（`deliver`）だけである。5 本を MODIFIED で書き写すと数千字の複製が 5 つできて直しが漏れるので、develop の spec に読み替えの要件を 1 本足し、部品で違う点を表にした。tmux の片付けの操作は、本体が `epic-launch-tmux.sh remove <path>`（`git worktree remove`、`--force` なし）を呼ぶ形に決めた。Orca の `orca worktree rm` は変えない。

### 9. 再開時の部品は `回し方:` のコメントから `EPIC_DISPATCH_LAUNCHER` で渡す

`launch`・`adopt` は部品を毎回今の環境から選ぶので、`回し方: tmux` と記録したエピックを Orca 管理下で開き直すと、新しい子だけ Orca で起動して部品が混ざる。経路を引き継ぐ規則（`route` をやり直さない）に、本体が最新の `回し方:` の部品名を `EPIC_DISPATCH_LAUNCHER` で `launch`・`adopt` に渡す手順を足した。使えなければ別の部品にもサブエージェント方式にも振り替えず、報告して止まる（`launch` に失敗した子をサブエージェント方式へ自動で振り替えない既存の規則と同じ向き）。記録に従う操作（`reply`・`reap` など）は記録の `launcher` で決まるので渡さない。

## Risks / Trade-offs

- [起動待ちの文字列が Claude Code の版で変わる] → `failed ready` になり、誤送信しない。文字列は部品の先頭の定数 1 か所。実機確認（tasks 5）で現行版を確かめる
- [送信の確かめを会話ログに頼る] → 会話ログの場所の規則（パスの英数字以外を `-` にする）は `decide_relaunch` が既に使っている（epic-dispatch.sh の `CLAUDE_PROJECTS_DIR`）。送った文の先頭 40 文字を含む user 行が現れない場合は `failed send` で止まり、親は送り直しのコマンドを主に出す（Orca と同じ扱い）。別のセッションの入力との取り違えは本文の照合で防ぐが、先頭 40 文字より後ろの欠けは検出できない
- [tmux の部品は `--lock` を付けないので、`git worktree prune` 相当の操作で消されうる] → 子のワークツリーは記録の `worktree` が指し、`reap` の安全確認を通らないと消さない。`git worktree prune` はディレクトリが無いものしか消さない
- [`send-keys` が長い指示で欠ける] → `-l` で渡すリテラルは長さに上限が無いが、改行を含むとEnter と解釈される。指示は 1 行（今も 1 行）。先頭 40 文字の照合では、末尾の欠けは検知できない（指示が 1 行で短いので許容）

## Migration Plan

記録の書式は変わらず、`launcher` に `tmux` が入りうるだけ。古い版の親が `tmux` の記録を読むことは、同じ版の plugin が全セッションに入るので起きない。戻し方: この change の PR を revert。`tmux` の記録は `launcher` を読めない記録として扱われる（Orca だけの版に戻したとき）ので、`~/.claude/epic-state/` の該当エピックのディレクトリを手で消してよい。

## Open Questions

なし（channel の住人が tmux の部品を使えるようにするかは #1126）。
