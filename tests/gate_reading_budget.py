"""Byte budgets for file reads and actual Codex prompts (no model invocation).

Input: explicit plans, source bodies and budgets. Catch excess, missing files,
incomplete inventories and malformed prompts. Equal-size prose substitutions,
wrong natural-language conditions and unreachable rules still require review.
Fixed REQUEST excludes variable PR bodies/logs; this is no total-token guarantee.
"""
import hashlib
import importlib.util
import json
import re
import shutil
import sys
import tempfile
from pathlib import Path

PLUGIN = Path('plugins/dev-workflow')
GATE = 'skills/pr-review-gate/'
EXTERNAL = ['skills/develop/references/epic-delegation.md']
COMMON = ['skills/develop/references/roles/gate-runner.md',
          'skills/develop/references/return-declaration.md']
BASE = {
    'prepare': ['stages/prepare.md'],
    'review': ['stages/review-run.md', 'stages/reviewer-brief.md'],
    'triage': ['stages/triage.md'],
    'pass': ['declarations.md', 'stages/pass.md'],
    'hold': ['stages/hold.md'],
}
# Each condition is a union: multiple references to the same file count once.
CONDITIONS = {
    'prepare': {
        'light': ['prepare-light'], 'partitions': ['prepare-partitions'],
        'reviewer': ['prepare-reviewer'], 'rereview': ['triage-convergence'],
        'approval-wait': ['hold', 'hold-categories'],
    },
    'review': {
        'fallback': ['prepare-reviewer'], 'partitions': ['prepare-partitions'],
        'summary': ['gate-triage'], 'comments': ['gate-triage', 'comment-parts'],
    },
    'triage': {
        'summary': ['gate-triage'],
        'partitions': ['gate-triage', 'gate-triage-partitions'],
        'supplement': ['gate-triage', 'prepare-reviewer'],
        'comments': ['gate-triage', 'comment-parts'],
        'row3': ['triage-row3', 'prepare'],
        'nonblocking': ['triage-nonblocking'],
        'epic': ['triage-nonblocking', 'triage-epic'],
        'convergence': ['triage-convergence'], 'failed': ['triage-escalation'],
    },
    'pass': {
        'issue-approved': ['issue-approved', 'authenticity-conversation'],
        'carryover': ['hold', 'carryover', 'authenticity'],
        'judge': ['hold', 'carryover', 'carryover-judge', 'authenticity'],
        'no-point': ['hold', 'no-point-check'],
        'risk-link': ['hold', 'authenticity'],
        'risk-conversation': ['hold', 'authenticity', 'authenticity-conversation'],
        'risk-relayed': ['hold', 'authenticity', 'authenticity-relayed'],
        'risk-delegated': ['hold', 'authenticity', 'authenticity-relayed', 'authenticity-delegated', *EXTERNAL],
        'wording': ['pass-wording'],
    },
    'hold': {
        'carryover': ['carryover', 'authenticity'],
        'judge': ['carryover', 'carryover-judge', 'authenticity'],
        'no-point': ['no-point-check'], 'resume': ['hold-resume'],
        'categories': ['hold-categories'],
        'split': ['hold-resume', 'triage-nonblocking', 'triage-epic'],
    },
}
# The unsuffixed route is the ordinary GitHub-link answer. Other formats
# read only their own authenticity details; max/legacy use the same union.
for stage in ['pass', 'hold']:
    for route in ['carryover', 'judge']:
        for form, details in {
            'conversation': ['authenticity-conversation'],
            'relayed': ['authenticity-relayed'],
            'delegated': ['authenticity-relayed', 'authenticity-delegated', *EXTERNAL],
        }.items():
            CONDITIONS[stage][route + '-' + form] = CONDITIONS[stage][route] + details

STAGES = dict(zip(['prepare', 'triage', 'pass', 'hold'],
                 ['前提確認と重さ判定', '照合と振り分け', '合格処理', '保留の解除']))
LEGACY = ['SKILL.md', 'declarations.md'] + ['stages/' + n + '.md' for n in
    ['prepare', 'review-run', 'reviewer-brief', 'triage', 'pass', 'hold']]
