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

値は `<claude_pid>.<start_token>`。`start_token` は `ps -o lstart= -p <claude_pid>` の出力から英数字以外を除いたもの（例: `Fri Sep 25 10:11:18 2026` → `FriSep251011182026`）。持ち主が生きているかは「その PID が存在し、同じ `start_token` を返すか」で判定する（PID の使い回しで生存と誤認しない）。

- **Claude Code が既に入れている `CLAUDE_CODE_SESSION_ID` を使わない理由**: 目印を外すには値を空にして起動する必要があり、同じ変数を他の用途（Claude Code 自身や他ツール）が読むと壊れる。またセッション ID からは持ち主のプロセスが生きているかを判定できず、別に登録簿が要る。`/clear` でセッション ID は変わるがプロセスは続くので、セッション ID 単位だと `/clear` のたびに止めることになる。
- **セッション ID + 登録簿ファイル案を採らない理由**: 登録簿の掃除と破損時の扱いが増える。値に持ち主の PID と開始時刻を埋めれば、登録簿なしで生存判定できる。
- **持ち主の Claude Code プロセスの見つけ方**: フックの PID から親をたどり（上限 8 段）、`comm` の basename が `claude` のプロセス、または `comm` が `node` で引数に `@anthropic-ai/claude-code` を含むプロセスを最初に見つけたものとする。見つからなければ目印を書かず、ログに 1 行残して終了する（止める側ではなく止めない側に倒れる）。

### SessionStart フックが目印を `CLAUDE_ENV_FILE` に追記する

`CLAUDE_ENV_FILE` が未設定・書けないときは何もしない。他のプラグインも同じファイルに書くので `>>` で追記し、上書きしない。フックは会話に何も出力せず、常に exit 0（`wt-setup-guard.sh` と同じ fail-soft）。

### SessionEnd フックは切り離した後始末プロセスを起動してすぐ戻る

SessionEnd の持ち時間は 1.5 秒で、TERM → 数秒 → KILL が収まらない。フックは後始末スクリプトを `nohup` 相当で切り離して起動し（標準入出力を閉じる）、すぐ exit 0 する。後始末プロセスは自分の環境から `CLAUDE_SESSION_PROC_MARK` を外して起動する（自分自身を止め対象にしない）。

後始末プロセスは、目印の持ち主の Claude Code プロセスが終了するのを最大 30 秒待ってから止める。30 秒たっても生きていれば止めずに終了する（`/clear`・`/resume` の切り替えでは同じプロセスが続くため、ここで止めないのが正しい。本当に終了していれば次の掃除で拾われる）。SessionEnd の `reason` で分岐しないのは、理由の値が増えても「持ち主が生きているか」だけで正しく決まるため。

### 落ちたセッションの掃除は SessionStart から起動する

候補は SessionStart と既存の定期ジョブだったが、このリポジトリには定期ジョブが無く、launchd の plist を配ると install / uninstall の手順が増える。Orca 運用ではセッションが頻繁に始まるので、SessionStart で十分な頻度になる。SessionStart フックは目印付けのあと、掃除を切り離して起動する。掃除は前回から 10 分以内なら何もしない（スタンプファイルで判定）。掃除の対象は「目印を持ち、その持ち主が生きていない」プロセス。自分のセッションの目印を持つプロセスは対象外（持ち主が生きているので自然に外れる）。

### 止める対象の決め方

1. `ps -U <自分の uid> -ww -o pid=,ppid=,comm=` と `ps -U <uid> eww -o pid=,command=` で自分のユーザーのプロセスだけを列挙する。他ユーザーのプロセスは最初から候補に入らない
2. 環境変数の中に `CLAUDE_SESSION_PROC_MARK=<対象の値>` が空白区切りの 1 語として現れるプロセスを「目印あり」とする
3. 「目印あり」の子孫（PPID でたどる）のうち、環境変数が読めないもの（プラットフォームバイナリ）を加える。環境変数が読めて、目印が無い・空・別の値のものは加えない（目印を外して起動したものを守る）
4. 自分自身（後始末プロセス）とその祖先は除く
5. 止める直前（TERM の前と KILL の前）に、同じ PID が同じ目印を持っているかをもう一度確かめる（PID の使い回し対策）。子孫として加えたものは同じ PID・同じ `comm` かで確かめる

