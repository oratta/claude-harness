## Context

Claude のセッションが Bash ツールから起動した dev サーバー（`wrangler dev` / `next dev` / `python -m http.server` 等）は、セッション終了後も親を launchd に付け替えて残り続ける。wt-clean の `kill_devserver_under`（`plugins/worktree/skills/wt-clean/SKILL.md`）はワークツリー削除時にしか走らないため、作業終了から削除までの数日から数週間は何も止まらない（issue #470）。

着手前に実機（macOS 26.7 / Darwin 25.6.0、2026-09-25）で確かめた事実:

- **プロセスの環境変数の見え方**: `ps eww -o command= -p <pid>`（`ps -E` も同じ）で、自分のユーザーの node・Homebrew の python3・`/usr/bin/python3`（Xcode の python を exec する）の環境変数は読めた。`/bin/sleep`・`/bin/sh` などのプラットフォームバイナリは、自分のユーザーのプロセスでも環境変数が空で返る（`sysctl KERN_PROCARGS2` の生データでも env 部が無い）。root のプロセスは `KERN_PROCARGS2` が EINVAL、`ps` は argv だけを返す。Bash ツールの砂場の中でも外でも同じ結果だった。
- **Bash ツールの環境**: Claude Code は Bash ツールの環境に `CLAUDE_CODE_SESSION_ID` を既に入れている。Bash ツールのシェルの親は Claude Code 本体（ネイティブ版では `comm` が `~/.local/bin/claude`）。
- **SessionEnd フックの持ち時間**: 公式文書（env-vars）によれば SessionEnd フック全体の予算は既定 1.5 秒で、プラグインのフックに書いた `timeout` では延びない。対象は終了・`/clear`・対話中の `/resume` の切り替え。
- **既存の定期ジョブ**: このリポジトリには launchd / cron の定期ジョブが無い。SessionStart フックは worktree プラグイン（`wt-setup-guard.sh`）と dev-workflow プラグイン（`session-tripwires.sh`）にある。

## Goals / Non-Goals

**Goals:**

- セッションの Bash ツールから起動したプロセス（バックグラウンド・`nohup` を含む）と、その子プロセスを、セッション終了時に止める
- SessionEnd が走らなかったセッション（KILL・クラッシュ）の分を、次に始まる任意のセッションで止める
- 目印を持たないプロセス、環境変数を読めないプロセス（子孫の例外を除く）、目印を外して起動したプロセスを止めない
- 止めたものを PID・コマンド名・目印でログに残す

**Non-Goals:**

- 親を失ったプロセスを一律に止めること（launchd の住人やダッシュボードを巻き込む）
- ツール名（wrangler・next 等）での個別判定
- wt-clean の `kill_devserver_under` の変更・撤去
- Linux 対応の確認（コードは POSIX の `ps` で書くが、受け入れ確認は macOS のみ）

## Decisions

### 目印は専用の環境変数 `CLAUDE_SESSION_PROC_MARK` にし、値で持ち主の Claude Code プロセスを表す

値は `<claude_pid>.<start_token>`。`start_token` は `LC_ALL=C ps -o lstart= -p <claude_pid>` の出力から英数字以外を除いたもの（例: `Fri Sep 25 10:11:18 2026` → `FriSep251011182026`）。持ち主が生きているかは「その PID が存在し、同じ `start_token` を返すか」で判定する（PID の使い回しで生存と誤認しない）。

- **`LC_ALL=C` を付ける理由**: macOS の `ps -o lstart=` はロケールに従って書式が変わる（実機で `LC_TIME=ja_JP.UTF-8` だと `金  9/25 10:24:52 2026`、`LC_ALL=C` だと `Fri Sep 25 10:24:52 2026`）。目印付けと生存判定が別のロケールで走ると、生きている持ち主を「もういない」と誤判定し、動いているセッションの dev サーバーを止める。`start_token` を計算する 3 か所（目印付け・後始末・掃除）のすべてで `LC_ALL=C` を付け、計算は 1 つの関数にまとめて 3 か所から呼ぶ
- **Claude Code が既に入れている `CLAUDE_CODE_SESSION_ID` を使わない理由**: 目印を外すには値を空にして起動する必要があり、同じ変数を他の用途（Claude Code 自身や他ツール）が読むと壊れる。またセッション ID からは持ち主のプロセスが生きているかを判定できず、別に登録簿が要る。`/clear` でセッション ID は変わるがプロセスは続くので、セッション ID 単位だと `/clear` のたびに止めることになる
- **セッション ID + 登録簿ファイル案を採らない理由**: 登録簿の掃除と破損時の扱いが増える。値に持ち主の PID と開始時刻を埋めれば、登録簿なしで生存判定できる
- **持ち主の Claude Code プロセスの見つけ方**: フックの PID から親をたどり（上限 8 段）、`comm` の basename が `claude` のプロセス、または `comm` が `node` で引数に `@anthropic-ai/claude-code` を含むプロセスを最初に見つけたものとする。見つからなければ目印を書かず、ログに 1 行残して終了する（止める側ではなく止めない側に倒れる）

