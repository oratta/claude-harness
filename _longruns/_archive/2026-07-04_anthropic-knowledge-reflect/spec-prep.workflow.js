// spec-prep.workflow.js — Build 前準備: OpenSpec change 作成 → spec レビュー → verification-guide 生成
//
// 通常モードの Build 前半（過去 run の「OpenSpec ドキュメント作成 + Spec Review + guide 生成」）を
// Workflow 化したもの。exec.md Step 4 の build-verify.workflow.js 起動前に実行する。
// タイムスタンプは args.timestamp / args.createdDate で注入する（Date.now() 禁止のため）。

export const meta = {
  name: 'longrun-spec-prep',
  description: 'anthropic-knowledge-reflect run の Build 前準備: 5 change の OpenSpec ドキュメント作成（validate --strict PASS まで）→ 各 change の Spec Review（1 回の修正ラウンド付き）→ verification-guide.md 生成',
  phases: [
    { title: 'Spec', detail: '5 change 並列: author（validate PASS まで）→ spec review → 必要なら fix + 再レビュー' },
    { title: 'Guide', detail: '全 change の Scenario を verification-guide.md に集約' },
  ],
};

const RUN_DIR = '/Users/oratta/orca/workspaces/oratta-claude-harness/anthropic論文をハーネスに反映/_longruns/2026-07-04_anthropic-knowledge-reflect';
const ROOT = '/Users/oratta/orca/workspaces/oratta-claude-harness/anthropic論文をハーネスに反映';

const reviewerSchema = {
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "reviewer-verdict",
  "type": "object",
  "additionalProperties": false,
  "required": ["status", "findings"],
  "properties": {
    "status": { "type": "string", "enum": ["APPROVE", "REQUEST_CHANGES"] },
    "findings": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["severity", "message"],
        "properties": {
          "severity": { "type": "string", "enum": ["BLOCKER", "SHOULD_FIX", "NOTE"] },
          "message": { "type": "string" }
        }
      }
    },
    "summary": { "type": "string" }
  }
};

const authorSchema = {
  "type": "object",
  "additionalProperties": false,
  "required": ["change", "validated", "capabilities", "scenarioCount"],
  "properties": {
    "change": { "type": "string" },
    "validated": { "type": "boolean", "description": "openspec validate --strict が exit 0 だったか" },
    "capabilities": { "type": "array", "items": { "type": "string" } },
    "scenarioCount": { "type": "integer" },
    "notes": { "type": "string" }
  }
};

const guideSchema = {
  "type": "object",
  "additionalProperties": false,
  "required": ["written", "scenarioTotal"],
  "properties": {
    "written": { "type": "boolean" },
    "scenarioTotal": { "type": "integer" },
    "notes": { "type": "string" }
  }
};

const changes = [
  {
    name: 'loops-plugin',
    planKey: 'change-1: loops-plugin',
    extra: '',
  },
  {
    name: 'skill-verification',
    planKey: 'change-2: skill-verification',
    extra: 'Build Contract レビューの NOTE: 受け入れ条件 8 / plan 本文の「e2s-distill」の実体はスキルディレクトリ plugins/experience-to-skill/skills/experience-to-skill/SKILL.md（コマンド名だけが e2s-distill）。棚卸し・検証節追加のタスクでは実パスで参照するよう tasks.md に明記すること。',
  },
  {
    name: 'goal-time-recipes',
    planKey: 'change-3: goal-and-time-recipes',
    extra: '',
  },
  {
    name: 'proactive-routines',
    planKey: 'change-4: proactive-routines',
    extra: 'Build Contract レビューの NOTE 2 点を tasks.md の構成に反映すること: (1) 3 ルーチン + 各デモを独立したサブマイルストーン（独立 commit）としてタスクグループを分け、1 ルーチンのデモ失敗が他をブロックしない構成にする。(2) デモは未インストールの loops プラグインのスキル起動（/loops:design）に依存させず、references の規約検査手順（停止基準必須・Bad Loop 検査）を手動実行する形で evidence を残す設計にする。',
  },
  {
    name: 'loops-integration',
    planKey: 'change-5: integration',
    extra: '',
  },
];

function authorPrompt(c) {
  return 'あなたは OpenSpec change ドキュメントの作成担当です。最終テキストは人間向けメッセージではなくデータとして扱われます。\n' +
    '対象リポジトリ: ' + ROOT + '（git worktree。ブランチはそのまま使う。コミットはしない）\n' +
    'plan.md: ' + RUN_DIR + '/plan.md を読み、「' + c.planKey + '」のスコープ・config.yaml rules・受け入れ条件・付録の根拠を把握すること。\n' +
    '\n' +
    'タスク: openspec/changes/' + c.name + '/ に longrun-tdd スキーマの change ドキュメント一式を作成する。\n' +
    '手順:\n' +
    '1. 既存 change の構造を参照する（例: ' + ROOT + '/openspec/changes/model-allocation/ の .openspec.yaml / proposal.md / design.md / tasks.md / specs/<capability>/spec.md）。\n' +
    '2. テンプレート ' + ROOT + '/openspec/schemas/longrun-tdd/templates/{proposal.md,design.md,tasks.md,spec.md} の構成に従う。\n' +
    '3. .openspec.yaml は「schema: longrun-tdd」と「created: ' + args.createdDate + '」の 2 行。\n' +
    '4. proposal.md: Why / What Changes / Capabilities（New/Modified） / Impact。\n' +
    '5. specs/<capability>/spec.md: 各 Requirement に WHEN/THEN 形式の Scenario を付ける（後段で verification-guide.md に集約される。builder が bats テストに落とせる粒度で書く）。capability 名は kebab-case で、この change 固有の名前空間（例: loops-recipe-format, loops-design-skill）を使う。\n' +
    '6. design.md: 技術判断（Decisions）。plan.md の config.yaml rules と制約（独自ランタイム再発明禁止・停止基準必須・モデルID直書き禁止等）を反映。\n' +
    '7. tasks.md: 「## N. <グループ>」見出し + 「- [ ] N.M <内容>」のチェックボックス形式。TDD 順（テスト先行）でタスクを並べる。\n' +
    '8. openspec validate --strict ' + c.name + ' を実行し、PASS するまで修正する（openspec CLI は PATH 上の volta 版 1.2.0）。\n' +
    (c.extra ? '\n追加指示（Build Contract レビューの反映）: ' + c.extra + '\n' : '') +
    '\n' +
    '制約: plan.md のスコープ外を仕様に含めない（特に「含まないもの」節: 定期実行の機構・配線、独自ループランタイムは書かない）。他の change のディレクトリには触れない。git commit しない。\n' +
    '完了したら StructuredOutput で change 名・validate 結果・capability 一覧・Scenario 総数を返すこと。';
}

