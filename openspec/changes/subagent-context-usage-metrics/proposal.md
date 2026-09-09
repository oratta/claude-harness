# subagent-context-usage-metrics — サブエージェントの初回・最終コンテキスト量を usage 監査に載せる

## Why

セッションとサブエージェントの起動直後に必ず載る固定分（rules・CLAUDE.md・MEMORY.md・skill 一覧・接続コネクタ名など）は、2026-08-31 の約 42,000 トークンから 09-08 の約 58,678 トークンへ 8 日で約 4 割増えた。これに誰も気づかなかったのは、増加の大半が harness の PR の diff に現れない要素（メモリ・接続コネクタ・Claude Code 本体）で発生し、事後にトランスクリプトを手集計するまで観測手段が無かったためである。

`subagent-context.sh` は「今この 1 体がいくら読んでいるか」を測るが、母集団の傾向（固定分が増えたか、上限 150,000 を超えて手渡しになる割合が増えたか）は測らない。観測が無いまま固定分の削減（issue #260）や途中停止 hook（#261）に進むと、効果を同じ物差しで確認できない。

親エピック: [#257](https://github.com/oratta/claude-harness/issues/257)。この change は [#259](https://github.com/oratta/claude-harness/issues/259)（観測のみ。強制はしない）に対応する。

## What Changes

- **集計スクリプトを新設する**: `plugins/dev-workflow/scripts/subagent-context-audit.sh`。直近 N 日（既定 14 日）のサブエージェントのトランスクリプトを走査し、1 行 JSON で「件数 / 初回コンテキストの中央値・最大 / 最終コンテキストの中央値・最大 / 上限（`DEV_WORKFLOW_CONTEXT_CAP`、既定 150,000）超の割合」を出す。
- **worktree 隔離のエージェントを集計対象に含める**: `isolation: "worktree"` で起こしたエージェントのトランスクリプトは `subagents/agent-*.jsonl` ではなく、**別 project ディレクトリにセッション UUID 名**で置かれる（実測: project ディレクトリ名が `…--claude-worktrees-agent-<hash>` で終わる）。この経路を走査対象に足す。
- **usage 監査の出力に載せる**: `session-tripwires.sh`（SessionStart hook）が集計を best-effort で実行し、結果を残量モードのブロックと並べてセッション文脈に注入する。結果は自前のキャッシュファイルに保存し、TTL 内は再走査しない（毎回のセッション開始で 14 日分を読み直さない）。
- **強制はしない**: 閾値超過でセッションやツールを止める判定は加えない（通知・記録のみ）。強制停止は別 issue（#261）が扱う。
- **全経路 fail-open**: トランスクリプトが 1 件も無い・読めない・`python3` が無い場合は exit 0 と空の結果（`count: 0`）を返し、注入も無出力にしてセッション開始を妨げない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-execution-strategy`: `subagent-context.sh`（1 体の実測）の契約を持つ capability に、母集団の実測を扱う要件を 2 つ追加する。① 集計スクリプト `subagent-context-audit.sh` の入出力・走査範囲・fail-open の契約、② `session-tripwires.sh` がその結果を SessionStart の注入内容に載せる契約（キャッシュ TTL と fail-open を含む）。既存の残量モード導出・共有枠モード導出・`subagent-context.sh` の要件は変更しない。

## Impact

- **コード**: `plugins/dev-workflow/scripts/subagent-context-audit.sh`（新規）、`plugins/dev-workflow/scripts/session-tripwires.sh`（注入ブロックの追加）、`plugins/dev-workflow/.claude-plugin/plugin.json`（version bump）。
- **テスト**: `plugins/dev-workflow/tests/` に新スイート（集計・fail-open・worktree 経路・注入）。`scripts/test.sh` が `git ls-files '*.bats'` で自動発見する。
- **spec**: `openspec/changes/subagent-context-usage-metrics/specs/dev-workflow-execution-strategy/spec.md`（ADDED Requirements 2 件）。
- **性能**: SessionStart の hook が触るファイル数が増える。トランスクリプトは 1 体で数百 MB になりうるため、全文読み込みはしない（先頭から最初の assistant レコードまでのストリーム読みと、末尾からの逆読み）。加えてキャッシュ TTL で走査頻度を抑える。
- **外部依存**: `~/.claude/projects` のディレクトリ構造とトランスクリプトの `usage` フィールドに依存する（`subagent-context.sh` と同じ依存で、Claude Code 側の変更で壊れうる。壊れたときは fail-open で無出力になる）。
- **やらないこと**: 閾値による強制停止（#261）、固定分の削減そのもの（#260）、編集時の予算ゲート（#258）。