### SessionStart フックが目印を `CLAUDE_ENV_FILE` に追記する

`CLAUDE_ENV_FILE` に `export CLAUDE_SESSION_PROC_MARK=<値>` の 1 行を `>>` で追記する（`export` を落とすとシェル変数にしかならず、子プロセスに渡らない）。他のプラグインも同じファイルに書くので上書きしない。`CLAUDE_ENV_FILE` が未設定・書けないときは何もしない。フックは会話に何も出力せず、常に exit 0（`wt-setup-guard.sh` と同じ fail-soft）。

### SessionEnd フックは切り離した後始末プロセスを起動してすぐ戻る

SessionEnd の持ち時間は 1.5 秒で、TERM → 数秒 → KILL が収まらない。フックは後始末スクリプトを切り離して起動し、すぐ exit 0 する。

- **後始末に渡す目印の求め方**: フックのプロセス環境に `CLAUDE_ENV_FILE` の変数が乗っているかは公式に書かれていないので頼らない。SessionEnd フックも SessionStart と同じく、フックの PID から親をたどって持ち主の Claude Code を特定し、同じ関数で目印の値を計算して後始末に引数で渡す。持ち主が見つからなければ後始末を起動せず、ログに 1 行残す（落ちたセッションと同じく掃除に任せる）
- **切り離し方**: `perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV' -- <後始末スクリプト> ...` で新しいセッション（プロセスグループも新しくなる）にして起動し、標準入出力は `/dev/null` に向ける。macOS には `setsid` コマンドが無く、`/usr/bin/perl` は macOS に標準で入っている（`python3` は `/usr/bin/python3` が Command Line Tools の導入を求める場合がある）。`nohup` や `( … & )` だけでは同じプロセスグループに残り、Claude Code がフックのプロセスグループごと落とすと後始末も消える。掃除の起動も同じ方法で切り離す
- **後始末自身は目印を持たない**: 起動時に `env -u CLAUDE_SESSION_PROC_MARK` を付ける（フック環境に乗っていた場合の保険。自分自身を止め対象にしない）

後始末プロセスは、目印の持ち主の Claude Code プロセスが終了するのを最大 30 秒（既定値）待ってから止める。30 秒たっても生きていれば止めずに終了する（`/clear`・`/resume` の切り替えでは同じプロセスが続くため、ここで止めないのが正しい。本当に終了していれば次の掃除で拾われる）。SessionEnd の `reason` で分岐しないのは、理由の値が増えても「持ち主が生きているか」だけで正しく決まるため。

### 落ちたセッションの掃除は SessionStart から起動する

候補は SessionStart と既存の定期ジョブだったが、このリポジトリには定期ジョブが無く、launchd の plist を配ると install / uninstall の手順が増える。Orca 運用ではセッションが頻繁に始まるので、SessionStart で十分な頻度になる。SessionStart フックは目印付けのあと、掃除を切り離して起動する。掃除は前回から 10 分（既定値）以内なら何もしない。判定に使うスタンプファイルはログと同じディレクトリに置く（`session-devserver-cleanup.sweep-stamp`）。掃除の対象は「目印を持ち、その持ち主が生きていない」プロセス。動いているセッションの目印を持つプロセスは対象外（持ち主が生きているので外れる）。

### 止める対象の決め方

**守備範囲**: 入力は `ps -U <自分の uid>` で列挙した自分のユーザーのプロセスの一覧だけ。拾いたいのは、持ち主が終了した目印を持つプロセスと、そこから環境変数が読めないプロセスだけを経由して届く子孫。通す（止めない）例は、launchd から起動した住人・ダッシュボード、端末から人が手で起動したもの、他ユーザーのプロセス、目印を外して起動したものとその配下、目印を持つ祖先がいない環境変数が読めないプロセス。止め漏れは wt-clean の `kill_devserver_under` が最後に拾うので、止め漏れの報告のたびに判定規則を足していくことを完了条件にしない。

