// build-verify.workflow.js — longrun Build → Verify フェーズ workflow（テンプレート）
//
// exec コマンドが plan.md の Changes 分解から具体値を埋めてこのテンプレートを生成し、
// Workflow ツールで起動する。Review フェーズの verdict が APPROVE のとき（v6.4: メインループが
// decisions.md に承認記録を書いて自動続行）に起動される（D5 の分割境界。REQUEST_CHANGES 時のみ
// AskUserQuestion を挟む）。
//
// === Workflow ツール制約（plugins/longrun/references/workflow-tool-reference.md を一次ソースとする）===
//   - JavaScript のみ。Date.now() / Math.random() / 引数なし new Date() は throw する
//     → タイムスタンプは args.timestamp で注入する
//   - meta はピュアリテラル
//   - workflow() ネストは 1 段まで（このファイル内で子 workflow を起動しない）
//   - agent(prompt, {schema}) で StructuredOutput を強制
//   - budget.total は「+Nk」指示の無いセッションでは null → budget.remaining() は Infinity を返す
//     ので、必ず `budget.total && budget.remaining() > N` の null ガードを入れる（無ガードだと
//     1000 agent キャップまで走る）
//   - agent() の返り値が null になりうる（スキップ / 終端エラー）→ null ガードする
//
// 埋め込みポイント（exec が置換する）:
//   __RUN_DIR__              ランディレクトリの絶対パス（_longruns/<run>/）
//   __PROJECT_ROOT__         プロジェクトルート（cwd）
//   __CHANGES_JSON__         plan.md の Changes 分解を [{name, worktree, dependsOn:[...]}] にした配列リテラル
//   __BUILDER_AGENT_TYPE__            builder agentType。既定 'longrun:longrun-builder'（D6: パラメータ化）
//   __VERIFIER_AGENT_TYPE__           静的 verifier agentType。既定 'longrun:longrun-verifier'（quality/completeness 担当）
//   __BROWSER_VERIFIER_AGENT_TYPE__   ブラウザ verifier agentType。既定 'longrun:longrun-browser-verifier'（functionality/ux 担当。change-2）
//   __BUILDER_SCHEMA__                builder-report.schema.json の中身（インライン JSON オブジェクト）
//   __VERIFIER_SCHEMA__               verifier-score.schema.json の中身（インライン JSON オブジェクト。静的/ブラウザ両 verifier で共用 = 部分返却, change-2 D2 候補1）
//   __BUILDER_MODEL__                 builder の opts.model 値（エイリアス文字列リテラル 'sonnet' 等、または null）
//   __VERIFIER_MODEL__                静的 verifier の opts.model 値（同上）
//   __BROWSER_VERIFIER_MODEL__        ブラウザ verifier の opts.model 値（同上。change-2）
//                            *_MODEL は null のとき下の条件付きスプレッドで model キー自体を出力しない（inherit, change-4 D2）。
//                            ティア → エイリアス値の解決は plugins/longrun/references/model-tiers.md（1 箇所集約）。

export const meta = {
  name: 'longrun-build-verify',
  description: 'longrun Build → Verify フェーズ: change ごとに longrun-builder で TDD 実装し、Verify ループ（上限 3 周 + budget ガード）で静的 verifier（quality/completeness）とブラウザ verifier（functionality/ux）を 2+2 分担で呼び、総合 verdict = 両者の論理積で機構判定する',
  phases: [
    { title: 'Build', detail: 'change ごとに longrun-builder で TDD 実装（builder-report schema 強制）' },
    { title: 'Verify', detail: '静的 2 軸 + ブラウザ 2 軸の定量評価ループ（上限 3 周 + budget ガード、verifier-score schema 強制、総合 verdict は論理積）' },
  ],
};

// --- 定数（コードに現れる上限。LLM の自制に依存しない）---
const VERIFY_MAX_ROUNDS = 3;       // Verify ループの明示上限（D3）
const VERIFY_ROUND_COST = 50000;   // 1 周あたりの想定トークン消費（budget ガードのしきい値）

const builderSchema = __BUILDER_SCHEMA__;
const verifierSchema = __VERIFIER_SCHEMA__;
const changes = __CHANGES_JSON__;

// モデル割り当て（change-4）。エイリアス文字列 or null。null は inherit = opts.model を渡さない（D2）。
// 解決は exec が resolve-model-allocation.mjs + references/model-tiers.md で行い、ここに埋める。
const builderModel = __BUILDER_MODEL__;
const verifierModel = __VERIFIER_MODEL__;
const browserVerifierModel = __BROWSER_VERIFIER_MODEL__;

// ===== Build フェーズ =====
phase('Build');

const buildReports = [];
for (let i = 0; i < changes.length; i++) {
  const change = changes[i];
  // builder 完了レポートを StructuredOutput で強制（散文 STATUS パースは廃止）。
  const report = await agent(
    `以下の change を TDD 実装してください: ${change.name}。` +
    `worktree パス: ${change.worktree}。plan.md: __RUN_DIR__/plan.md。` +
    `verification-guide.md の該当 Scenario を進捗に応じて [x] 化すること。` +
    `実装完了後、必ず worktree ブランチにコミットすること（git add -A && git commit）。` +
    `未コミットの変更は worktree 削除時に消失する。commits にコミットの短縮ハッシュを必ず含めること。`,
    {
      label: `build ${change.name}`,
      phase: 'Build',
      agentType: '__BUILDER_AGENT_TYPE__',
      schema: builderSchema,
      ...(builderModel ? { model: builderModel } : {}),
    }
  );
  buildReports.push({ change: change.name, report });
}

