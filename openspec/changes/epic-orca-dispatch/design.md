## Context

`/develop <エピック番号>` の本体は、今は blocked されていない子ごとに W を `isolation: "worktree"` で起こし、R1・G も自分で起こす。子の往復がすべて本体のコンテキストに積もる。

エピック #402 の手動実験（記録は #402 のコメント）でわかった事実:

- `orca worktree create --name issue-<N> --issue <N> --parent-worktree <親> --agent claude --prompt "/develop #<N> ..." --json` で、親の下に子ワークツリーができ、`claude --dangerously-skip-permissions '<prompt>'` で独立セッションが起動する。スラッシュコマンドは初期プロンプトとしてそのまま実行される
- 親子関係は Orca の `parentWorktreeId` として記録され、UI で親の下に並ぶ（git のブランチ構造には影響しない）
- selector は `path:<絶対パス>` に統一する。`orca worktree set --worktree worktree:<id>` は `selector_not_found` で失敗し、`path:` は create と set の両方で通った
- ブランチは `oratta/issue-<N>`（`--name issue-<N>` から Orca が作る）、起点は手元の `origin/main`。先に `git fetch origin main` しないと古い main から切られうる
- 同じファイル群を触る子（#284 と #283）は `blocked_by` で直列にし、先行側の起動プロンプトに「後続の範囲に手を出さない」と書く必要があった
- 親の待ちは `gh` で子 issue の state を 5 分おきに見るシェルのループで、待っている間のトークンは 0

Orca の CLI について手元で確かめた事実（Orca の CLI ヘルプと実行結果）:

- `orca worktree create` は `--name` が必須で、`--base-branch <ref>` で起点を明示できる。`--repo` を省くと、今いる Orca 管理のワークツリーから repo を推測する
- `orca worktree current` は、今いるディレクトリが Orca 管理のワークツリーなら exit 0、そうでなければ exit 1（`/tmp` で exit 1 を確認）。`--json` では `.result.worktree.repoId` と `.result.worktree.path` が取れる
- `orca worktree list --json` は `.result.worktrees[]` に、`repoId`・`path`・`linkedIssue`（関連付けた issue 番号の数値、無ければ null）・`isArchived` を持つ。マージ済みの子のワークツリー（`issue-332` など）も撤去するまで残る

本体（メインセッション）は背景タスクの完了で再起動されるので、`run_in_background` で起動して完了通知で続行してよい（`plugins/dev-workflow/references/subagent-waiting.md`「この禁止はサブエージェントに限られる」）。

## Goals / Non-Goals

**Goals:**
- 並列にできる子が 2 件以上あり、Orca 管理のワークツリーで本体が動いている環境では、子ごとに独立セッションで `/develop #<N>` を回し、本体のコンテキストに子の往復を積まない
- 子の起動と待ちを LLM を使わないスクリプトにし、本体は子が閉じたときだけ起こされる
- `orca` が無い、または本体が Orca 管理外のワークツリーにいる環境では、今の方式のまま動く

**Non-Goals:**
- Orca 以外のツールでの並列起動
- 子の PR の自動マージ
- 子セッションの中身（develop の 1 ループ）の変更。子セッションは普通の interactive の `/develop #<N>` として動く
- unmanned（`--unmanned`、1 サイクル 1 仕事）での Orca 経路。背景で待って起こされる動きが 1 サイクル 1 仕事と合わないので、unmanned は今のサブエージェント方式のままにする

## Decisions

### 経路の判定は、スクリプトの `route` サブコマンドにする

issue は振り分け条件を「並列にできる子が 2 件以上あり、`orca` コマンドがある」と決めている。これを SKILL.md の文章だけに置くと、受け入れ条件「`orca` が PATH に無い環境では今のサブエージェント方式で進むことがテストで確かめられている」を文書の検査でしか確かめられない。そこで判定を `epic-dispatch.sh route <child>...` に置き、本体は依存グラフから求めた blocked されていない子の番号を渡して、出力の 1 語（`orca` / `subagent`）で経路を決める。依存グラフを読む処理はスクリプトに入れない（今の SKILL.md どおり本体が `gh api .../dependencies/blocked_by` で読む。スクリプトを状態を持たない小さな部品に保つため）。

