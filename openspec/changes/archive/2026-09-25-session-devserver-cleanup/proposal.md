# session-devserver-cleanup — Claude のセッションが起動したプロセスをセッション終了時に止める

## Why

2026-09-24、Claude のセッションが動作確認のために起動した `wrangler dev` が、セッション終了後も 21 本（配下を含め 105 プロセス・約 1.1GB・最古 10 日前）残っていた（issue #470）。wt-clean はワークツリー削除の直前に配下のプロセスを止める（#39・#66）が、ワークツリーは作業終了後も数日から数週間残す運用のため、その間は何も止まらない。止める対象のツールが足りないのではなく、止めるタイミングが遅すぎる。

## What Changes

- **目印を付ける**: worktree プラグインの SessionStart フックが、セッションの持ち主である Claude Code プロセスを識別する目印の環境変数 `CLAUDE_SESSION_PROC_MARK` を `CLAUDE_ENV_FILE` に追記する。Bash ツールから起動したプロセスは、ツールの種類を問わずこの目印を環境変数として引き継ぐ（親が launchd に付け替わっても残る）。
- **終わったときに止める**: SessionEnd フックが、目印を持つ自分のユーザーのプロセスを TERM → 数秒待って生存確認 → KILL で止める。SessionEnd フックの持ち時間（既定 1.5 秒、プラグインの `timeout` では延びない）に収めるため、フック自体は親をたどって持ち主から目印を計算し、新しいセッションとして切り離した後始末プロセスを起動してすぐ戻る。後始末プロセスは目印の持ち主の Claude Code プロセスが終了したのを確かめてから止める（`/clear` や `/resume` で同じプロセスが続く場合は止めない）。
- **落ちたセッションの分を拾う**: SessionStart フックが、持ち主の Claude Code プロセスがもう存在しない目印を持つプロセスを、上と同じ手順で止める（間隔を空けて実行する）。
- **止めない側に倒す**: 環境変数を読めないプロセス（他ユーザーのプロセス、macOS のプラットフォームバイナリ）は、目印を持つプロセスの子孫でない限り止めない。目印を空にして起動したプロセスは子孫でも止めない。
- **ログ**: 止めたプロセスの PID・コマンド名・目印をログファイルに 1 行ずつ残す。
- **目印を外す手段を文書化する**: サーバーを立てたままセッションを閉じたいときの書き方（`CLAUDE_SESSION_PROC_MARK= nohup <cmd> &`）を worktree プラグインの references に書く。
- wt-clean の `kill_devserver_under` はそのまま残す（最後の保険）。親を失ったプロセスを一律に止める方式はとらない。

## Capabilities

### New Capabilities

- `session-devserver-cleanup`: Claude Code セッションが Bash ツールから起動したプロセスに目印を付け、セッション終了時と落ちたセッションの定期掃除で、目印を持つプロセスだけを TERM → KILL で止め、ログに残す振る舞い。

### Modified Capabilities

（なし。`wt-clean-devserver-cleanup` の要件は変えない）

## Impact

- **コード**: `plugins/worktree/hooks/hooks.json`（SessionStart に目印付けと掃除、SessionEnd を追加）、`plugins/worktree/scripts/` に目印付け・SessionEnd の入口・後始末のスクリプトを追加。
- **文書**: `plugins/worktree/references/session-devserver-cleanup.md`（仕組み・目印を外す書き方・ログの場所・止まらない場合の限界）、`plugins/worktree/changes/470.md`（変更の記録）。
- **テスト**: `plugins/worktree/tests/` に bats を追加。
- **マージ**: `plugins/worktree/hooks/hooks.json` は auto-merge の聖域パスに当たるため、この PR は自動マージされず主の明示承認が要る。
- **環境変数の契約**: `CLAUDE_SESSION_PROC_MARK` の名前と値の意味は、このプラグインのフックと、目印を外したい利用者（人と Claude）との間の契約になる。
- **利用者の体験**: セッションを閉じると、そのセッションで起動した dev サーバーも止まる（2026-09-24 オーナー了承済みのリスク）。
- **常時注入の予算**: フックは会話に何も出力しないので、常時注入の固定分は増えない。
