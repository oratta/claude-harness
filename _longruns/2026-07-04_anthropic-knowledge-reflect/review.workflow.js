// review.workflow.js — longrun Review フェーズ workflow（テンプレート）
//
// exec コマンドが plan.md の Changes 分解から具体値を埋めてこのテンプレートを生成し、
// Workflow ツールで起動する。本ファイルは「埋め込みポイントを ${...} で示した骨格」であり、
// 生成後のスクリプトは plain JavaScript（型注釈なし）になる。
//
// === Workflow ツール制約（plugins/longrun/references/workflow-tool-reference.md を一次ソースとする）===
//   - JavaScript のみ。Date.now() / Math.random() / 引数なし new Date() は throw する
//     → タイムスタンプは args.timestamp で注入する
//   - meta はピュアリテラル（変数・関数・スプレッド・テンプレート補間 不可）
//   - workflow() ネストは 1 段まで。承認ゲートはメインループに戻して分割する（このファイルは Review 単体）
//   - agent(prompt, {schema}) で StructuredOutput を強制（不適合はツール層が拒否しモデルがリトライ）
//
// 埋め込みポイント（exec が置換する）:
//   /Users/oratta/orca/workspaces/oratta-claude-harness/anthropic論文をハーネスに反映/_longruns/2026-07-04_anthropic-knowledge-reflect/plan.md            plan.md の絶対パス
//   /Users/oratta/orca/workspaces/oratta-claude-harness/anthropic論文をハーネスに反映         プロジェクトルート（cwd）
//   {"$schema":"http://json-schema.org/draft-07/schema#","title":"reviewer-verdict","description":"longrun-reviewer の Build Contract / Spec Review 判定。Workflow スクリプトの Review フェーズが status で承認ゲート分岐を機構判定する。","type":"object","additionalProperties":false,"required":["status","findings"],"properties":{"status":{"type":"string","enum":["APPROVE","REQUEST_CHANGES"],"description":"BLOCKER 0 なら APPROVE、1 件以上なら REQUEST_CHANGES"},"findings":{"type":"array","description":"指摘事項。APPROVE 時は空配列または NOTE のみ","items":{"type":"object","additionalProperties":false,"required":["severity","message"],"properties":{"severity":{"type":"string","enum":["BLOCKER","SHOULD_FIX","NOTE"]},"message":{"type":"string"}}}},"summary":{"type":"string","description":"判定の総括（任意）"}}}      reviewer-verdict.schema.json の中身（インライン JSON オブジェクト）
//   longrun:longrun-reviewer  既定 'longrun:longrun-reviewer'
//   null       reviewer の opts.model 値（エイリアス文字列リテラル 'sonnet' 等、または null）
//                            null のときは下の条件付きスプレッドで model キー自体を出力しない（inherit, change-4 D2）。
//                            ティア → エイリアス値の解決は plugins/longrun/references/model-tiers.md（1 箇所集約）。

export const meta = {
  name: 'longrun-review',
  description: 'longrun Review フェーズ: plan.md の Changes 分解を longrun-reviewer で Build Contract レビューし、判定 JSON を返す',
  phases: [
    { title: 'Review', detail: 'Build Contract レビュー（reviewer-verdict schema 強制）' },
  ],
};

phase('Review');

const reviewerSchema = {"$schema":"http://json-schema.org/draft-07/schema#","title":"reviewer-verdict","description":"longrun-reviewer の Build Contract / Spec Review 判定。Workflow スクリプトの Review フェーズが status で承認ゲート分岐を機構判定する。","type":"object","additionalProperties":false,"required":["status","findings"],"properties":{"status":{"type":"string","enum":["APPROVE","REQUEST_CHANGES"],"description":"BLOCKER 0 なら APPROVE、1 件以上なら REQUEST_CHANGES"},"findings":{"type":"array","description":"指摘事項。APPROVE 時は空配列または NOTE のみ","items":{"type":"object","additionalProperties":false,"required":["severity","message"],"properties":{"severity":{"type":"string","enum":["BLOCKER","SHOULD_FIX","NOTE"]},"message":{"type":"string"}}}},"summary":{"type":"string","description":"判定の総括（任意）"}}};

// モデル割り当て（change-4）。エイリアス文字列 or null。null は inherit = opts.model を渡さない（D2）。
const reviewerModel = null;

// reviewer 判定を StructuredOutput で強制する。散文 STATUS パースは行わない。
const verdict = await agent(
  `Build Contract レビュー: /Users/oratta/orca/workspaces/oratta-claude-harness/anthropic論文をハーネスに反映/_longruns/2026-07-04_anthropic-knowledge-reflect/plan.md の Changes 分解を評価してください。` +
  `プロジェクトルートは /Users/oratta/orca/workspaces/oratta-claude-harness/anthropic論文をハーネスに反映 です。` +
  `各 change の実装計画の現実性・技術リスク・依存順序・スコープ適切性を評価し、` +
  `BLOCKER が 0 件なら status=APPROVE、1 件以上なら status=REQUEST_CHANGES として findings に列挙してください。`,
  {
    label: 'Build Contract review',
    phase: 'Review',
    agentType: 'longrun:longrun-reviewer',
    schema: reviewerSchema,
    ...(reviewerModel ? { model: reviewerModel } : {}),
  }
);

log(`Review verdict: ${verdict ? verdict.status : 'null'} (timestamp=${args.timestamp})`);

// 承認ゲート: メインループが verdict.status を見て AskUserQuestion で承認を取り、
// APPROVE なら build.workflow.js を起動する（このファイルは Review で完了する）。
return {
  phase: 'Review',
  verdict,
  timestamp: args.timestamp,
};
