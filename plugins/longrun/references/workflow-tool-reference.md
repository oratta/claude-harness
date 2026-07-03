# Workflow Tool Reference（実機検証済み）

change-2 (workflow-exec) の実装一次ソース。**ここに書かれていないシグネチャ・挙動を推測で使ってはならない。** 未記載の挙動が必要になったら、追加プローブで検証してから本ファイルに追記すること。

- 検証日: 2026-06-12
- 検証方法: hello-world プローブ workflow を実機起動（runId: `wf_b289e06d-75b`）+ 同 runId での resume 再実行
- 各項目に「実機検証」または「組み込みドキュメント由来（未実機）」を明記

## 1. 起動と返却（実機検証）

Workflow ツール呼び出しは**即座に Task ID を返してバックグラウンド実行**される。完了時に `<task-notification>` がメインループに届く。

- 入力: `script`（インライン）または `scriptPath`。`args` は任意の JSON 値（文字列化しない）
- 起動時の返却情報: Task ID / Run ID / Script file パス（自動永続化される）/ Transcript dir
- 完了通知の `<result>` には **スクリプトの `return` 値が JSON でそのまま入る**

エビデンス（初回実行の result）:
```json
{"plain":"PROBE_OK","structured":{"status":"APPROVE","score":95,"findings":["none"]},"piped":["7","15"],"par":["ALPHA","BETA"],"budgetTotal":null,"spentSoFar":440311,"argsEcho":{"probeTimestamp":"2026-06-12T14:00:00+09:00","purpose":"change-2 workflow-tool-reference"}}
```

## 2. meta ブロック（実機検証）

```js
export const meta = {
  name: 'hello-world-probe',                 // 必須
  description: '...',                        // 必須（権限ダイアログに表示）
  phases: [{ title: 'Probe', detail: '...' }], // 任意。phase() と同名タイトルで進捗グループ化
}
```

- **ピュアリテラル必須**（変数・関数呼び出し・スプレッド・テンプレート補間は不可）→ 違反時はパースエラー（組み込みドキュメント由来、プローブでは正常系のみ確認）
- `phases[].model` でフェーズ単位のモデル表記も可（組み込みドキュメント由来・未実機）

## 3. agent()（実機検証）

```js
const text = await agent(prompt)                          // → 最終テキストが string で返る
const obj  = await agent(prompt, { schema: JSON_SCHEMA }) // → 検証済みオブジェクトが返る
```

検証済み opts:
- `label`: 進捗表示用ラベル（実機検証）
- `model`: `'haiku'` を指定して動作確認（実機検証）。`'sonnet' | 'opus' | inherit(省略)` も同じ機構（組み込みドキュメント由来）。**省略時はメインループのモデルを継承**
- `schema`: JSON Schema を渡すと StructuredOutput が強制され、**検証済みオブジェクト**が返る（実機検証: `{type:'object', properties:{status:{enum:[...]}, score:{type:'number'}, findings:{type:'array'}}, required:[...], additionalProperties:false}` で期待どおりの型付きオブジェクトを受領）。検証はツール呼び出し層で行われ、不適合時はモデルがリトライする（組み込みドキュメント由来）
- `phase`: 進捗グループの明示割り当て。pipeline/parallel 内では race 防止のため明示推奨（実機検証: `phase: 'Probe'` で同一グループに収容）
- `agentType`: `'longrun:longrun-builder'` 等のカスタム agent 定義を参照可能（組み込みドキュメント由来・**未実機**。change-2 実装時に最初の本番 workflow で確認し本ファイルに追記すること）
- `isolation: 'worktree'`: git worktree 分離（組み込みドキュメント由来・未実機。セットアップコスト ~200-500ms/agent）
- 返り値が `null` になるケース: ユーザーによるスキップ / 終端 API エラー（組み込みドキュメント由来）→ `.filter(Boolean)` ガード推奨

## 4. pipeline() / parallel()（実機検証）

