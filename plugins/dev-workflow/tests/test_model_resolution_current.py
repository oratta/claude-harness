"""The tier of a role does not depend on the configuration (model-tier-resolution, #614).

Expected values are literals: never read the profile JSON or the tier map to derive this oracle.
Every role, configuration, budget mode pair and input combination is pinned, and the tuples of
the no-input conserve / ok row stay the values fixed in #613.
"""
import importlib.util
import itertools
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import types
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
REASONS = {'auto:claude-write-codex-review': 'both-providers-have-headroom',
           'auto:codex-standard': 'only-codex-has-headroom',
           'auto:claude-default': 'only-claude-has-headroom'}

INPUTS = {
    'none': (),
    'sacred': ('--pre-class', 'sacred'),
    'merge': ('--pre-class', 'merge'),
    'contract': ('--pre-class', 'contract'),
    'billing': ('--pre-class', 'billing'),
    'design': ('--design-judgment',),
    'first': ('--failure', 'first'),
    'executor': ('--failure', 'executor'),
    'judgment': ('--failure', 'judgment'),
    'unmanned': ('--unmanned',),
    'merge-unmanned': ('--pre-class', 'merge', '--unmanned'),
}
# The twelve tiers of one row, in the order FABLE_MODES x SHARED_MODES (ok, throttled, depleted).
LOW = ('最安',) * 12
MIDDLE = ('中位',) * 12
READER = ('上位', '中位', '中位') * 4
RAISED = ('上位', '上位', '中位') * 4
TOP = (('最上位', '上位', '中位') * 3) + ('上位', '上位', '中位')
TOP_UNMANNED = (('最上位', '上位', '中位') * 2) + (('上位', '上位', '中位') * 2)
WRITER = {'none': MIDDLE, 'sacred': RAISED, 'merge': RAISED, 'contract': RAISED,
          'billing': RAISED, 'design': RAISED, 'first': MIDDLE, 'executor': RAISED,
          'judgment': MIDDLE, 'unmanned': MIDDLE, 'merge-unmanned': RAISED}
GATE = dict.fromkeys(INPUTS, MIDDLE)
REVIEW = {'none': READER, 'sacred': READER, 'merge': TOP, 'contract': TOP, 'billing': TOP,
          'design': READER, 'first': READER, 'executor': READER, 'judgment': READER,
          'unmanned': READER, 'merge-unmanned': TOP_UNMANNED}
DECIDER = {'none': TOP, 'sacred': TOP, 'merge': TOP, 'contract': TOP, 'billing': TOP,
           'design': TOP, 'first': RAISED, 'executor': RAISED, 'judgment': TOP,
           'unmanned': TOP_UNMANNED, 'merge-unmanned': TOP_UNMANNED}
READ_ONLY_LOW = dict.fromkeys(INPUTS, LOW)
TIER_TABLE = {'spec': WRITER, 'implement': WRITER, 'finish': WRITER, 'gate': GATE,
              'spec-review': REVIEW, 'review': REVIEW, 'decider': DECIDER,
              'explore': READ_ONLY_LOW, 'summarize': READ_ONLY_LOW}


class Fixture(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        assert ROLES == m.CANONICAL_ROLES
        assert set(TIER_TABLE) == set(m.PHASES)
        cls.temp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.temp.cleanup)
        cls.root = Path(cls.temp.name).resolve()
        cls.cwd = cls.root / 'repo'
        cls.cwd.mkdir()
        git_env = {'PATH': os.environ['PATH'], 'HOME': str(cls.root),
                   'GIT_CONFIG_GLOBAL': os.devnull, 'GIT_CONFIG_NOSYSTEM': '1'}
        subprocess.run(['git', 'init', '-q', str(cls.cwd)], check=True, env=git_env)
        subprocess.run(['git', '-C', str(cls.cwd), '-c', 'user.name=Test',
                        '-c', 'user.email=test@example.invalid', 'commit',
                        '--allow-empty', '-qm', 'fixture'], check=True, env=git_env)
        cls.home = cls.root / 'home'
        cls.home.mkdir()
        cls.instructions = cls.root / 'input.txt'
        cls.instructions.write_text('Characterization only.')
        cls.out = cls.root / 'request.json'

    def call(self, configuration, phase, fable='conserve', shared='ok', inputs=()):
        self.out.unlink(missing_ok=True)
        args = [str(SCRIPT), 'request', '--phase', phase, *inputs,
                '--input', str(self.instructions), '--cwd', str(self.cwd),
                '--account-home', 'current=' + str(self.home), '--out', str(self.out)]
        if not configuration.startswith('auto:'):
            args.extend(['--profile', configuration])
        claude_margin, codex_margin = MARGINS.get(configuration, (20, 10))
        with patch.dict(os.environ, {'FABLE_BUDGET_MODE': fable,
                                     'SHARED_BUDGET_MODE': shared,
                                     'CLAUDE_CONFIG_DIR': str(self.root),
                                     'PATH': os.environ['PATH']}, clear=True), \
                patch.object(sys, 'argv', args), \
                patch.object(m, '_run_usage_probe'), \
                patch.object(m, 'claude_usage_evidence', return_value={
                    'account': 'fixture', 'margin': claude_margin, 'fetched_at': 1}), \
                patch.object(m, 'read_codex_usages', return_value={'current': {'fetched_at': 1}}), \
                patch.object(m, 'usage_margin', return_value=codex_margin), \
                patch.object(m.usage_view, 'read_codex_enabled', return_value=True):
            return m.main()