`orca` を返す条件は次の 3 つがすべて成り立つときにする。

1. 引数の子が 2 件以上
2. `command -v orca` が通る
3. `orca worktree current` が exit 0（本体が Orca 管理のワークツリーにいる）

3 つ目は issue に無い条件だが、足さないと Orca.app を入れた Mac で、普通のターミナルや Orca 外のワークツリーから `/develop <エピック>` を始めたときに `route` が `orca` を返し、そのあと `launch` の `orca worktree set --worktree path:<親>` が失敗する（`orca worktree create` も `--repo` を省くと今いる Orca 管理ワークツリーから repo を推測するので通らない）。経路は途中で変えないので、今はサブエージェント方式で回っている状況が止まる状況に変わってしまう。`route` の時点で Orca 管理外なら `subagent` を返せば、この状況は今までどおりに回る。

### 経路はエピックの解決セッションの開始時に 1 回決め、再開時はコメントから引き継ぐ

Orca 経路で走り出したあとに依存が解けた子が 1 件だけだった場合、判定をやり直すとサブエージェント方式に切り替わり、同じエピックで 2 方式が混ざる。混ざると本体が子ごとに「待つのはスクリプトか W の return か」を管理することになるので、経路は `/develop <エピック番号>` の最初の開始時の判定で固定する。Orca 経路では、あとから解けた子は件数にかかわらず `launch` で起動する。

決めた経路はエピックに 1 行コメント（`回し方: Orca（並列可能な子 k 件）` または `回し方: サブエージェント（並列可能な子 k 件）`）で残す。別セッションで同じエピックを再開したとき、本体はエピックのコメントのうち `回し方:` で始まる最新の 1 件を読んで経路を引き継ぎ、`route` をやり直さない。`回し方:` のコメントが無いときだけ `route` で決める。

### 再開時の二重起動は `launch` が同じ issue の子ワークツリーを見つけて skip する

再開した本体は、前のセッションで起動した「動いている子」を覚えていない。open で blocked されていない子をそのまま `launch` すると、同じ子に `orca worktree create` を二度呼ぶ。防ぎ方は 2 つあった。

- 本体が再開時に `orca worktree list --json` を読み、起動済みの子を自分で除いてから `launch` する
- `launch` 自身が、子を作る前に `orca worktree list --json` を読み、同じ repo で同じ issue 番号が関連付いた、archive されていないワークツリーがあれば作らずに `skipped <N>` を出す

後者を採る。理由は、二重起動の防止をスクリプトに置けば bats の `orca` スタブ（`list --json` の返り値）で確かめられるのに対し、前者は本体（LLM）の手順なので文書の検査しかできないため。また、再開時だけでなく、本体が同じ子を取り違えて二度 `launch` した場合にも同じ仕組みで止まる。同じ repo かどうかは、`orca worktree current --json` の `repoId` と、一覧の各ワークツリーの `repoId` が一致するかで見る（別のリポジトリの同じ番号の issue を取り違えないため）。JSON の読み取りには `jq` を使う（macOS の `/usr/bin/jq`、CI の ubuntu の `jq` のどちらでも使える）。

再開した本体は、起動済みの子（`skipped`）と新しく起動した子（`launched`）をあわせて「動いている子」とし、`wait` に渡す。

### `launch` の手順と引数

```
epic-dispatch.sh launch [--note <text>] [--base <branch>] <epic> <child>...
```

1. `orca` が PATH に無ければ stderr に理由を出して exit 1（何も呼ばない）
2. `orca worktree current --json` で今の repo の `repoId` を得る。失敗したら exit 1（何も作らない）
3. 親ワークツリーのパスを `git rev-parse --show-toplevel` で求める（本体は親ワークツリーで動いている）
4. `git fetch origin <base>`。失敗したら exit 1（子を作らない）
5. `orca worktree set --worktree path:<親> --issue <epic>`（親をエピックに関連付ける）。失敗したら exit 1（子を作らない）
6. `orca worktree list --json` を 1 回読む。失敗したら exit 1（二重起動を確かめられないので子を作らない）
7. 子ごとに、同じ `repoId`・`linkedIssue` が `<N>`・`isArchived` が false のワークツリーがあれば `skipped <N>`。無ければ `orca worktree create --name issue-<N> --issue <N> --base-branch origin/<base> --parent-worktree path:<親> --agent claude --prompt "<prompt>" --json`