```js
// pipeline: 各 item が全 stage を独立に流れる（stage 間バリアなし）
const piped = await pipeline(
  [3, 7],
  (item, orig, idx) => agent(`...${item}...`, {...}),       // stage1
  (prev, orig, idx) => agent(`...${prev}...`, {...})        // stage2: 前 stage の戻り値が第1引数
)
// 実機結果: [3,7] → x2 → +1 → ["7","15"]（型は string。agent の返却は常にテキスト）

// parallel: thunk 配列。全件完了までバリア
const par = await parallel([
  () => agent('...'),
  () => agent('...'),
])
// 実機結果: ["ALPHA","BETA"]（投入順を保持）
```

- 注意: **agent() のテキスト返却は string**。数値が欲しい場合も string で返るため、後段で `Number()` / `String(prev).trim()` の変換が必要（実機で確認）
- parallel の thunk が throw すると該当要素は `null`（組み込みドキュメント由来）
- 同時実行は min(16, cores-2) でキャップ、超過分はキュー（組み込みドキュメント由来）

## 5. resumeFromRunId（実機検証）

```js
Workflow({ scriptPath: "<永続化されたスクリプトパス>", resumeFromRunId: "wf_b289e06d-75b" })
```

実機エビデンス:
| 指標 | 初回実行 | resume 実行 |
|------|---------|------------|
| duration | 16,326 ms | **3,537 ms** |
| tool_uses | 2 | **0** |
| 結果 | 上記 JSON | **完全一致**（spentSoFar のみ 440311→443338 と微増 = 共有プールの最新値） |

- スクリプト・args が同一なら **全 agent() がキャッシュヒット**し、即座に同一結果を返す
- 編集した場合は「最長一致プレフィックス」までキャッシュ、以降は live 実行（組み込みドキュメント由来）
- **change-2 の resume 設計はこの機構をそのまま使える**: runId を `_longruns/<run>/` に記録 → 中断後に同 scriptPath + resumeFromRunId で再起動 → 完了済み change の builder は再実行されない（受け入れ条件 10 の実装根拠）
- 制約: same-session only（組み込みドキュメント由来）。**セッションをまたぐ resume は不可** → runId 記録に加えて checkpoint.md（人間向け）での進行記録が引き続き必要

## 6. budget / args / log / phase（実機検証）

- `args`: Workflow 呼び出しの `args` がそのまま script グローバルに注入される（実機: オブジェクトが verbatim でエコーバックされた）。**タイムスタンプは args で注入する**（Date.now() 禁止のため）
- `budget.total`: 「+500k」系のトークン指示が無いセッションでは **null**（実機確認）。`budget.remaining()` は total が null なら Infinity → **`while (budget.total && budget.remaining() > N)` のように必ず total の null ガードを入れる**（無ガードだと 1000 agent キャップまで走る）
- `budget.spent()`: メインループ + 全 workflow の**共有プール**の消費値（実機: プローブ自体は軽量なのに 440k を返した = 並行中の builder agent の消費を含む）
- `log(message)`: 進捗ナレーター行（実機で `args received: ...` を出力）
- `phase(title)`: 以降の agent() を進捗グループ化（実機検証）

## 7. スクリプト言語制約（組み込みドキュメント由来）

- **JavaScript のみ**（TypeScript 型注釈・interface・ジェネリクスはパースエラー）
- **`Date.now()` / `Math.random()` / 引数なし `new Date()` は throw する**（resume 再現性のため）→ タイムスタンプは args 注入、乱数はプロンプト/ラベルを index で変える
- ファイルシステム・Node.js API へのアクセス不可
- `workflow()` ネストは 1 段まで。子の中で workflow() を呼ぶと throw
- script body は async コンテキスト（トップレベル await 可、実機検証）
- 1 回の pipeline/parallel に渡せる item は最大 4096。workflow 生涯 agent 数キャップ 1000

## 8. ユーザー対話の境界（組み込みドキュメント由来 + 設計判断）

