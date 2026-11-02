## Context

`plugins/dev-workflow/scripts/epic-dispatch.sh`（1585 行）は、エピックの子を並列に起動して見張るスクリプトで、子の状態は change 1 からローカルの記録（`~/.claude/epic-state/`、読み書きは `epic-state.sh`）にある。ただし子のワークツリーを作る・セッションを開く・指示を送る・閉じる・消す・Orca の画面に印を写す処理は、`orca` のコマンドを直接呼ぶ形で次の箇所に散らばっている。

| 箇所 | `orca` の呼び出し |
|---|---|
| `cmd_route` | `orca worktree current --json`（Orca 管理かの判定） |
| `cmd_launch` | `worktree current`（`repoId`）→ `worktree set --issue <E>`（親をエピックに紐づける）→ `worktree list`（記録の無い既存の子を探す）→ 子ごとに `repo list`（別リポジトリの子の clone の発見と `repoId`。1 回の launch で 1 回）→ `worktree create` → `terminal list` / `terminal send`（空のシェルへ起動コマンド）か `terminal create` → `terminal wait --for tui-idle` → `terminal send --wait-submit` |
| `deliver_reply`（`reply`・`notify-closed`・`wait --resolve` が使う） | `terminal list` → 送る（`terminal send`）か、`terminal close --all` → `terminal create` → `terminal wait` → `terminal send` |
| `cmd_reap` | `terminal close --all`（失敗したら `terminal list` を出して待ち、1 回だけ閉じ直す）→ `worktree rm`（`--force` なし。stderr の `terminal sweep failed` で理由を分ける） |
| `cmd_adopt` | `worktree current`（`repoId` と `id`）→ `worktree list` |
| `mirror_orca`（`mark`・`wait --watch-stopped`） | `worktree set --worktree <current か path:…> --workspace-status … / --comment …` |
| 各コマンドの入口 | `command -v orca`（無ければ `orca is not on PATH` で exit 1） |

`tests/epic-dispatch.bats`（4870 行・370 件）は PATH の先頭に `orca`・`git`・`gh` のスタブを置き、呼び出しを `STUB_LOG` に書いて回数まで照合する（`calls()`）。テストの 1 件は「`orca` の語を含むシェルスクリプトは `epic-dispatch.sh` だけ」を `grep -rlw orca` で確かめている（既存要件「develop の手順書に orca のコマンドを書かず、orca を呼ぶスクリプトは 1 本にする」）。

起動部品の境目の出発点は `openspec/changes/archive/2026-10-20-epic-state-files/design.md` の Decision 12（サブコマンド `create`・`start`・`send`・`restart`・`close`・`remove`・`mirror` の 7 つ、記録と見張りは `epic-dispatch.sh` に残す、tmux の部品、サブエージェント方式も記録を書く、`route` の 4 値）。この change はそのうち境目と Orca の部品だけを扱い、tmux の部品・`route` の 4 値・サブエージェント方式の記録・SKILL.md は 3b（`epic-launcher-tmux`）に回す。

## Goals / Non-Goals

**Goals:**

- `orca` のコマンドを呼ぶのは `scripts/epic-launch-orca.sh` の 1 本だけにする
- 起動部品のサブコマンドと出力の契約を、tmux の部品もそのまま実装できる形で決める
- `epic-dispatch.sh` の外から見える動き（stdout・exit code・stderr の文言・記録の中身）と、`orca`・`git`・`gh` の呼び出しの順と回数を変えない

**Non-Goals:**

- tmux の部品（`epic-launch-tmux.sh`）、`route` の `tmux`、記録の `launcher` ごとに部品を選ぶこと、サブエージェント方式に記録を書かせるかの決め直し、develop の SKILL.md「エピックの扱い」の書き直し、実機確認（いずれも 3b）
- 起動の指示の文（`… から Orca で起動`）の言い換え（部品ごとの名前を入れるかは 3b で決める）
- `reap` の安全確認（PR・未コミット・未マージのコミット）の移動。これは開発に固有の判定なので `epic-dispatch.sh` に残す
- channel モード（#1126 の範囲）

