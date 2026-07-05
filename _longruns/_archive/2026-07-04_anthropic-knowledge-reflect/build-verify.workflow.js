// build-verify.workflow.js — longrun Build → Verify フェーズ workflow（テンプレート）
//
// exec コマンドが plan.md の Changes 分解から具体値を埋めてこのテンプレートを生成し、
// Workflow ツールで起動する。Review フェーズが APPROVE され、メインループが Build Contract
// 承認を取得した後に起動される（D5 の分割境界）。
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
//   /Users/oratta/orca/workspaces/oratta-claude-harness/anthropic論文をハーネスに反映/_longruns/2026-07-04_anthropic-knowledge-reflect              ランディレクトリの絶対パス（_longruns/<run>/）
//   /Users/oratta/orca/workspaces/oratta-claude-harness/anthropic論文をハーネスに反映         プロジェクトルート（cwd）
//   [{"name":"loops-plugin","worktree":"/Users/oratta/orca/workspaces/oratta-claude-harness/anthropic論文をハーネスに反映","dependsOn":[]},{"name":"skill-verification","worktree":"/Users/oratta/orca/workspaces/oratta-claude-harness/anthropic論文をハーネスに反映","dependsOn":["loops-plugin"]},{"name":"goal-time-recipes","worktree":"/Users/oratta/orca/workspaces/oratta-claude-harness/anthropic論文をハーネスに反映","dependsOn":["loops-plugin"]},{"name":"proactive-routines","worktree":"/Users/oratta/orca/workspaces/oratta-claude-harness/anthropic論文をハーネスに反映","dependsOn":["loops-plugin","goal-time-recipes"]},{"name":"loops-integration","worktree":"/Users/oratta/orca/workspaces/oratta-claude-harness/anthropic論文をハーネスに反映","dependsOn":["loops-plugin","skill-verification","goal-time-recipes","proactive-routines"]}]         plan.md の Changes 分解を [{name, worktree, dependsOn:[...]}] にした配列リテラル
//   longrun:longrun-builder            builder agentType。既定 'longrun:longrun-builder'（D6: パラメータ化）
//   longrun:longrun-verifier           静的 verifier agentType。既定 'longrun:longrun-verifier'（quality/completeness 担当）
//   longrun:longrun-browser-verifier   ブラウザ verifier agentType。既定 'longrun:longrun-browser-verifier'（functionality/ux 担当。change-2）
//   {"$schema":"http://json-schema.org/draft-07/schema#","title":"builder-report","description":"longrun-builder Agent の完了レポート。Workflow スクリプトの agent(prompt, {schema}) で StructuredOutput を強制し、散文 STATUS 行のパースを置き換える。","type":"object","additionalProperties":false,"required":["status","change","commits","tasks","tests"],"properties":{"status":{"type":"string","enum":["SUCCESS","FAILURE"],"description":"change の TDD 実装の総合判定"},"change":{"type":"string","description":"実装した change 名"},"commits":{"type":"array","description":"worktree ブランチに積まれたコミットの短縮ハッシュ一覧（最低 1 件。未コミットは status=FAILURE）","items":{"type":"string","pattern":"^[0-9a-f]{7,40}$"},"minItems":0},"tasks":{"type":"object","additionalProperties":false,"required":["completed","total"],"description":"tasks.md のチェックボックス進捗","properties":{"completed":{"type":"integer","minimum":0},"total":{"type":"integer","minimum":0}}},"tests":{"type":"object","additionalProperties":false,"required":["passed","failed","added"],"description":"テストスイートの結果（passed/failed は最終状態、added は本 change で新規追加した本数）","properties":{"passed":{"type":"integer","minimum":0},"failed":{"type":"integer","minimum":0},"added":{"type":"integer","minimum":0}}},"notes":{"type":"string","description":"特記事項（任意）"}}}                builder-report.schema.json の中身（インライン JSON オブジェクト）
//   {"$schema":"http://json-schema.org/draft-07/schema#","title":"verifier-score","description":"longrun-verifier（静的: quality/completeness）と longrun-browser-verifier（ブラウザ: functionality/ux）の共有スコア schema。各軸 0-100。各 verifier は自分の担当 2 軸 + verdict を返す部分返却（required は verdict のみ）。Workflow の Verify ループが 2 返却をマージし、総合 verdict = 両者の論理積で PASS/FAIL を機構判定する。","type":"object","additionalProperties":false,"required":["verdict"],"properties":{"functionality":{"type":"integer","minimum":0,"maximum":100,"description":"機能性（spec Scenario 通過率）。ハードしきい値 100"},"quality":{"type":"integer","minimum":0,"maximum":100,"description":"品質（テスト + lint + 型チェック + ビルド）。ハードしきい値 100"},"completeness":{"type":"integer","minimum":0,"maximum":100,"description":"完成度（エッジケース・エラーハンドリング）。ハードしきい値 80"},"ux":{"type":"integer","minimum":0,"maximum":100,"description":"UX（操作フロー）。ハードしきい値 70"},"verdict":{"type":"string","enum":["PASS","FAIL"],"description":"この verifier が担当する 2 軸のハードしきい値を全て満たすかの判定。Verify ループは静的 verdict ∧ ブラウザ verdict を総合 verdict とし、FAIL なら合算 findings を builder へ修正依頼する"},"findings":{"type":"array","description":"FAIL 時の残課題（修正依頼の根拠）。各要素は人間可読の一文","items":{"type":"string"}}}}               verifier-score.schema.json の中身（インライン JSON オブジェクト。静的/ブラウザ両 verifier で共用 = 部分返却, change-2 D2 候補1）
//   null                 builder の opts.model 値（エイリアス文字列リテラル 'sonnet' 等、または null）
//   'sonnet'                静的 verifier の opts.model 値（同上）
//   null        ブラウザ verifier の opts.model 値（同上。change-2）
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

