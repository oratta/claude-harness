## Why

Fable が消費するのはターン数（会話履歴の cache 読込）であって出力ではない。実装・修正ループは 1 件で数十〜数百ターン回るため、実行役を Fable で走らせると週次枠が一気に溶ける（2026-09 の監査で W の 4 割が Fable、fork 1 本で 271 USD 換算）。一方で決める役（修正方針・最終 verify・マージ可否・設計判断）は数ターンで終わるので Fable でよい。

現在この線引きは文書（役割表・事前分類表・昇格ラダー）にしか無く、機械的な強制が無い。PR #236 で入った PreToolUse ガード `plugins/dev-workflow/scripts/agent-model-guard.sh` は `model` 未指定の spawn を拒否するが、**`model: "fable"` を明示した spawn はどの種別でも素通りする**。実際 2026-09-08 に develop の本体が「層間契約だから」を根拠に実行役の W を `model: fable` で spawn している。文書が自分で例外を作れる状態なので、線引きをガードに移す。

## What Changes

- 決める役のエージェント種別 `dev-workflow:decider` を新設する。`model: fable` かつ `tools` は読み取り専用（Read / Grep / Glob）で、Edit / Write / NotebookEdit / Bash を持たない。編集できないので実行ループが物理的に回せず、これが「Fable は実行役にならない」の機械的な保証になる
- `agent-model-guard.sh` を拡張し、Fable を指す `model`（エイリアス `fable`、完全 ID `claude-fable-*`）の `Agent` 呼び出しを、`subagent_type` が決める役の allowlist に載っているときだけ許可する。それ以外（`general-purpose` / `Explore` / `Plan` / 未指定 / 他のプラグイン種別）は deny。新規フックは作らず既存フックに足す
- **BREAKING**（運用上）: 昇格ラダーを「実行役を sonnet → opus → fable と 1 段ずつ上げる」から「失敗の原因が判断側か実行側かで、上げる相手を一方だけ決める」に置き換える。実行役の上限は opus、fable は決める役だけ
- 重要実装の事前分類表から W（実行役）の `fable` 行を無くして `opus` にし、R1 / G が要求するレビュアー（読んで判断する役）が事前分類で fable に当たるときは `subagent_type: dev-workflow:decider` で spawn すると書き換える
- `Workflow` ツール経路の `agent(prompt, {model:'fable'})` が `Agent` の PreToolUse を通るかを実測し、結果を issue #250 にコメントする（通らないなら別 issue。この change では塞がない）

## Capabilities

### New Capabilities
- `dev-workflow-decider-agent`: 決める役の種別 `dev-workflow:decider` の定義（モデル・読み取り専用ツール・入出力契約）と、Fable を既定モデルに持つエージェント定義が編集系ツールを持たないという横断規約

### Modified Capabilities
- `dev-workflow-execution-strategy`: `agent-model-guard.sh` の判定に「Fable を指す `model` は決める役の種別でだけ許可」を追加する。既存の判定（`model` 未指定の deny・`fork` の共有枠判定・定義側 model の許可・`DEV_WORKFLOW_MODEL_GUARD=off`・fail-open）は変えない。あわせて重要実装の事前分類表から実行役の `fable` 行を無くし上限を opus とする
- `dev-workflow-escalation-tripwires`: 失敗ループの昇格を「1 段ずつ Sonnet → Opus → Fable」から「決める役 / 実行役の分離ラダー」に置き換える
- `dev-workflow-develop`: `worker.md` の事前分類表を規定する要件と、役割ごとのモデルを規定する要件から W の `fable` 行を無くし、レビュアーの fable を `dev-workflow:decider` 経由に変える
- `dev-workflow-spec-review`: R1 が事前分類の `fable` 行に当たるとき、`model: fable` の `general-purpose` ではなく `dev-workflow:decider` で spawn すると規定する

## Impact

- 新規: `plugins/dev-workflow/agents/decider.md`
- 変更: `plugins/dev-workflow/scripts/agent-model-guard.sh`
- 文書（昇格ラダー）: `plugins/dev-workflow/skills/develop/SKILL.md`、`skills/develop/references/roles/worker.md`、`skills/develop/references/roles/gate-runner.md`、`skills/pr-review-gate/SKILL.md`、`templates/escalation-tripwires.md`、`rules/subagent-model-selection.md`
- 文書（事前分類表）: `skills/develop/references/roles/worker.md`（正本）、`skills/develop/SKILL.md`、`skills/develop/references/roles/spec-reviewer.md`、`skills/develop/references/roles/gate-runner.md`、`skills/pr-review-gate/SKILL.md`、`plugins/dev-workflow/README.md`
- テスト: `plugins/dev-workflow/tests/agent-model-guard.bats`（追加）、`model-escalation-policy.bats`、`develop-roles.bats`、`spec-decision-and-review.bats`、`develop-skill.bats`、`tripwire-hook.bats`（緑のまま）、Fable 定義の読み取り専用検証テスト（新規）
- バージョン: `plugins/dev-workflow/.claude-plugin/plugin.json` 2.4.1 → 2.5.0、`.claude-plugin/marketplace.json`、`CHANGELOG.md`
- この change の外（別リポ）: flatmate `docs/agent-loop.md` の実装 fable 条件と修正ラダー。プラグイン更新後の住人再起動
