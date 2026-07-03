// build-verify.workflow.js — longrun Build → Verify フェーズ workflow（テンプレート）
//
// exec コマンドが plan.md の Changes 分解から具体値を埋めてこのテンプレートを生成し、
// Workflow ツールで起動する。Review フェーズが APPROVE され、メインループが Build Contract
// 承認を取得した後に起動される（D5 の分割境界）。
//
// === Workflow ツール制約（_longruns/<run>/workflow-tool-reference.md を一次ソースとする）===
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
//   /Users/oratta/.claude/plugins/marketplaces/oratta-claude-harness/_longruns/2026-07-03_plugin-review-fixes              ランディレクトリの絶対パス（_longruns/<run>/）
//   /Users/oratta/.claude/plugins/marketplaces/oratta-claude-harness         プロジェクトルート（cwd）
//   [{"name":"change-1","worktree":"/Users/oratta/.superset/worktrees/plugin-review-fixes","dependsOn":[]},{"name":"change-2","worktree":"/Users/oratta/.superset/worktrees/plugin-review-fixes","dependsOn":[]},{"name":"change-3","worktree":"/Users/oratta/.superset/worktrees/plugin-review-fixes","dependsOn":["change-2"]},{"name":"change-4","worktree":"/Users/oratta/.superset/worktrees/plugin-review-fixes","dependsOn":[]},{"name":"change-5","worktree":"/Users/oratta/.superset/worktrees/plugin-review-fixes","dependsOn":[]},{"name":"change-6","worktree":"/Users/oratta/.superset/worktrees/plugin-review-fixes","dependsOn":["change-5"]},{"name":"change-7","worktree":"/Users/oratta/.superset/worktrees/plugin-review-fixes","dependsOn":["change-1","change-3","change-4","change-6"]}]         plan.md の Changes 分解を [{name, worktree, dependsOn:[...]}] にした配列リテラル
//   longrun:longrun-builder   builder agentType。既定 'longrun:longrun-builder'（D6: パラメータ化）
//   longrun:longrun-verifier  既定 'longrun:longrun-verifier'
//   {"$schema":"http://json-schema.org/draft-07/schema#","title":"builder-report","description":"longrun-builder Agent の完了レポート。Workflow スクリプトの agent(prompt, {schema}) で StructuredOutput を強制し、散文 STATUS 行のパースを置き換える。","type":"object","additionalProperties":false,"required":["status","change","commits","tasks","tests"],"properties":{"status":{"type":"string","enum":["SUCCESS","FAILURE"],"description":"change の TDD 実装の総合判定"},"change":{"type":"string","description":"実装した change 名"},"commits":{"type":"array","description":"worktree ブランチに積まれたコミットの短縮ハッシュ一覧（最低 1 件。未コミットは status=FAILURE）","items":{"type":"string","pattern":"^[0-9a-f]{7,40}$"},"minItems":0},"tasks":{"type":"object","additionalProperties":false,"required":["completed","total"],"description":"tasks.md のチェックボックス進捗","properties":{"completed":{"type":"integer","minimum":0},"total":{"type":"integer","minimum":0}}},"tests":{"type":"object","additionalProperties":false,"required":["passed","failed","added"],"description":"テストスイートの結果（passed/failed は最終状態、added は本 change で新規追加した本数）","properties":{"passed":{"type":"integer","minimum":0},"failed":{"type":"integer","minimum":0},"added":{"type":"integer","minimum":0}}},"notes":{"type":"string","description":"特記事項（任意）"}}}       builder-report.schema.json の中身（インライン JSON オブジェクト）
//   {"$schema":"http://json-schema.org/draft-07/schema#","title":"verifier-score","description":"longrun-verifier / longrun-browser-verifier の 4 軸定量評価。各軸 0-100。Workflow スクリプトの Verify ループが verdict で PASS/FAIL を機構判定する。","type":"object","additionalProperties":false,"required":["functionality","quality","completeness","ux","verdict"],"properties":{"functionality":{"type":"integer","minimum":0,"maximum":100,"description":"機能性（spec Scenario 通過率）。ハードしきい値 100"},"quality":{"type":"integer","minimum":0,"maximum":100,"description":"品質（テスト + lint + 型チェック + ビルド）。ハードしきい値 100"},"completeness":{"type":"integer","minimum":0,"maximum":100,"description":"完成度（エッジケース・エラーハンドリング）。ハードしきい値 80"},"ux":{"type":"integer","minimum":0,"maximum":100,"description":"UX（操作フロー）。ハードしきい値 70"},"verdict":{"type":"string","enum":["PASS","FAIL"],"description":"4 軸のハードしきい値を全て満たすかの総合判定。FAIL なら Verify ループが builder に修正依頼する"},"findings":{"type":"array","description":"FAIL 時の残課題（修正依頼の根拠）。各要素は人間可読の一文","items":{"type":"string"}}}}      verifier-score.schema.json の中身（インライン JSON オブジェクト）
//   null        builder の opts.model 値（エイリアス文字列リテラル 'sonnet' 等、または null）
//   null       verifier の opts.model 値（同上）
//                            null のときは下の条件付きスプレッドで model キー自体を出力しない（inherit, change-4 D2）。
//                            ティア → エイリアス値の解決は plugins/longrun/references/model-tiers.md（1 箇所集約）。

