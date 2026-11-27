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


def original_path(path, aliases):
    # Before #1690 extracted the shared conditions, they were part of pass.md.
    if path == 'skills/develop/references/epic-delegation.md':
        return budget.GATE + 'stages/pass.md'
    name = Path(path).stem
    if name not in aliases:
        return path
    old = aliases[name]
    if old == 'gate-runner':
        return budget.COMMON[0]
    return budget.GATE + ('declarations.md' if old == 'declarations'
                          else 'stages/' + old + '.md')


def compare(root):
    after = budget.measure(root)
    fixtures = root / 'tests/fixtures/gate-contracts'
    aliases = json.loads((fixtures / 'prose.json').read_text())['aliases']
    plan = budget.plans()
    result = {}
    # Per-file breakdown: profile -> (before files, after files) and file -> chars.
    files = {'before': {}, 'after': {}, 'claude': {}, 'codex': {}}
    after_read = lambda name: (root / budget.PLUGIN / name).read_bytes().decode('utf-8')

    def git_source(name):
        return subprocess.check_output(
            ['git', '-C', str(root), 'show', REVISION + ':' + str(budget.PLUGIN / name)])

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
            return (plugin / name).read_bytes().decode('utf-8')

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
                original_path(p, aliases) for p in paths
                if stage != 'legacy-all' or p != budget.GATE + 'SKILL.md'])
            before_claude = ''.join(read(p) for p in sorted(claude_paths))
            after_paths = set(['agents/gate-runner.md'] + budget.COMMON + paths)
            if stage == 'legacy-all':
                after_paths.discard(budget.GATE + 'SKILL.md')
            files['claude'][key] = (sorted(claude_paths), sorted(after_paths))
            for p in claude_paths:
                files['before'][p] = len(read(p))
            for p in after_paths:
                files['after'][p] = len(after_read(p))
            # The profile total is exactly the sum of its distinct files.
            assert sum(files['before'][p] for p in claude_paths) == len(before_claude), key
            assert sum(files['after'][p] for p in after_paths) == len(after['claude/' + key]), key
            extra = {original_path(p, aliases) for p in paths} - injected
            if stage == 'review':
                extra.discard(budget.GATE + 'stages/review-run.md')
            before_codex = prompt + ''.join(read(p) for p in sorted(extra))
            files['codex'][key] = {'before_injected': sorted(injected), 'before_extra': sorted(extra),
                                   'before_prompt': len(prompt)}
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
    after_prompts = {}
    adapter = budget.load_adapter(root)
    for stage in [*budget.BASE, 'legacy-all']:
        phase = 'review' if stage == 'review' else 'gate'
        request = 'Dispatch HEAD: e10f0a9896d82d0b86c0f7a10becb70c4983bc63\nレビュー経路: '
        request += ('従来' if stage == 'legacy-all' else 'adapter') + '\n'
        if stage != 'review':
            request += '段: ' + ('一括（従来経路）' if stage == 'legacy-all'
                                else budget.STAGES[stage]) + '\n'
        prompt = adapter.prompt(phase, request, {'cwd': '/gate-reading-fixture'},
                                plugin_root='/gate-reading-plugin-fixture')
        after_prompts[stage] = (len(prompt), sorted({m[1] for m in budget.HEADER.finditer(prompt)}))
    files['after_prompts'] = after_prompts
    files['head'] = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
    return result, plan, files


def render_files(result, plan, files):
    short = lambda p: p.replace(budget.GATE, '')
    common = ['agents/gate-runner.md'] + budget.COMMON
    lines = [
        'ファイル別内訳: before は固定 main `' + REVISION + '`、after は HEAD `' + files['head'] + '`。'
        '字数は物理ファイルを UTF-8 で decode した文字数（`LC_ALL=en_US.UTF-8 wc -m` と同じ値）。'
        '同じ profile の中で同じファイルは一度だけ数える。hook の注入（SessionStart 等）は数えない。',
        '', '共通 3 本（Claude の全 profile に入る）:', '',
        '| ファイル | before | after |', '|---|---:|---:|',
    ]
    for p in common:
        lines.append(f"| {p} | {files['before'][p]:,} | {files['after'][p]:,} |")
    for stage in budget.BASE:
        before, after = files['claude'][stage]
        lines += ['', f'Claude 基礎 `{stage}`（共通 3 本を除くファイル）:', '',
                  '| before のファイル | 字数 | after のファイル | 字数 |', '|---|---:|---|---:|']
        b = [p for p in before if p not in common]
        a = [p for p in after if p not in common]
        for i in range(max(len(b), len(a))):
            cb = f"{short(b[i])} | {files['before'][b[i]]:,}" if i < len(b) else ' | '
            ca = f"{short(a[i])} | {files['after'][a[i]]:,}" if i < len(a) else ' | '
            lines.append(f'| {cb} | {ca} |')
        value = result['claude/' + stage]
        lines.append(f"| 合計（共通 3 本を含む） | {value['before'][0]:,} | | {value['after'][0]:,} |")
    lines += ['', 'Claude 条件別 profile の基礎との差分（after で足すファイル。before は移動元のファイルで、'
              '基礎に含まれていれば増えない）:', '',
              '| profile | after で足すファイル（字数） | before で足すファイル |', '|---|---|---|']
    for key in plan:
        if key.startswith('legacy-') or key in budget.BASE:
            continue
        stage = key.split('-', 1)[0]
        add_a = [p for p in files['claude'][key][1] if p not in files['claude'][stage][1]]
        add_b = [p for p in files['claude'][key][0] if p not in files['claude'][stage][0]]
        cell_a = '、'.join(f"{short(p)}（{files['after'][p]:,}）" for p in add_a) or 'なし'
        cell_b = '、'.join(short(p) for p in add_b) or 'なし（基礎に含まれる）'
        lines.append(f'| {key} | {cell_a} | {cell_b} |')
    lines += ['', 'Codex（Claude とは別。固定 REQUEST・cwd `/gate-reading-fixture`、after は固定 Plugin root '
              '`/gate-reading-plugin-fixture` で生成した prompt。prompt には定型文・REQUEST・ヘッダー・sha256 と注入した正本本文が入る）:', '',
              '| 基礎 | before prompt | before に注入した正本 | after prompt | after に注入した正本 |',
              '|---|---:|---|---:|---|']
    for stage in [*budget.BASE, 'legacy-all']:
        c = files['codex'][stage]
        n, inj = files['after_prompts'][stage]
        lines.append(f"| {stage} | {c['before_prompt']:,} | {'、'.join(short(p) for p in c['before_injected'])} | "
                     f"{n:,} | {'、'.join(short(p) for p in inj)} |")
    lines += ['', 'Codex の条件付き追加読込は prompt に注入されないファイルだけを数える（下の表の before追加・after追加）。']
    return '\n'.join(lines)


def render(result, plan):
    lines = [
        '字数は UTF-8 の文字数（Python len、wc -m 相当）。同じファイルは一度だけ。'
        'before は固定 main `' + REVISION + '` から実測。'
        '共有 `skills/develop/references/epic-delegation.md` は before では `stages/pass.md` に内包されていた条件に対応させる。'
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
    result, plan, files = compare(Path(sys.argv[1] if len(sys.argv) > 1 else '.').resolve())
    print(render(result, plan))
    print()
    print(render_files(result, plan, files))
