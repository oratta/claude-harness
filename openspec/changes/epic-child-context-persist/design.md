## Context

エピックの Orca 経路では、親セッションの本体が `epic-dispatch.sh launch` で子ごとにワークツリーと端末を作り、`/develop #<N>` の指示を送る。子への情報は 2 か所にしか無い。

| 情報 | 今の置き場所 | 子のセッションを閉じて `/develop #N` を打ち直すと |
|---|---|---|
| 子ごとの注意書き（`launch --note`） | 最初に送る指示の文面 | 消える |
| エピックの子であること | 端末を起動するコマンドの前置き `EPIC_DISPATCH_PARENT_EPIC=<epic>` | 消える。`route` が `nested` を返さない |

前の子 #805（PR #824）で決まったこと（覆さない）:

- `orca` のコマンドを呼ぶのは `plugins/dev-workflow/scripts/epic-dispatch.sh` の 1 本だけ。develop の手順書（`plugins/dev-workflow/skills/develop/`）には `orca` のコマンドを書かない（`grep -rnE 'orca [a-z]+' plugins/dev-workflow/skills/develop` が 0 行）
- `reap` は `orca worktree current --json` の `id` と一覧の `parentWorktreeId` の一致で「親の `launch` が作った子」を判定している。実機（Orca 1.4.222）の `orca worktree list --json` は `.result.worktrees[]` に `id`（`<repoId>::<パス>`）・`repoId`・`path`・`linkedIssue`・`isArchived`・`isMainWorktree`・`workspaceStatus`・`parentWorktreeId` を持ち、`orca worktree current --json` の `.result.worktree` も同じ項目を持つ。2026-10-08 に実機で、`launch` が作った子（例: flatmate の issue-1398）の `parentWorktreeId` が親ワークツリーの `id` で、その親の `linkedIssue` がエピック番号（1384）であることを確かめた。親を持たないワークツリーの `parentWorktreeId` は `null`

エピック #811 で主が決めたこと（覆さない）: Orca のコマンドは 1 本のスクリプトだけが呼び、手順書には環境によらない動作だけを書く。Orca の有無での切り替えは作らない。判定はシェルで行い LLM のコストを増やさない。wt-clean・wt-setup は触らない。

## Goals / Non-Goals

**Goals:**

- 子のワークツリーで何本セッションを起動し直しても、親が渡した注意書きが届き、`route` が `nested` を返す
- 別の PC で再開しても注意書きが届く
- #532・#487・#498・#499 の直しを同じ PR で閉じる

**Non-Goals:**

- サブエージェント方式の子（`launch` を通らない）への注意書きの永続化。本体が spawn のたびに入力文に入れるので消えない
- develop 以外のセッション（素の Claude Code）に注意書きを届けること
- この変更の前に起動された子ワークツリー（注意書きのコメントが無い）の救済。親子関係の判定は過去の子にも効く
- `parentWorktreeId` が、`launch` 以外の方法で作られたワークツリーにも付く場合の区別（下の Risks）

## Decisions

### 注意書きは子 issue のコメントに置く（ワークツリーのファイルにしない）

develop は開始時に記録先の issue の本文と関連コメントを読むので、issue のコメントに置けば起動し直したセッションにも別の PC にも届き、新しい保存場所が要らない。退けた案: ワークツリーにファイルを置き、セッション開始の hook で読ませる。develop 以外のセッションにも届くが、毎回のセッションに文章が足され、issue とファイルの 2 か所を同じに保つ必要がある（issue #809 の備考）。

コメントの 1 行目は `親エピックからの注意書き: #<epic>` に固定し、2 行目を空け、3 行目以降に `--note` の文をそのまま置く。1 行目を固定するのは、SKILL.md から「この行で始まるコメントに従う」と書けるようにするため（本体が関連コメントを選ぶときに落とさない）。既存の機械照合の行（`仕様化判断:`・`仕様レビュー:`・`回し方:`・`後で別に起動するエピック:`）とは重ならない。