class ConfigurationDoesNotChangeTheTier(Fixture):
    def test_a_writer_stays_upper_under_claude_write_codex_review(self):
        # #605: the automatic route ran a pre-classified W on sonnet.
        for configuration in ('claude-write-codex-review', 'auto:claude-write-codex-review'):
            with self.subTest(configuration=configuration):
                result = self.call(configuration, 'implement', inputs=INPUTS['contract'])
                self.assertEqual((result['tier'], result['model']), ('上位', 'opus'))


def tier_case(configuration, phase):
    def test(self):
        # 11 inputs x 12 modes would spend most of the run in git and in writing request files, so
        # these are replaced here and the cells are compared at once. The tuple tests keep them.
        toplevel = types.SimpleNamespace(returncode=0, stdout=str(self.cwd))
        cells = [(name, index, fable, shared) for name, (index, (fable, shared)) in itertools.product(
            INPUTS, enumerate(itertools.product(FABLE_MODES, SHARED_MODES)))]
        with patch.object(m.subprocess, 'run', return_value=toplevel), \
                patch.object(m, 'git', return_value='fixture-head'), \
                patch.object(m, 'prompt', return_value='fixture prompt'), \
                patch.object(m, 'write'):
            actual = {cell: self.call(configuration, phase, cell[2], cell[3], INPUTS[cell[0]])['tier']
                      for cell in cells}
        self.assertEqual(actual, {cell: TIER_TABLE[phase][cell[0]][cell[1]] for cell in cells})
    return test


for configuration, phase in itertools.product(EXPECTED, TIER_TABLE):
    name = 'test_' + '_'.join((configuration, phase)).replace(':', '_').replace('-', '_')
    setattr(ConfigurationDoesNotChangeTheTier, name, tier_case(configuration, phase))


class NoInputKeepsTheCurrentTuples(Fixture):
    """The conserve / ok row with no input is the executor and model fixed in #613."""


def tuple_case(configuration, index, expected):
    def test(self):
        result = self.call(configuration, PHASES[index])
        self.assertEqual(result['selection']['configuration'], configuration.removeprefix('auto:'))
        automatic = configuration.startswith('auto:')
        if automatic:
            self.assertEqual(result['selection']['reason'], REASONS[configuration])
        self.assertEqual(result['selection']['selection_mode'], 'automatic' if automatic else 'explicit')
        self.assertEqual((result['executor'], result['model']), expected)
        self.assertEqual(result['role'], 'impl-review' if ROLES[index] == 'review' else ROLES[index])
        if expected[0] == 'codex':
            self.assertEqual(result['status'], 'request-written')
            self.assertEqual(json.loads(self.out.read_text())['model'], expected[1])
        else:
            self.assertEqual(result['status'], 'agent-required')
            self.assertFalse(self.out.exists())
    return test


for configuration, index in itertools.product(EXPECTED, range(8)):
    name = 'test_' + '_'.join((configuration, ROLES[index])).replace(':', '_').replace('-', '_')
    setattr(NoInputKeepsTheCurrentTuples, name,
            tuple_case(configuration, index, EXPECTED[configuration][index]))


class ModelTiersDocument(unittest.TestCase):
    # model-tiers.md still states the Claude aliases for people; they must not drift from the map.
    def test_the_document_agrees_with_the_claude_column_of_the_map(self):
        table = json.loads((SCRIPT.parents[1] / 'references/model-tier-map.json').read_text())
        claude = table['executors']['claude']
        text = (SCRIPT.parents[1] / 'references/model-tiers.md').read_text()
        rows = {row.split('|')[1].strip().strip('`'): row.split('|')[3].strip().strip("`'")
                for row in text.splitlines() if row.startswith('| `')}
        self.assertEqual(rows['haiku'], claude['最安'])
        self.assertEqual(rows['sonnet'], claude['中位'])
        self.assertEqual(rows['fable'], claude['最上位'])
        self.assertIn(f"重めの実装・レビューを中位ティアで回すときは `'{claude['上位']}'` を渡す", text)
        self.assertIn('上の格の `上位` に当たる', text)
