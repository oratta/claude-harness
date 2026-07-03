# Proposal: longrun-browser-verify-restore — Verify 4 軸評価の復活と一次ソース reference の同梱化

## Why

`longrun-browser-verifier` agent は「機能性・UX」の 2 軸を担当すると宣言しているが、`build-verify.workflow.js` のどの実行経路からも呼ばれておらず orphan 化している。結果、Verify フェーズは `longrun-verifier`（静的・品質/完成度）だけが走り、`verifier-score` schema が要求する 4 軸（functionality/quality/completeness/ux）と `functionality=100 / ux>=70` のハードしきい値が実際には誰も検証しないまま PASS 判定される構造になっている。あわせて、Workflow ツール仕様の一次ソース `workflow-tool-reference.md` が配布物の外（`_longruns/2026-06-12_harness-workflow-overhaul/`）にあり、archive・plugin 更新で消えると exec.md / 両 workflow テンプレの参照が切れる。

## What Changes

- `templates/workflow/build-verify.workflow.js` の Verify ループに `longrun-browser-verifier` を呼ぶステップを追加し、**静的 2 軸（quality / completeness）+ ブラウザ 2 軸（functionality / ux）の 2+2 分担**を機構化する。各 verifier は自分の 2 軸だけを採点し、Verify の総合 verdict は両者の verdict の論理積とする
- `scripts/render-workflow.mjs` / `params.json` / `exec.md` の埋め込みポイントに `BROWSER_VERIFIER_AGENT_TYPE`（既定 `longrun:longrun-browser-verifier`）と `BROWSER_VERIFIER_MODEL` を追加する。`BROWSER_VERIFIER_MODEL` は既存の `__*_MODEL__` 系と同じく未指定なら render が `null`（inherit）既定値にする
- `verifier-score.schema.json` の 4 軸を 2 verifier で分担する具体設計（2 分割 or 1 schema の部分返却）を確定する。schema は外部ファイル（`schemas/*.schema.json`）を唯一のソースとする既存 GATE を維持し、インライン重複コピーはしない
- `longrun-verifier.md` / `longrun-browser-verifier.md` の担当宣言（2 軸ずつ）と workflow の呼び分けを一致させ、二重評価・評価漏れをなくす
- `workflow-tool-reference.md` を `_longruns/2026-06-12_harness-workflow-overhaul/` から `plugins/longrun/references/` へ移動し、`commands/exec.md` / `build-verify.workflow.js` / `review.workflow.js` の 3 箇所の参照を `${CLAUDE_PLUGIN_ROOT}/references/...` に書き換える。元の run ディレクトリには移動先を示すスタブを残す。`references/model-tiers.md` の同 reference への参照と bats フィクスチャ内の `_longruns/2026-06-12*` 文字列も掃除し、`grep -rn "_longruns/2026-06-12" plugins/` が 0 件になる状態にする

## Capabilities

### New Capabilities
- `longrun-browser-verify-step`: build-verify workflow の Verify フェーズに browser-verifier を組み込み、静的 2 軸 + ブラウザ 2 軸の 2+2 分担を機構化する。render-workflow.mjs / params / exec.md への `BROWSER_VERIFIER_AGENT_TYPE` / `BROWSER_VERIFIER_MODEL` 埋め込みポイント追加、schema の 4 軸分担、agent 定義との整合、レンダリング後の `node --check` PASS を含む
- `longrun-workflow-reference-bundle`: Workflow ツール仕様の一次ソース `workflow-tool-reference.md` を配布物内（`plugins/longrun/references/`）へ移動し、参照元 3 箇所を `${CLAUDE_PLUGIN_ROOT}/references/` に書き換え、元 run ディレクトリにスタブを残す。`_longruns/2026-06-12` への参照が `plugins/` 配下から 0 件になる状態の保証を含む

### Modified Capabilities

（なし — `openspec/specs/` 配下に本 change が対象とする既存 capability は存在しない。verifier-score / build-verify 関連は archive 済み change の成果物であり、現行 `openspec/specs/` には未昇格）

## Impact

- **書き換え**: `plugins/longrun/templates/workflow/build-verify.workflow.js`（Verify ループに browser-verifier ステップ追加）、`plugins/longrun/scripts/render-workflow.mjs`（埋め込みポイント文書とデフォルト規則の追記）、`plugins/longrun/commands/exec.md`（params 表に BROWSER_VERIFIER_* 追加 + reference パス書換）
- **移動**: `_longruns/2026-06-12_harness-workflow-overhaul/workflow-tool-reference.md` → `plugins/longrun/references/workflow-tool-reference.md`（元パスに移動先スタブを残す）
- **修正**: `plugins/longrun/templates/workflow/review.workflow.js`（reference パス書換）、`plugins/longrun/references/model-tiers.md`（reference パス書換）、`plugins/longrun/agents/longrun-verifier.md` / `longrun-browser-verifier.md`（担当宣言と workflow の整合。orchestrator 残骸の掃除は change-3 が担当）、`plugins/longrun/tests/*.bats`（`_longruns/2026-06-12*` フィクスチャ名の掃除と Verify ステップ静的検証の追随）
- **schema**: `plugins/longrun/schemas/verifier-score.schema.json`（4 軸分担の設計次第で分割 or 部分返却対応。最終形は builder 設計 + reviewer 承認）
- **依存**: 独立（change-2）。ただし exec.md / README / plugin.json は change-3 とも触れ合うため、マージ順の直列化は change-3 側の dependsOn で担保される
- **version**: longrun の plugin.json version bump は change-7 の最終同期で marketplace.json と揃える（本 change は version/description の最終同期に手を出さない）