**「環境変数が読めない」の定義**: `ps -ww -E -o command=` の出力（argv と環境変数が空白でつながったもの）に、`[A-Za-z_][A-Za-z0-9_]*=` の形の語が 1 つも無いこと。プラットフォームバイナリ（`/bin/sh` 等）がこれに当たる。`env -i` で環境を空にして起動したものもここに入り、目印ありの配下なら止まる（references に書く）。

手順:

1. `LC_ALL=C ps -U <自分の uid> -ww -E -o pid=,ppid=,command=` と `ps -U <uid> -o pid=,comm=` で自分のユーザーのプロセスだけを列挙する。他ユーザーのプロセスは最初から候補に入らない（macOS の `ps` は BSD 形式の `eww` と `-U` を同時に使えないため `-E` を使う。実機で確認済み）
2. 環境変数の中に `CLAUDE_SESSION_PROC_MARK=<対象の値>` が空白区切りの 1 語として現れるプロセスを「目印あり」とする
3. 「目印あり」から PPID をたどって子へ降りる。子が「環境変数が読めない」なら加えて、さらにその子へ降りる。子の環境変数が読めて、対象の目印を持たない（無い・空・別の値）なら、そのプロセスも配下も見ない（打ち切る）。読めない子孫を加えるのは、目印ありから読めないプロセスだけを経由して届く範囲に限る（子が目印ありなら、それ自体が 2 で拾われている）
4. 自分自身（後始末・掃除のプロセス）とその祖先は除く
5. 止める直前（TERM の前と KILL の前）に、目印ありとして拾ったものは同じ PID が同じ目印を持っているかを、子孫として加えたものは同じ PID・同じ `comm`・同じ PPID かを、もう一度確かめる（PID の使い回し対策）。違えば送らない

`/bin/sh` のようなプラットフォームバイナリで、目印を持つ祖先がいないもの（Bash ツールのシェルが直接起動した `sleep` など）は止まらない。受け入れ条件の対象（wrangler = node、next = node、`python -m http.server`）と、その子（workerd・esbuild は Homebrew / npm の非プラットフォームバイナリ）は目印が読める。この限界は references に書く。

### 停止手順とログ

`kill_devserver_under` と同じ段取り: 対象に TERM → 3 秒（既定値）待つ → `kill -0` で生存確認 → 生きていれば KILL。対象の決定から停止までの各プロセスについて、`<ISO8601 時刻> <TERM|KILL|GONE> pid=<pid> comm=<comm> mark=<値> trigger=<session-end|sweep>` を 1 行ずつログに追記する。何も止めなかったときも `none` の 1 行を残す（無音の実行をしない）。

ログの場所は `${CLAUDE_PLUGIN_DATA}/session-devserver-cleanup.log`。`CLAUDE_PLUGIN_DATA` が未設定なら `~/.claude/logs/session-devserver-cleanup.log`（ディレクトリは `mkdir -p` で作る）。1MB を超えたら 1 世代だけ `.1` に回す。

### 既定値を変える環境変数（テスト用）

次の環境変数で既定値と入力を差し替えられるようにする。本番で設定する想定はない。

| 環境変数 | 既定 | 何を変えるか |
|---|---|---|
| `SESSION_REAPER_OWNER_WAIT_SECS` | 30 | 後始末が持ち主の終了を待つ上限 |
| `SESSION_REAPER_TERM_GRACE_SECS` | 3 | TERM から生存確認までの待ち |
| `SESSION_REAPER_SWEEP_INTERVAL_SECS` | 600 | 掃除の最小間隔 |
| `SESSION_REAPER_PS_FIXTURE_DIR` | 未設定 | 設定されていれば、`ps` を実行せずこのディレクトリの固定出力を読む |
| `SESSION_REAPER_LOG_DIR` | 未設定 | ログとスタンプファイルの置き場所を上書きする |
| `SESSION_REAPER_HOOK_PID` | フック自身の PID | 持ち主の Claude Code を探し始める PID（テストで偽の持ち主を指すため） |

### 置き場所は worktree プラグイン

dev サーバーのプロセスを止める既存の処理（`kill_devserver_under`）と SessionStart フックが worktree プラグインにあり、止め方の段取りを揃えやすい。dev-workflow は開発手順の規約を持つプラグインで、プロセス管理を置く先として筋が遠い。ワークツリー以外（メインリポ）のセッションでも動く点はプラグイン名とずれるが、references にその旨を書く。