投稿は `gh issue comment <N> --body <本文>`（リポジトリは親ワークツリーのカレントから gh が解決する。`wait` の `gh api repos/{owner}/{repo}/...` と同じ前提）。

**いつ投稿するか**: `orca worktree create` が exit 0 で終わった子ごとに 1 回、端末を作る前に投稿する。

- `skipped` の子（一覧に同じ子のワークツリーがある、または同じ呼び出しで処理済み）には投稿しない。前の `launch` で投稿済みなので、再開のたびに `launch` を呼んでも重複しない
- worktree create が失敗した子には投稿しない。ワークツリーが無いので次の `launch` で作られ、そのとき投稿される
- worktree create が exit 0 で、そのあとの端末の作成・送信が失敗した子には投稿済みになる。ワークツリーは残り、次の `launch` では `skipped` になるので、手で端末を作り直したセッションにも注意書きが届く（これが投稿を端末より前に置く理由）

**投稿に失敗したら**: 子の stdout の 1 行（`launched` / `skipped` / `failed`）と exit code は変えず、stderr に `note not posted to #<N>` と、手で投稿するための `gh issue comment <N> --body '<本文>'` を出す。起動そのものは成功していて、最初の指示の文面には注意書きが入っているので、起動を `failed` にすると本体が止まり、子のセッションを捨てる理由にならない失敗で作業が止まる。本体は SKILL.md の手順で、stderr にこの行があればその子 issue に同じ本文を投稿する。

### 親子関係の判定は環境変数とワークツリーの親の「どちらか」

`route` と `launch` は、次のどちらかが成り立てば「エピックの子のセッション」とみなす。

1. `EPIC_DISPATCH_PARENT_EPIC` が空でない（今までどおり。このときは `orca` を呼ばない）
2. `orca` と `jq` が PATH にあり、`orca worktree current --json` が exit 0 で、`.result.worktree.parentWorktreeId` が空でも `null` でもなく、`orca worktree list --json` の `.result.worktrees[]` のうち `id` がその値のものの `linkedIssue` が `null` でない

親の判定に親の `linkedIssue` を要るのは、`launch` が親ワークツリーに必ず `orca worktree set --issue <epic>` を付けてから子を作るため。手で作った子ワークツリー（親に issue が付いていない）を子扱いしない。親が archive されていても判定は変えない（子であることは変わらない）。

親エピックの番号は、1 なら環境変数の値、2 なら親の `linkedIssue`。

判定の関数（仮名 `epic_parent`）は親エピックの番号を stdout に出すか、子でなければ何も出さない。`route` と `launch` が共有する。`orca worktree current --json` の結果は `route` の `orca` 判定（exit 0 か）にもそのまま使い、呼び出しを 1 回に保つ。

**判定できないとき**: `jq` が無い、`orca worktree list --json` が失敗する、または読めないときは「子ではない」として扱い、今までの判定に進む（`route` は stderr に `could not read the parent worktree` を出す）。`route` の exit 0 と stdout 1 行の契約を保つため。一覧が読めなければ `launch` も子を 1 件も作らずに止まる（既存の規定）ので、孫が作られる経路はサブエージェント方式だけで、一覧の一時的な失敗が `route` の 1 回と重なる場合に限られる。逆に「判定できないなら `nested`」にすると、子ではないエピックの本体が親エピックに `後で別に起動するエピック:` の誤った行を書いて止まる。

### `nested` の出力に親エピックの番号を足す（stdout は変えない）

`nested` を受けたセッションは「親エピックと自分の issue に `後で別に起動するエピック: #<自分>` とコメントする」が、起動し直したセッションには環境変数が無いので親エピックの番号を知らない。`route` は `nested` のとき stderr に `parent epic: #<N>` の 1 行を出し、SKILL.md はそこから番号を読むと書く。stdout は今までどおり `nested` の 1 行（既存の bats と本体の読み方を壊さない）。

### `route` は子の件数によらず先に親子関係を見る

