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
- 悪意のある回避（変数展開でコマンド名を組み立てる、スクリプトファイルに書いて実行する等）を防ぐこと。目的はルールを読み飛ばした Claude を止めることで、セキュリティ境界ではない（spec の「守備範囲:」の段落が通すことを許す入力の正本。スクリプト先頭のコメントにも同じことを書く）
- push 済みの `git commit --amend`、`git rebase -i`、ブランチ名を書かない `git push`（現在のブランチが main のとき）。リポジトリの状態を見ないと判定できないので、ルール本文に残す
- #629（auto-merge テンプレの deny）、#364（epic #360 保留中）、Codex のワーカー（Claude Code の hook が効かない）

## Decisions

### 判定はスクリプトに一本化し、hooks.json の `if` では絞らない

hooks.json は `matcher: "Bash"` だけにし、どのコマンドが対象かはスクリプトが決める。

- 採らなかった案: `if: "Bash(git reset --hard*)"` のような権限ルール構文で hook の起動を絞る（issue 概要 2 の案）
- 理由: (1) `if` の判定は Claude Code の中で行われるので bats から検査できず、受け入れ条件の「9 種を hook に通すと ask か deny」を検査しても、実運用で hook が起動するかは別の層の問題として残る。(2) 一覧が hooks.json の `if` とスクリプトの 2 か所に分かれ、片方だけ直す事故が起きる。(3) `git -C x reset --hard` や `git -c k=v push --force` のように git の大域オプションが前に来る形を前方一致では拾えない
- 代償は Bash 呼び出しごとのプロセス起動。`context-tripwire.sh` の早期 exit と同じ形で、stdin の payload 全体に `git` の文字列が無ければシェルの文字列検査だけで exit 0 し、python3 は起動しない（payload の別の欄に `git` があれば余計に起動するだけで、判定は変わらない）。既存の `context-tripwire.sh` も Bash ごとに走っており、桁は変わらない
- 新しいエントリは PreToolUse 配列の末尾に足す。`plugins/dev-workflow/tests/tripwire-hook.bats` が `PreToolUse[0]` を Agent のエントリと前提にしているため

### `ask` と `deny` は payload の `permission_mode` で切り替える

- 既定: `permission_mode` が `default` / `acceptEdits` / `plan` のときは `ask`（確認画面が出て、主がその場で承認できる）
- それ以外（`bypassPermissions`・`dontAsk`・`auto`・未知の値・欠落）は `deny`。確認画面が出るか分からないモードで `ask` を返すと、確認なしで実行される恐れがあるので、分からないものは止める側に倒す
- 実装の最初に実機で確かめ、bypassPermissions の扱いを確定する。判定条件:
  - 手順: 使い捨ての git リポジトリ（scratchpad 配下）に追跡ファイルを 1 つ commit し、作業ツリーで書き換える。`DEV_WORKFLOW_GIT_GUARD_FORCE=ask`（検査専用。下記）を付けて `claude -p --plugin-dir plugins/dev-workflow --dangerously-skip-permissions` を起動し、`git reset --hard` を実行するよう頼む。終了後に書き換えが残っているかを見る
  - 対照実験（先に行う）: 同じ手順を `DEV_WORKFLOW_GIT_GUARD=off` で走らせ、書き換えが消える（Claude が実際に `git reset --hard` を打つ）ことを確かめる。消えなければ、Claude が頼みを断ったのか権限システムが止めたのかが区別できないので、hook についての結論を出さない（頼み方を変えてやり直す）
  - `--dangerously-skip-permissions` を付けない側（`permission_mode: default`）は `--allowedTools "Bash"` を付け、権限システムが hook より先に止めない状態で走らせる。対照実験もこの条件で行う
  - 書き換えが消えていたら（`ask` が確認なしで実行された）: bypassPermissions は `deny` のまま確定する
  - 書き換えが残っていて、出力に確認待ちか拒否が出ていたら: `-p` では `ask` が実行を止めることまでは言える。ただし対話セッションで確認画面が出るかは `-p` では観測できないので、bypassPermissions は `deny` のまま確定する（主が承認できる画面が出ると確かめられたときだけ `ask` に移す。対話セッションでの確認は主に頼む `画面確認:` の対象にする）
  - 同じ手順を `--dangerously-skip-permissions` 無し（`permission_mode: default`）でも行い、`-p` で `ask` が実行を止めることを確かめる。書き換えが消えていたら、`-p` では `ask` が効かないことになるので、全モードで `deny` に切り替える
  - 結果（対照実験を含む各回の出力と、書き換えが残ったか）は PR 本文に貼る（issue の受け入れ条件「両方の結果を PR に貼る」）
  - 結果で対応が変わるときは、スクリプトと bats に加えて spec.md と design.md も同じ commit で直す