- workflow 内の agent から AskUserQuestion は**使えない**（subagent 全般の制約）
- → change-2 設計どおり、Build Contract 承認ゲート / Feedback Tier 確認は **workflow を分割してメインループに戻り AskUserQuestion → 次の workflow を起動**する
- Workflow 起動の opt-in: 「ユーザーが起動した slash command の指示で呼ぶ」場合は追加確認不要（`/lr:e` はこれに該当）

## 9. change-2 実装への適用メモ

- Verify ループ: `while (round < 3)` + `budget.total && budget.remaining()` ガード（§6 の null ガード必須）
- 4 軸スコア / builder レポート / reviewer 判定は §3 の `schema` opts で強制（schema は `plugins/longrun/schemas/*.schema.json` に外部化し、exec が読み込んで埋め込む）
- runId は起動応答から取得して `_longruns/<run>/` に記録（§5）
- agentType による既存 agent 再利用（`longrun:longrun-builder` 等）は**未実機**のため、生成 workflow の最初の実行時に必ず動作確認し、結果を本ファイルに追記すること

## 10. change-2 実装後メモ（builder による静的実装）

- change-2 のテンプレート実装は本 reference §1〜§9 の確定事項のみを使用した（記憶・推測でのシグネチャ追加なし）。具体的には: `agent(prompt, {label, phase, agentType, schema})`（§3）、`pipeline`/`parallel` は未使用（Build は逐次 for ループ）、`budget.total && budget.remaining()` の null ガード（§6）、`args.timestamp` 注入（§6・§7）、meta ピュアリテラル（§2）、ネスト 1 段（§7）、`resumeFromRunId` + runId 記録（§5）。
- ~~未実機のまま残る確認項目~~ → **全て実走確認済み（2026-06-12、下記 §11）**

## 11. 実走確認結果（orchestrator による最小 fixture 実走、2026-06-12）

テンプレート実体化（プレースホルダ手動充填）で review → build-verify を実走し、未実機項目を全て確定した。

| 項目 | 結果 | エビデンス |
|------|------|-----------|
| `agentType: 'longrun:longrun-reviewer'` の解決 | **OK** | review workflow（runId `wf_b0263fa2-2fe`、23s）が APPROVE + findings(NOTE 2件) の型付き JSON を返却 |
| `agentType: 'longrun:longrun-builder'` の解決 | **OK** | build-verify workflow（runId `wf_a36f47ee-baf`）で builder が /tmp/fixture-hello に hello.sh + tests/hello.bats を TDD 実装、commit `95b6e23`、bats 1/1 PASS |
| `agentType: 'longrun:longrun-verifier'` の解決 | **OK** | verifier が 4 軸スコア {functionality:100, quality:100, completeness:90, ux:80, verdict:"PASS"} を schema どおり返却 |
| インライン展開した外部 schema での StructuredOutput 強制 | **OK** | reviewer-verdict / builder-report / verifier-score の 3 schema とも required キー完備・enum 遵守のオブジェクトを受領 |
| Verify ループの機構判定 | **OK** | round 1 で verdict=PASS → `stopReason: 'PASS'` で break。`verify.rounds: 1, maxRounds: 3, passed: true` |
| resume（受け入れ条件 10 / S17） | **OK** | 同 scriptPath + `resumeFromRunId: wf_a36f47ee-baf` で再実行 → **3ms / subagent_tokens 0 / tool_uses 0**、builds[].report 完全一致 = builder 再実行なし |

- 残る未実機: `isolation: 'worktree'`（本テンプレートでは未使用のため不要）、`pipeline`/`parallel` のテンプレート内使用（Build は逐次 for ループ採用のため不要）
- fixture サンドボックス: `/tmp/longrun-fixture-run/`（plan.md）+ `/tmp/fixture-hello/`（git repo、builder 成果物 commit 95b6e23）
- 生成テンプレートの静的検証（禁止 API 不使用・meta ピュアリテラル・Verify 上限 3・schema インライン・ネスト 1 段・`node --check`）は `plugins/longrun/tests/workflow-template.bats`（20 本）で機械化済み。schema 不適合の拒否は `plugins/longrun/tests/schema-rejection.bats`（11 本）で機械化済み。