## Decisions

### 1. 起動部品は別のプロセスとして呼ぶスクリプトにし、状態を持たせない

`epic-dispatch.sh` は起動部品を `bash "<epic-dispatch.sh と同じディレクトリ>/epic-launch-<名前>.sh" <サブコマンド> <引数...>` で呼ぶ。起動部品は記録を読み書きせず、記録・見張り・上限・`reap` の安全確認は `epic-dispatch.sh` に残す（Decision 12 のとおり）。起動部品の stdout は契約の行（決まった語か 1 行 1 件の JSON）だけにし、stderr には、切り出す前の `epic-dispatch.sh` が stderr に出していたもの（`worktree set`・`worktree create`・`terminal create`・`send`・`wait`・`close` の出力、閉じ直しのときの `terminal list`、`worktree rm` の stderr、理由と案内の文）だけを同じ順と文で出し、中で解釈するだけの JSON（`worktree current`・`worktree list`・`repo list`・閉じ直し以外の `terminal list`）はどこにも出さない（今もどこにも出していないため。出すと stderr の文言が変わる）。

- 案: `epic-state.sh` と同じく `source` で読み込む関数にする。呼び出しは速いが、`ready`・`submit`・`agent_cmd` のような大域変数を部品の中から読めてしまい、境目が守られているかをテストで確かめられない。tmux の部品を足すときに、どの値が境目を越えているかが分からなくなる。別のプロセスなら、渡したものだけが部品に届く
- `bash <パス>` で呼ぶのは、実行権の有無に左右されないため（`epic-state.sh` と同じ置き場で、install 先でも同じ相対位置にある）
- 待ち時間の値（`EPIC_DISPATCH_READY_TIMEOUT_MS`・`EPIC_DISPATCH_SUBMIT_WAIT`・`EPIC_DISPATCH_REAP_CLOSE_RETRY_WAIT`）は、`epic-dispatch.sh` が今と同じ場所で検査して既定を当てた値を、同じ名前の環境変数に入れて部品に渡す。部品は検査をやり直さない（検査の文言と exit 2 の位置が今と変わらないようにするため）

### 2. サブコマンドは 12 個にする（Decision 12 の 7 個から足す・まとめる）

