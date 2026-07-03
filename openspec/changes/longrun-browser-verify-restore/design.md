# Design: longrun-browser-verify-restore

## Context

現行の `build-verify.workflow.js` は Verify フェーズで `__VERIFIER_AGENT_TYPE__`（既定 `longrun:longrun-verifier`）だけを 1 回呼び、その返り値の `verdict` で PASS/FAIL を機構判定している。ところが:

- `verifier-score.schema.json` は 4 軸（functionality / quality / completeness / ux）+ verdict を required にしている
- `longrun-verifier.md` は「静的検証（品質・完成度）担当。ブラウザ検証（機能性・UX）は longrun-browser-verifier が担当」と自己申告している
- `longrun-browser-verifier.md` は機能性・UX の 2 軸を担当すると宣言しているが、どの workflow からも呼ばれていない（orphan）

つまり静的 verifier が単独で 4 軸すべてを埋める建前になっており、functionality/ux はブラウザ実操作なしに採点される（=形骸化）か、schema required を満たすためにダミー値が入る。本 change は browser-verifier を Verify ループに正式に組み込み、2+2 分担を機構化する。

あわせて、Workflow ツール仕様の一次ソース `workflow-tool-reference.md` が run ディレクトリ側にあり配布物の外に出ているため、`plugins/longrun/references/` へ同梱する（`model-tiers.md` / `plan-interview-methodology.md` が既に置かれている実績あるディレクトリ）。

制約:
- Workflow スクリプト制約: `Date.now()` / `Math.random()` / 引数なし `new Date()` 不可、meta ピュアリテラル、ネスト 1 段まで、`agent()` は null を返しうる（null ガード必須）、`budget.total && budget.remaining()` の null ガード
- schema は外部ファイル（`schemas/*.schema.json`）を唯一のソースとする既存 GATE を維持
- モデル ID を exec.md・テンプレート・plan.md に直書きしない（`references/model-tiers.md` が唯一のソース）
- 既存の `__*_MODEL__` レンダリング規則（未指定なら `null` 既定・inherit）に browser-verifier も乗せる

## Goals / Non-Goals

**Goals:**
- browser-verifier を build-verify workflow の Verify ループへ機構的に組み込む（orphan 解消）
- 静的 2 軸 + ブラウザ 2 軸の 2+2 分担を確立し、総合 verdict = 論理積で判定
- `render-workflow.mjs` / params / exec.md へ `BROWSER_VERIFIER_AGENT_TYPE` / `BROWSER_VERIFIER_MODEL` を追加
- `workflow-tool-reference.md` を配布物内へ同梱し、参照元 3 箇所 + model-tiers.md + bats フィクスチャの `_longruns/2026-06-12` 参照を一掃

**Non-Goals:**
- orchestrator 残骸（`longrun-browser-verifier.md:102,151,188` 等の checkpoint.md/orchestrator 言及）の掃除 → **change-3 の担当**。本 change は担当宣言と workflow の整合に必要な最小限のみ触る
- longrun plugin.json version bump と marketplace.json 同期 → **change-7 の担当**
- browser-verifier のツール優先順位（Playwright MCP → claude-in-chrome）ロジック自体の変更（現行維持）
- UI を持たない run での機能性/UX 評価方針の全面設計（下記 Open Questions に論点を残す）

## Decisions

### D1: Verify ループ 1 周で静的 + ブラウザの両 verifier を呼ぶ

Verify ループの各周で、まず静的 verifier（quality/completeness）を呼び、続けて browser verifier（functionality/ux）を呼ぶ。両者の verdict を論理積して当該周の総合 verdict とする。どちらかが FAIL なら合算 findings を添えて builder に修正依頼し、次周で両者を再評価する。

- 代替案A: 静的を先に回し PASS したときだけブラウザを回す（早期打ち切り）→ ブラウザ側の FAIL 発見が遅れ、修正が 2 段階に分かれてラウンド数を浪費するため却下（両方まとめて findings を builder に渡す方がラウンド効率が良い）
- 代替案B: ブラウザverify を別 workflow フェーズに分離 → workflow ネスト 1 段制約と「Verify は 1 フェーズ」という meta.phases の単純さを崩すため却下

### D2: schema の 4 軸分担 — 「1 schema の部分返却」を第一候補、「2 schema 分割」を対抗案とする

**論点**: `verifier-score.schema.json` は 4 軸すべてを `required` にしている。2 verifier がそれぞれ 2 軸だけ返す設計にどう合わせるか。

- **候補1（推奨寄り）: 1 schema の部分返却**。`verifier-score.schema.json` の `required` を verdict のみに緩め、各 verifier は自分の 2 軸 + verdict を返す。workflow 側で 2 つの返却をマージして 4 軸を合成し、総合 verdict = 両 verdict の論理積。schema が 1 本のままで「4 軸の定義の唯一のソース」が保たれる利点。欠点は「どの軸が欠けているか」が schema 制約では強制されない（プロンプトと workflow ロジックで担保）
- **候補2: 2 schema に分割**。`static-verifier-score.schema.json`（quality/completeness/verdict）と `browser-verifier-score.schema.json`（functionality/ux/verdict）に割る。各 verifier が返す軸が schema で厳密に強制される利点。欠点は 4 軸定義が 2 ファイルに分かれ、しきい値の一覧性が下がる。既存 `verifier-score.schema.json` を参照する archive 済み成果物との名前整合も要検討