`<base>` の既定は `main`（issue の受け入れ条件どおり）。このプラグインは既定ブランチが main でないリポジトリでも使われるので、環境変数 `EPIC_DISPATCH_BASE` か `--base <branch>` で変えられるようにし、フラグが環境変数より優先する（`wait` の間隔・上限と同じ優先順位）。`--base-branch origin/<base>` は、直前に fetch した起点を Orca の既定値に頼らず明示するために付ける。

`<prompt>` は `/develop #<N> （エピック #<epic> の子。親ワークツリー <親> から Orca で起動）` で、`--note` があればその後ろに空白 1 つを挟んで足す。`--note` は同じ呼び出しの子すべてに付く。子ごとに違う注意書き（#284 の「後続の範囲に手を出さない」のような文）が要るときは、本体が子ごとに `launch` を分けて呼ぶ。

出力は子ごとに 1 行で、`launched <N>`・`skipped <N>`・`failed <N>` のどれか。`orca` の出力（`--json` の結果を含む）は stderr に流し、stdout は子ごとの 1 行だけにする。1 件の失敗で残りの子を止めず、失敗が 0 件（`launched` と `skipped` だけ）なら exit 0、1 件でも `failed` があれば exit 1。失敗した子を本体がサブエージェント方式に自動で振り替えることはしない（Orca 側に途中までできたワークツリーが残っている可能性があり、二重に起動しうるため）。本体は失敗をユーザーに報告する。

### `wait` の出力・exit code・待ちの上限と間隔

```
epic-dispatch.sh wait [--interval <sec>] [--timeout <sec>] <child>...
```

1 回の確認（ポーリング）で、子ごとに `gh api repos/{owner}/{repo}/issues/<N> --jq .state` を実行する（`gh issue view` は GraphQL エラーで落ちる環境があるので REST を使う。`{owner}/{repo}` は `gh` がカレントのリポジトリから埋める）。子ごとの結果は、出力が `closed` なら閉じている、`open` なら開いている、`gh` が非 0 で終わったか出力が `open` / `closed` 以外（空文字を含む）なら失敗、とする。stdout にはどの終わり方でも必ず 1 行だけを出す。

| 終わり方 | stdout（1 行） | exit |
|---|---|---|
| そのポーリングで 1 件以上の子が `closed` | `closed <N>...`（閉じていた子の番号を引数の順に空白区切り） | 0 |
| 上限時間に達した | `timeout <N>...`（まだ開いている子と、そのポーリングで失敗した子の番号） | 2 |
| 失敗したポーリングが 3 回続いた | `error gh <N>...`（3 回目のポーリングで失敗した子の番号） | 1 |
| 引数の誤り（子が 0 件・番号でない・`--interval` / `--timeout` が非負整数でない） | なし（stderr に使い方） | 1 |

「失敗したポーリング」は、1 件以上の子が失敗し、かつ `closed` の子が 1 件も無いポーリングと数える。一部の子だけが失敗し続け、ほかの子が `open` を返している場合も失敗したポーリングに数えるので、存在しない番号や権限の無い issue を渡したときは、上限時間を待たずに 3 回目で `error` として表に出る。失敗の無いポーリングが 1 回あれば数え直す。`closed` の子がいるポーリングは、ほかの子の失敗があっても `closed` で終わる（閉じた子の後続を先に進めるほうが大事で、失敗している子は次の `wait` で再び確かめられるため）。

exit 2 を上限到達に使うのは、`subagent-context.sh` の「2 = 上限超過」とそろえるため。

