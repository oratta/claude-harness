"""Characterize request tuples, not coordinator-applied Claude budget caps (#613).

672 independently collected cases correspond to the rows in model-resolution-current.md.
Expected tuples are literals: never read the profile JSON to derive this oracle.
"""
import importlib.util
import itertools
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/codex-develop.py'
spec = importlib.util.spec_from_file_location('model_resolution_develop', SCRIPT)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

ROLES = ('spec-write', 'spec-review', 'implement', 'impl-review', 'review',
         'decider', 'explore', 'summarize')
# review is a compatibility alias for impl-review; there is no independent CLI phase.
PHASES = ('spec', 'spec-review', 'implement', 'review', 'review',
          'decider', 'explore', 'summarize')
FABLE_MODES = ('abundant', 'conserve', 'reserve', 'exhausted')
SHARED_MODES = ('ok', 'throttled', 'depleted')
EXPECTED = {
    'codex-standard': (
        ('codex', 'sol'), ('codex', 'sol'), ('codex', 'sol'), ('codex', 'sol'),
        ('codex', 'sol'), ('codex', 'astra'), ('codex', 'luna'), ('codex', 'luna')),
    'codex-economy': (
        ('codex', 'luna'), ('codex', 'sol'), ('codex', 'luna'), ('codex', 'sol'),
        ('codex', 'sol'), ('codex', 'astra'), ('codex', 'luna'), ('codex', 'luna')),
    'hybrid-standard': (
        ('codex', 'sol'), ('claude', 'opus'), ('codex', 'sol'), ('claude', 'opus'),
        ('claude', 'opus'), ('claude', 'fable'), ('codex', 'luna'), ('codex', 'luna')),
    'claude-write-codex-review': (
        ('claude', 'sonnet'), ('codex', 'sol'), ('claude', 'sonnet'), ('codex', 'sol'),
        ('codex', 'sol'), ('codex', 'astra'), ('claude', 'haiku'), ('claude', 'haiku')),
    'auto:claude-write-codex-review': (
        ('claude', 'sonnet'), ('codex', 'sol'), ('claude', 'sonnet'), ('codex', 'sol'),
        ('codex', 'sol'), ('codex', 'astra'), ('claude', 'haiku'), ('claude', 'haiku')),
    'auto:codex-standard': (
        ('codex', 'sol'), ('codex', 'sol'), ('codex', 'sol'), ('codex', 'sol'),
        ('codex', 'sol'), ('codex', 'astra'), ('codex', 'luna'), ('codex', 'luna')),
    'auto:claude-default': (
        ('claude', 'sonnet'), ('claude', 'opus'), ('claude', 'sonnet'), ('claude', 'opus'),
        ('claude', 'opus'), ('claude', 'fable'), ('claude', 'haiku'), ('claude', 'haiku')),
}
# Feed provider evidence to the real automatic selector (no network or personal usage).
MARGINS = {'auto:claude-write-codex-review': (20, 10),
           'auto:codex-standard': (-5, 30), 'auto:claude-default': (20, -5)}


class ModelResolutionCurrent(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Keep the independently collected cases and the documented triple rows aligned.
        document = SCRIPT.parents[1] / 'references/model-resolution-current.md'
        rows = [line.split('|')[1:4] for line in document.read_text().splitlines()
                if line.startswith('| ') and line.split('|')[1].strip() in ROLES
                and line.split('|')[2].strip() in EXPECTED]
        keys = [tuple(cell.strip() for cell in row) for row in rows]
        expected_keys = {(role, config, f'{fable}/{shared}') for role, config, fable, shared
                         in itertools.product(ROLES, EXPECTED, FABLE_MODES, SHARED_MODES)}
        assert len(keys) == 672 and set(keys) == expected_keys
        assert ROLES == m.CANONICAL_ROLES
        cls.temp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.temp.cleanup)
        cls.root = Path(cls.temp.name).resolve()
        cls.cwd = cls.root / 'repo'
        cls.cwd.mkdir()
        subprocess.run(['git', 'init', '-q', str(cls.cwd)], check=True)
        subprocess.run(['git', '-C', str(cls.cwd), '-c', 'user.name=Test',
                        '-c', 'user.email=test@example.invalid', 'commit',
                        '--allow-empty', '-qm', 'fixture'], check=True)
        cls.home = cls.root / 'home'
        cls.home.mkdir()
        cls.instructions = cls.root / 'input.txt'
        cls.instructions.write_text('Characterization only.')


def case(configuration, index, fable, shared, expected):
    def test(self):
        out = self.root / 'request.json'
        if out.exists():
            out.unlink()
        args = [str(SCRIPT), 'request', '--phase', PHASES[index],
                '--input', str(self.instructions), '--cwd', str(self.cwd),
                '--account-home', 'current=' + str(self.home), '--out', str(out)]
        automatic = configuration.startswith('auto:')
        selected = configuration.removeprefix('auto:')
        if not automatic:
            args.extend(['--profile', configuration])
        claude_margin, codex_margin = MARGINS.get(configuration, (20, 10))
        with patch.dict(os.environ, {'FABLE_BUDGET_MODE': fable,
                                     'SHARED_BUDGET_MODE': shared,
                                     'CLAUDE_CONFIG_DIR': str(self.root)}, clear=True), \
                patch.object(sys, 'argv', args), \
                patch.object(m, '_run_usage_probe'), \
                patch.object(m, 'claude_usage_evidence', return_value={
                    'account': 'fixture', 'margin': claude_margin, 'fetched_at': 1}), \
                patch.object(m, 'read_codex_usages', return_value={'current': {'fetched_at': 1}}), \
                patch.object(m, 'usage_margin', return_value=codex_margin), \
                patch.object(m.usage_view, 'read_codex_enabled', return_value=True):
            result = m.main()
        self.assertEqual(result['selection']['configuration'], selected)
        self.assertEqual(result['selection']['selection_mode'], 'automatic' if automatic else 'explicit')
        self.assertEqual((result['executor'], result['model']), expected)
        self.assertEqual(result['role'], 'impl-review' if ROLES[index] == 'review' else ROLES[index])
        if expected[0] == 'codex':
            self.assertEqual(result['status'], 'request-written')
            self.assertEqual(json.loads(out.read_text())['model'], expected[1])
        else:
            self.assertEqual(result['status'], 'agent-required')
            self.assertFalse(out.exists())
    return test


for configuration, index, fable, shared in itertools.product(
        EXPECTED, range(8), FABLE_MODES, SHARED_MODES):
    name = 'test_' + '_'.join((configuration, ROLES[index], fable, shared)).replace(':', '_').replace('-', '_')
    setattr(ModelResolutionCurrent, name,
            case(configuration, index, fable, shared, EXPECTED[configuration][index]))
