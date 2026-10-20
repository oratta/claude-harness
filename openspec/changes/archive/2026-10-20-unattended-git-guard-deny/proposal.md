## Why

`git-destructive-guard.sh` は、主の呼び出しで `permission_mode` が `bypassPermissions` なら `ask`（確認画面）を返す。flatmate の住人は `--dangerously-skip-permissions`（= `bypassPermissions`）の対話 TUI として tmux に常駐し、オーナーは Discord だけを見ているので、確認画面が出ても誰も押さず、セッションが無期限に止まる。止まっている間はセッション cron もチャンネルの受信も動かない（issue #1124。2026-10-20 に flatmate #1637 の子セッションで、レビュアーの `git checkout -q -- <path>` が確認画面で止まっていた）。

サブエージェントからの呼び出し（payload の `agent_id`）を確認画面なしで拒否する処理は #1108 で入っている。残っているのは、主の呼び出しのうち「画面を見ている人がいないセッション」を見分けて拒否することで、payload の値だけでは住人とオーナーの対話セッションを見分けられない（どちらも `bypassPermissions` の対話セッション）。

## What Changes

- 環境変数 `DEV_WORKFLOW_UNATTENDED` を「このセッションの画面を見ている人がいない」という印として定める。未設定・空・`0` は印なし、それ以外の値は印あり。印はセッションを起動する側（flatmate の `boot.sh` など）が claude の環境に入れる
- 印のあるセッションでは、主の呼び出しにも `permission_mode` と `DEV_WORKFLOW_GIT_GUARD_FORCE` によらず `deny` を返す。子の呼び出し（`agent_id` が空でない文字列）は今までどおり子の規則が先に決める
- 印のあるセッションの主の呼び出しへの拒否理由を、チャンネル（Discord など）でオーナーに承認を求める文面にする。確認画面を出している旨は書かない
- 印の無いセッション（オーナーの対話セッション）の振る舞いは変えない（`bypassPermissions` などでは今までどおり `ask`）
- `rules/destructive-git-guard.md` の「hook との分担」節と `rules/README.md` の該当行に、画面を見ている人のいないセッション（印の付いたセッション）でも確認画面を出さずに拒否されるので、チャンネルで主に承認を求めることを足す（hook の無人向け理由文だけ「オーナー」）
- flatmate の住人の起動で印を付ける作業を flatmate（genetta-inc/flatmate）の issue として起票し、#1124 からリンクする
- 採らない案: payload の値（`permission_mode` や、チャンネル経由のセッションに付く値）で見分ける。住人とオーナーの対話セッションは payload の上で同じ形をしており、`bypassPermissions` を一律 `deny` にするとオーナーの対話セッションで確認画面から承認できなくなる（受け入れ条件 3 に反する）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `destructive-git-hook`: 「確認画面が出るモードでだけ ask を返す」（印のあるセッションの主の呼び出しは deny）、「拒否理由は承認の取り方を案内する」（印のあるセッション向けの理由文）、「ルール本文と hook の分担」（印のあるセッションの扱いを足す）を変える

## Impact

- `plugins/dev-workflow/scripts/git-destructive-guard.sh`（decision の決定部・理由文・冒頭の説明）
- `plugins/dev-workflow/tests/git-destructive-guard.bats`
- `rules/destructive-git-guard.md`・`rules/README.md`（常時注入の量が増える。現在の合計 38,920 バイトに対し予算 40,260 バイトで、1 文の追加は予算内に収まる見込み。`tests/injection-budget.bats` を通す）
- `plugins/dev-workflow/changes/1124.md`（変更の記録）
- flatmate 側: 住人の起動（`boot.sh`）で `DEV_WORKFLOW_UNATTENDED=1` を claude の環境に入れる作業（別リポジトリの issue）
- hooks と rules は聖域なので、マージには主の承認が要る