export const meta = {
  name: 'longrun-build-verify',
  description: 'longrun Build → Verify フェーズ: change ごとに longrun-builder で TDD 実装し、Verify ループ（上限 3 周 + budget ガード）で longrun-verifier の 4 軸スコアを機構判定する',
  phases: [
    { title: 'Build', detail: 'change ごとに longrun-builder で TDD 実装（builder-report schema 強制）' },
    { title: 'Verify', detail: '4 軸定量評価ループ（上限 3 周 + budget ガード、verifier-score schema 強制）' },
  ],
};

// --- 定数（コードに現れる上限。LLM の自制に依存しない）---
const VERIFY_MAX_ROUNDS = 3;       // Verify ループの明示上限（D3）
const VERIFY_ROUND_COST = 50000;   // 1 周あたりの想定トークン消費（budget ガードのしきい値）

const builderSchema = {"$schema":"http://json-schema.org/draft-07/schema#","title":"builder-report","description":"longrun-builder Agent の完了レポート。Workflow スクリプトの agent(prompt, {schema}) で StructuredOutput を強制し、散文 STATUS 行のパースを置き換える。","type":"object","additionalProperties":false,"required":["status","change","commits","tasks","tests"],"properties":{"status":{"type":"string","enum":["SUCCESS","FAILURE"],"description":"change の TDD 実装の総合判定"},"change":{"type":"string","description":"実装した change 名"},"commits":{"type":"array","description":"worktree ブランチに積まれたコミットの短縮ハッシュ一覧（最低 1 件。未コミットは status=FAILURE）","items":{"type":"string","pattern":"^[0-9a-f]{7,40}$"},"minItems":0},"tasks":{"type":"object","additionalProperties":false,"required":["completed","total"],"description":"tasks.md のチェックボックス進捗","properties":{"completed":{"type":"integer","minimum":0},"total":{"type":"integer","minimum":0}}},"tests":{"type":"object","additionalProperties":false,"required":["passed","failed","added"],"description":"テストスイートの結果（passed/failed は最終状態、added は本 change で新規追加した本数）","properties":{"passed":{"type":"integer","minimum":0},"failed":{"type":"integer","minimum":0},"added":{"type":"integer","minimum":0}}},"notes":{"type":"string","description":"特記事項（任意）"}}};
const verifierSchema = {"$schema":"http://json-schema.org/draft-07/schema#","title":"verifier-score","description":"longrun-verifier / longrun-browser-verifier の 4 軸定量評価。各軸 0-100。Workflow スクリプトの Verify ループが verdict で PASS/FAIL を機構判定する。","type":"object","additionalProperties":false,"required":["functionality","quality","completeness","ux","verdict"],"properties":{"functionality":{"type":"integer","minimum":0,"maximum":100,"description":"機能性（spec Scenario 通過率）。ハードしきい値 100"},"quality":{"type":"integer","minimum":0,"maximum":100,"description":"品質（テスト + lint + 型チェック + ビルド）。ハードしきい値 100"},"completeness":{"type":"integer","minimum":0,"maximum":100,"description":"完成度（エッジケース・エラーハンドリング）。ハードしきい値 80"},"ux":{"type":"integer","minimum":0,"maximum":100,"description":"UX（操作フロー）。ハードしきい値 70"},"verdict":{"type":"string","enum":["PASS","FAIL"],"description":"4 軸のハードしきい値を全て満たすかの総合判定。FAIL なら Verify ループが builder に修正依頼する"},"findings":{"type":"array","description":"FAIL 時の残課題（修正依頼の根拠）。各要素は人間可読の一文","items":{"type":"string"}}}};
const changes = [{"name":"change-1","worktree":"/Users/oratta/.superset/worktrees/plugin-review-fixes","dependsOn":[]},{"name":"change-2","worktree":"/Users/oratta/.superset/worktrees/plugin-review-fixes","dependsOn":[]},{"name":"change-3","worktree":"/Users/oratta/.superset/worktrees/plugin-review-fixes","dependsOn":["change-2"]},{"name":"change-4","worktree":"/Users/oratta/.superset/worktrees/plugin-review-fixes","dependsOn":[]},{"name":"change-5","worktree":"/Users/oratta/.superset/worktrees/plugin-review-fixes","dependsOn":[]},{"name":"change-6","worktree":"/Users/oratta/.superset/worktrees/plugin-review-fixes","dependsOn":["change-5"]},{"name":"change-7","worktree":"/Users/oratta/.superset/worktrees/plugin-review-fixes","dependsOn":["change-1","change-3","change-4","change-6"]}];

