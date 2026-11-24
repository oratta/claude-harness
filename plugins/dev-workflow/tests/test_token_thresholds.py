"""Contract tests for the independently callable threshold foundation."""
import contextlib
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/token_thresholds.py'
TABLE = SCRIPT.parent.parent / 'references/token-thresholds.json'
MODELS = ['claude-opus-5-5', 'claude-sonnet-5-5']
VALUES = dict(context_cap=150000, context_hard_cap=220000,
              pr_token_cap=30000000, epic_child_token_cap=60000000)
ENVS = dict(context_cap='DEV_WORKFLOW_CONTEXT_CAP',
            context_hard_cap='DEV_WORKFLOW_CONTEXT_HARD_CAP',
            pr_token_cap='DEV_WORKFLOW_PR_TOKEN_CAP')
GUIDE = 'plugins/dev-workflow/skills/develop/references/token-thresholds.md'
SOURCE = 'https://github.com/oratta/claude-harness/issues/1799#issuecomment-7120074012'


class ThresholdTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('token_thresholds', SCRIPT)
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    def resolve(self, model=None, env=None):
        return self.module.resolve_thresholds(model, {} if env is None else env)

    def fixture(self, table):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / 'table.json'
        path.write_text(json.dumps(table), encoding='utf-8')
        return path

    def test_table_values_and_evidence(self):
        table = json.loads(TABLE.read_text())
        self.assertEqual(table['schema_version'], 1)
        self.assertEqual(set(table['models']), set(MODELS))
        for row in [*table['models'].values(), table['fallback']]:
            for metric, value in VALUES.items():
                with self.subTest(metric=metric):
                    record = row[metric]
                    self.assertEqual(record['value'], value)
                    self.assertEqual(record['decided_models'], MODELS)
                    self.assertEqual(record['decided_at'], '2026-11-24')
                    self.assertEqual(record['source'], SOURCE)
                    self.assertTrue(record['evidence'])
        self.assertIn('1410', table['fallback']['context_cap']['evidence'])
        self.assertIn('17', table['fallback']['context_cap']['evidence'])
        self.assertIn('未検証', table['fallback']['context_hard_cap']['evidence'])
        for metric in ('pr_token_cap', 'epic_child_token_cap'):
            self.assertIn('混合', table['fallback'][metric]['evidence'])
            self.assertIn('単一モデル', table['fallback'][metric]['evidence'])

    def test_known_models_and_silent_api(self):
        for model in MODELS:
            stdout, stderr = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                result = self.resolve(model)
            self.assertEqual((stdout.getvalue(), stderr.getvalue()), ('', ''))
            self.assertEqual(result['requested_model'], model)
            self.assertEqual(result['matched_model'], model)
            self.assertFalse(result['fallback_used'])
            self.assertFalse(result['revalidation_required'])
            self.assertEqual(result['diagnostics'], [])
            for metric, value in VALUES.items():
                self.assertEqual(result['thresholds'][metric]['value'], value)
                self.assertEqual(result['thresholds'][metric]['source_kind'], 'model')
                self.assertEqual(result['thresholds'][metric]['baseline']['source'], SOURCE)

    def test_unknown_models_diagnostics_repeat_without_inference(self):
        for model in (None, '', 'opus', 'sonnet', 'claude-opus-future',
                      'claude-opus-5-5 ', 'CLAUDE-OPUS-5-5', 'gpt-future'):
            result = self.resolve(model, {'AGENT_MODEL': MODELS[0]})
            self.assertEqual(result, self.resolve(model, {'AGENT_MODEL': MODELS[0]}))
            self.assertIsNone(result['matched_model'])
            self.assertTrue(result['fallback_used'])
            self.assertTrue(result['revalidation_required'])
            self.assertIn('unknown_model', [d['code'] for d in result['diagnostics']])
            notices = [d for d in result['diagnostics'] if d['code'] == 'revalidation_required']
            self.assertEqual({d['metric'] for d in notices}, set(VALUES))
            for notice in notices:
                self.assertEqual(notice['requested_model'], model)
                self.assertEqual(notice['decided_models'], MODELS)
                self.assertEqual(notice['guide'], GUIDE)
            for metric, value in VALUES.items():
                self.assertEqual(result['thresholds'][metric]['value'], value)
                self.assertEqual(result['thresholds'][metric]['source_kind'], 'fallback')

    def test_known_row_with_different_evidence(self):
        table = json.loads(TABLE.read_text())
        table['models']['new-fixed-id'] = copy.deepcopy(table['fallback'])
        with patch.object(self.module, 'TABLE_PATH', self.fixture(table)):
            result = self.resolve('new-fixed-id')
        self.assertFalse(result['fallback_used'])
        self.assertTrue(result['revalidation_required'])

    def test_each_override_and_blank_zero_ascii_contract(self):
        for metric, name in ENVS.items():
            for text, expected in (('', VALUES[metric]), (' \t', VALUES[metric]),
                                   ('0', 0), (' 0040000000 \n', 40000000)):
                with self.subTest(metric=metric, text=text):
                    result = self.resolve(MODELS[0], {name: text})
                    for other, value in VALUES.items():
                        self.assertEqual(result['thresholds'][other]['value'], expected if other == metric else value)
                    item = result['thresholds'][metric]
                    self.assertEqual(item['baseline']['value'], VALUES[metric])
                    self.assertEqual(item['source_kind'], 'environment' if text.strip() else 'model')
            for invalid in ('-1', '1.5', 'abc', '+1', '１', '1_000'):
                with self.subTest(metric=metric, invalid=invalid):
                    with self.assertRaisesRegex(ValueError, name):
                        self.resolve(MODELS[0], {name: invalid})

    def test_override_diagnostics_environment_default_and_authority(self):
        env = {name: str(index) for index, name in enumerate(ENVS.values())}
        env['DEV_WORKFLOW_EPIC_CHILD_TOKEN_CAP'] = '999'
        result = self.resolve('unknown', env)
        self.assertTrue(result['fallback_used'])
        self.assertTrue(result['revalidation_required'])
        self.assertEqual(len(result['diagnostics']), 5)
        self.assertEqual(result['thresholds']['epic_child_token_cap']['value'], 60000000)
        self.assertEqual(result['thresholds']['pr_token_cap']['value'], 2)
        with patch.dict(os.environ, env, clear=True):
            self.assertEqual(self.module.resolve_thresholds('unknown'), result)
            self.assertEqual(self.resolve(MODELS[0])['thresholds']['context_cap']['value'], 150000)

    def test_invalid_tables_and_additional_fields(self):
        original = json.loads(TABLE.read_text())
        invalid = [None, [], {}, {**original, 'schema_version': 2}]
        for row_key in ('fallback', MODELS[0]):
            for metric in VALUES:
                table = copy.deepcopy(original)
                row = table['fallback'] if row_key == 'fallback' else table['models'][row_key]
                del row[metric]
                invalid.append(table)
                for field in ('value', 'decided_models', 'decided_at', 'evidence', 'source'):
                    table = copy.deepcopy(original)
                    row = table['fallback'] if row_key == 'fallback' else table['models'][row_key]
                    del row[metric][field]
                    invalid.append(table)
        for value in invalid:
            with self.subTest(table=value), patch.object(self.module, 'TABLE_PATH', self.fixture(value)):
                with self.assertRaisesRegex(ValueError, 'invalid_table'):
                    self.resolve(MODELS[0])
                stdout, stderr = io.StringIO(), io.StringIO()
                with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                    code = self.module.main(['--model', MODELS[0]])
                self.assertEqual(code, 1)
                result = json.loads(stdout.getvalue())
                self.assertEqual(result['error']['code'], 'invalid_table')
                self.assertNotIn('thresholds', result)
                self.assertTrue(stderr.getvalue())
        path = self.fixture(original)
        for content in ('{', ''):
            path.write_text(content)
            with patch.object(self.module, 'TABLE_PATH', path):
                with self.assertRaisesRegex(ValueError, 'invalid_table'):
                    self.resolve()
        path.unlink()
        with patch.object(self.module, 'TABLE_PATH', path):
            with self.assertRaisesRegex(ValueError, 'invalid_table'):
                self.resolve()
        original['future'] = True
        original['fallback']['context_cap']['future'] = True
        with patch.object(self.module, 'TABLE_PATH', self.fixture(original)):
            self.assertEqual(self.resolve(MODELS[0])['matched_model'], MODELS[0])

    def test_cli_matches_api_outside_repo(self):
        with tempfile.TemporaryDirectory() as cwd:
            for model in (None, MODELS[0], MODELS[1], 'unknown'):
                args = [sys.executable, str(SCRIPT)] + ([] if model is None else ['--model', model])
                run = subprocess.run(args, cwd=cwd, env={**os.environ, **{name: '' for name in ENVS.values()}}, capture_output=True, text=True)
                self.assertEqual(run.returncode, 0, run.stderr)
                self.assertEqual(len(run.stdout.splitlines()), 1)
                self.assertEqual(json.loads(run.stdout), self.resolve(model))
                self.assertEqual(bool(run.stderr), model not in MODELS)
                if run.stderr:
                    self.assertIn('revalidation_required', run.stderr)
                    self.assertIn(GUIDE, run.stderr)

    def test_cli_errors_no_usable_thresholds(self):
        for name in ENVS.values():
            for value in ('-1', '1.5', 'abc'):
                with patch.dict(os.environ, {name: value}, clear=True):
                    stdout, stderr = io.StringIO(), io.StringIO()
                    with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                        code = self.module.main([])
                self.assertEqual(code, 1)
                result = json.loads(stdout.getvalue())
                self.assertEqual(result['error']['code'], 'invalid_override')
                self.assertIn(name, stderr.getvalue())
                self.assertNotIn('thresholds', result)
        with patch.object(self.module, 'TABLE_PATH', Path('/nonexistent/token-threshold-table.json')):
            stdout, stderr = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                code = self.module.main([])
            self.assertEqual(code, 1)
            self.assertEqual(json.loads(stdout.getvalue())['error']['code'], 'invalid_table')
            self.assertTrue(stderr.getvalue())


if __name__ == '__main__':
    unittest.main()
