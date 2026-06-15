#!/usr/bin/env node
// validate-against-schema.mjs — 成果物 JSON が schema に適合するかを検証する最小バリデータ。
//
// Workflow ツールの agent(prompt, {schema}) は内部で StructuredOutput を検証し、不適合は
// モデルにリトライさせる（散文の無言受理を起こさない）。本スクリプトはその検証層が「不正形式を
// 確かに拒否する」ことを bats（受け入れ条件 8a / spec「不正形式の成果物が機構的に拒否される」）で
// 機械検証するための、同等の検証ロジック。外部依存なし。Date.now()/Math.random() 不使用。
//
// 対応する JSON Schema 機能: type / enum / required / additionalProperties:false /
//   minimum / maximum / pattern / items / properties / minItems。
// 適合なら exit 0、不適合なら違反内容を stderr に出して exit 1。
//
// 使い方: node validate-against-schema.mjs <schema.json> <instance.json>

import { readFileSync } from 'node:fs';

const errors = [];

function typeOf(v) {
  if (v === null) return 'null';
  if (Array.isArray(v)) return 'array';
  if (Number.isInteger(v)) return 'integer';
  return typeof v; // 'number' | 'string' | 'boolean' | 'object'
}

function matchesType(v, t) {
  if (t === 'integer') return Number.isInteger(v);
  if (t === 'number') return typeof v === 'number';
  return typeOf(v) === t;
}

function validate(schema, value, path) {
  if (schema.type) {
    if (!matchesType(value, schema.type)) {
      errors.push(`${path}: expected type ${schema.type}, got ${typeOf(value)}`);
      return; // 型が違えば以降の制約は無意味
    }
  }

  if (schema.enum && !schema.enum.includes(value)) {
    errors.push(`${path}: value ${JSON.stringify(value)} not in enum ${JSON.stringify(schema.enum)}`);
  }

  if (typeof value === 'number') {
    if (schema.minimum !== undefined && value < schema.minimum) {
      errors.push(`${path}: ${value} < minimum ${schema.minimum}`);
    }
    if (schema.maximum !== undefined && value > schema.maximum) {
      errors.push(`${path}: ${value} > maximum ${schema.maximum}`);
    }
  }

  if (typeof value === 'string' && schema.pattern) {
    if (!new RegExp(schema.pattern).test(value)) {
      errors.push(`${path}: "${value}" does not match pattern ${schema.pattern}`);
    }
  }

  if (schema.type === 'object' && typeOf(value) === 'object') {
    const props = schema.properties || {};
    for (const req of schema.required || []) {
      if (!(req in value)) {
        errors.push(`${path}: missing required property "${req}"`);
      }
    }
    for (const key of Object.keys(value)) {
      if (key in props) {
        validate(props[key], value[key], `${path}.${key}`);
      } else if (schema.additionalProperties === false) {
        errors.push(`${path}: additional property "${key}" not allowed`);
      }
    }
  }

  if (schema.type === 'array' && Array.isArray(value)) {
    if (schema.minItems !== undefined && value.length < schema.minItems) {
      errors.push(`${path}: array length ${value.length} < minItems ${schema.minItems}`);
    }
    if (schema.items) {
      value.forEach((item, idx) => validate(schema.items, item, `${path}[${idx}]`));
    }
  }
}

const [, , schemaPath, instancePath] = process.argv;
if (!schemaPath || !instancePath) {
  process.stderr.write('usage: validate-against-schema.mjs <schema.json> <instance.json>\n');
  process.exit(2);
}

const schema = JSON.parse(readFileSync(schemaPath, 'utf8'));
const instance = JSON.parse(readFileSync(instancePath, 'utf8'));

validate(schema, instance, '$');

if (errors.length > 0) {
  process.stderr.write(errors.join('\n') + '\n');
  process.exit(1);
}
process.exit(0);