`/bin/sh` のようなプラットフォームバイナリで、目印を持つ祖先がいないもの（Bash ツールのシェルが直接起動した `sleep` など）は止まらない。受け入れ条件の対象（wrangler = node、next = node、`python -m http.server`）と、その子（workerd・esbuild は Homebrew / npm の非プラットフォームバイナリ）は目印が読める。この限界は references に書く。

### 停止手順とログ

`kill_devserver_under` と同じ段取り: 対象に TERM → 3 秒待つ → `kill -0` で生存確認 → 生きていれば KILL。対象の決定から停止までの各プロセスについて、`<ISO8601 時刻> <TERM|KILL|GONE> pid=<pid> comm=<comm> mark=<値> trigger=<session-end|sweep>` を 1 行ずつログに追記する。何も止めなかったときも `none` の 1 行を残す（無音の実行をしない）。

ログの場所は `${CLAUDE_PLUGIN_DATA}/session-devserver-cleanup.log`。`CLAUDE_PLUGIN_DATA` が未設定なら `~/.claude/logs/session-devserver-cleanup.log`。1MB を超えたら 1 世代だけ `.1` に回す。

### 置き場所は worktree プラグイン

dev サーバーのプロセスを止める既存の処理（`kill_devserver_under`）と SessionStart フックが worktree プラグインにあり、止め方の段取りと除外の考え方を揃えやすい。dev-workflow は開発手順の規約を持つプラグインで、プロセス管理を置く先として筋が遠い。ワークツリー以外（メインリポ）のセッションでも動く点はプラグイン名とずれるが、references にその旨を書く。

- スクリプト: `plugins/worktree/scripts/session-proc-mark.sh`（SessionStart: 目印付けと掃除の起動）、`plugins/worktree/scripts/session-proc-reaper.sh`（止める本体。`--session-end <mark>` と `--sweep` の 2 モード）
- `hooks.json`: SessionStart（matcher `startup|resume|clear`）に目印付けを追加、SessionEnd を新設

### テスト

bats で次を確かめる。`ps` の出力はテスト用の環境変数（例: `SESSION_REAPER_PS_FIXTURE_DIR`）で差し替えられるようにし、判定の分岐（目印あり・空の目印・別の目印・環境が読めない子孫・環境が読めない非子孫・他ユーザー）を固定の出力で確かめる。加えて実プロセスでの確認として、目印付きの python3 の `sleep` と目印を空にした python3 の `sleep` を起動し、後始末で前者だけが止まり、TERM を無視する python3 は KILL で止まることを確かめる（環境変数が読めない環境では skip）。

## Risks / Trade-offs

- [セッションを閉じると、そのセッションで起動した dev サーバーも止まる] → 2026-09-24 オーナー了承済み。目印を空にして起動する書き方を references に書く
- [Bash ツールから別の Claude Code を起動すると、子の Claude Code 自身が親の目印を持ち、親の終了時に止められる] → 子の Claude Code の配下は子の SessionStart が付け直した目印を持つので、止まるのは子の Claude Code プロセスとその目印を引き継いだものだけ。Orca や端末から起動した Claude Code は目印を持たないので影響しない。親より長く生かしたいときは目印を外して起動する
- [プラットフォームバイナリで、目印を持つ祖先がいないプロセスは止まらない] → 受け入れ条件の対象は止まる。残りは wt-clean の `kill_devserver_under` が最後に拾う
- [`ps eww` の出力で、引数に `CLAUDE_SESSION_PROC_MARK=<値>` と同じ文字列を含むプロセスを目印ありと誤認する] → 値は持ち主の PID と開始時刻で、別の用途で引数に現れる状況は grep 等で値そのものを探すときに限られる。掃除プロセス自身は対象から除く
- [SessionEnd が走っても、30 秒以内に Claude Code が終了しないと止まらない] → 次の SessionStart の掃除で拾われる
- [掃除は次にセッションが始まるまで走らない] → Orca 運用ではセッション開始の頻度が高い。セッションを一切始めない期間は残るが、その間に増えることもない
- [PID の使い回し] → 目印の値に開始時刻を含め、止める直前に目印を読み直す

## Open Questions

- SessionStart フックの実行環境で `CLAUDE_PLUGIN_DATA` が設定されるかは実装時に確かめる（未設定なら上記の代わりの場所を使うので、どちらでも動く）
- npm 版 Claude Code での持ち主の見つけ方（`node` + `@anthropic-ai/claude-code`）は手元にネイティブ版しか無いため、実装時は固定の `ps` 出力でのテストで確かめる
