#!/usr/bin/env node
// render-workflow.mjs — Workflow スクリプトテンプレートの埋め込みポイントを置換して
// 具体的な実行スクリプトを生成する参照実装。
//
// exec コマンドは概念的にこれと同じ置換を行う（exec.md に手順を記述）。本スクリプトは
// bats 静的検証（生成後スクリプトの禁止 API 不使用・schema インライン・上限 3 等）の素材を
// 決定論的に作るためにも使う。Date.now() / Math.random() を使わない（テンプレート規律を
// レンダラ自身も守る）。
//
// 使い方:
//   node render-workflow.mjs <template.js> <params.json> > out.js
//
// params.json の例（build-verify 用）:
//   {
//     "RUN_DIR": "/abs/_longruns/2026-...",
//     "PROJECT_ROOT": "/abs",
//     "CHANGES_JSON": "[{\"name\":\"c1\",\"worktree\":\"_worktrees/c1\",\"dependsOn\":[]}]",
//     "BUILDER_AGENT_TYPE": "longrun:longrun-builder",
//     "VERIFIER_AGENT_TYPE": "longrun:longrun-verifier",
//     "BUILDER_SCHEMA": "<schema json string>",
//     "VERIFIER_SCHEMA": "<schema json string>"
//   }

import { readFileSync } from 'node:fs';

function die(msg) {
  process.stderr.write(`render-workflow: ${msg}\n`);
  process.exit(1);
}

const [, , templatePath, paramsPath] = process.argv;
if (!templatePath || !paramsPath) {
  die('usage: render-workflow.mjs <template.js> <params.json>');
}

const template = readFileSync(templatePath, 'utf8');
const params = JSON.parse(readFileSync(paramsPath, 'utf8'));

// __NAME__ 形式の埋め込みポイントを params[NAME] で置換する。
// （${NAME} 形式は JS テンプレートリテラルの補間 ${round} 等と衝突するため使わない。）
// 置換値が未指定の埋め込みポイントが残ったらエラー（推測値の混入を防ぐ）。
//
// 例外: モデル割り当て（change-4）の __*_MODEL__ 系は未指定なら 'null' を既定値にする。
// inherit（model 未指定 = opts.model キーを出力しない）が安全側のデフォルトであり（D2/D5）、
// モデル割り当て表の無い旧 plan.md でも render が落ちないようにするため（受け入れ条件 14）。
let rendered = template.replace(/__([A-Z][A-Z0-9_]*)__/g, (whole, key) => {
  if (!(key in params)) {
    if (/_MODEL$/.test(key)) {
      return 'null';
    }
    die(`missing param for placeholder __${key}__`);
  }
  return params[key];
});

const leftover = rendered.match(/__[A-Z][A-Z0-9_]*__/);
if (leftover) {
  die(`unresolved placeholder remains: ${leftover[0]}`);
}

process.stdout.write(rendered);