// モデル割り当て（change-4）。エイリアス文字列 or null。null は inherit = opts.model を渡さない（D2）。
// 解決は exec が resolve-model-allocation.mjs + references/model-tiers.md で行い、ここに埋める。
const builderModel = null;
const verifierModel = null;
// plan.md「モデル割り当て」表の change 別 builder ティア（resolve-model-allocation.mjs の解決結果）。
// テンプレのグローバル builderModel は Verify 修正ループ（change 横断）用に inherit のまま残す。
const builderModelByChange = {
  'change-1': 'sonnet',
  'change-2': null,
  'change-3': 'sonnet',
  'change-4': null,
  'change-5': 'sonnet',
  'change-6': 'sonnet',
  'change-7': null,
};

// ===== Build フェーズ =====
phase('Build');

const buildReports = [];
for (let i = 0; i < changes.length; i++) {
  const change = changes[i];
  // builder 完了レポートを StructuredOutput で強制（散文 STATUS パースは廃止）。
  const report = await agent(
    `以下の change を TDD 実装してください: ${change.name}。` +
    `worktree パス: ${change.worktree}。plan.md: /Users/oratta/.claude/plugins/marketplaces/oratta-claude-harness/_longruns/2026-07-03_plugin-review-fixes/plan.md。` +
    `verification-guide.md の該当 Scenario を進捗に応じて [x] 化すること。` +
    `実装完了後、必ず worktree ブランチにコミットすること（git add -A && git commit）。` +
    `未コミットの変更は worktree 削除時に消失する。commits にコミットの短縮ハッシュを必ず含めること。`,
    {
      label: `build ${change.name}`,
      phase: 'Build',
      agentType: 'longrun:longrun-builder',
      schema: builderSchema,
      ...(builderModelByChange[change.name] ? { model: builderModelByChange[change.name] } : {}),
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
  const score = await agent(
    `静的検証を実行してください。longrun-dir: /Users/oratta/.claude/plugins/marketplaces/oratta-claude-harness/_longruns/2026-07-03_plugin-review-fixes。` +
    `テスト・lint・型チェック・ビルドの品質検証とコードレビューによる完成度評価を行い、` +
    `functionality / quality / completeness / ux を各 0-100 で採点し、` +
    `ハードしきい値（quality=100, functionality=100, completeness>=80, ux>=70）を全て満たせば verdict=PASS、` +
    `満たさなければ verdict=FAIL として findings に残課題を列挙してください。（round ${round}）`,
    {
      label: `verify round ${round}`,
      phase: 'Verify',
      agentType: 'longrun:longrun-verifier',
      schema: verifierSchema,
      ...(verifierModel ? { model: verifierModel } : {}),
    }
  );
  lastScore = score;

  if (score && score.verdict === 'PASS') {
    stopReason = 'PASS';
    break;
  }

  // FAIL → builder に修正依頼（次周で再検証）。上限到達時はループ条件で停止する。
  if (round < VERIFY_MAX_ROUNDS) {
    await agent(
      `Verify が FAIL しました（round ${round}）。以下の残課題を修正してください: ` +
      `${score && score.findings ? JSON.stringify(score.findings) : '(詳細不明)'}。` +
      `修正後コミットすること。`,
      {
        label: `fix round ${round}`,
        phase: 'Verify',
        agentType: 'longrun:longrun-builder',
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