- スクリプト: `plugins/worktree/scripts/session-proc-mark.sh`（SessionStart: 目印付けと掃除の起動）、`plugins/worktree/scripts/session-proc-end.sh`（SessionEnd: 目印を計算して後始末を切り離して起動）、`plugins/worktree/scripts/session-proc-reaper.sh`（止める本体。`--session-end <mark>` と `--sweep` の 2 モード）。持ち主の特定と `start_token` の計算は reaper 側の関数にまとめ、他の 2 つはそれを呼ぶ
- `hooks.json`: SessionStart（matcher `startup|resume|clear`）に目印付けを追加、SessionEnd を新設。`plugins/*/hooks/` は auto-merge の聖域パスなので、この PR は自動マージされず主の明示承認が要る

### wt-clean との違い

wt-clean の `kill_devserver_under` はワークツリーのパス配下で動くプロセスを対象にし、シェルとエディタを除外する。今回の後始末は目印を持つプロセスとその読めない子孫を対象にし、シェルを除外しない（目印の配下の `/bin/sh` は止める）。対象の母集団が違うので、除外の基準が違っても矛盾しない。references にこの違いを書く。

### テスト

bats で次を確かめる。`SESSION_REAPER_PS_FIXTURE_DIR` で `ps` の出力を固定し、判定の分岐（目印あり・空の目印・別の目印・環境が読めない子孫・環境が読めない非子孫・他ユーザー・目印ありの子に目印を空にしたプロセスがいてその子に読めないプロセスがいる打ち切りの場合）を確かめる。`start_token` は `LC_TIME=ja_JP.UTF-8` を付けても同じ値になることを確かめる。実プロセスでは、目印付きの python3 と目印を空にした python3 を起動し、後始末で前者だけが止まり、TERM を無視する python3 は KILL で止まり、フックの親（とそのプロセスグループ）を終了させても切り離した後始末が生き残ることを確かめる（環境変数が読めない環境では skip）。

## Risks / Trade-offs

- [セッションを閉じると、そのセッションで起動した dev サーバーも止まる] → 2026-09-24 オーナー了承済み。目印を空にして起動する書き方を references に書く
- [Bash ツールから別の Claude Code を起動すると、子の Claude Code 自身が親の目印を持ち、親の終了時に止められる] → 子の Claude Code の配下は子の SessionStart が付け直した目印を持つので、止まるのは子の Claude Code プロセスとその目印を引き継いだものだけ。Orca や端末から起動した Claude Code は目印を持たないので影響しない。親より長く生かしたいときは目印を外して起動する
- [プラットフォームバイナリで、目印を持つ祖先がいないプロセスは止まらない] → 受け入れ条件の対象は止まる。残りは wt-clean の `kill_devserver_under` が最後に拾う
- [`ps -E` の出力で、引数に `CLAUDE_SESSION_PROC_MARK=<値>` と同じ文字列を含むプロセスを目印ありと誤認する] → 値は持ち主の PID と開始時刻で、別の用途で引数に現れる状況は grep 等で値そのものを探すときに限られる。掃除プロセス自身は対象から除く
- [SessionEnd が走っても、既定 30 秒以内に Claude Code が終了しないと止まらない] → 次の SessionStart の掃除で拾われる
- [掃除は次にセッションが始まるまで走らない] → Orca 運用ではセッション開始の頻度が高い。セッションを一切始めない期間は残るが、その間に増えることもない
- [PID の使い回し] → 目印の値に開始時刻を含め、止める直前に目印（子孫は comm と PPID）を読み直す
- [TERM を無視する「環境変数が読めない子孫」は、親が先に止まると PPID が 1 に変わり、KILL の直前の読み直し（同じ PPID か）で外れて KILL されない] → 止めない側に倒れる挙動として受け入れる。受け入れ条件「TERM で止まらないプロセスは KILL で止める」の対象は目印を持つプロセスで、その読み直しは目印で行うため KILL まで届く（実プロセスのテストで確認）。読めない子孫はプラットフォームバイナリ（`/bin/sh` 等）で TERM を無視するものは稀で、残っても wt-clean の `kill_devserver_under` が拾う。PPID の代わりに開始時刻で読み直す案は、読み直しの規則（要件の文言）を変えることになるので採らない
- [目印の配下で `env -i` により環境を空にして起動したものは止まる] → 読めないプロセスと区別できないため。外したいときは `env -i` ではなく目印を空にして起動する書き方を references に書く

## Open Questions

- SessionStart フックの実行環境で `CLAUDE_PLUGIN_DATA` が設定されるかは実装時に確かめる（未設定なら上記の代わりの場所を使うので、どちらでも動く）
- npm 版 Claude Code での持ち主の見つけ方（`node` + `@anthropic-ai/claude-code`）は手元にネイティブ版しか無いため、実装時は固定の `ps` 出力でのテストで確かめる
