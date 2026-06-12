// review.workflow.js — longrun Review フェーズ workflow（テンプレート）
//
// exec コマンドが plan.md の Changes 分解から具体値を埋めてこのテンプレートを生成し、
// Workflow ツールで起動する。本ファイルは「埋め込みポイントを ${...} で示した骨格」であり、
// 生成後のスクリプトは plain JavaScript（型注釈なし）になる。
//
// === Workflow ツール制約（_longruns/<run>/workflow-tool-reference.md を一次ソースとする）===
//   - JavaScript のみ。Date.now() / Math.random() / 引数なし new Date() は throw する
//     → タイムスタンプは args.timestamp で注入する
//   - meta はピュアリテラル（変数・関数・スプレッド・テンプレート補間 不可）
//   - workflow() ネストは 1 段まで。承認ゲートはメインループに戻して分割する（このファイルは Review 単体）
//   - agent(prompt, {schema}) で StructuredOutput を強制（不適合はツール層が拒否しモデルがリトライ）
//
// 埋め込みポイント（exec が置換する）:
//   __PLAN_PATH__            plan.md の絶対パス
//   __PROJECT_ROOT__         プロジェクトルート（cwd）
//   __REVIEWER_SCHEMA__      reviewer-verdict.schema.json の中身（インライン JSON オブジェクト）
//   __REVIEWER_AGENT_TYPE__  既定 'longrun:longrun-reviewer'
//   __REVIEWER_MODEL__       reviewer の opts.model 値（エイリアス文字列リテラル 'sonnet' 等、または null）
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

const reviewerSchema = __REVIEWER_SCHEMA__;

// モデル割り当て（change-4）。エイリアス文字列 or null。null は inherit = opts.model を渡さない（D2）。
const reviewerModel = __REVIEWER_MODEL__;

// reviewer 判定を StructuredOutput で強制する。散文 STATUS パースは行わない。
const verdict = await agent(
  `Build Contract レビュー: __PLAN_PATH__ の Changes 分解を評価してください。` +
  `プロジェクトルートは __PROJECT_ROOT__ です。` +
  `各 change の実装計画の現実性・技術リスク・依存順序・スコープ適切性を評価し、` +
  `BLOCKER が 0 件なら status=APPROVE、1 件以上なら status=REQUEST_CHANGES として findings に列挙してください。`,
  {
    label: 'Build Contract review',
    phase: 'Review',
    agentType: '__REVIEWER_AGENT_TYPE__',
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
