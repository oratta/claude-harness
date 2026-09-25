# セッション終了時に、そのセッションが起動したプロセスを止める（issue #470）

Claude のセッションが Bash ツールから起動した dev サーバー（`wrangler dev` / `next dev` / `python -m http.server` など）は、
セッションが終わっても親を launchd に付け替えて残り続ける。wt-clean の `kill_devserver_under` はワークツリーを消すときにしか
走らないので、作業が終わってから片付けるまでの数日から数週間は何も止まらない。そこで止めるタイミングをセッション終了時に移した。
振る舞いの正本は `openspec/specs/session-devserver-cleanup/spec.md`、スクリプトは `plugins/worktree/scripts/session-proc-*.sh`。

ワークツリー以外（メインリポジトリ）のセッションでも動く。worktree プラグインに置いたのは、プロセスを止める既存の処理と
SessionStart フックがここにあるためで、ワークツリー専用という意味ではない。

## 仕組み

| いつ | スクリプト | 何をするか |
|---|---|---|
| SessionStart（startup / resume / clear） | `session-proc-mark.sh` | 親をたどってセッションの持ち主の Claude Code プロセスを見つけ、`export CLAUDE_SESSION_PROC_MARK=<claude_pid>.<start_token>` を `CLAUDE_ENV_FILE` に 1 行追記する。Bash ツールから起動したプロセスは、ツールの種類を問わずこの目印を環境変数として引き継ぐ |
| SessionStart（前回から 10 分以上たっていれば） | 同上 → `session-proc-reaper.sh --sweep` | 持ち主（PID と開始時刻の組）がもういない目印のプロセスを止める。KILL やクラッシュで SessionEnd が走らなかったセッションの分を拾う |
| SessionEnd | `session-proc-end.sh` → `session-proc-reaper.sh --session-end <mark>` | フックは目印を計算して後始末を切り離して起動し、すぐ戻る（SessionEnd の持ち時間は 1.5 秒で、プラグインの `timeout` では延びない）。後始末は持ち主の Claude Code の終了を最大 30 秒待ち、終了していればその目印のプロセスを止める。`/clear` や `/resume` で同じプロセスが続いていれば止めない |

`start_token` は `LC_ALL=C ps -o lstart=` から英数字以外を除いたもの。`LC_ALL=C` を外すと macOS では曜日や日付の書式がロケールで
変わり、目印付けと生存判定が別のロケールで走ったときに、生きている持ち主を「もういない」と判定して動いているセッションの
dev サーバーを止めてしまう。

止め方は `kill_devserver_under` と同じで、TERM → 3 秒待つ → 生きていれば KILL。信号を送る直前に、目印ありとして拾ったものは
同じ目印を、子孫として加えたものは同じコマンド名・同じ親 PID を持っているかを読み直し、違えば送らない（PID の使い回し対策）。

## 止まるもの・止まらないもの

止まるのは、自分のユーザーのプロセスのうち、環境変数に目印を持つものと、そこから環境変数が読めないプロセスだけを経由して
届く子孫。「環境変数が読めない」は、`ps -ww -E -o command=` の出力に `NAME=value` の形の語が 1 つも無いことをいう。
macOS では `/bin/sh` や `/bin/sleep` などの Apple 同梱のバイナリと root のプロセスは、`ps -E` でも環境変数が返らない。

- **Bash ツールから起動したものは種類を問わず止まる。** dev サーバーに限らず、Bash ツールから起動した子の Claude Code、`code` CLI で開いたエディタなども、セッションの目印を引き継いでいるので止まる
- **子の Claude Code の配下は子の目印で動く。** 子のセッションの SessionStart が目印を付け直すので、親のセッションが終わって止まるのは子の Claude Code 本体と、親の目印を引き継いだものだけ
- **止まらないもの**: 目印を持たないプロセス（launchd から起動した住人・ダッシュボード、端末から人が手で起動したもの、Orca や端末から起動した Claude Code）、別のセッションの目印を持つプロセスで持ち主が生きているもの、他ユーザーのプロセス、目印を外して起動したものとその配下
- **環境変数が読めず、目印を持つ祖先もいないプロセスは止まらない。** 例えば Bash ツールのシェルが直接 `exec` した `/bin/sleep`。親が launchd に付け替わったあとは、どのセッションのものか判別できない
- **引数に `NAME=` の形の語を持つ Apple 同梱のバイナリは「読める・目印なし」と判定され、そこで探索が止まる。** 例: `/bin/sh -c "FOO=1 cmd"` や `/usr/bin/env FOO=1 cmd` の配下は、目印付きのプロセスの子孫でも止まらない。止めない側に倒れるので事故にはならない
- **止め漏れは wt-clean の `kill_devserver_under` が最後に拾う。** 止め漏れの報告があっても、そのたびに判定規則を足していくことはしない（守備範囲の外）