| サブコマンド | 引数 | stdout と exit | Orca の部品が呼ぶもの |
|---|---|---|---|
| `available` | なし | 何も出さない。使えれば exit 0、使えなければ stderr に理由（Orca は `orca is not on PATH`）を出して exit 1 | `command -v orca` |
| `here` | なし | 今のワークツリーが部品の管理下なら `{"repo_id":…,"worktree_id":…}` の 1 行で exit 0。管理下の判定は `orca worktree current --json` の exit だけで決め、`jq` が無い・JSON を読めない・値が無いときは値を空の文字列にする（今の `route` は `jq` を使わずに判定しているため。bats 565 行がこれを固定している）。管理外・部品が使えなければ exit 1（stderr に `not in an Orca-managed worktree`） | `orca worktree current --json` |
| `prepare` | `<親のワークツリー> <エピックの番号>` | 何も出さない。親をエピックに紐づけたら exit 0、失敗は exit 1 | `orca worktree set --worktree path:<親> --issue <E>` |
| `list` | なし | 部品が知っている子のワークツリーを 1 行 1 件の JSON `{"repo_id","issue","path","branch","parent_id","status","stop"}` で出す（片付け済みのものは出さない。`branch` は `refs/heads/` を外す。`status` は `done`・`waiting`・`running`、`stop` は `stopped`・`stopped-seen`・`resumed`・空に読み替える）。読めなければ exit 1 | `orca worktree list --json` |
| `repos` | なし | 部品に登録された clone を 1 行 1 件の JSON `{"id","path"}`（`path` の末尾の `/` は外す）で出す。読めなければ exit 1 | `orca repo list --json` |
| `unregistered` | `<clone>` | stdout に理由の語（Orca は `not-in-orca`）を出し、stderr に登録の仕方を出して exit 0 | 呼ばない（案内の文だけ） |
| `create` | `<clone> <repo_id> <子の番号> <起点> <親のワークツリー>` | 作れたら `{"path","branch"}` の 1 行で exit 0。作れなかったら exit 1。作ったと言うがパスを読めなければ exit 2 | `orca worktree create [--repo id:<repo_id>] --name issue-<N> --issue <N> --base-branch origin/<起点> --parent-worktree path:<親> --json`（`repo_id` が空なら `--repo` を付けない。`clone` は使わない） |
| `start` | `<ワークツリー> <起動コマンド> <最初の指示> <子の呼び方>` | 指示が届いたら `started <session>` で exit 0。届かなかったら `failed <段> <session か空>` で exit 1（段は `terminal`・`ready`・`send`） | 今の `shell_start` → `terminal create` → `terminal wait` → `terminal send` |
| `deliver` | `<ワークツリー> <relaunch 0か1> <送る文> <起動コマンド> <起動し直しの指示>` | `sent`・`relaunched <session>`（どちらも exit 0）・`failed <理由>`（理由は `terminal-list`・`ambiguous-terminal`・`send`・`close`・`create`・`ready`、exit 1）のどれか 1 行。「端末一覧が空」なら起動し直し、「端末はあるが子のセッションに決められない」（シェルの端末だけを含む）なら `relaunch` 0 のとき `ambiguous-terminal` で送りも起動し直しもしない（今の動き。bats 3396 行） | 今の `deliver_reply` の `terminal list` 以降 |
| `close` | `<ワークツリー> <子の呼び方>` | 何も出さない。閉じたら exit 0、1 回閉じ直しても駄目なら exit 1。子の呼び方は閉じ直しの stderr の文（`terminal close was incomplete for #<N>; …`）にだけ使う | `orca terminal close --worktree path:<wt> --all`（失敗したら `terminal list` を出し、待って 1 回だけ閉じ直す） |
| `remove` | `<ワークツリー>` | 消したら何も出さず exit 0。消せなければ `rm-failed` か `rm-failed-terminal-sweep` を出して exit 1 | `orca worktree rm --worktree path:<wt>`（`--force` なし） |
| `mirror` | `<current かワークツリー> <done・waiting・stopped・resumed・stopped-seen のどれか> <記録のパス>` | 何も出さず常に exit 0。写せなければ stderr に出す。部品が使えなければ何もしない | `orca worktree set --worktree <current か path:…> --workspace-status completed／in-review` か `--comment epic-stopped／epic-resumed／epic-stopped-seen` |

決め直した点（Decision 12 の項目を指す）:

