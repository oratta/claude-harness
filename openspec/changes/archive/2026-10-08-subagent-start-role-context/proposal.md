## Why

`session-tripwires.sh` が SessionStart で注入する運用情報（Fable 残量モード・共有枠モード・コンテキスト量の閾値）は親セッションにしか入らない。dev-workflow の作業役（worker）・レビュー役（reviewer）・ゲート役（gate-runner）は、自分の指示書が「上限は共有枠モードが先に決める」「途中計測の通知を受けたら締める」と書いているのに、その時点の値を知らずに起動する。SubagentStart hook の `additionalContext` はサブエージェントの初期コンテキストに入り、自動の要約（compaction）を経ても残るので、ここで渡せば役が起動時から現在値を知って動ける。

あわせて、仲裁役 `casting-arbiter` は「フェーズ宣言文と主張リストだけで裁定する」設計なのに CLAUDE.md を読み込んでいる。`omitClaudeMd: true`（Claude Code 2.1.271）で読み込みを切り、入力の限定を設定でも担保する。

## What Changes

- dev-workflow の `hooks/hooks.json` に SubagentStart のエントリを足す（matcher `^dev-workflow:(worker|reviewer|gate-runner)$`）。起動するのは新規スクリプト `scripts/subagent-start-context.sh`
- 新規スクリプトは入力の `agent_type` を自分でも照合し、対象 3 役以外には何も出力しない。対象なら役に必要な行だけを `hookSpecificOutput.additionalContext` で返す
  - worker / gate-runner: Fable 残量モードと共有枠モード（値・出どころ・効果）、途中計測の閾値の現在値と正本への案内
  - reviewer: 途中計測の閾値の現在値と正本への案内だけ（モデルを選ばないので残量モードは渡さない）
- 残量モードの導出は複製しない。`session-tripwires.sh` に「サブエージェント向けの範囲だけを出す」出力範囲の切り替えを足し、新規スクリプトはそれを呼ぶ（`prompt-tripwires-refresh.sh` が `session-tripwires.sh` を呼んで本文を作っているのと同じ形）。サブエージェント向けの範囲では usage-probe を走らせない
- `plugins/casting/agents/casting-arbiter.md` の frontmatter に `omitClaudeMd: true` を足す
- どの経路も fail-open（判定できなければ無出力・exit 0。サブエージェントの起動を止めない）

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-escalation-tripwires`: SubagentStart hook で dev-workflow の 3 役に運用情報を注入する要件を足す
- `casting-consultation-protocol`: 仲裁 subagent の入力契約に、frontmatter の `omitClaudeMd: true` を足す

## Impact

- `plugins/dev-workflow/hooks/hooks.json`（自己統治物件。PR で主の承認を求める）
- `plugins/dev-workflow/scripts/session-tripwires.sh`（出力範囲の切り替えを追加。既定の出力は変えない）
- `plugins/dev-workflow/scripts/subagent-start-context.sh`（新規）
- `plugins/dev-workflow/tests/subagent-start-context.bats`（新規）
- `plugins/casting/agents/casting-arbiter.md`
- 変更記録 `plugins/dev-workflow/changes/715.md`・`plugins/casting/changes/715.md`
- 常時注入の予算（`tests/injection-budget.bats`）: description は変えないので測定値は動かない見込み。frontmatter の許可リスト書式検査を `omitClaudeMd: true` が通ることを確かめる
