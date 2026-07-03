# Tasks: longrun-browser-verify-restore

> **実装規律**: Workflow ツール仕様の一次ソースは `plugins/longrun/references/workflow-tool-reference.md`（本 change でここへ移動する）。記憶・推測でシグネチャを書かない。schema は `plugins/longrun/schemas/*.schema.json` を唯一のソースとし、テンプレート・プロンプトへ軸定義やしきい値をインライン重複コピーしない。

## 1. 一次ソース reference の配布物内同梱（付録 B-2）

- [x] 1.1 `_longruns/2026-06-12_harness-workflow-overhaul/workflow-tool-reference.md` を `plugins/longrun/references/workflow-tool-reference.md` へ移動する（内容は等価）
- [x] 1.2 移動元パスに「配布物内 `plugins/longrun/references/workflow-tool-reference.md` へ移動済み」を示すスタブを残す
- [x] 1.3 `commands/exec.md` の一次ソース参照（:16-17 付近）を `${CLAUDE_PLUGIN_ROOT}/references/workflow-tool-reference.md` へ書き換える
- [x] 1.4 `templates/workflow/build-verify.workflow.js` 先頭コメント（:7）の参照を配布物内パスへ書き換える
- [x] 1.5 `templates/workflow/review.workflow.js` 先頭コメント（:7）の参照を配布物内パスへ書き換える
- [x] 1.6 `references/model-tiers.md`（:19）の同 reference への参照を配布物内パスへ書き換える
- [x] 1.7 `tests/*.bats` の合成フィクスチャ名 `_longruns/2026-06-12*`（degraded-artifacts.bats / feedback-backlog-fallback.bats）をテスト意図を変えずに別日付へ置換する
- [x] 1.8 `grep -rn "_longruns/2026-06-12" plugins/` が 0 件になることを確認する

## 2. schema の 4 軸分担設計の確定（付録 B-1）

- [x] 2.1 D2 の候補（1: `verifier-score.schema.json` の部分返却 / 2: 静的・ブラウザの 2 schema 分割）を builder が確定し、判断根拠を decisions.md に記録して reviewer 承認を得る
- [x] 2.2 確定した設計に沿って `schemas/verifier-score.schema.json`（候補1）または新 schema ファイル（候補2）を更新する。schema は外部ファイルを唯一のソースとし、4 軸のしきい値（functionality=100 / quality=100 / completeness>=80 / ux>=70）を保つ
- [x] 2.3 `jq . plugins/longrun/schemas/*.schema.json` の構文検証が通ることを確認する

## 3. build-verify workflow への browser-verifier ステップ追加（付録 B-1）

- [x] 3.1 `templates/workflow/build-verify.workflow.js` の Verify ループに `longrun-browser-verifier` を呼ぶ `agent()` を追加し、静的 verifier（quality/completeness）+ browser verifier（functionality/ux）の 2+2 分担にする
- [x] 3.2 当該周の総合 verdict を両 verifier の verdict の論理積とし、FAIL 時は合算 findings を builder へ渡す制御にする（`agent()` の null ガード・`budget.total && budget.remaining()` の null ガードを維持）
- [x] 3.3 埋め込みポイント `__BROWSER_VERIFIER_AGENT_TYPE__` / `__BROWSER_VERIFIER_MODEL__` と（候補2 の場合）browser 用 `__*_SCHEMA__` をテンプレートに追加する。`__BROWSER_VERIFIER_MODEL__` は条件付きスプレッドで null 時に `model` キーを出力しない形にする
- [x] 3.4 テンプレート先頭コメントの埋め込みポイント一覧と `meta.description` を 2+2 分担の実態に更新する

## 4. render-workflow.mjs / exec.md の埋め込みポイント追加（付録 B-1）

- [x] 4.1 `scripts/render-workflow.mjs` のヘッダコメント（params.json 例）に `BROWSER_VERIFIER_AGENT_TYPE` を追記する（`__*_MODEL__` の null 既定規則は既存のまま `BROWSER_VERIFIER_MODEL` に適用される）
- [x] 4.2 `commands/exec.md` Step 2 の params 表に `BROWSER_VERIFIER_AGENT_TYPE`（既定 `longrun:longrun-browser-verifier`）と `BROWSER_VERIFIER_MODEL` の行を追加する
- [x] 4.3 exec.md の Step 4（Build → Verify 起動）記述を、Verify フェーズが静的 + ブラウザの 2 verifier で 4 軸を分担する実態に更新する（モデル ID の直書きはしない）

## 5. agent 定義と workflow の整合（付録 B-1）

- [x] 5.1 `agents/longrun-verifier.md` の担当宣言が静的 2 軸（quality/completeness）、`agents/longrun-browser-verifier.md` がブラウザ 2 軸（functionality/ux）であることを確認し、workflow の呼び分けと一致させる（orchestrator 残骸の掃除は change-3 の担当なので触らない）
- [x] 5.2 4 軸がちょうど一方の verifier に割り当てられ、二重評価・評価漏れが無いことを確認する

## 6. 静的検証と bats 追随

- [x] 6.1 `render-workflow.mjs` で build-verify テンプレートをレンダリングし、生成 `.js` が `node --check` PASS することを確認する
- [x] 6.2 レンダリング済み workflow が Workflow ツール制約（Date.now/Math.random/argless new Date 不使用・meta ピュアリテラル・ネスト 1 段）に違反しないことを bats で検証する
- [x] 6.3 Verify ステップに browser-verifier 呼び出しが含まれること、`BROWSER_VERIFIER_MODEL` 未指定でも render が落ちず null 化されること、`BROWSER_VERIFIER_MODEL` null 時に model キーが出ないことを bats で検証する
- [x] 6.4 `find plugins -name '*.bats' -print0 | xargs -0 bats` が PASS することを確認する