const failedBuilds = buildReports.filter((b) => !b.report || b.report.status !== 'SUCCESS');

// ===== Verify フェーズ（上限 3 周 + budget ガード）=====
phase('Verify');

let round = 0;
let lastScore = null;
let stopReason = null;

// 上限がコードの条件式になっている。4 周目は構造的に実行されない（D3）。
// budget.total が null（=トークン上限指示なし）のセッションでは null ガードにより
// budget チェックを無視して上限 3 周まで回る。total があれば残量で早期停止する。
while (round < VERIFY_MAX_ROUNDS) {
  // budget 枯渇ガード（null ガード必須。total が null なら remaining() は Infinity）
  if (budget.total && budget.remaining() <= VERIFY_ROUND_COST) {
    stopReason = 'BUDGET_EXHAUSTED';
    log(`Verify ループを budget 枯渇で停止（round=${round}, remaining=${budget.remaining()}）`);
    break;
  }

  round++;

  // --- 静的 verifier（quality / completeness の 2 軸）---
  const staticScore = await agent(
    `静的検証を実行してください。longrun-dir: __RUN_DIR__。` +
    `テスト・lint・型チェック・ビルドの品質評価とエッジケース/エラーハンドリングのコードレビューによる完成度評価を行い、` +
    `quality / completeness を各 0-100 で採点し、` +
    `ハードしきい値（quality=100, completeness>=80）を満たせば verdict=PASS、` +
    `満たさなければ verdict=FAIL として findings に残課題を列挙してください。（round ${round}）`,
    {
      label: `verify(static) round ${round}`,
      phase: 'Verify',
      agentType: '__VERIFIER_AGENT_TYPE__',
      schema: verifierSchema,
      ...(verifierModel ? { model: verifierModel } : {}),
    }
  );

  // --- ブラウザ verifier（functionality / ux の 2 軸）---
  const browserScore = await agent(
    `ブラウザ動作検証を実行してください。longrun-dir: __RUN_DIR__。` +
    `Playwright MCP（優先）または claude-in-chrome で spec Scenario の WHEN/THEN を実操作し、` +
    `functionality / ux を各 0-100 で採点し、` +
    `ハードしきい値（functionality=100, ux>=70）を満たせば verdict=PASS、` +
    `満たさなければ verdict=FAIL として findings に残課題を列挙してください。（round ${round}）`,
    {
      label: `verify(browser) round ${round}`,
      phase: 'Verify',
      agentType: '__BROWSER_VERIFIER_AGENT_TYPE__',
      schema: verifierSchema,
      ...(browserVerifierModel ? { model: browserVerifierModel } : {}),
    }
  );

  // 2 返却を 4 軸へマージ（agent() は null を返しうる → null ガード）。
  // 総合 verdict = 静的 verdict ∧ ブラウザ verdict（両方 PASS のときのみ PASS）。
  const bothPass =
    staticScore && staticScore.verdict === 'PASS' &&
    browserScore && browserScore.verdict === 'PASS';
  const mergedFindings = []
    .concat(staticScore && staticScore.findings ? staticScore.findings : [])
    .concat(browserScore && browserScore.findings ? browserScore.findings : []);
  const merged = {
    quality: staticScore ? staticScore.quality : null,
    completeness: staticScore ? staticScore.completeness : null,
    functionality: browserScore ? browserScore.functionality : null,
    ux: browserScore ? browserScore.ux : null,
    staticVerdict: staticScore ? staticScore.verdict : null,
    browserVerdict: browserScore ? browserScore.verdict : null,
    verdict: bothPass ? 'PASS' : 'FAIL',
    findings: mergedFindings,
  };
  lastScore = merged;

  if (bothPass) {
    stopReason = 'PASS';
    break;
  }

  // FAIL → builder に合算 findings で修正依頼（次周で両 verifier を再評価）。上限到達時はループ条件で停止。
  if (round < VERIFY_MAX_ROUNDS) {
    await agent(
      `Verify が FAIL しました（round ${round}、静的=${merged.staticVerdict} / ブラウザ=${merged.browserVerdict}）。` +
      `以下の残課題を修正してください: ${mergedFindings.length ? JSON.stringify(mergedFindings) : '(詳細不明)'}。` +
      `修正後コミットすること。`,
      {
        label: `fix round ${round}`,
        phase: 'Verify',
        agentType: '__BUILDER_AGENT_TYPE__',
        schema: builderSchema,
        ...(builderModel ? { model: builderModel } : {}),
      }
    );
  }
}

if (!stopReason) {
  // ループ条件（round < 3）で抜けた = 上限到達
  stopReason = 'MAX_ROUNDS_REACHED';
  log(`Verify ループが上限 ${VERIFY_MAX_ROUNDS} 周に到達して停止`);
}

// 状態を構造化して返す。メインループがこれを見て Feedback Tier 確認の AskUserQuestion を出す（D5）。
return {
  phase: 'Build+Verify',
  timestamp: args.timestamp,
  builds: buildReports,
  failedBuilds: failedBuilds.map((b) => b.change),
  verify: {
    rounds: round,
    maxRounds: VERIFY_MAX_ROUNDS,
    stopReason,
    score: lastScore,
    passed: stopReason === 'PASS',
  },
};
