## Context

- `rules/destructive-git-guard.md` は常時注入のルールで、承認なしに実行しない git 操作の一覧を持つ。止める仕組みは無い
- dev-workflow には既に PreToolUse の command hook が 2 つある（`agent-model-guard.sh`: Agent の model 未指定を deny、`context-tripwire.sh`: Edit/Write/Bash をコンテキスト上限で deny）。どちらも「payload を stdin から python3 で読み、拒否時だけ `hookSpecificOutput` の JSON を出して exit 0、読めなければ fail-open」の形で、bats で単体検査している
- 主のセッションの多くは `cld`（`--dangerously-skip-permissions`）で動き、payload の `permission_mode` は `bypassPermissions` になる。epic-dispatch の子セッションも同じ。確認画面が出ない前提のセッションで `ask` がどう扱われるかは未確認
- `always-on-injection-scope` は destructive-git-guard.md を常時注入に残し、本文に「承認なしに実行しない操作の一覧」と目印（`例外なく事前承認` / `` `git reset --hard` `` / `` `git push <remote> main|master`（remote 名を問わない） ``）を残すことを要求している（`tests/always-on-injection-scope.bats`）
- `global-push-guard` は「ローカル main 運用では承認後の main への push が正常系」という理由で、グローバル pre-push フックに main 拒否を入れていない。この hook も、承認済みの main への push を通す経路を持つ必要がある

## Goals / Non-Goals

**Goals:**
- ルールの一覧のうちコマンド文字列で判定できる 9 種を、Bash の実行前に止める（主が見ているセッションでは確認画面、見ていないセッションでは拒否）
- 判定の正本を 1 か所（hook スクリプト）に置き、bats で全種を検査できるようにする
- 承認済みの操作を実行する経路を残す

**Non-Goals:**
- 悪意のある回避（変数展開でコマンド名を組み立てる、スクリプトファイルに書いて実行する等）を防ぐこと。目的はルールを読み飛ばした Claude を止めることで、セキュリティ境界ではない
- push 済みの `git commit --amend`、`git rebase -i`、ブランチ名を書かない `git push`（現在のブランチが main のとき）。リポジトリの状態を見ないと判定できないので、ルール本文に残す
- #629（auto-merge テンプレの deny）、#364（epic #360 保留中）、Codex のワーカー（Claude Code の hook が効かない）

## Decisions

### 判定はスクリプトに一本化し、hooks.json の `if` では絞らない

hooks.json は `matcher: "Bash"` だけにし、どのコマンドが対象かはスクリプトが決める。

- 採らなかった案: `if: "Bash(git reset --hard*)"` のような権限ルール構文で hook の起動を絞る（issue 概要 2 の案）
- 理由: (1) `if` の判定は Claude Code の中で行われるので bats から検査できず、受け入れ条件の「9 種を hook に通すと ask か deny」を検査しても、実運用で hook が起動するかは別の層の問題として残る。(2) 一覧が hooks.json の `if` とスクリプトの 2 か所に分かれ、片方だけ直す事故が起きる。(3) `git -C x reset --hard` や `git -c k=v push --force` のように git の大域オプションが前に来る形を前方一致では拾えない
- 代償は Bash 呼び出しごとのプロセス起動。コマンドに `git` の文字列を含まなければシェルの文字列検査だけで exit 0 し、python3 は起動しない。既存の `context-tripwire.sh` も Bash ごとに走っており、桁は変わらない

### `ask` と `deny` は payload の `permission_mode` で切り替える

- 既定: `permission_mode` が `default` / `acceptEdits` / `plan` のときは `ask`（確認画面が出て、主がその場で承認できる）
- それ以外（`bypassPermissions`・`dontAsk`・`auto`・未知の値・欠落）は `deny`。確認画面が出るか分からないモードで `ask` を返すと、確認なしで実行される恐れがあるので、分からないものは止める側に倒す
- 実装の最初に実機で確かめ、bypassPermissions の扱いを確定する。判定条件:
  - 手順: 使い捨ての git リポジトリ（scratchpad 配下）に追跡ファイルを 1 つ commit し、作業ツリーで書き換える。`DEV_WORKFLOW_GIT_GUARD_FORCE=ask`（検査専用。下記）を付けて `claude -p --plugin-dir plugins/dev-workflow --dangerously-skip-permissions` を起動し、`git reset --hard` を実行するよう頼む。終了後に書き換えが残っているかを見る
  - 書き換えが消えていたら（`ask` が確認なしで実行された）: bypassPermissions は `deny` のまま確定する
  - 書き換えが残っていて、出力に確認待ちか拒否が出ていたら: `-p` では `ask` が実行を止めることまでは言える。ただし対話セッションで確認画面が出るかは `-p` では観測できないので、bypassPermissions は `deny` のまま確定する（主が承認できる画面が出ると確かめられたときだけ `ask` に移す。対話セッションでの確認は主に頼む `画面確認:` の対象にする）
  - 同じ手順を `--dangerously-skip-permissions` 無し（`permission_mode: default`）でも行い、`-p` で `ask` が実行を止めることを確かめる。書き換えが消えていたら、`-p` では `ask` が効かないことになるので、全モードで `deny` に切り替える
  - 結果（両方の出力と、書き換えが残ったか）は PR 本文に貼る（issue の受け入れ条件「両方の結果を PR に貼る」）