いずれを採っても spec Requirement「4 軸のハードしきい値が schema と矛盾しない」「schema は外部ファイルが唯一のソース」を満たすこと。**最終判断は builder が実装時に行い reviewer 承認を得る**（config.yaml rule）。

**確定（builder, 2026-07-03）: 候補1（1 schema の部分返却）を採用。** `verifier-score.schema.json` の `required` を `["verdict"]` へ緩和し、4 軸の property 定義・しきい値 description は保持。各 verifier は自分の 2 軸 + verdict を返し、workflow 側で 2 返却をマージして 4 軸を合成、総合 verdict = 論理積。理由: 4 軸定義の単一ソース維持・YAGNI（schema を増やさない）・可逆性（`required` 緩和のみで property 名/定義は不変）。軸欠落は agent 担当宣言 + workflow マージロジックで担保する（候補1 の既知トレードオフを許容）。詳細は `_longruns/2026-07-03_plugin-review-fixes/decisions.md#D-change2-1`。

### D3: `BROWSER_VERIFIER_AGENT_TYPE` は exec.md params で常時供給、`BROWSER_VERIFIER_MODEL` は render デフォルト null

`render-workflow.mjs` は `__*_MODEL__` サフィックスの埋め込みポイントのみ未指定時 `null` 既定にし、それ以外は未解決で die する（推測値の混入防止）。この規律を維持するため:

- `BROWSER_VERIFIER_AGENT_TYPE` は `VERIFIER_AGENT_TYPE` 等と同じく **exec.md の params 表に既定値 `longrun:longrun-browser-verifier` を明記して常時供給する**（render にハードコードのデフォルトは持たせない）
- `BROWSER_VERIFIER_MODEL` は `__*_MODEL__` 規則に自動的に乗り、params 未指定なら render が `null`（inherit）にする。旧 plan.md（モデル割り当て表なし）でも render が落ちない

### D4: schema は外部ファイルを唯一のソースとする GATE を維持

browser-verifier 用の schema（候補1 なら緩めた `verifier-score`、候補2 なら新設 2 本）も、テンプレートには `__*_SCHEMA__` 埋め込みポイント経由で外部ファイルから注入する。テンプレートやプロンプトに軸定義・しきい値を直書きしない。exec.md の既存 GATE 文言（「schema は外部ファイルを唯一のソースとし、スクリプトやプロンプトにインライン重複コピーしてはならない」）はそのまま適用され、候補2 を採る場合は params 表に新 schema の埋め込みポイントを追加する。

### D5: `workflow-tool-reference.md` は移動 + 元位置スタブ

`plugins/longrun/references/` へ移動し、元の `_longruns/2026-06-12_harness-workflow-overhaul/workflow-tool-reference.md` には「配布物内 `plugins/longrun/references/workflow-tool-reference.md` へ移動済み」を示すスタブを残す。参照元は `commands/exec.md`（Step の一次ソース記述）・`build-verify.workflow.js`（先頭コメント）・`review.workflow.js`（先頭コメント）の 3 箇所。加えて `references/model-tiers.md:19` の同 reference への参照も配布物内パスへ書き換える。

## Risks / Trade-offs

- [browser verify はブラウザ実操作に依存し、UI を持たない run（本 marketplace 自体のような Markdown/スクリプト集）では機能性/UX を実ブラウザで検証できない] → browser-verifier agent 側が「駆動対象の UI が無い場合の扱い」を判断する既存責務に委ねる。workflow は browser-verifier を呼ぶところまでを機構化し、UI 不在時の採点方針は agent の裁量（Open Questions に残す）
- [`grep -rn "_longruns/2026-06-12" plugins/` を 0 件にするため bats フィクスチャの合成ディレクトリ名 `2026-06-12_x` の変更が必要] → フィクスチャ名は reference と無関係な合成値なので、テストの意図を変えずに別日付（例 `2099-01-01_x`）へ機械置換すれば足りる。テストが検証している挙動は不変
- [`verifier-score.schema.json` の required 緩和（候補1）は、archive 済み成果物が旧 required を前提にしている場合に整合を要する] → archive は履歴として触らない方針。現行 `openspec/specs/` には未昇格のため実害は limited。reviewer 承認時に確認

## Migration Plan

1. `workflow-tool-reference.md` を移動しスタブを残す → 参照元 3 箇所 + model-tiers.md を書換 → `grep -rn "_longruns/2026-06-12" plugins/` 0 件を確認
2. schema 分担設計（D2 の候補確定）→ schema ファイル更新 → build-verify テンプレに browser-verifier ステップ追加
3. render-workflow.mjs / exec.md params 表に `BROWSER_VERIFIER_*` 追加
4. agent 定義（verifier / browser-verifier）の担当宣言を workflow と一致させる（最小限）
5. bats: Verify ステップの静的検証追加 + `_longruns/2026-06-12*` フィクスチャ掃除
6. `render-workflow.mjs` でレンダリングし `node --check` PASS を確認

ロールバック: 本 change は独立 change。マージ前なら worktree ごと破棄で復元可能。

## Open Questions

- **D2 の schema 分担（候補1: 部分返却 / 候補2: 2 分割）の最終確定** — builder が実装時に決定し reviewer 承認を得る（config.yaml rule 明記）
- **UI を持たない run での functionality/ux 採点方針** — browser-verifier agent が「駆動対象 UI 不在」をどう verdict へ反映するか（自動 PASS / N/A スコア / 静的フォールバック）。本 change のスコープでは agent 裁量に委ね、必要なら別 finding として起票
