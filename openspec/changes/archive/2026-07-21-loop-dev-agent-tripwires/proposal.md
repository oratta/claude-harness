## Why

issue #26 の v2 後半。dev-workflow の昇格トリップワイヤー（dev-workflow-escalation-tripwires、archived 2026-07-21）は interactive 導入手順を持つが、効果が最大の unmanned パス（loop-dev-agent の憲法）への組み込みが未実施。また longrun の reserve 降格（longrun-exec-model-allocation、archived 2026-07-21）は `LONGRUN_AUTOMATED=1` を無人配線が設定する前提だが、その前提が憲法テンプレート・install スキルのどこにも記載されていない。

## What Changes

- `plugins/loops/templates/agent-loop-template.md` の Step 3（実装モード）に昇格トリップワイヤー節を追加する。3本を unmanned の既存経路に写像する（①規模超過→github-issue スキルの workflow 型/サブ issue 分割、②失敗ループ→1段昇格・reserve 時 Opus 上限で needs-approval、③仕様の発明→Discord 質問 + needs-approval でサイクル終了）
- 環境変数の前提（`LONGRUN_AUTOMATED=1` / `FABLE_BUDGET_MODE`。RATE_* と同じく配線側が設定）を憲法テンプレートと loops-dev-agent-install スキルに明記する
- bats テストを追加する（テンプレートのトリップワイヤー3本・env 前提・Workflow ツール直接呼び出し不在）
- `plugins/loops/.claude-plugin/plugin.json` のバージョン更新

## Capabilities

### New Capabilities

- `loop-dev-agent-tripwires`: loop-dev-agent 憲法テンプレートにおける昇格トリップワイヤーの unmanned 写像と、残量モード関連環境変数の配線前提

### Modified Capabilities

（なし — 憲法テンプレートを直接扱う既存 spec は存在しない）

## Impact

- `plugins/loops/templates/agent-loop-template.md` — トリップワイヤー節の追加
- `plugins/loops/skills/loops-dev-agent-install/SKILL.md` — 環境変数前提の追記
- `plugins/loops/tests/` — テスト追加
- `plugins/loops/.claude-plugin/plugin.json` — バージョン
- 前提: dev-workflow-execution-strategy / longrun-exec-model-allocation（いずれも archived 2026-07-21）
