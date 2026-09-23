## Context

`/develop <エピック番号>` の本体は、今は blocked されていない子ごとに W を `isolation: "worktree"` で起こし、R1・G も自分で起こす。子の往復がすべて本体のコンテキストに積もる。

エピック #402 の手動実験（記録は #402 のコメント）でわかった事実:

- `orca worktree create --name issue-<N> --issue <N> --parent-worktree <親> --agent claude --prompt "/develop #<N> ..." --json` で、親の下に子ワークツリーができ、`claude --dangerously-skip-permissions '<prompt>'` で独立セッションが起動する。スラッシュコマンドは初期プロンプトとしてそのまま実行される
- 親子関係は Orca の `parentWorktreeId` として記録され、UI で親の下に並ぶ（git のブランチ構造には影響しない）
- selector は `path:<絶対パス>` に統一する。`orca worktree set --worktree worktree:<id>` は `selector_not_found` で失敗し、`path:` は create と set の両方で通った
- ブランチは `oratta/issue-<N>`（`--name issue-<N>` から Orca が作る）、起点は手元の `origin/main`。先に `git fetch origin main` しないと古い main から切られうる
- 同じファイル群を触る子（#284 と #283）は `blocked_by` で直列にし、先行側の起動プロンプトに「後続の範囲に手を出さない」と書く必要があった
- 親の待ちは `gh` で子 issue の state を 5 分おきに見るシェルのループで、待っている間のトークンは 0

`orca worktree create` は `--name` が必須で、`--base-branch <ref>` で起点を明示できる（`orca worktree create --help`）。

本体（メインセッション）は背景タスクの完了で再起動されるので、`run_in_background` で起動して完了通知で続行してよい（`plugins/dev-workflow/references/subagent-waiting.md`「この禁止はサブエージェントに限られる」）。

## Goals / Non-Goals

**Goals:**
- 並列にできる子が 2 件以上あり `orca` が使える環境では、子ごとに独立セッションで `/develop #<N>` を回し、本体のコンテキストに子の往復を積まない
- 子の起動と待ちを LLM を使わないスクリプトにし、本体は子が閉じたときだけ起こされる
- `orca` が無い環境では今の方式のまま動く

**Non-Goals:**
- Orca 以外のツールでの並列起動
- 子の PR の自動マージ
- 子セッションの中身（develop の 1 ループ）の変更。子セッションは普通の interactive の `/develop #<N>` として動く

## Decisions

### 経路の判定は、スクリプトの `route` サブコマンドにする

issue は振り分け条件を「並列にできる子が 2 件以上あり、`orca` コマンドがある」と決めている。これを SKILL.md の文章だけに置くと、受け入れ条件「`orca` が PATH に無い環境では今のサブエージェント方式で進むことがテストで確かめられている」を文書の検査でしか確かめられない。そこで判定を `epic-dispatch.sh route <child>...` に置き、本体は依存グラフから求めた blocked されていない子の番号を渡して、出力の 1 語（`orca` / `subagent`）で経路を決める。`orca` の有無は `command -v orca` で見る。依存グラフを読む処理はスクリプトに入れない（今の SKILL.md どおり本体が `gh api .../dependencies/blocked_by` で読む。スクリプトを状態を持たない小さな部品に保つため）。

### 経路はエピックの解決セッションの開始時に 1 回決め、そのセッションの間は変えない

Orca 経路で走り出したあとに依存が解けた子が 1 件だけだった場合、判定をやり直すとサブエージェント方式に切り替わり、同じエピックで 2 方式が混ざる。混ざると本体が子ごとに「待つのはスクリプトか W の return か」を管理することになるので、経路は `/develop <エピック番号>` の開始時の判定で固定する。Orca 経路では、あとから解けた子は件数にかかわらず `launch` で起動する。決めた経路はエピックに 1 行コメント（`回し方: Orca（並列可能な子 k 件）` または `回し方: サブエージェント（...）`）で残し、別セッションで再開したときにも同じ経路で続けられるようにする。

### `launch` の手順と引数

```
epic-dispatch.sh launch [--note <text>] <epic> <child>...
```