HEADER = re.compile(r'\n\nCANONICAL SOURCE (\S+) sha256=([0-9a-f]{64})\n')


def load_adapter(root):
    spec = importlib.util.spec_from_file_location('gate_budget_adapter',
                root / PLUGIN / 'scripts/codex-develop.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def verify_prompt(text, expected, read):
    matches = list(HEADER.finditer(text))
    names = [m[1] for m in matches]
    assert len(names) == len(set(names)), ('duplicate source', names)
    assert set(names) == set(expected), ('source set', names, expected)
    for i, match in enumerate(matches):
        body = text[match.end():matches[i + 1].start() if i + 1 < len(matches) else len(text)]
        source = read(match[1])
        assert body == source, ('source body', match[1])
        assert hashlib.sha256(source.encode()).hexdigest() == match[2], ('sha256', match[1])
    return set(names)


def condition_path(name):
    # Bare names are gate stages; explicit paths are relative to Plugin root.
    return name if '/' in name else GATE + 'stages/' + name + '.md'


def plans():
    result = {}
    for stage, base in BASE.items():
        result[stage] = [GATE + p for p in base]
        for condition, names in CONDITIONS[stage].items():
            result[stage + '-' + condition] = result[stage] + [condition_path(n) for n in names]
        result[stage + '-max'] = sorted(set(p for key, paths in result.items()
            if key == stage or key.startswith(stage + '-') for p in paths))
    result['legacy-all'] = [GATE + p for p in LEGACY]
    all_details = sorted(set(p for paths in result.values() for p in paths))
    result['legacy-all-max'] = all_details
    # The legacy caller can encounter each conditional path as well.
    for stage in BASE:
        for condition in CONDITIONS[stage]:
            result['legacy-' + stage + '-' + condition] = result['legacy-all'] + result[stage + '-' + condition]
    return {k: sorted(set(v)) for k, v in result.items()}


def validate_inventory(root, plan):
    files = {str(p.relative_to(root / PLUGIN)) for p in (root / PLUGIN / GATE).rglob('*.md')}
    files.update(p for p in EXTERNAL if (root / PLUGIN / p).is_file())
    covered = set(p for paths in plan.values() for p in paths)
    assert files == covered, ('unmeasured/missing files', files - covered, covered - files)
    # Every planned detail must actually be referenced by a procedure (not only by the index).
    refs = '\n'.join(p.read_text() for p in (root / PLUGIN / GATE / 'stages').glob('*.md'))
    refs += (root / PLUGIN / COMMON[0]).read_text()
    detail = covered - {GATE + p for p in LEGACY}
    for path in detail:
        reference = path.removeprefix(GATE)
        assert '`' + reference + '`' in refs, ('unreferenced detail', path)
    gate = (root / PLUGIN / COMMON[0]).read_text()
    for stage in STAGES:
        # Split the row into columns first: the stage-name column has its own parentheses.
        row = next(line for line in gate.splitlines() if line.startswith('| ' + STAGES[stage]))
        cells = [c.strip() for c in row.strip().strip('|').split('|')]
        assert cells[0].startswith(STAGES[stage]), (stage, cells[0])
        reads = cells[1]
        before, _, inside = reads.partition('（')
        paths = lambda text: set(re.findall(r'`([^`]+\.md)`', text))
        # Unconditional reads are exactly BASE; conditional reads are a subset of CONDITIONS.
        assert paths(before) == set(BASE[stage]), ('base reads differ', stage, paths(before))
        allowed = {condition_path(n).removeprefix(GATE) for names in CONDITIONS[stage].values() for n in names}
        assert paths(inside) <= allowed, ('unknown conditional reads', stage, paths(inside) - allowed)


def measure(root, adapter=None):
    plan = plans()
    validate_inventory(root, plan)
    # Preserve physical line endings for wc -c equivalent file-read budgets.
    read = lambda name: (root / PLUGIN / name).read_bytes().decode('utf-8')
    adapter = adapter or load_adapter(root)
    prompts = {}
    for stage in BASE.keys() | {'legacy-all'}:
        phase = 'review' if stage == 'review' else 'gate'
        req = 'Dispatch HEAD: e10f0a9896d82d0b86c0f7a10becb70c4983bc63\nレビュー経路: '
        req += ('従来' if stage == 'legacy-all' else 'adapter') + '\n'
        if stage != 'review':
            req += '段: ' + ('一括（従来経路）' if stage == 'legacy-all' else STAGES[stage]) + '\n'
        expected = COMMON + ([GATE + 'stages/reviewer-brief.md'] if stage == 'review' else
            [GATE + p for p in LEGACY] if stage == 'legacy-all' else [GATE + p for p in BASE[stage]])
        prompt = adapter.prompt(phase, req, {'cwd': '/gate-reading-fixture'},
                                plugin_root='/gate-reading-plugin-fixture')
        injected = verify_prompt(prompt, expected, read)
        prompts[stage] = (prompt, injected)
    result = {}
    for key, paths in plan.items():
        stage = 'legacy-all' if key.startswith('legacy-') else key.split('-', 1)[0]
        prompt, injected = prompts[stage]
        claude_paths = sorted(set(['agents/gate-runner.md'] + COMMON + paths))
        # Claude's bulk comparison is declarations + six stages, as in design.
        # Codex additionally injects the index, verified above.
        if stage == 'legacy-all':
            claude_paths.remove(GATE + 'SKILL.md')
        result['claude/' + key] = ''.join(read(p) for p in claude_paths)
        # phase review injects reviewer-brief only. review-run is a caller-side file.
        extra = set(paths) - injected
        if stage == 'review':
            extra.discard(GATE + 'stages/review-run.md')
        result['codex/' + key] = prompt + ''.join(read(p) for p in sorted(extra))
    return result


def parse_budgets(text, expected):
    values = {}
    for line in text.splitlines():
        if line.startswith('#') or not line.strip():
            continue
        match = re.fullmatch(r'(\S+) ([1-9][0-9]*)', line)
        assert match, ('invalid budget', line)
        name, value = match.groups()
        assert name not in values, ('duplicate profile', name)
        values[name] = int(value)
    assert set(values) == set(expected), ('profile inventory', set(values) ^ set(expected))
    return values


def check(values, budgets):
    for name, text in values.items():
        actual = len(text.encode())
        budget = budgets[name]
        assert actual <= budget, (name, actual, budget, 'over budget')
        assert budget * 10 <= actual * 11, (name, actual, budget, 'more than 1.1x')


def must_fail(fn):
    try:
        fn()
    except (AssertionError, FileNotFoundError):
        return
    raise AssertionError('negative fixture unexpectedly passed')


def fixtures(root):
    values = {'profile': '日本語'}
    actual = len(values['profile'].encode())
    check(values, {'profile': actual})  # exact boundary
    must_fail(lambda: check(values, {'profile': actual - 1}))  # +1 byte
    must_fail(lambda: check(values, {'profile': actual * 2}))
    for malformed in ['unknown 9', '', 'profile 9\nprofile 9', 'profile NaN', 'profile -1', 'profile 0']:
        must_fail(lambda: parse_budgets(malformed, values))
    assert parse_budgets('profile 9', values) == {'profile': 9}
    body = '本文\n'; name = COMMON[0]
    prompt = '\n\nCANONICAL SOURCE ' + name + ' sha256=' + hashlib.sha256(body.encode()).hexdigest() + '\n' + body
    verify_prompt(prompt, [name], lambda _: body)
    for bad in ['', prompt + prompt, prompt.replace('本文', '別文'), prompt.replace('sha256=', 'sha256=0')]:
        must_fail(lambda: verify_prompt(bad, [name], lambda _: body))
    must_fail(lambda: verify_prompt(prompt, [], lambda _: body))
    with tempfile.TemporaryDirectory() as tmp:
        fixture = Path(tmp)
        shutil.copytree(root / PLUGIN / 'skills', fixture / PLUGIN / 'skills')
        shutil.copytree(root / PLUGIN / 'agents', fixture / PLUGIN / 'agents')
        # Reuse the real adapter code but read canonical sources in the fixture.
        adapter = load_adapter(root)
        adapter.ROOT = fixture / PLUGIN
        plan = plans()
        validate_inventory(fixture, plan)
        added = fixture / PLUGIN / GATE / 'stages/unmeasured.md'
        added.write_text('new conditional detail')
        must_fail(lambda: validate_inventory(fixture, plan))
        added.unlink()
        # The stage table must match BASE before its parenthesis and CONDITIONS inside it.
        runner = fixture / PLUGIN / COMMON[0]
        runner_text = runner.read_text()
        row = next(line for line in runner_text.splitlines() if line.startswith('| ' + STAGES['pass']))
        for changed in [
            row.replace('`stages/pass.md`', '`stages/pass.md` と `stages/pass-wording.md`', 1),
            row.replace('`declarations.md` と `stages/pass.md`（', '`declarations.md`（`stages/pass.md`、', 1),
            row.replace('`stages/carryover.md`', '`stages/carryover.md`・`stages/unknown-detail.md`', 1),
        ]:
            assert changed != row
            runner.write_text(runner_text.replace(row, changed))
            must_fail(lambda: validate_inventory(fixture, plan))
        runner.write_text(runner_text)
        validate_inventory(fixture, plan)
        # Issue approval reads the conversation detail for owner-reply-check results.
        conversation = condition_path('authenticity-conversation')
        issue_approved = {GATE + p for p in BASE['pass']} | {
            condition_path('issue-approved'), conversation}
        assert set(plan['pass-issue-approved']) == issue_approved
        assert set(plan['legacy-pass-issue-approved']) == set(plan['legacy-all']) | issue_approved
        for key in ['pass-issue-approved', 'legacy-pass-issue-approved',
                    'pass-max', 'legacy-all-max']:
            assert plan[key].count(conversation) == 1, key
        # Carryover/judge recheck the original answer in its own format.
        formats = {
            'conversation': ['authenticity-conversation'],
            'relayed': ['authenticity-relayed'],
            'delegated': ['authenticity-relayed', 'authenticity-delegated', *EXTERNAL],
        }
        for stage in ['pass', 'hold']:
            for route in ['carryover', 'judge']:
                base = stage + '-' + route
                for form, details in formats.items():
                    key = base + '-' + form
                    expected = set(plan[base]) | {condition_path(n) for n in details}
                    assert key in plan, ('missing answer-format profile', key)
                    assert set(plan[key]) == expected, key
                    assert set(plan['legacy-' + key]) == set(plan['legacy-all']) | expected, key
                for details in formats.values():
                    assert not set(plan[base]) & {condition_path(n) for n in details}, base
        initial_formats = measure(fixture, adapter)
        for detail in ['authenticity-conversation', 'authenticity-relayed',
                       'authenticity-delegated', *EXTERNAL]:
            path = condition_path(detail)
            target = fixture / PLUGIN / path
            body = target.read_bytes()
            target.write_bytes(body + b'x')
            grown_formats = measure(fixture, adapter)
            for key, value in initial_formats.items():
                profile = key.split('/', 1)[1]
                assert len(grown_formats[key].encode()) - len(value.encode()) == int(path in plan[profile]), key
            if detail == 'authenticity-conversation':
                for provider in ['claude', 'codex']:
                    for profile in ['pass-issue-approved', 'legacy-pass-issue-approved']:
                        key = provider + '/' + profile
                        limit = len(initial_formats[key].encode())
                        must_fail(lambda: check({key: grown_formats[key]}, {key: limit}))
            target.write_bytes(body)
        # Delegation reads a shared develop source, once per conditional union.
        delegation = 'skills/develop/references/epic-delegation.md'
        affected = {'pass-risk-delegated', 'pass-max',
                    'legacy-pass-risk-delegated', 'hold-max', 'legacy-all-max'}
        affected |= {prefix + stage + '-' + route + '-delegated'
                     for prefix in ['', 'legacy-'] for stage in ['pass', 'hold']
                     for route in ['carryover', 'judge']}
        assert {key for key, paths in plan.items() if delegation in paths} == affected
        for key in affected:
            assert plan[key].count(delegation) == 1, key
        delegated = fixture / PLUGIN / delegation
        delegated_body = delegated.read_bytes()
        initial = measure(fixture, adapter)
        limits = {key: len(value.encode()) for key, value in initial.items()}
        delegated.write_bytes(delegated_body + b'x')
        grown = measure(fixture, adapter)
        for key in initial:
            expected = int(key.split('/', 1)[1] in affected)
            assert len(grown[key].encode()) - limits[key] == expected, key
        must_fail(lambda: check(grown, limits))
        delegated.write_bytes(delegated_body)
        delegated.unlink()
        must_fail(lambda: validate_inventory(fixture, plan))
        delegated.write_bytes(delegated_body)
        detail = fixture / PLUGIN / GATE / 'stages/authenticity-delegated.md'
        detail_body = detail.read_text()
        assert '`' + delegation + '`' in detail_body
        detail.write_text(detail_body.replace('`' + delegation + '`', '`missing.md`'))
        must_fail(lambda: validate_inventory(fixture, plan))
        detail.write_text(detail_body)
        # The real adapter tells a worker how to resolve this explicit shared path.
        prompt = adapter.prompt('gate', '段: 合格処理', {'cwd': str(fixture)},
                                plugin_root=str(fixture / PLUGIN))
        assert '`skills/...` resolves to <Plugin root>/skills/...' in prompt
        assert (fixture / PLUGIN / delegation).is_file()
        # Fixed before predates the shared file: its delegation conditions lived in pass.md.
        import gate_reading_report as report
        aliases = json.loads((root / 'tests/fixtures/gate-contracts/prose.json').read_text())['aliases']
        assert report.original_path(delegation, aliases) == GATE + 'stages/pass.md'
        for key in affected:
            before = {report.original_path(p, aliases) for p in plan[key]}
            assert delegation not in before
            assert GATE + 'stages/pass.md' in before
            assert before == {report.original_path(p, aliases) for p in plan[key] if p != delegation}
        target = fixture / PLUGIN / GATE / 'stages/prepare-light.md'
        baseline = target.read_bytes()
        budgets = {k: len(v.encode()) for k, v in measure(fixture, adapter).items()}
        check(measure(fixture, adapter), budgets)
        # A CRLF is two physical bytes; universal-newline reads must not hide one.
        target.write_bytes(baseline + b'\r\n')
        must_fail(lambda: check(measure(fixture, adapter),
                                {name: limit + 1 for name, limit in budgets.items()}))
        target.write_bytes(baseline)
        # Corrupt real generated prompts through the same measurement entry point.
        original_prompt = adapter.prompt
        def corrupted_prompt(phase, instructions, state, **kwargs):
            return mutate(original_prompt(phase, instructions, state, **kwargs))
        for mutate in [
            lambda text: text[:list(HEADER.finditer(text))[-1].start()],
            lambda text: text + text[list(HEADER.finditer(text))[-1].start():],
            lambda text: text.replace('CANONICAL SOURCE ' + COMMON[0],
                                      'CANONICAL SOURCE extra.md', 1),
            lambda text: text[:-1] + 'x',
            lambda text: HEADER.sub(lambda m: m[0].replace(m[2], '0' * 64), text, count=1),
        ]:
            adapter.prompt = corrupted_prompt
            must_fail(lambda: measure(fixture, adapter))
        adapter.prompt = original_prompt
        # Bulk plans include hold via multiple conditions; it is still one read.
        assert plans()['legacy-pass-carryover'].count(GATE + 'stages/hold.md') == 1
        target.write_bytes(baseline + b'x')
        must_fail(lambda: check(measure(fixture, adapter), budgets))
        target.unlink()
        must_fail(lambda: measure(fixture, adapter))
        target.write_bytes(baseline)
        canonical = fixture / PLUGIN / COMMON[0]
        canonical.unlink()
        must_fail(lambda: measure(fixture, adapter))



def main():
    mode, root = sys.argv[1], Path(sys.argv[2]).resolve()
    if mode == 'fixtures':
        fixtures(root)
        return
    values = measure(root)
    if mode == 'measure':
        print(json.dumps({k: [len(v), len(v.encode())] for k, v in values.items()}, ensure_ascii=False, indent=2))
    else:
        budgets = parse_budgets((root / 'tests/gate-reading-budget.txt').read_text(), values)
        check(values, budgets)
        print(f'{len(values)} profiles: byte budgets and canonical inventories passed')


if __name__ == '__main__':
    main()
