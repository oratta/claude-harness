"""Registration coverage only: never execute hooks or prove the meaning of reasons."""
from collections import Counter
import html
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
DOC = Path('plugins/dev-workflow/docs/codex-hook-inventory.md')
GUIDE = DOC.with_name('codex-develop.md')
CHANGE = Path('plugins/dev-workflow/changes/1858.md')
PLUGINS = ('dev-workflow', 'capability-registry')
COLUMNS = ('plugin', 'event', 'matcher', 'command', '方針', '現状', '入力・出力依存',
           '理由', 'ソース根拠', '載せ替え先・後続', 'Codex 本体', 'native subagent', 'codex-worker.py')
POLICIES = {'Codex で動く', '載せ替える', 'Codex では持たない'}


def cells(line):
    return [html.unescape(c.strip().strip('`')) for c in line.strip().strip('|').split('|')]


def validate(root):
    """Return diagnostics; the CLI exposes them as a nonzero exit status."""
    errors, expected, rows = [], [], []
    for plugin in PLUGINS:
        data = json.loads((root / f'plugins/{plugin}/hooks/hooks.json').read_text())
        for event, groups in data['hooks'].items():
            for group in groups:
                for hook in group['hooks']:
                    expected.append((plugin, event, group.get('matcher', ''), hook['command']))
    lines = (root / DOC).read_text().splitlines()
    header_seen = False
    for number, line in enumerate(lines, 1):
        if not line.startswith('|'):
            continue
        row = cells(line)
        if row == list(COLUMNS):
            header_seen = True
            continue
        if all(re.fullmatch(r':?-+:?', cell) for cell in row):
            continue
        if len(row) != len(COLUMNS):
            errors.append(f'line {number}: required columns: {row!r}')
            continue
        key = tuple(row[:4])
        rows.append(key)
        if row[4] not in POLICIES or any(not c for i, c in enumerate(row) if i != 2):
            errors.append(f'line {number}: invalid policy/empty required cell: {key!r}')
        if not re.search(r'plugins/[^ :`]+:\d+-\d+', row[8]):
            errors.append(f'line {number}: source path and range required: {key!r}')
    if not header_seen:
        errors.append('missing inventory header')
    for name, keys in (('hooks.json', expected), ('inventory', rows)):
        errors.extend(f'{name}: duplicate {key!r}' for key, n in Counter(keys).items() if n > 1)
    errors.extend(f'missing: {key!r}' for key in (Counter(expected) - Counter(rows)).elements())
    errors.extend(f'stale: {key!r}' for key in (Counter(rows) - Counter(expected)).elements())
    return errors


class InventoryTests(unittest.TestCase):
    def test_repository_coverage(self):
        self.assertEqual(validate(ROOT), [])

    def test_reference_contract_and_change_record(self):
        guide = (ROOT / GUIDE).read_text()
        self.assertIn('](codex-hook-inventory.md)', guide)
        self.assertTrue((ROOT / GUIDE.parent / 'codex-hook-inventory.md').is_file())
        doc = (ROOT / DOC).read_text()
        self.assertIn('#1856 A1', doc)
        self.assertIn('この一覧を参照し、複製しない', doc)
        self.assertTrue((ROOT / CHANGE).is_file())

    def test_isolated_probe_preparation(self):
        # Execute the published preparation only; no Codex/auth or denied commands.
        doc = (ROOT / DOC).read_text()
        self.assertIn('<!-- codex-hook-probe-preparation -->', doc)
        block = doc.split('<!-- codex-hook-probe-preparation -->', 1)[1]
        script = block.split('```sh\n', 1)[1].split('```', 1)[0]
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(['/bin/sh', '-eu'], input=script, text=True,
                                    capture_output=True,
                                    env={'PATH': '/usr/bin:/bin', 'TMPDIR': directory,
                                         'GIT_CONFIG_COUNT': '1',
                                         'GIT_CONFIG_KEY_0': 'url.invalid.insteadOf',
                                         'GIT_CONFIG_VALUE_0': '/'})
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            probes = list(Path(directory).glob('codex-hook-probe.*'))
            self.assertEqual(len(probes), 1)
            probe = probes[0]
            self.assertTrue((probe / 'codex-home').is_dir())
            self.assertFalse((probe / 'codex-home/auth.json').exists())
            self.assertTrue((probe / 'feature/.git').is_file())
            self.assertEqual((probe / 'before.txt').read_bytes(),
                             (probe / 'after.txt').read_bytes())
            self.assertIn('refs/heads/probe-feature', (probe / 'before.txt').read_text())

    def test_counterexamples_and_semantic_limit(self):
        # Each input is a fresh repository-external copy, without auth or execution.
        cases = ('row_removed', 'registration_added', 'registration_removed', 'event',
                 'matcher', 'command', 'duplicate_row', 'duplicate_registration',
                 'policy', 'unrelated_reason', *('empty_' + c for c in COLUMNS if c != 'matcher'))
        for case in cases:
            with self.subTest(case=case), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                for rel in (DOC, *(Path(f'plugins/{p}/hooks/hooks.json') for p in PLUGINS)):
                    (root / rel).parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(ROOT / rel, root / rel)
                path = root / DOC
                lines = path.read_text().splitlines()
                # Delete only one event of a script registered twice.
                index = next(i for i, line in enumerate(lines)
                             if line.startswith('| `dev-workflow`') and '`PostToolUse`' in line)
                row = cells(lines[index])
                if case == 'row_removed':
                    lines.pop(index)
                elif case == 'duplicate_row':
                    lines.append(lines[index])
                elif case == 'policy' or case.startswith('empty_') or case == 'unrelated_reason':
                    column = '方針' if case == 'policy' else '理由' if case == 'unrelated_reason' else case[6:]
                    row[COLUMNS.index(column)] = ('unknown' if case == 'policy' else
                                                  '今日は晴れです' if case == 'unrelated_reason' else '')
                    lines[index] = '| ' + ' | '.join('`' + c.replace('|', '&#124;') + '`' for c in row) + ' |'
                else:
                    hooks_path = root / 'plugins/dev-workflow/hooks/hooks.json'
                    data = json.loads(hooks_path.read_text())
                    groups = data['hooks']['PostToolUse']
                    if case == 'registration_added':
                        data['hooks']['NewEvent'] = groups
                    elif case == 'registration_removed':
                        del data['hooks']['PostToolUse']
                    elif case == 'duplicate_registration':
                        groups[0]['hooks'].append(dict(groups[0]['hooks'][0]))
                    elif case == 'event':
                        data['hooks']['ChangedEvent'] = data['hooks'].pop('PostToolUse')
                    elif case == 'matcher':
                        groups[0]['matcher'] = 'ChangedMatcher'
                    elif case == 'command':
                        groups[0]['hooks'][0]['command'] += ' --changed'
                    hooks_path.write_text(json.dumps(data))
                path.write_text('\n'.join(lines) + '\n')
                result = subprocess.run([sys.executable, __file__, '--check-root', str(root)],
                                        capture_output=True, text=True)
                if case == 'unrelated_reason':
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                else:
                    self.assertNotEqual(result.returncode, 0, case)
                    self.assertTrue(result.stdout.strip(), result.stderr)


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--check-root':
        try:
            diagnostics = validate(Path(sys.argv[2]))
        except (OSError, ValueError, KeyError) as error:
            diagnostics = [str(error)]
        print('\n'.join(diagnostics))
        sys.exit(bool(diagnostics))
    unittest.main()