- `DEV_WORKFLOW_GIT_GUARD_FORCE=ask|deny` は上の確認と bats のための上書きで、恒久設定にしない。ルール本文には書かない

### 承認済みの操作は主が自分で実行する

`deny` は Claude からは越えられない。承認済みの操作（ローカル main 運用の `git push origin main` など）は、拒否理由の中で「主に承認を求め、承認されたら主が自分で実行する（Claude Code の入力欄で `!` を付けるか、自分の端末で）」と案内する。

- 採らなかった案: コマンドに付ける目印（`GIT_GUARD_APPROVED=1 git push ...`）で通す。Claude が自分で付けられるので、ルールを読み飛ばす Claude を止めるという目的が崩れる
- `!` 入力が PreToolUse hook を通らないことは実機で確かめる。通る（止められる）なら、案内から `!` を外して「自分の端末で」だけにする
- セッション全体で止めたいときは `DEV_WORKFLOW_GIT_GUARD=off` を起動時の環境に入れる。hook の環境変数は Claude Code のプロセスから来るので、コマンド文字列の先頭に書いても効かない

### 一覧はルール本文に残す（issue 概要 3 からの変更）

issue 概要 3 は「ルール本文を、なぜ止めるかと hook で拾えない項目だけに縮める」としていたが、一覧は短い形で残す。

- `always-on-injection-scope` が一覧と目印を本文に残すことを MUST としている。この要件を変えるには、hook が全環境で一覧を覆うことが前提になる
- hook はコマンド文字列しか見ないので、スクリプトファイルや Makefile の中の git、dev-workflow を無効にしたプロジェクト、`DEV_WORKFLOW_GIT_GUARD=off` のセッションでは止まらない。そこではルールの文章が唯一の歯止めになる
- 本文に足すのは 2 点: 一覧の操作は hook が実行前に止めること（止まったら言い換えて再実行せず主に聞く）と、hook で拾えないもの（push 済みの `--amend`・`rebase -i`・ブランチ名を書かない push・スクリプト経由）。経緯の括弧書きなど、読まれなくても挙動が変わらない文は削り、予算の増分を抑える

### コマンド文字列の分解

python3 の `shlex`（`punctuation_chars=True`）で字句に分け、次の単位で単純コマンドを取り出して再帰的に判定する。

- 制御演算子（`&&` `||` `;` `|` `&` 改行）と括弧で区切る
- 字句の中の `$(...)` とバッククォートの中身、`bash` / `sh` / `zsh` の `-c` の引数、`eval` の引数を取り出して同じ判定にかける
- 単純コマンドの先頭の環境変数代入（`FOO=1`）と `command` / `env` / `sudo` / `nohup` / `time` を読み飛ばし、`git`（パスの末尾が `git` のものを含む）を探す
- git の大域オプション（`-C <path>` `-c <k=v>` `--git-dir[=]` `--work-tree[=]` `--namespace[=]` `--no-pager` `-P` など）を読み飛ばしてサブコマンドを決める
- `shlex` が引用符の不整合で失敗したら、空白で割った字句に同じ判定をかける（判定を諦めて素通りにしない）

## Risks / Trade-offs

- [判定の取りこぼし] 変数で組み立てたコマンドやスクリプト経由は止まらない → Non-Goals に明記し、ルール本文に hook で拾えないものとして書く
- [誤検知] `git commit -m "--no-verify を外す"` のように、引用符の中の文字列は 1 つの字句になるので当たらない。`echo git reset --hard` のように git が単純コマンドの先頭でなければ当たらない。それでも当たったら主が自分で実行すれば済み、取り返しのつかない損失にはならない
- [主のセッションで毎回拒否される] 主の `cld` セッションは bypassPermissions なので `deny` になり、承認済みの操作も主が自分で打つ必要がある。対象は頻度の低い操作に限られるので受け入れる。bypassPermissions で確認画面が出ると確かめられたら `ask` に移す
- [hook の障害] python3 が無い・payload が読めないときは fail-open（何も出さない）。止める仕組みが黙って外れるが、既存の hook と同じ扱いで、ルール本文が残っている

## Migration Plan

マージ後、各 PC で dev-workflow プラグインが更新されると有効になる。戻すときは hooks.json の該当エントリを外す PR を出す（その間は `DEV_WORKFLOW_GIT_GUARD=off` で止められる）。