const builderSchema = {"$schema":"http://json-schema.org/draft-07/schema#","title":"builder-report","description":"longrun-builder Agent の完了レポート。Workflow スクリプトの agent(prompt, {schema}) で StructuredOutput を強制し、散文 STATUS 行のパースを置き換える。","type":"object","additionalProperties":false,"required":["status","change","commits","tasks","tests"],"properties":{"status":{"type":"string","enum":["SUCCESS","FAILURE"],"description":"change の TDD 実装の総合判定"},"change":{"type":"string","description":"実装した change 名"},"commits":{"type":"array","description":"worktree ブランチに積まれたコミットの短縮ハッシュ一覧（最低 1 件。未コミットは status=FAILURE）","items":{"type":"string","pattern":"^[0-9a-f]{7,40}$"},"minItems":0},"tasks":{"type":"object","additionalProperties":false,"required":["completed","total"],"description":"tasks.md のチェックボックス進捗","properties":{"completed":{"type":"integer","minimum":0},"total":{"type":"integer","minimum":0}}},"tests":{"type":"object","additionalProperties":false,"required":["passed","failed","added"],"description":"テストスイートの結果（passed/failed は最終状態、added は本 change で新規追加した本数）","properties":{"passed":{"type":"integer","minimum":0},"failed":{"type":"integer","minimum":0},"added":{"type":"integer","minimum":0}}},"notes":{"type":"string","description":"特記事項（任意）"}}};
const verifierSchema = {"$schema":"http://json-schema.org/draft-07/schema#","title":"verifier-score","description":"longrun-verifier（静的: quality/completeness）と longrun-browser-verifier（ブラウザ: functionality/ux）の共有スコア schema。各軸 0-100。各 verifier は自分の担当 2 軸 + verdict を返す部分返却（required は verdict のみ）。Workflow の Verify ループが 2 返却をマージし、総合 verdict = 両者の論理積で PASS/FAIL を機構判定する。","type":"object","additionalProperties":false,"required":["verdict"],"properties":{"functionality":{"type":"integer","minimum":0,"maximum":100,"description":"機能性（spec Scenario 通過率）。ハードしきい値 100"},"quality":{"type":"integer","minimum":0,"maximum":100,"description":"品質（テスト + lint + 型チェック + ビルド）。ハードしきい値 100"},"completeness":{"type":"integer","minimum":0,"maximum":100,"description":"完成度（エッジケース・エラーハンドリング）。ハードしきい値 80"},"ux":{"type":"integer","minimum":0,"maximum":100,"description":"UX（操作フロー）。ハードしきい値 70"},"verdict":{"type":"string","enum":["PASS","FAIL"],"description":"この verifier が担当する 2 軸のハードしきい値を全て満たすかの判定。Verify ループは静的 verdict ∧ ブラウザ verdict を総合 verdict とし、FAIL なら合算 findings を builder へ修正依頼する"},"findings":{"type":"array","description":"FAIL 時の残課題（修正依頼の根拠）。各要素は人間可読の一文","items":{"type":"string"}}}};
const changes = [{"name":"loops-plugin","worktree":"/Users/oratta/orca/workspaces/oratta-claude-harness/anthropic論文をハーネスに反映","dependsOn":[]},{"name":"skill-verification","worktree":"/Users/oratta/orca/workspaces/oratta-claude-harness/anthropic論文をハーネスに反映","dependsOn":["loops-plugin"]},{"name":"goal-time-recipes","worktree":"/Users/oratta/orca/workspaces/oratta-claude-harness/anthropic論文をハーネスに反映","dependsOn":["loops-plugin"]},{"name":"proactive-routines","worktree":"/Users/oratta/orca/workspaces/oratta-claude-harness/anthropic論文をハーネスに反映","dependsOn":["loops-plugin","goal-time-recipes"]},{"name":"loops-integration","worktree":"/Users/oratta/orca/workspaces/oratta-claude-harness/anthropic論文をハーネスに反映","dependsOn":["loops-plugin","skill-verification","goal-time-recipes","proactive-routines"]}];