function reviewPrompt(c, rerun) {
  return (rerun ? '再レビュー: ' : '') + 'Spec Review を実施してください。\n' +
    '対象: ' + ROOT + '/openspec/changes/' + c.name + '/ の全ドキュメント（proposal.md / design.md / tasks.md / specs/**/spec.md）。\n' +
    '判断基準: ' + RUN_DIR + '/plan.md の「' + c.planKey + '」のスコープ・config.yaml rules・受け入れ条件との整合。\n' +
    '観点: (1) スコープ逸脱（特に plan の「含まないもの」の混入）、(2) Scenario の検証可能性（WHEN/THEN が機械検証に落とせるか）、(3) tasks.md の TDD 順序と粒度、(4) 停止基準必須・非破壊デフォルト等の安全規約の反映漏れ。\n' +
    'BLOCKER が 0 件なら status=APPROVE、1 件以上なら status=REQUEST_CHANGES として findings に列挙すること。嗜好レベルの指摘は NOTE に留める。';
}

function fixPrompt(c, review) {
  return 'Spec Review で REQUEST_CHANGES となりました。以下の findings を openspec/changes/' + c.name + '/ のドキュメントに反映して修正してください。\n' +
    'findings: ' + JSON.stringify(review.findings) + '\n' +
    'リポジトリ: ' + ROOT + '。plan.md: ' + RUN_DIR + '/plan.md（「' + c.planKey + '」）。\n' +
    '修正後に openspec validate --strict ' + c.name + ' を再実行して PASS を確認すること。git commit はしない。\n' +
    '完了したら StructuredOutput で change 名・validate 結果・capability 一覧・Scenario 総数を返すこと。';
}

phase('Spec');

const results = await pipeline(
  changes,
  (c) => agent(authorPrompt(c), { label: 'author:' + c.name, phase: 'Spec', schema: authorSchema }),
  (authored, c) => {
    if (!authored || !authored.validated) {
      log('author:' + c.name + ' が validate PASS を返さなかった（authored=' + JSON.stringify(authored) + '）');
    }
    return agent(reviewPrompt(c, false), { label: 'spec-review:' + c.name, phase: 'Spec', agentType: 'longrun:longrun-reviewer', schema: reviewerSchema })
      .then((review) => ({ authored: authored, review: review }));
  },
  async (res, c) => {
    if (res && res.review && res.review.status === 'REQUEST_CHANGES') {
      log('spec-review:' + c.name + ' REQUEST_CHANGES → 修正ラウンド 1 回');
      const fixed = await agent(fixPrompt(c, res.review), { label: 'spec-fix:' + c.name, phase: 'Spec', schema: authorSchema });
      const rereview = await agent(reviewPrompt(c, true), { label: 'spec-rereview:' + c.name, phase: 'Spec', agentType: 'longrun:longrun-reviewer', schema: reviewerSchema });
      return { change: c.name, authored: fixed, review: rereview, fixRounds: 1 };
    }
    return { change: c.name, authored: res ? res.authored : null, review: res ? res.review : null, fixRounds: 0 };
  }
);

phase('Guide');

const guide = await agent(
  'verification-guide.md を生成してください。\n' +
  '入力: ' + ROOT + '/openspec/changes/{loops-plugin,skill-verification,goal-time-recipes,proactive-routines,loops-integration}/specs/**/spec.md の全 Scenario。\n' +
  '出力: ' + RUN_DIR + '/verification-guide.md（上書き作成）。\n' +
  '形式は過去 run の ' + ROOT + '/_longruns/2026-06-12_harness-workflow-overhaul/verification-guide.md に合わせる:\n' +
  '- 冒頭に「## 環境」節（対象は CLI プラグイン、テストコマンド find plugins -name *.bats | xargs bats、構文検証 jq / node --check）\n' +
  '- change ごとに「## <change名>」節\n' +
  '- Scenario ごとに「### S<通し番号>: [<capability>] <タイトル>」、WHEN / THEN 行、そして 4 つのチェックボックス「- [ ] テスト実装完了」「- [ ] ロジック実装完了」「- [ ] 動作確認完了」「- [ ] ユーザー確認完了」\n' +
  '通し番号は全 change を通して S1 から連番にする。Scenario の内容は spec.md から忠実に転記する（要約で情報を落とさない）。\n' +
  '完了したら StructuredOutput で written と Scenario 総数を返すこと。',
  { label: 'verification-guide', phase: 'Guide', schema: guideSchema }
);

return {
  phase: 'SpecPrep',
  timestamp: args.timestamp,
  changes: results,
  guide: guide,
};