間隔と上限は秒で指定する。既定は間隔 300 秒（#402 の実験と同じ 5 分）、上限 21600 秒（6 時間）。環境変数 `EPIC_DISPATCH_INTERVAL` / `EPIC_DISPATCH_TIMEOUT` で既定を変えられ、フラグが環境変数より優先する。経過時間は bash の `SECONDS` で測り、ポーリングのあとで「経過 + 間隔 > 上限」なら眠らずに `timeout` で終わる。したがって `--timeout 0` は 1 回だけ確認して終わる。

上限を設けるのは、子が `needs-approval` で止まったり人の承認待ちで長く止まったりしたときに、本体が一度も起こされないまま放置されるのを避けるためである。上限の長さは 2 つの損失の釣り合いで選んだ。短すぎるときの損失は、本体が起きて子の様子を確かめ、再び待つ 1 回分のトークンだけで小さい。長すぎるときの損失は、止まった子に気づくのが遅れることである。6 時間なら 1 日に起こされるのは数回で、止まった子にもその日のうちに気づける。参考値として、#402 の #332 は起動からマージまで約 3.4 時間だった（計測は 1 件だけ）。

**テストで待ち時間を短くする手段**: `--interval 0` と `--timeout 0` を受け付ける（0 秒の間隔でもポーリングの回数は `gh` スタブの呼び出し回数で数えられる）。間隔が実際に使われることは、PATH 上の `sleep` をスタブにして引数を記録することで、実時間を待たずに確かめる。

### 本体の動き（SKILL.md に書く手順）

Orca 経路は interactive のときだけ使う。unmanned は `route` を呼ばず、今のサブエージェント方式のままにする。Orca 経路の本体は次を繰り返す。

1. `launch` の出力で `launched` と `skipped` になった子を「動いている子」として持ち、`epic-dispatch.sh wait <動いている子>...` を Bash の `run_in_background: true` で起動してターンを終える（本体は背景タスクの完了で起こされる）
2. `closed <N>...` で起こされたら、閉じた子ごとに `gh api repos/{owner}/{repo}/issues/<N> --jq .state_reason` を読む。`completed` ならエピックへ `子 #N マージ → 残り k 件` とコメントし、依存グラフを読み直して解けた子を `launch` する。`completed` 以外（`not_planned` など）ならエピックへ `子 #N 見送り（<state_reason>）→ 残り k 件` とコメントし、その子を前提にしていた子は起動せずにユーザーに報告する（GitHub の依存 API では、前提の issue が閉じれば理由を問わず後続は blocked でなくなるので、本体が理由を見ないと、作業されていない前提の上に後続が起動する）。そのうえで、残りの動いている子があれば 1 に戻る。動いている子も解けた子も無くなったら、今までどおりエピックの完了条件の確認に進む
3. `timeout <N>...` で起こされたら、その子 issue に `needs-approval` ラベルや止まっている旨のコメントが無いかを見て、あればユーザーに報告する。報告したかどうかにかかわらず、残りの動いている子で 1 に戻る（止まっている子もユーザーが手を入れれば進むので、待ちの対象から外さない）
4. `error gh ...` や `launch` の `failed <N>` はユーザーに報告して止まる

`timeout` での確認で気づけない止まり方がある。子セッションは interactive の `/develop` なので、子が自分のタブでユーザーに質問して止まっていても、`needs-approval` ラベルは付かず issue にもコメントは残らない。SKILL.md にはこのことを書き、子のタブも見るようユーザーに伝える。

子の PR のマージは今までどおり子セッションの中で人の承認で行う。本体は子セッションに SendMessage できない（別プロセスの独立セッション）ので、子への指示はすべて起動プロンプトで渡す。

### 守備範囲

`route` / `launch` / `wait` の引数を渡すのは本体（LLM）で、依存グラフから求めた子の番号と、SKILL.md の手順どおりに付けるフラグである。人が手で打つことは想定しない。引数の検査で拾いたいのは、番号の取り違えで引数が空になる、`#12` のように記号が付く、フラグ値を打ち間違える、の 3 つだけにする。数字でさえあれば、存在しない issue 番号・重複した番号・blocked されている子の番号も通す（`route` は依存を検証しない。存在しない番号は `wait` で失敗したポーリングとして数えられ、`error` で表に出る）。非常に大きい `--timeout` も通す。検査をすり抜ける入力が見つかるたびに塞ぐことは、この change の完了条件にしない。

