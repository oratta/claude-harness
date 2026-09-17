import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/codex-develop.py'
spec = importlib.util.spec_from_file_location('develop', SCRIPT)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class ManualDevelop(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.cwd = self.root / 'repo'
        self.cwd.mkdir()
        subprocess.run(['git', 'init', '-q', str(self.cwd)], check=True)
        subprocess.run(['git', '-C', str(self.cwd), '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '--allow-empty', '-qm', 'fixture'], check=True)
        self.run = self.root / 'run'
        self.input = self.root / 'input.txt'
        self.input.write_text('Prepare only the requested phase. No merge.')
        self.calls = []
        self.jobs = {}
        self.fake = patch.object(m, 'worker', self.worker)
        self.fake.start()
        self.addCleanup(self.fake.stop)
        self.call('init', '--account', 'spare', '--model', 'explicit-model', '--cwd', str(self.cwd), '--worker-state', str(self.root / 'worker'))

    def call(self, *args):
        with patch.object(sys, 'argv', [str(SCRIPT), '--run-dir', str(self.run), *args]):
            return m.main()

    def worker(self, state, command, option, value):
        self.calls.append((command, value))
        if command == 'submit':
            req = json.loads(Path(value).read_text())
            self.jobs[req['request_id']] = req
            return {'job_id': req['request_id'], 'status': 'completed'}
        marker = '仕様レビュー: APPROVE' if self.jobs.get(value, {}).get('role') == 'spec-review' else 'レビュー: APPROVE'
        return {'job_id': value, 'status': 'completed', 'text': marker, 'error_kind': None}

    def test_complete_loop_with_revision_and_fixed_account(self):
        phases = ['spec', 'spec-review', 'spec', 'spec-review', 'implement', 'finish', 'gate', 'review', 'decider', 'implement', 'review', 'gate']
        ids = []
        for phase in phases:
            output = self.call('dispatch', '--phase', phase, '--input', str(self.input))
            ids.append(output['job_id'])
            self.call('result')
            self.call('ack')
        self.assertEqual(len(set(ids)), len(phases))
        state = json.loads((self.run / 'run.json').read_text())
        self.assertEqual(len(state['history']), len(phases))
        self.assertNotIn('approved', state)  # transport cannot fabricate quality approval
        for request in self.jobs.values():
            self.assertEqual(request['account'], 'spare')
            self.assertEqual(request['model'], 'explicit-model')
            self.assertEqual(request['origin'], 'manual')
            self.assertIn('CANONICAL SOURCE', request['prompt'])
        reviews = [self.jobs[ids[n]]['role'] for n in (1, 3, 7, 8)]
        self.assertEqual(reviews, ['spec-review', 'spec-review', 'impl-review', 'decider'])

    def test_no_spec_path_follows_coordinator_without_creating_artifacts(self):
        # Same coordinator-selected sequence as Claude when specification is unnecessary.
        self.input.write_text('Apply canonical decision criteria; no separate specification is needed.')
        for phase in ('spec', 'implement', 'finish', 'review', 'gate'):
            self.call('dispatch', '--phase', phase, '--input', str(self.input))
            self.call('ack')
        state = json.loads((self.run / 'run.json').read_text())
        self.assertEqual([v['phase'] for v in state['history']],
                         ['spec', 'implement', 'finish', 'review', 'gate'])
        self.assertEqual(list(self.cwd.glob('openspec')), [])
        self.assertNotIn('spec_paths', state)
        self.assertNotIn('approvals', state)
        self.assertNotIn('checks', state)
        first = next(iter(self.jobs.values()))['prompt']
        self.assertIn('仕様化判断', first)
        self.assertIn('it does not require', first)

    def test_dispatch_does_not_invent_prerequisites_or_clean_tree_requirement(self):
        # The coordinator owns quality decisions, even if work is dirty or no spec exists.
        (self.cwd / 'change.txt').write_text('implementation in progress')
        for phase in ('implement', 'spec-review', 'finish', 'gate'):
            self.call('dispatch', '--phase', phase, '--input', str(self.input))
            self.call('ack')
        self.assertEqual(len(self.jobs), 4)

    def test_results_are_evidence_not_executor_approval(self):
        self.call('dispatch', '--phase', 'review', '--input', str(self.input))
        cases = [
            {'status': 'completed', 'text': 'レビュー: REQUEST_CHANGES', 'error_kind': None},
            {'status': 'completed', 'text': 'レビュー: APPROVE', 'error_kind': 'auth_profile_changed'},
            {'status': 'failed', 'text': None, 'error_kind': 'unsupported_server_request'},
        ]
        for result in cases:
            with self.subTest(result=result), patch.object(m, 'worker', return_value=result):
                self.assertEqual(self.call('result'), result)
        with patch.object(m, 'worker', return_value=cases[1]):
            self.call('ack')
        state = json.loads((self.run / 'run.json').read_text())
        self.assertEqual(state['history'][-1]['result'], cases[1])
        self.assertNotIn('approvals', state)

    def test_legacy_run_metadata_does_not_reintroduce_workflow_gates(self):
        path = self.run / 'run.json'
        state = json.loads(path.read_text())
        state.update(spec_paths=['missing/spec.md'], approvals={}, checks={'unchanged': False})
        path.write_text(json.dumps(state))
        for phase in ('implement', 'finish', 'gate'):
            self.call('dispatch', '--phase', phase, '--input', str(self.input))
            self.call('ack')
        self.assertEqual(len(self.jobs), 3)

    def test_init_defaults_resolve_registered_worker_and_unique_run(self):
        with patch.object(m.Path, 'home', return_value=self.root):
            with patch.object(sys, 'argv', [str(SCRIPT), 'init', '--account', 'spare', '--model', 'm', '--cwd', str(self.cwd)]):
                result = m.main()
        path = Path(result['run_dir'])
        self.assertEqual(path.parent, (self.root / '.local/state/claude-harness-codex/runs').resolve())
        state = json.loads((path / 'run.json').read_text())
        self.assertEqual(state['worker_state'], str((self.root / '.local/state/claude-harness-codex/jobs').resolve()))

    def test_uncertain_submit_reuses_request_id(self):
        with patch.object(m, 'worker', side_effect=RuntimeError('connection lost')):
            with self.assertRaises(RuntimeError):
                self.call('dispatch', '--phase', 'spec', '--input', str(self.input))
        request_id = json.loads((self.run / 'request.json').read_text())['request_id']
        output = self.call('dispatch', '--phase', 'spec', '--input', str(self.input))
        self.assertEqual(output['job_id'], request_id)

    def test_retry_replays_legacy_envelope_after_uncertain_delivery(self):
        with patch.object(m, 'worker', side_effect=RuntimeError('connection lost')):
            with self.assertRaises(RuntimeError):
                self.call('dispatch', '--phase', 'spec', '--input', str(self.input))
        path = self.run / 'request.json'
        old = json.loads(path.read_text())
        old['prompt'] = 'Old version prompt, preserved exactly'
        path.write_text(json.dumps(old))
        result = self.call('retry')
        self.assertEqual(result['job_id'], old['request_id'])
        self.assertEqual(self.jobs[old['request_id']], old)
        self.call('retry')
        self.assertEqual(len(self.jobs), 1)
        old['account'] = 'other'
        path.write_text(json.dumps(old))
        with self.assertRaisesRegex(RuntimeError, 'identity differs'):
            self.call('retry')

    def test_pending_cannot_be_replaced_or_switched(self):
        self.call('dispatch', '--phase', 'spec', '--input', str(self.input))
        with self.assertRaisesRegex(RuntimeError, 'pending request differs'):
            self.call('dispatch', '--phase', 'spec-review', '--input', str(self.input))
        with self.assertRaisesRegex(RuntimeError, 'run exists'):
            self.call('init', '--account', 'other', '--model', 'm', '--cwd', str(self.cwd), '--worker-state', str(self.root))

    def test_unknown_cannot_ack(self):
        self.call('dispatch', '--phase', 'spec', '--input', str(self.input))
        with patch.object(m, 'worker', return_value={'status': 'unknown'}):
            with self.assertRaisesRegex(RuntimeError, 'unknown'):
                self.call('ack')
        self.assertIsNotNone(json.loads((self.run / 'run.json').read_text())['pending'])

    def test_missing_worker_does_not_fallback(self):
        with patch.object(m, 'ROOT', self.root):
            with self.assertRaises(RuntimeError):
                # Test the real transport separately from the fixture.
                self.fake.stop()
                try:
                    m.worker({'worker_state': str(self.root)}, 'status', '--job', 'x')
                finally:
                    self.fake.start()


class TransportIntegration(unittest.TestCase):
    def test_no_spec_assignment_reaches_actual_worker_and_preserves_review_result(self):
        # Fake only the external App Server; exercise both real CLI processes/ledgers.
        from test_codex_worker import WorkerTest
        fixture = WorkerTest()
        fixture.setUp()
        self.addCleanup(fixture.tearDown)
        run = fixture.root / 'develop-run'
        instructions = fixture.root / 'assignment.txt'
        instructions.write_text('Existing develop selected no specification. Implement the requested fix.')

        def cli(*args):
            result = subprocess.run([sys.executable, str(SCRIPT), '--run-dir', str(run), *args],
                                    env=fixture.env, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            return json.loads(result.stdout)

        cli('init', '--account', 'test', '--model', 'fixture-model', '--cwd', str(fixture.cwd),
            '--worker-state', str(fixture.state))
        for phase, text in [('implement', 'Implementation finished'),
                            ('review', 'レビュー: REQUEST_CHANGES')]:
            fixture.config(items=[{'type': 'agentMessage', 'phase': 'final_answer', 'text': text}])
            submitted = cli('dispatch', '--phase', phase, '--input', str(instructions))
            terminal = fixture.wait(submitted['job_id'])
            self.assertEqual(terminal['status'], 'completed')
            self.assertEqual(cli('result')['text'], text)
            cli('ack')
        starts = [call['params'] for call in fixture.calls() if call.get('method') == 'thread/start']
        self.assertEqual([p['sandbox'] for p in starts], ['workspace-write', 'read-only'])
        state = json.loads((run / 'run.json').read_text())
        self.assertEqual([v['phase'] for v in state['history']], ['implement', 'review'])
        self.assertNotIn('approvals', state)
        self.assertFalse((fixture.cwd / 'openspec').exists())


if __name__ == '__main__':
    unittest.main()