- **`send` と `restart` を `deliver` 1 つにまとめた。** Decision 12 は `send`（動いている子に送る）と `restart`（閉じて起動し直す）を分けていた。分けると、端末の一覧を `send` が読み、端末が無かったときに `restart` がもう一度読むので、`orca terminal list` の回数が今の 1 回から 2 回に増え、既存の bats の回数の照合が落ちる。加えて、2 回の読みのあいだに別の端末ができると、二重に起動する窓ができる。一覧を 1 回読んで「送る」か「閉じて起動し直す」かをその場で決める今の `deliver_reply` の形のまま部品へ移す。tmux の部品も、ウィンドウの一覧を 1 回読んで決める同じ形で書ける
- **`available`・`here`・`prepare`・`list`・`repos`・`unregistered` を足した。** Decision 12 の 7 個は子 1 件の起動と片付けだけを見ていて、親の側の Orca の呼び出し（管理かの判定、親をエピックに紐づける、記録の無い既存の子を探す、別リポジトリの clone の発見）が境目に入っていなかった。これらを `epic-dispatch.sh` に残すと `orca` を呼ぶスクリプトが 2 本になる。tmux の部品では、`prepare` は何もせず exit 0、`list`・`repos` は何も出さず exit 0、`here` は tmux の中にいるかで決める、のように「何もしない」実装で埋まる（3b で決める）
- **`adopt` 専用のサブコマンドは作らない。** `adopt` は `here`（`repo_id` と `worktree_id`）と `list`（`parent_id`・`status`・`stop`）を組み合わせれば今の判定のまま `epic-dispatch.sh` に書ける。Orca の印から記録へ写す読み替えの表（`completed` → `done` など）は Orca の語なので `list` の中に置き、`epic-dispatch.sh` は記録の語だけを見る
- **`close` と `remove` の失敗の理由は部品が出す。** 閉じ直しの待ちと `terminal sweep failed` の見分けは Orca に固有なので部品に置き、`epic-dispatch.sh` は `kept <N> close-failed` と、部品が出した理由をそのまま付けた `kept <N> <理由>` を出す。主の操作の案内（`owner action for #<N>: open the workspace … in Orca, … then run: epic-dispatch.sh reap <N>`）は子の番号と `epic-dispatch.sh` のコマンドを含むので、`close` が exit 1 を返したあとに `epic-dispatch.sh` が出す。`start` と `close` は子の番号を含む stderr の文（`no terminal handle for #<N> …`・`terminal close was incomplete for #<N>; …`）を出すので、子の呼び方を引数で受ける（`epic-dispatch.sh` が今その文に入れている値をそのまま渡す）
- **`remove` のあとの、ワークツリーが git の一覧から外れるのを待つ処理と、ブランチの片付けは `epic-dispatch.sh` に残す。** どちらも `git` だけで行い、Orca を呼ばない

### 3. 呼び出しの順と回数は、サブコマンドを今の `orca` の呼び出しの位置に 1 対 1 で置いて守る

- 各サブコマンドは、今の `epic-dispatch.sh` の中で連続している `orca` の呼び出しのまとまりに対応させ、そのまとまりがあった位置で呼ぶ。たとえば `launch` は今と同じく `available` → `here` → （`git fetch`）→ `prepare` → `list` の順で、`here` と `prepare` のあいだにある記録の照合・`origin` の読み取り・`git fetch` の位置は変えない
- `repos` は 1 回の `launch` で多くても 1 回だけ呼び、結果を `epic-dispatch.sh` が控える（今の `orca_repos_load` と同じ）。clone を `EPIC_DISPATCH_CLONES` で見つけて `repo_id` だけが要るときも、見つからずに clone を探すときも、同じ控えを使う
- `gh` と `git` の呼び出しは部品に移さない（`create` に `clone` を渡すが、Orca の部品は使わない。別リポジトリの子の `git -C <clone> fetch` は今の位置のまま `epic-dispatch.sh` が行う）
- stderr の文言は、移したものも含めて今と同じ文にする（bats が文言を照合しているため）

### 4. この change では、どのコマンドも Orca の部品を固定で呼ぶ

記録の `launcher` はこの版では `orca` だけなので、今 `command -v orca` を確かめている位置（`launch`・`reply`・`notify-closed`・`reap`・`adopt` の入口）で Orca の部品の `available` を呼び、そのあとも Orca の部品を呼ぶ。今その確認をしていない `wait --resolve` は、確認を足さずに `deliver` を呼ぶ（`orca` が無ければ今と同じく端末の一覧を読めずに `failed <N> terminal-list` になる）。記録の `launcher` を読んで部品を選ぶ処理は、2 つ目の部品が入る 3b で足す（今入れると、`launcher` が `orca` 以外の記録がどこからも作られないので、テストできない分岐になる）。`mirror` だけは今も記録の `launcher` が `orca` のときにだけ呼ぶ（既存の要件のまま）。