### bats のスタブ方針

`plugins/dev-workflow/tests/epic-dispatch.bats` を新しく作り、既存の bats ファイルには手を入れない（並行している #284・#283 がアサーションの書き方を直しているため）。

- テストごとに `BATS_TEST_TMPDIR` にスタブ置き場を作り、`orca`・`gh`・`git`・`sleep` のスタブを置く。各スタブは自分の名前と引数を 1 行ずつ同じログファイルに追記し、呼び出し順はそのログの行順で確かめる。引数の区切りが見えるように、引数は `printf '%q '` で書く
- `orca` スタブは、サブコマンドごとの返り値（`worktree current` の exit code と `--json` の出力、`worktree list --json` の出力、`set` / `create` の成否）を設定ファイルで切り替える
- `gh` スタブの返り値（`open` / `closed` / 失敗 / それ以外の値）は、呼び出し回数を数えるファイルと、子番号ごとの返り値を書いたファイルで制御する（例: 3 回目の呼び出しから `closed` を返す）
- スクリプトは `PATH="<スタブ置き場>:/usr/bin:/bin"` で走らせる。これで手元の実物の `orca`（`/Applications/Orca.app/...`）と `gh`（`/opt/homebrew/bin`）は見えない。`jq` は実物（`/usr/bin/jq`）を使う。`orca` が無い環境のテストは、`orca` スタブを置かない同じ PATH で走らせる
- テスト名は ASCII のみ（bats はマルチバイトのテスト名を扱えない）
- テストの途中に素の `[[ ]]` を置かない（bash 3.2 では途中の `[[ ]]` が偽でも errexit で止まらず素通りする。#284 の件）。途中の判定は `[ ]`・`grep -q`・`|| { echo ...; false; }` で書き、失敗が必ず検出される形にする
- SKILL.md の記述の検査（振り分け条件・`route` / `launch` / `wait` の名前・今の方式の記述が残っていること）も同じファイルに置く

## Risks / Trade-offs

- [子セッションは `--dangerously-skip-permissions` で動く] → Orca の起動方式でこちらからは変えられない。子セッションでは許可の確認画面が出ない（hooks は効く）。マージを止めているのは確認画面ではなく、develop と pr-review-gate の規則（マージは人の承認）と hooks である。SKILL.md にはこの事実をそのまま書く
- [子が自分のタブで質問して止まっている] → `wait` の `timeout` での確認では気づけない。SKILL.md に書いてユーザーに子のタブを見てもらう
- [上限 6 時間が長すぎる／短すぎる] → 環境変数とフラグで変えられる。実エピックで 1 回通したときの子の所要時間を見て、既定値を直すかを判断する
- [`jq` が無い環境] → `launch` の二重起動の確認に要る。`orca` を入れた Mac と CI の ubuntu には入っているので、無い場合は `launch` が exit 1 で終わり、子を作らない

## 検証方法（実機。自動テストの外）

- **実エピックで 1 回通す**: 並列にできる子が 2 件以上あるエピックで、Orca 管理のワークツリーから `/develop <エピック>` を起動し、`route` が `orca` を返して `launch` で子が起動されること、Orca の UI で子ワークツリーが親の下に並ぶこと、子の PR がマージされたあと `wait` が `closed <N>` で終わって本体が起こされ、依存が解けた次の子が自動で `launch` されることを確かめる。確かめた内容（使ったエピック番号・子の番号・`wait` の出力・UI の確認結果）をエピックのコメントに記録する
- **トークン量の比較**: #402 の残りの子 #284・#283 が終わった時点で、子セッションごとのトークン量（各子セッションのトランスクリプトの usage の合計）と、今のサブエージェント方式で同じ子を回したときに 1 本体に集まる量（過去のエピックで本体のトランスクリプトに積もった子ごとの往復の量）を比べ、数字を #420 のコメントに残す