- `DEV_WORKFLOW_GIT_GUARD_FORCE=ask|deny` は上の確認と bats のための上書きで、恒久設定にしない。ルール本文には書かない

### 承認済みの操作は主が自分で実行する

`deny` は Claude からは越えられない。承認済みの操作（ローカル main 運用の `git push origin main` など）は、拒否理由の中で「主に承認を求め、承認されたら主が自分で実行する（Claude Code の入力欄で `!` を付けるか、自分の端末で）」と案内する。

- 採らなかった案: コマンドに付ける目印（`GIT_GUARD_APPROVED=1 git push ...`）で通す。Claude が自分で付けられるので、ルールを読み飛ばす Claude を止めるという目的が崩れる
- `!` 入力が PreToolUse hook を通らないことは実機で確かめる。通る（止められる）なら、案内から `!` を外して「自分の端末で」だけにする
- セッション全体で止めたいときは `DEV_WORKFLOW_GIT_GUARD=off` を起動時の環境に入れる。hook の環境変数は Claude Code のプロセスから来るので、コマンド文字列の先頭に書いても効かない

### ルール本文は外さず足すだけにする（issue 概要 3 からの変更）

issue 概要 3 は「ルール本文を、なぜ止めるかと hook で拾えない項目だけに縮める」としていたが、本文の文は 1 つも外さず、hook との分担を足すだけにする。

- `always-on-injection-scope` が一覧と目印を本文に残すことを MUST とし、縮約は削除ではなく移設（外した文ごとに移設先と分類を示す）であることを求めている。この 21 行のルールから文を外すと、移設先と移設表を用意する手間がかかり、削れるバイト数に見合わない
- hook はコマンド文字列しか見ないので、スクリプトファイルや Makefile の中の git、dev-workflow を無効にしたプロジェクト、`DEV_WORKFLOW_GIT_GUARD=off` のセッションでは止まらない。そこではルールの文章が唯一の歯止めになる
- 足すのは 2 点: 一覧の操作は hook が実行前に止めること（止まったら言い換えて再実行せず主に聞く。拒否されたセッションでは承認後も主が自分で実行する）と、hook で拾えないもの（push 済みの `--amend`・`rebase -i`・ブランチ名を書かない push・スクリプト経由）。目印「例外なく事前承認」を含む文は変えない
- 予算（`tests/injection-budget.txt`）は増える。増分と理由（hook との分担を書かないと、拒否されたときに言い換えて再実行する・hook の穴を知らずに安心する、のどちらかが起きる）を PR 本文に書く

### wt-clean のブランチ削除は、この change の中で SKILL.md の案内を足して扱う

`plugins/worktree/skills/wt-clean/SKILL.md` は Claude に `git -C "$MAIN_REPO" branch -D "$BRANCH_NAME"` を直接打たせる（squash 済みの 🟢/🟡 の自動削除と、🔴 の破棄削除）。主の `cld` セッションも `--unattended` の cron も bypassPermissions なので、何もしなければマージした時点で wt-clean のブランチ削除が毎回 deny になる。

- 選んだ案: この change の中で wt-clean の SKILL.md に案内を 2 か所足す。①`git branch -D` を使う規則の節（squash 済みの扱い）に、hook に拒否されたら言い換えて再実行せず、worktree の削除までで止めてブランチを `HELD` に入れ、完了レポートに主が打つコマンドを載せること。②cron への載せ方の節に、無人運用のジョブの環境に `DEV_WORKFLOW_GIT_GUARD=off` を入れること（入れなければ squash 済みブランチの削除が拒否され、完了レポートの保留に載る）
- 選んだ理由: 選ぶ基準は「マージした時点で wt-clean が黙って壊れた状態にならないこと」。直しは同じファイルへの案内 2 か所で済み、拒否されたブランチは保留として完了レポートに出るので黙っては壊れない。別の子 issue に切ると、#710 のマージから子のマージまでの間、wt-clean が拒否のたびにどう振る舞うか決まっていない状態になる
- 採らなかった案: ①hook で wt-clean の `git branch -D` だけを通す（hook はマージ済みかを判定できず、ブランチ名や呼び出し元で通すと Claude が同じ形を使えば通ってしまう）。②wt-clean のブランチ削除をスクリプトファイルに移して hook の守備範囲外にする（hook の穴を設計に組み込むことになり、変更も大きい）
- 代償: 主の対話セッションでは、squash 済みブランチの削除が毎回主の手作業（`!` で打つ）になる。worktree の削除は今までどおり自動で、残るのはブランチ名だけなので、作業の取り違えは起きない
- 既存の cron ジョブは各住人の `cron-jobs.md` にあり、このリポジトリの外にある。環境変数を足すまでの間は、ブランチ削除が保留として完了レポート（ログに残す成果物）に出る

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