1. `orca` が PATH に無ければ stderr に理由を出して exit 1（何も呼ばない）
2. 親ワークツリーのパスを `git rev-parse --show-toplevel` で求める（本体は親ワークツリーで動いている）
3. `git fetch origin main`。失敗したら exit 1（子を作らない）
4. `orca worktree set --worktree path:<親> --issue <epic>`（親をエピックに関連付ける）。失敗したら exit 1（子を作らない。親が Orca 管理外のワークツリーだとここで落ちる）
5. 子ごとに `orca worktree create --name issue-<N> --issue <N> --base-branch origin/main --parent-worktree path:<親> --agent claude --prompt "<prompt>" --json`

`<prompt>` は `/develop #<N> （エピック #<epic> の子。親ワークツリー <親> から Orca で起動）` で、`--note` があればその後ろに空白 1 つを挟んで足す。`--note` は同じ呼び出しの子すべてに付く。子ごとに違う注意書き（#284 の「後続の範囲に手を出さない」のような文）が要るときは、本体が子ごとに `launch` を分けて呼ぶ。`--base-branch origin/main` は、直前に fetch した `origin/main` を起点にすることを Orca の既定値に頼らず明示するために付ける。

出力は子ごとに 1 行で、`launched <N>` または `failed <N>`。`orca` の出力（`--json` の結果を含む）は stderr に流し、stdout は子ごとの 1 行だけにする。1 件の失敗で残りの子を止めず、全部起動できれば exit 0、1 件でも失敗すれば exit 1。失敗した子を本体がサブエージェント方式に自動で振り替えることはしない（Orca 側に途中までできたワークツリーが残っている可能性があり、二重に起動しうるため）。本体は失敗をユーザーに報告する。

### `wait` の出力・exit code・待ちの上限と間隔

```
epic-dispatch.sh wait [--interval <sec>] [--timeout <sec>] <child>...
```

1 回の確認（ポーリング）で、子ごとに `gh api repos/{owner}/{repo}/issues/<N> --jq .state` を実行する（`gh issue view` は GraphQL エラーで落ちる環境があるので REST を使う。`{owner}/{repo}` は `gh` がカレントのリポジトリから埋める）。stdout にはどの終わり方でも必ず 1 行だけを出す。

| 終わり方 | stdout（1 行） | exit |
|---|---|---|
| そのポーリングで 1 件以上の子が `closed` | `closed <N>...`（閉じていた子の番号を引数の順に空白区切り） | 0 |
| 上限時間に達した | `timeout <N>...`（まだ開いている子の番号） | 2 |
| `gh` の失敗が 3 ポーリング連続した | `error gh <N>...`（そのポーリングで失敗した子の番号） | 1 |
| 引数の誤り（子が 0 件・番号でない・`--interval` / `--timeout` が非負整数でない） | なし（stderr に使い方） | 1 |

exit 2 を上限到達に使うのは、`subagent-context.sh` の「2 = 上限超過」とそろえるため。1 回のポーリングで一部の子の `gh` が失敗しても、ほかの子が `closed` ならそちらを優先して `closed` で終わる。

間隔と上限は秒で指定する。既定は間隔 300 秒（#402 の実験と同じ 5 分）、上限 21600 秒（6 時間）。環境変数 `EPIC_DISPATCH_INTERVAL` / `EPIC_DISPATCH_TIMEOUT` で既定を変えられ、フラグが環境変数より優先する。経過時間は bash の `SECONDS` で測り、ポーリングのあとで「経過 + 間隔 > 上限」なら眠らずに `timeout` で終わる。したがって `--timeout 0` は 1 回だけ確認して終わる。

上限を設けるのは、子が `needs-approval` で止まったり人の承認待ちで長く止まったりしたときに、本体が一度も起こされないまま放置されるのを避けるためである。6 時間は、#402 で子 1 件がマージまでにかかった時間（#332 で約 3.4 時間）より長く、1 日に数回だけ本体が起こされる長さとして選んだ。

**テストで待ち時間を短くする手段**: `--interval 0` と `--timeout 0` を受け付ける（0 秒の間隔でもポーリングの回数は `gh` スタブの呼び出し回数で数えられる）。間隔が実際に使われることは、PATH 上の `sleep` をスタブにして引数を記録することで、実時間を待たずに確かめる。

### 本体の動き（SKILL.md に書く手順）

Orca 経路の本体は次を繰り返す。