今の `route` は子が 2 件以上のときだけ `orca worktree current` を呼ぶ。子が 1 件や 0 件でも、子のセッションがサブエージェント方式で孫を作るのを止めたいので、`nested` の判定を件数の判定より先に置く。その結果、`orca` が PATH にあれば子の件数によらず `orca worktree current --json` を 1 回呼ぶ。冒頭コメント（#532）にも「route は子 0 件でも subagent（エピックの子のセッションなら nested）」と書く。

### `launch` の拒否は `git fetch` と `orca worktree set` より前

`launch` は今 `orca worktree current --json` を最初に呼び、そのあと `git fetch`・`orca worktree set --worktree path:<親> --issue <epic>` と進む。子のセッションでこれが走ると、子のワークツリーの `linkedIssue` がエピック番号で上書きされる。親子関係の判定は `orca worktree current --json` の直後、`git rev-parse` より前に行い、子なら stderr に `this session is a child of epic #<N> (parent worktree); child epics are not expanded here` を出して exit 1 で終わる（stdout は空）。環境変数による拒否（`orca` も `git` も呼ばない）は変えない。親を持たないワークツリーでは呼び出しの順序は今までと同じ（`list` の追加呼び出しは親があるときだけ）。

### 同じ PR で閉じる小さな直し

- #532: 冒頭コメントの「route は子 0 件でも subagent」を、`nested` 優先を含む文に置き換える（親子関係の判定の追加に合わせた文面にする）
- #487: `resend_hint` の `--terminal $1` を `--terminal $(shq "$1")` にし、`orca terminal read --terminal` の案内も同じにする
- #498: `recreate_hint` の最初の echo の直後に `check that no terminal is already running claude there before creating one: orca terminal list --worktree path:<子> --json` を出す
- #499: SKILL.md「エピックの扱い」手順 6 に、端末を作れなかった `failed` の子は、stderr に出た確認のコマンドで既存の端末が無いことを確かめ、stderr の作り直しのコマンドで端末を作り、返ったハンドルに送信のコマンドを送って動き出したのを確かめてから再開する、と書く。#499 の提案文は `orca terminal create` を含むが、#805 で決まった「手順書に `orca` のコマンドを書かない」に合わせて「stderr に出た作り直しのコマンド」と書き換える

### 手順書の書き方

SKILL.md「エピックの扱い」の Orca 経路の段落に、`launch` が `--note` を子 issue に `親エピックからの注意書き:` で始まるコメントとして残すこと、子のセッションの本体（起動し直したものを含む）は記録先にこの行で始まるコメントがあれば従い、W・R1・G に渡す関連コメントに必ず含めることを書く。`nested` の段落は、子であることの判定が環境変数とワークツリーの親の両方であること（`orca` のコマンド名は書かない）、親エピックの番号は `route` の stderr の `parent epic: #<N>` から読むことに直す。`launch` の拒否の stderr の見分け方は、共通の語 `child epics are not expanded here` で書く。

## Risks / Trade-offs

- `launch` 以外で、`linkedIssue` の付いたワークツリーを親にしてワークツリーを作ると（Orca の UI で親を選んで作るなど）、そこで回すエピックは `nested` になり展開されない。issue #809 の判定条件どおりで、親の `linkedIssue` がエピックかどうかは `gh` を呼ばないと分からないため区別しない。起こる頻度: 2026-10-08 の実機の一覧では、`parentWorktreeId` を持つワークツリーはすべて `launch` が作った `issue-<N>` だった。当たったときは、親を持たないワークツリーでエピックを開き直せば展開できる（`nested` の報告文はそう案内しない。主がこの事例に当たったら案内を足す）
- 注意書きのコメントは、子 issue を読む誰にでも見える（issue の公開範囲と同じ）。`--note` に書くのは作業範囲の指示で、秘密を書く場面は想定しない
- 実機の受け入れ条件（Orca 経路で起動した子を閉じ、同じワークツリーで `/develop #N` だけで起動し直したとき、注意書きが読まれ `route` が `nested` を返す）は bats では確かめられない。PR に実機の結果を貼る
