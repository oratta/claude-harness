# 別リポジトリの子を扱う親（develop）

別 repo の子を扱う前に読む。通常の手順 1〜7・9 は `references/epic-loop.md`、停止の手順 8 は `references/epic-stop.md`、マージ待ちは `references/epic-merge-wait.md`。以下の手順番号はこの対応で読む。

**別のリポジトリの子（複数リポジトリのエピック）**: エピックの子が親と別のリポジトリにあるときは、上の手順を次のとおり読み替える。表に無い呼び出しの形・書式・判定は、同じリポジトリの子では変えない。

| 上の書き方 | 別のリポジトリの子での読み替え |
|---|---|
| 子の依存 `gh api repos/<owner>/<repo>/issues/<N>/dependencies/blocked_by` | 子のリポジトリ（`repos/<子の owner>/<子の repo>/issues/<N>/dependencies/blocked_by`）で読む。前提の issue のリポジトリは応答の `repository_url` から取り、前提の state もそのリポジトリで読む。前提が別リポジトリにあっても閉じていれば解けている。前提の issue を `gh` が読めないときは、解けていないものとして待つ |
| 子エピックの判定 `gh api repos/{owner}/{repo}/issues/<N> --jq .sub_issues_summary.total` | 子のリポジトリ（`repos/<子の owner>/<子の repo>/issues/<N>`）で読む。別リポジトリというだけでは外さず、sub-issue を持つ子だけを外す |
| エピックの子の一覧 | エピックのリポジトリの sub-issue（`gh api repos/{owner}/{repo}/issues/<E>/sub_issues`。各要素の `repository_url` から子のリポジトリを取る）と、エピック本文の子の表（`<owner>/<repo>#<N>` か `#<N>`）を合わせて組み立てる。同じ子は小文字にそろえた `<owner>/<repo>#<N>` で 1 件に数える |
| 子を `route`・`launch`・`wait`（位置引数と `--watch-done`）・`reap`・`pending-owner`・`notify-closed`・`reply`・`adopt`・`child-log` に渡す | 別のリポジトリの子は `<owner>/<repo>#N` の形で渡す（同じリポジトリの子は番号だけ） |
| エピックへのコメント `後で別に起動するエピック: #N`、その行で子を外す照合（手順 2・`closed` の確認） | 別のリポジトリの子は `後で別に起動するエピック: <owner>/<repo>#N`。照合も `<owner>/<repo>#N` の形の行で行う |
| `子 #N マージ → 残り k 件`・`子 #N 見送り（<state_reason>）→ 残り k 件`・`子 #N のワークツリーを残した`・`親の判断: 子 #N 通した — ...` | 別のリポジトリの子は `子 <owner>/<repo>#N` の同じ形（`親の判断: 子 <owner>/<repo>#N 通した — ...`）。完了報告も同じ呼び方 |
| 手順 3 (b) の起点ブランチ | その子の記録の `base`（子のリポジトリの既定ブランチか `--base` の値）。親のリポジトリの `main` ではない |
| 手順 4 の `gh api repos/{owner}/{repo}/issues/<N> --jq .state_reason` | `gh api repos/<子の owner>/<子の repo>/issues/<N> --jq .state_reason`（親のリポジトリの同じ番号を読んで `completed` と `not_planned` を取り違えない） |
| 手順 8・マージ待ちの子・PR トークン上限の子の、子 issue の `子の停止: 主の返事待ち` と `親の判断:` のコメントの読み先（`author_association` を含む） | 子のリポジトリ（`repos/<子の owner>/<子の repo>/issues/<N>/comments`） |
| マージ待ちの子の入力収集と判断の印 | `parent-merge-inputs.sh` に子を `<owner>/<repo>#<N>` で渡す。PR と base の `auto-merge.yml` は PR の URL から読み先を決める。印も子の PR に付ける（コメントは `gh pr comment <PR> -R <子の repo>`、ラベルは `gh api repos/<子の repo>/issues/<PR番号>/labels`）。印が数えられるのは `gh` の認証アカウントが子のリポジトリの OWNER・MEMBER・COLLABORATOR のときだけで、そうでなければ決める役を起こさず手順 8 の形で主に上げる |
| 注意書き `親エピックからの注意書き: #<エピック番号>` | `親エピックからの注意書き: <エピックの owner>/<repo>#<E>`（子のリポジトリの issue に残る） |
| 親から届く返事の頭 | `親エピック #<E>（<owner>/<repo>）の判断（主の承認ではない）: ` と `主の返事（親エピック #<E>（<owner>/<repo>）経由）: `（番号のあとにエピックのリポジトリが付く） |
| `stop-judge.sh <epic> <child>` の `<child>` | 番号か `<owner>/<repo>#<N>`。後者は子の本文・コメントを `repos/<o>/<r>/issues/<N>` から読み、エピックのコメントの過去の判断を `親の判断: 子 <o>/<r>#<N> ` で始まる行から探す |

別のリポジトリの子は、`launch` が子の clone（環境変数 `EPIC_DISPATCH_CLONES`、無ければ、Orca の部品なら Orca に登録済みのリポジトリ。tmux の部品は登録が要らない）に子のワークツリーを作り、親のワークツリーに親子の線を張る。記録の `repo` は子のリポジトリ、`parent_worktree` は親のワークツリーで、`wait`・`reap` は記録を読む。

別のリポジトリの子の起点は、`--base` / `EPIC_DISPATCH_BASE` が無ければ子のリポジトリの既定ブランチ（親のリポジトリの `main` ではない）。リポジトリごとに既定ブランチが違う子を混ぜるときは `--base` を付けないか、`launch` をリポジトリごとに分ける。`--base` と `EPIC_DISPATCH_BASE` は 1 回の `launch` の全部の子に掛かる。

## epic-loop.md 手順６の読み替え

別のリポジトリの子の `failed <child> <理由>` の新しい理由も、主に報告して止まる（サブエージェント方式に自動で振り替えない）: `no-clone`（`EPIC_DISPATCH_CLONES` の設定か `git clone` を主に頼む）・`ambiguous-clone`（stderr の候補のパスを添える）・`not-in-orca`（Orca の部品のとき。Orca への clone の登録を主に頼む。stderr に登録のコマンドが出る。tmux の部品では登録は要らない）・`no-push`・`permission-lookup-failed`・`base-lookup-failed`（stderr の `gh` の認証アカウントと子のリポジトリを添える）。
