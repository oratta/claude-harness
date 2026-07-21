#!/usr/bin/env node
// resolve-model-allocation.mjs — plan.md の「モデル割り当て」表を読み、
// ティアを references/model-tiers.md で解決して change × role ごとの opts.model 値を出力する。
//
// exec コマンドはこのスクリプトを呼び出し、出力 JSON を render-workflow.mjs の
// MODEL_* 埋め込みポイントに渡す（exec.md 参照）。
//
// 設計（change-4 / design.md、longrun-exec-model-allocation で拡張）:
//   - ティア語彙は haiku / sonnet / fable / inherit の 4 値（D1）
//   - inherit = opts.model キーを出力しない（D2）→ model: null で表現する
//   - ティア → opts.model 値の解決は model-tiers.md の表 1 箇所のみ（D3）
//   - 上書き欄 > ティア欄（D4。上書き欄が非空ならそれを採用）
//   - 未知ティア・パース不能行は inherit + 警告で続行（D5 fail-soft）
//   - 「モデル割り当て」セクションが無い旧 plan.md は hasSection:false で全 inherit（D5 特殊ケース）
//   - reserve 降格: FABLE_BUDGET_MODE=reserve かつ LONGRUN_AUTOMATED=1 のとき
//     fable を 'opus' に降格 + 警告（実行は中断しない）。他ティアは影響を受けない
//
// 規律: Date.now() / Math.random() を使わない（テンプレート規律をスクリプトも守る）。
//
// 使い方:
//   node resolve-model-allocation.mjs <plan.md> <model-tiers.md> > allocations.json

import { readFileSync } from 'node:fs';

function die(msg) {
  process.stderr.write(`resolve-model-allocation: ${msg}\n`);
  process.exit(1);
}

const [, , planPath, tiersPath] = process.argv;
if (!planPath || !tiersPath) {
  die('usage: resolve-model-allocation.mjs <plan.md> <model-tiers.md>');
}

const plan = readFileSync(planPath, 'utf8');
const tiersDoc = readFileSync(tiersPath, 'utf8');

// --- ティア → opts.model 値の解決表を model-tiers.md から動的に組み立てる ---
// model-tiers.md の `| haiku | ... | `'haiku'` |` 形式の行から
// ティア名 → 渡し値（バッククォート内のエイリアス）を抽出する。inherit は「渡さない」なので null。
function buildTierMap(doc) {
  const map = { inherit: null };
  const lines = doc.split('\n');
  for (const line of lines) {
    if (!line.includes('|')) continue;
    const cells = line.split('|').map((c) => c.trim());
    // 期待: | ティア | 用途 | `'haiku'` |
    if (cells.length < 4) continue;
    const tierCell = cells[1].replace(/`/g, '').trim();
    const valCell = cells[3];
    if (tierCell !== 'haiku' && tierCell !== 'sonnet' && tierCell !== 'fable') continue;
    // バッククォートで囲まれたエイリアス値を取り出す
    const m = valCell.match(/`'([^']+)'`/);
    if (m) map[tierCell] = m[1];
  }
  // フォールバック（表が読めなかった場合でもティア名自体をエイリアスとして使う）
  if (!('haiku' in map) || map.haiku == null) map.haiku = 'haiku';
  if (!('sonnet' in map) || map.sonnet == null) map.sonnet = 'sonnet';
  if (!('fable' in map) || map.fable == null) map.fable = 'fable';
  return map;
}

const tierMap = buildTierMap(tiersDoc);
const KNOWN_TIERS = ['haiku', 'sonnet', 'fable', 'inherit'];

// reserve 降格（model-tiers.md「reserve 降格ルール」参照）:
// FABLE_BUDGET_MODE=reserve かつ LONGRUN_AUTOMATED=1（無人配線が設定）のときのみ発動。
const RESERVE_DOWNGRADE =
  process.env.FABLE_BUDGET_MODE === 'reserve' && process.env.LONGRUN_AUTOMATED === '1';

// --- plan.md から「モデル割り当て」セクションの表をパースする ---
const warnings = [];
const allocations = [];

// セクション見出し（## モデル割り当て）から次の同レベル以上の見出しまでを切り出す。
// （`m` フラグ + `$` は行末ごとにマッチして空捕捉になるため、行ベースで切り出す。）
const planLines = plan.split('\n');
const headingIdx = planLines.findIndex((l) => /^##+\s*モデル割り当て/.test(l));
const hasSection = headingIdx !== -1;
let body = '';
if (hasSection) {
  const rest = planLines.slice(headingIdx + 1);
  const endRel = rest.findIndex((l) => /^#+\s/.test(l));
  const sectionLines = endRel === -1 ? rest : rest.slice(0, endRel);
  body = sectionLines.join('\n');
}

if (hasSection) {
  const rows = body.split('\n').filter((l) => l.trim().startsWith('|'));
  for (const row of rows) {
    const cells = row.split('|').map((c) => c.trim());
    // | change | ロール | ティア | 理由 | 上書き |  → cells: ['', change, role, tier, reason, override, '']
    if (cells.length < 6) continue;
    const change = cells[1];
    const role = cells[2];
    const tierRaw = cells[3];
    const override = cells[5];

    // ヘッダ行・区切り行をスキップ
    if (change === 'change' || role === 'ロール') continue;
    if (/^:?-{2,}:?$/.test(change) || /^-+$/.test(change)) continue;
    if (!change || !role) continue;
    // プレースホルダ行（change-[A] のテンプレ例）はスキップ
    if (/\[[A-Z]\]/.test(change)) continue;

    // 上書き欄 > ティア欄（D4）
    const chosenRaw = override ? override : tierRaw;
    const chosen = chosenRaw.toLowerCase();

    let tier;
    if (KNOWN_TIERS.includes(chosen)) {
      tier = chosen;
    } else {
      // 未知ティア → inherit + 警告（D5 fail-soft）
      warnings.push(
        `未知のティア値「${chosenRaw}」（change=${change}, role=${role}）のため inherit として扱いました（unknown tier → inherit）`
      );
      tier = 'inherit';
    }

    let model = tier === 'inherit' ? null : tierMap[tier];
    if (tier === 'fable' && RESERVE_DOWNGRADE) {
      model = 'opus';
      warnings.push(
        `FABLE_BUDGET_MODE=reserve の自動実行のため fable を opus に降格しました（change=${change}, role=${role}）`
      );
    }
    allocations.push({ change, role, tier, model });
  }
}

process.stdout.write(
  JSON.stringify({ hasSection, allocations, warnings }, null, 2) + '\n'
);