// モデル割り当て（change-4）。エイリアス文字列 or null。null は inherit = opts.model を渡さない（D2）。
// 解決は exec が resolve-model-allocation.mjs + references/model-tiers.md で行い、ここに埋める。
const builderModel = null;
const verifierModel = 'sonnet';
const browserVerifierModel = null;

// ===== Build フェーズ =====
phase('Build');

const buildReports = [];
for (let i = 0; i < changes.length; i++) {
  const change = changes[i];
  // builder 完了レポートを StructuredOutput で強制（散文 STATUS パースは廃止）。
  const report = await agent(
    `以下の change を TDD 実装してください: ${change.name}。` +
    `worktree パス: ${change.worktree}。plan.md: /Users/oratta/orca/workspaces/oratta-claude-harness/anthropic論文をハーネスに反映/_longruns/2026-07-04_anthropic-knowledge-reflect/plan.md。` +
    `verification-guide.md の該当 Scenario を進捗に応じて [x] 化すること。` +
    `実装完了後、必ず worktree ブランチにコミットすること（git add -A && git commit）。` +
    `未コミットの変更は worktree 削除時に消失する。commits にコミットの短縮ハッシュを必ず含めること。`,
    {
      label: `build ${change.name}`,
      phase: 'Build',
      agentType: 'longrun:longrun-builder',
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
    `静的検証を実行してください。longrun-dir: /Users/oratta/orca/workspaces/oratta-claude-harness/anthropic論文をハーネスに反映/_longruns/2026-07-04_anthropic-knowledge-reflect。` +
    `テスト・lint・型チェック・ビルドの品質評価とエッジケース/エラーハンドリングのコードレビューによる完成度評価を行い、` +
    `quality / completeness を各 0-100 で採点し、` +
    `ハードしきい値（quality=100, completeness>=80）を満たせば verdict=PASS、` +
    `満たさなければ verdict=FAIL として findings に残課題を列挙してください。（round ${round}）`,
    {
      label: `verify(static) round ${round}`,
      phase: 'Verify',
      agentType: 'longrun:longrun-verifier',
      schema: verifierSchema,
      ...(verifierModel ? { model: verifierModel } : {}),
    }
  );

  // --- ブラウザ verifier（functionality / ux の 2 軸）---
  const browserScore = await agent(
    `ブラウザ動作検証を実行してください。longrun-dir: /Users/oratta/orca/workspaces/oratta-claude-harness/anthropic論文をハーネスに反映/_longruns/2026-07-04_anthropic-knowledge-reflect。` +
    `Playwright MCP（優先）または claude-in-chrome で spec Scenario の WHEN/THEN を実操作し、` +
    `functionality / ux を各 0-100 で採点し、` +
    `ハードしきい値（functionality=100, ux>=70）を満たせば verdict=PASS、` +
    `満たさなければ verdict=FAIL として findings に残課題を列挙してください。（round ${round}）`,
    {
      label: `verify(browser) round ${round}`,
      phase: 'Verify',
      agentType: 'longrun:longrun-browser-verifier',
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