### 5. orca を呼ぶスクリプトの照合は「`orca` をコマンドとして書いた行」で行う

切り出したあとも `epic-dispatch.sh` は `launcher` の値・`route` の出力・stderr の文言（`orca is not on PATH`・`orca worktree current --json has no repoId` など、bats が照合している文）として `orca` の語を含むので、`grep -rlw orca` の「`epic-dispatch.sh` の 1 本だけ」は成り立たなくなる。照合を、`orca` がコマンドの位置（行頭・`;`・`&`・`|`・`(`・`!`・`$(`・`if`/`then`/`do`/`else`/`while`/`until` のあと）にあって半角英小文字のサブコマンドが続く行を探す次の検索に変える。

```
grep -rlE '(^|[;&|(!]|(if|then|do|else|while|until) )[[:space:]]*orca [a-z]+' plugins/dev-workflow --include='*.sh'
```

結果が `scripts/epic-launch-orca.sh` の 1 行だけであることを確かめる。この形は今の `epic-dispatch.sh` の 27 行の呼び出しをすべて拾い、`echo "orca is not on PATH"` のような文字列と `# orca …` のコメントは拾わない（2026-10-21 に今の木で確かめた）。拾いたい誤り（部品以外のスクリプトに `orca` の呼び出しを足すこと）はこれで拾える。

- 案 1: `orca` の語の照合のまま、許す 2 本（`epic-dispatch.sh` と `epic-launch-orca.sh`）を列挙する。`epic-dispatch.sh` に `orca` のコマンドを書き足す誤りを拾えなくなるので採らない
- 案 2: 手順書と同じ `orca [a-z]+` で探す。`epic-dispatch.sh` に残る stderr の文言（`orca worktree list --json is not readable` など）まで拾うので、文言を部品へ移すか変えることになり、「stderr の文言を変えない」と両立しない。採らない

## Risks / Trade-offs

- [部品の stdout に `orca` の出力が混ざり、`epic-dispatch.sh` が契約の行を読み違える] → 部品は、今 stderr に出している `orca` の出力だけを stderr に転送し、中で解釈する JSON はどこにも出さない（Decision 1）。bats の既存の stdout の照合と、部品を直接呼んで stdout が契約の行だけであることを確かめるテスト（tasks 3.2）で拾う
- [切り出しの途中で `orca`・`git`・`gh` の呼び出しの順や回数がずれる] → 既存の 370 件の bats を書き換えずに通すことを完了条件にする（例外は Decision 5 の照合 1 件だけ）。書き換えが要ると分かったら、その理由を tasks と PR 本文に書く
- [呼び出しごとに bash を 1 つ起こすぶん遅くなる] → 1 回の `launch` で子 1 件あたり数回で、`orca` の呼び出しそのもの（数百ミリ秒〜秒）に比べて小さい
- [3b で tmux の部品を書いたときに、この境目では足りないと分かる] → 境目を決める段で tmux の部品が各サブコマンドをどう埋めるかを Decision 2 で確かめた（`prepare`・`list`・`repos` は何もしない、`deliver` は一覧を 1 回読む）。足りなければ 3b の design.md でこの Decision を指して決め直す

## Migration Plan

1. 記録の書式・stdout・`orca` の呼び出しが変わらないので、実行中のエピックの親も子も、マージの前後でそのまま動く。移行の手順は無い
2. 戻し方: この change の PR を revert する。記録はそのまま読める

## Open Questions

3b への申し送り: tmux の部品の `repos` を空にするだけでは、`xrepo_resolve` の「clone の登録 ID が無ければ `unregistered`」の判定を通れない。3b で、登録の仕組みを持たない部品の `create` の `clone` と空の `repo_id` の意味を決め直す。


なし（tmux の部品のワークツリーの置き場とブランチ名、起動待ちと送信の確かめ方、`route` の判定順、サブエージェント方式の記録は 3b で決める）。