wt-clean の `kill_devserver_under` はワークツリーのパス配下で動くプロセスを対象にして、シェルとエディタを除外する。
ここでの後始末は目印を持つプロセスとその読めない子孫を対象にし、シェルを除外しない（目印の配下の `/bin/sh` は止める）。
対象の母集団が違う（パス配下と目印）ので、除外の基準が違っても矛盾しない。

## サーバーを立てたままセッションを閉じたいとき

目印を空にして起動する。

```bash
CLAUDE_SESSION_PROC_MARK= nohup npm run dev >/tmp/dev.log 2>&1 &
```

空の目印を持つプロセスは「環境変数が読めて目印を持たない」ので、それ自体もその配下も止まらない。

`env -i` で環境を空にして起動するのは目印を外したことにならない。環境変数が 1 つも無いプロセスは「読めない」と区別できず、
目印を持つプロセスの配下にいれば止まる。外したいときは上の書き方を使う。

## ログ

止めた各プロセスを 1 行ずつ残す。何も止めなかったときも `none` の 1 行を残す。

```
2026-09-25T01:23:45Z TERM pid=12345 comm=node mark=88032.FriSep251011182026 trigger=session-end
2026-09-25T01:23:48Z KILL pid=12346 comm=workerd mark=88032.FriSep251011182026 trigger=session-end
2026-09-25T01:30:00Z none mark=- trigger=sweep
```

- 場所: `${CLAUDE_PLUGIN_DATA}/session-devserver-cleanup.log`。`CLAUDE_PLUGIN_DATA` が無ければ `~/.claude/logs/session-devserver-cleanup.log`。1MB を超えたら 1 世代だけ `.1` に回す
- 種類: `TERM` / `KILL`（送った信号）、`GONE`（送る直前の読み直しで別のプロセスになっていた・もういなかった）、`none`（止めるものが無かった。`reason=owner-alive` は持ち主がまだ生きていたので止めなかった）、`no-owner`（フックが持ち主の Claude Code を見つけられず、目印を付けなかった・後始末を起動しなかった）
- `comm` は `ps -o comm=` の basename。macOS の Homebrew の `python3` は `Python` になる（`Python.app` の実行ファイルに exec するため）
- 掃除の間隔を判定するスタンプファイル `session-devserver-cleanup.sweep-stamp` もログと同じディレクトリに置く

## テスト用の環境変数

本番で設定する想定はない。`plugins/worktree/tests/session-proc-cleanup.bats` が使う。

| 環境変数 | 既定 | 何を変えるか |
|---|---|---|
| `SESSION_REAPER_OWNER_WAIT_SECS` | 30 | 後始末が持ち主の終了を待つ上限 |
| `SESSION_REAPER_TERM_GRACE_SECS` | 3 | TERM から生存確認までの待ち |
| `SESSION_REAPER_SWEEP_INTERVAL_SECS` | 600 | 掃除の最小間隔 |
| `SESSION_REAPER_PS_FIXTURE_DIR` | 未設定 | `ps` を実行せず、このディレクトリの固定出力（`ps-env.txt` / `ps-comm.txt` / `lstart.txt`）を読む。このときは信号を送らず `DRY` 行をログに書くだけ |
| `SESSION_REAPER_LOG_DIR` | 未設定 | ログとスタンプファイルの置き場所 |
| `SESSION_REAPER_HOOK_PID` | フック自身の PID | 持ち主の Claude Code を探し始める PID |