1. `launch` した子を「動いている子」として持ち、`epic-dispatch.sh wait <動いている子>...` を Bash の `run_in_background: true` で起動してターンを終える（本体は背景タスクの完了で起こされる）
2. `closed <N>...` で起こされたら、閉じた子ごとにエピックへ `子 #N マージ → 残り k 件` をコメントし、依存グラフを読み直して解けた子を `launch` し、1 に戻る。動いている子も解けた子も無くなったら、今までどおりエピックの完了条件の確認に進む
3. `timeout <N>...` で起こされたら、その子 issue に `needs-approval` ラベルや止まっている旨のコメントが無いかを見て、あればユーザーに報告する。無ければそのまま 1 に戻る
4. `error gh ...` や `launch` の `failed <N>` はユーザーに報告して止まる

子の PR のマージは今までどおり子セッションの中で人の承認で行う。本体は子セッションに SendMessage できない（別プロセスの独立セッション）ので、子への指示はすべて起動プロンプトで渡す。

### bats のスタブ方針

`plugins/dev-workflow/tests/epic-dispatch.bats` を新しく作り、既存の bats ファイルには手を入れない（並行している #284・#283 がアサーションの書き方を直しているため）。

- テストごとに `BATS_TEST_TMPDIR` にスタブ置き場を作り、`orca`・`gh`・`git`・`sleep` のスタブを置く。各スタブは自分の名前と引数を 1 行ずつ同じログファイルに追記し、呼び出し順はそのログの行順で確かめる。引数の区切りが見えるように、引数は `printf '%q '` で書く
- `gh` スタブの返り値（`open` / `closed` / 失敗）は、呼び出し回数を数えるファイルと、子番号ごとの返り値を書いたファイルで制御する（例: 3 回目の呼び出しから `closed` を返す）
- スクリプトは `PATH="<スタブ置き場>:/usr/bin:/bin"` で走らせる。これで手元の実物の `orca`（`/Applications/Orca.app/...`）と `gh`（`/opt/homebrew/bin`）は見えない。`orca` が無い環境のテストは、`orca` スタブを置かない同じ PATH で走らせる
- テスト名は ASCII のみ（bats はマルチバイトのテスト名を扱えない）
- テストの途中に素の `[[ ]]` を置かない（bash 3.2 では途中の `[[ ]]` が偽でも errexit で止まらず素通りする。#284 の件）。途中の判定は `[ ]`・`grep -q`・`|| { echo ...; false; }` で書き、失敗が必ず検出される形にする
- SKILL.md の記述の検査（振り分け条件・`route` / `launch` / `wait` の名前・今の方式の記述が残っていること）も同じファイルに置く

## Risks / Trade-offs

- [子セッションは `--dangerously-skip-permissions` で動く] → Orca の起動方式でこちらからは変えられない。子は普通の `/develop #<N>` として動き、マージは人の承認が要るので、承認を飛ばす経路は増えない。この点は SKILL.md に書く
- [本体のワークツリーが Orca 管理外] → `launch` の `orca worktree set` で失敗して exit 1 になり、子は 1 件も作られない。`route` は `orca` の有無しか見ないので、この場合は本体がユーザーに報告する（サブエージェント方式に自動で切り替えるかは実エピックでの確認後に決める）
- [上限 6 時間が長すぎる／短すぎる] → 環境変数とフラグで変えられる。実エピックで 1 回通したときの子の所要時間を見て、既定値を直すかを判断する

## 検証方法（実機。自動テストの外）

- **実エピックで 1 回通す**: 並列にできる子が 2 件以上あるエピックで `/develop <エピック>` を起動し、`route` が `orca` を返して `launch` で子が起動されること、Orca の UI で子ワークツリーが親の下に並ぶこと、子の PR がマージされたあと `wait` が `closed <N>` で終わって本体が起こされ、依存が解けた次の子が自動で `launch` されることを確かめる。確かめた内容（使ったエピック番号・子の番号・`wait` の出力・UI の確認結果）をエピックのコメントに記録する
- **トークン量の比較**: #402 の残りの子 #284・#283 が終わった時点で、子セッションごとのトークン量（各子セッションのトランスクリプトの usage の合計）と、今のサブエージェント方式で同じ子を回したときに 1 本体に集まる量（過去のエピックで本体のトランスクリプトに積もった子ごとの往復の量）を比べ、数字を #420 のコメントに残す
