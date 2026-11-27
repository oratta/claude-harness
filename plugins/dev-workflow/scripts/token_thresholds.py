"""Resolve bundled, evidence-bearing defaults without changing any hook state."""
import argparse
import copy
import json
import os
from pathlib import Path
import re
import sys

TABLE_PATH = Path(__file__).resolve().parent.parent / 'references/token-thresholds.json'
GUIDE = 'plugins/dev-workflow/skills/develop/references/token-thresholds.md'
METRICS = ('context_cap', 'context_hard_cap', 'pr_token_cap', 'epic_child_token_cap')
OVERRIDES = {
    'context_cap': 'DEV_WORKFLOW_CONTEXT_CAP',
    'context_hard_cap': 'DEV_WORKFLOW_CONTEXT_HARD_CAP',
    'pr_token_cap': 'DEV_WORKFLOW_PR_TOKEN_CAP',
}


def _load_table():
    try:
        table = json.loads(TABLE_PATH.read_text(encoding='utf-8'))
        if not isinstance(table, dict) or type(table.get('schema_version')) is not int or table['schema_version'] != 1:
            raise ValueError('expected schema_version 1')
        if not isinstance(table.get('models'), dict) or not table['models']:
            raise ValueError('models must be a nonempty object')
        rows = [table['fallback'], *table['models'].values()]
        if any(not isinstance(model, str) or not model for model in table['models']):
            raise ValueError('model IDs must be nonempty strings')
        for row in rows:
            if not isinstance(row, dict):
                raise ValueError('threshold row must be an object')
            for metric in METRICS:
                record = row[metric]
                if not isinstance(record, dict):
                    raise ValueError(f'{metric}: record must be an object')
                if type(record['value']) is not int or record['value'] < 0:
                    raise ValueError(f'{metric}: value must be a nonnegative integer')
                models = record['decided_models']
                if not isinstance(models, list) or not models or any(not isinstance(m, str) or not m.strip() for m in models):
                    raise ValueError(f'{metric}: decided_models must contain model IDs')
                for field in ('decided_at', 'evidence', 'source'):
                    if not isinstance(record[field], str) or not record[field].strip():
                        raise ValueError(f'{metric}: {field} must be nonempty')
        return table
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise ValueError(f'invalid_table: {error}') from error


def resolve_thresholds(model_id=None, environ=None):
    """Return JSON-compatible values and diagnostics; raise ValueError on bad input.

    An explicit environment mapping replaces os.environ. The baseline always
    describes the bundled evidence, including when an environment value wins.
    """
    table = _load_table()
    env = os.environ if environ is None else environ
    matched = model_id if model_id in table['models'] else None
    fallback = matched is None
    row = table['fallback'] if fallback else table['models'][matched]
    diagnostics = []
    label = model_id if model_id else '不明'
    if fallback:
        diagnostics.append(dict(code='unknown_model', requested_model=model_id,
                                message=f'unknown_model: {label}; fallback を使用'))
    thresholds = {}
    for metric in METRICS:
        baseline = copy.deepcopy(row[metric])
        item = dict(value=baseline['value'], source_kind='fallback' if fallback else 'model', baseline=baseline)
        if model_id not in baseline['decided_models']:
            diagnostics.append(dict(
                code='revalidation_required', requested_model=model_id,
                decided_models=baseline['decided_models'], metric=metric, guide=GUIDE,
                message=f'revalidation_required: {label}; 根拠モデル={baseline["decided_models"]}; 対象={metric}; 手順={GUIDE}'))
        name = OVERRIDES.get(metric)
        text = env.get(name, '') if name else ''
        if not isinstance(text, str):
            raise ValueError(f'invalid_override: {name}: ASCII 非負整数が必要')
        text = text.strip()
        if text:
            if not re.fullmatch(r'[0-9]+', text):
                raise ValueError(f'invalid_override: {name}: ASCII 非負整数が必要')
            try:
                item['value'] = int(text)
            except ValueError as error:
                raise ValueError(f'invalid_override: {name}: {error}') from error
            item['source_kind'] = 'environment'
        thresholds[metric] = item
    return dict(requested_model=model_id, matched_model=matched, fallback_used=fallback,
                revalidation_required=any(d['code'] == 'revalidation_required' for d in diagnostics),
                thresholds=thresholds, diagnostics=diagnostics)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model', help='effective fixed model ID (exact match)')
    args = parser.parse_args(argv)
    try:
        result = resolve_thresholds(args.model)
    except ValueError as error:
        message = str(error)
        print(json.dumps({'error': {'code': message.split(':', 1)[0], 'message': message}}, ensure_ascii=False))
        print(message, file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False))
    for diagnostic in result['diagnostics']:
        print(diagnostic['message'], file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main())
