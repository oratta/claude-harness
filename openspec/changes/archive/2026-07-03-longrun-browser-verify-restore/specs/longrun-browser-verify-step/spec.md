# longrun-browser-verify-step — Verify フェーズへの browser-verifier 復帰と 2+2 軸分担

## ADDED Requirements

### Requirement: build-verify workflow の Verify ループが browser-verifier を呼ぶ
`templates/workflow/build-verify.workflow.js` の Verify フェーズは、`longrun-verifier`（静的）に加えて `longrun-browser-verifier`（ブラウザ）を呼び出さなければならない（MUST）。静的 verifier は quality / completeness の 2 軸を、browser verifier は functionality / ux の 2 軸を採点し、Verify ループの総合 verdict は両 verifier の verdict の論理積（両方 PASS のときのみ PASS）でなければならない（MUST）。browser-verifier がどの実行経路からも呼ばれない orphan 状態を残してはならない（MUST NOT）。

#### Scenario: Verify フェーズが静的とブラウザの両 verifier を起動する
- **WHEN** レンダリング済みの build-verify workflow の Verify フェーズが 1 周実行される
- **THEN** `agentType` が browser-verifier 埋め込みポイントの値（既定 `longrun:longrun-browser-verifier`）である `agent()` 呼び出しが存在する
- **THEN** `agentType` が静的 verifier（既定 `longrun:longrun-verifier`）である `agent()` 呼び出しも同じ Verify フェーズ内に存在する

#### Scenario: 総合 verdict は両 verifier の論理積である
- **WHEN** 静的 verifier または browser verifier のいずれかが FAIL を返す
- **THEN** Verify ループの当該周の総合判定は FAIL となり、builder への修正依頼へ進む
- **WHEN** 静的 verifier と browser verifier の両方が PASS を返す
- **THEN** Verify ループは `stopReason=PASS` で停止する

### Requirement: 4 軸のハードしきい値判定が verifier-score schema と矛盾しない
Verify ステップが適用するハードしきい値は `schemas/verifier-score.schema.json` の記述と一致しなければならない（MUST）: functionality=100（ブラウザ）、quality=100（静的）、completeness>=80（静的）、ux>=70（ブラウザ）。schema は外部ファイル（`schemas/*.schema.json`）を唯一のソースとし、workflow スクリプトやプロンプトに軸定義・しきい値をインライン重複コピーしてはならない（MUST NOT）。4 軸を 2 verifier に分担する具体形（schema の 2 分割 or 1 schema の部分返却）は、いずれを採っても schema が定義する 4 軸・しきい値と矛盾しないこと（MUST）。

#### Scenario: workflow のしきい値が schema の description と一致する
- **WHEN** build-verify workflow のしきい値記述（functionality=100 / quality=100 / completeness>=80 / ux>=70）と `verifier-score.schema.json` の各軸 description のしきい値を突き合わせる
- **THEN** 4 軸すべてでしきい値が一致する

#### Scenario: schema が外部ファイルを唯一のソースとする GATE が維持される
- **WHEN** レンダリング前のテンプレート（build-verify.workflow.js）と `schemas/verifier-score.schema.json` を確認する
- **THEN** schema 本体（プロパティ定義）はテンプレートに直書きされておらず、`__VERIFIER_SCHEMA__` 等の埋め込みポイント経由で外部ファイルから注入されている

### Requirement: render-workflow.mjs / params / exec.md に browser-verifier 埋め込みポイントを追加する
`scripts/render-workflow.mjs`・`build-verify.workflow.js` テンプレート・`commands/exec.md` の params 表は、`BROWSER_VERIFIER_AGENT_TYPE`（既定 `longrun:longrun-browser-verifier`）と `BROWSER_VERIFIER_MODEL` の埋め込みポイントを備えなければならない（MUST）。`BROWSER_VERIFIER_MODEL` は既存の `__*_MODEL__` 系と同じく、params に未指定なら render が `null`（inherit = `opts.model` を出力しない）を既定値としなければならない（MUST）。`BROWSER_VERIFIER_MODEL` が `null` のとき、テンプレートは条件付きスプレッドで `model` キー自体を出力してはならない（MUST NOT）。

#### Scenario: BROWSER_VERIFIER_MODEL 未指定でも render が落ちない
- **WHEN** `BROWSER_VERIFIER_MODEL` を含まない params.json で `render-workflow.mjs` に build-verify テンプレートを渡す
- **THEN** render はエラー終了せず、`__BROWSER_VERIFIER_MODEL__` が `null` に置換された出力を生成する

#### Scenario: BROWSER_VERIFIER_MODEL が null のとき model キーを出力しない
- **WHEN** `BROWSER_VERIFIER_MODEL` が `null` でレンダリングされた build-verify workflow の browser-verifier の `agent()` 呼び出しを確認する
- **THEN** その `opts` に `model` キーが含まれていない

#### Scenario: exec.md の params 表に browser-verifier 埋め込みポイントが記載されている
- **WHEN** `commands/exec.md` の Step 2 params 表を確認する
- **THEN** `BROWSER_VERIFIER_AGENT_TYPE`（既定 `longrun:longrun-browser-verifier`）と `BROWSER_VERIFIER_MODEL` の行が存在する

### Requirement: レンダリング後の workflow が node --check を通過する
`render-workflow.mjs` で build-verify テンプレートをレンダリングした出力は、`node --check` の構文検証を通過しなければならない（MUST）。Workflow ツール制約（`Date.now()` / `Math.random()` / 引数なし `new Date()` 不使用、meta ピュアリテラル、ネスト 1 段まで）に違反してはならない（MUST NOT）。

#### Scenario: レンダリング済み build-verify workflow が node --check PASS する
- **WHEN** `render-workflow.mjs` で build-verify テンプレートをレンダリングし、生成された `.js` に `node --check` を実行する
- **THEN** 構文エラーなく終了コード 0 で完了する

### Requirement: agent 定義の担当宣言が workflow の呼び分けと整合する
`agents/longrun-verifier.md` は自分の担当を静的 2 軸（quality / completeness）と宣言し、`agents/longrun-browser-verifier.md` はブラウザ 2 軸（functionality / ux）を宣言していなければならない（MUST）。workflow の Verify ステップは各 agent をその宣言どおりの軸で呼び出し、同一軸を両 agent に二重評価させてはならない（MUST NOT）。どの軸も少なくとも一方の verifier が評価する状態でなければならない（MUST）。

#### Scenario: 4 軸が漏れなく重複なく 2 verifier に割り当てられている
- **WHEN** `longrun-verifier.md` / `longrun-browser-verifier.md` の担当宣言と workflow の各 verifier 呼び出しの採点対象軸を突き合わせる
- **THEN** quality / completeness は静的 verifier のみ、functionality / ux は browser verifier のみが担当し、4 軸すべてがちょうど一方に割り当てられている
