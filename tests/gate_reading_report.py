"""Reproduce before/after tables from fixed main and the current checkout.

Run: python3 -B tests/gate_reading_report.py .
Requires the fixed main object locally. No model or remote service is invoked.
"""
import json
import subprocess
import sys
import tempfile
import types
from pathlib import Path

import gate_reading_budget as budget

REVISION = '0e7bf3f80d0241bd9582f7b89e5ec3f529f2139f'


def compare(root):
    after = budget.measure(root)
    fixtures = root / 'tests/fixtures/gate-contracts'
    aliases = json.loads((fixtures / 'prose.json').read_text())['aliases']
    plan = budget.plans()
    result = {}

    def git_source(name):
        return subprocess.check_output(
            ['git', '-C', str(root), 'show', REVISION + ':' + str(budget.PLUGIN / name)])

    def original_path(path):
        name = Path(path).stem
        if name not in aliases:
            return path
        old = aliases[name]
        if old == 'gate-runner':
            return budget.COMMON[0]
        return budget.GATE + ('declarations.md' if old == 'declarations'
                              else 'stages/' + old + '.md')

    with tempfile.TemporaryDirectory(prefix='gate-reading-report-') as tmp:
        plugin = Path(tmp) / budget.PLUGIN
        sources = budget.COMMON + ['agents/gate-runner.md']
        sources += [budget.GATE + p for p in budget.LEGACY]
        for name in sources:
            target = plugin / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(git_source(name))
        # Load the fixed adapter with local utility imports, then redirect canonical reads.
        budget.load_adapter(root)
        module = types.ModuleType('baseline_gate_adapter')
        module.__file__ = str(root / budget.PLUGIN / 'scripts/codex-develop.py')
        code = git_source('scripts/codex-develop.py').decode()
        exec(compile(code, module.__file__, 'exec'), module.__dict__)
        module.ROOT = plugin

        def read(name):
            return (plugin / name).read_text()

        for key, paths in plan.items():
            stage = 'legacy-all' if key.startswith('legacy-') else key.split('-', 1)[0]
            phase = 'review' if stage == 'review' else 'gate'
            request = 'Dispatch HEAD: e10f0a9896d82d0b86c0f7a10becb70c4983bc63\nレビュー経路: '
            request += ('従来' if stage == 'legacy-all' else 'adapter') + '\n'
            if stage != 'review':
                request += '段: ' + ('一括（従来経路）' if stage == 'legacy-all'
                                    else budget.STAGES[stage]) + '\n'
            prompt = module.prompt(phase, request, {'cwd': '/gate-reading-fixture'})
            injected = {m[1] for m in budget.HEADER.finditer(prompt)}
            claude_paths = set(['agents/gate-runner.md'] + budget.COMMON + [
                original_path(p) for p in paths
                if stage != 'legacy-all' or p != budget.GATE + 'SKILL.md'])
            before_claude = ''.join(read(p) for p in sorted(claude_paths))
            extra = {original_path(p) for p in paths} - injected
            if stage == 'review':
                extra.discard(budget.GATE + 'stages/review-run.md')
            before_codex = prompt + ''.join(read(p) for p in sorted(extra))
            for group, text in [('claude', before_claude), ('codex', before_codex)]:
                current = after[group + '/' + key]
                result[group + '/' + key] = {
                    'before': [len(text), len(text.encode())],
                    'after': [len(current), len(current.encode())],
                }
    # Independently reproduce the original comparison values before deriving new conditions.
    fixed = json.loads((fixtures / 'before.json').read_text())
    for key in [*budget.BASE, 'legacy-all']:
        assert result['claude/' + key]['before'] == fixed['claude'][key], key
    for key, name in {**budget.STAGES, 'review': 'review',
                      'legacy-all': '一括（従来経路）'}.items():
        assert result['codex/' + key]['before'] == fixed['codex'][name], key
    return result, plan


def render(result, plan):
    lines = [
        '字数は UTF-8 の文字数（Python len、wc -m 相当）。同じファイルは一度だけ。'
        'before は固定 main `' + REVISION + '` から実測。'
        'Codex は定型指示・固定 REQUEST・ヘッダー・sha256・正本本文を含む実際の prompt() 生成物。'
        '可変の PR 本文・結果・ログは予算外で、全実行の総トークン数の保証ではない。'
        '予算は UTF-8 バイト数、全 ' + str(len(result)) + ' profile を実測の1.0倍に設定。',
        '', 'Claude 基礎5場面・条件別（max は同じ段の全条件の和集合）:', '',
        '| profile | before | after |', '|---|---:|---:|',
    ]
    keys = [k for k in plan if not k.startswith('legacy-')] + ['legacy-all', 'legacy-all-max']
    for key in keys:
        value = result['claude/' + key]
        lines.append(f"| {key} | {value['before'][0]:,} | {value['after'][0]:,} |")
    lines += ['', 'Codex 固定生成 prompt（追加読込なし）:', '',
              '| profile | before | after |', '|---|---:|---:|']
    for key in [*budget.BASE, 'legacy-all']:
        value = result['codex/' + key]
        lines.append(f"| {key} | {value['before'][0]:,} | {value['after'][0]:,} |")
    lines += ['', 'Codex 条件付き追加読込（注入済みを除外。total は生成 prompt＋追加読込）:', '',
              '| profile | before追加 | after追加 | before total | after total |',
              '|---|---:|---:|---:|---:|']
    for key in keys:
        if key in budget.BASE or key == 'legacy-all':
            continue
        stage = 'legacy-all' if key.startswith('legacy-') else key.split('-', 1)[0]
        value, base = result['codex/' + key], result['codex/' + stage]
        lines.append(f"| {key} | {value['before'][0] - base['before'][0]:,} | "
                     f"{value['after'][0] - base['after'][0]:,} | "
                     f"{value['before'][0]:,} | {value['after'][0]:,} |")
    return '\n'.join(lines)


if __name__ == '__main__':
    print(render(*compare(Path(sys.argv[1] if len(sys.argv) > 1 else '.').resolve())))
