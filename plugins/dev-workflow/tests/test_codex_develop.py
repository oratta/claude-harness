import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

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
        return {'job_id': value, 'status': 'completed', 'text': 'fixture result, not quality approval'}

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

    def test_uncertain_submit_reuses_request_id(self):
        with patch.object(m, 'worker', side_effect=RuntimeError('connection lost')):
            with self.assertRaises(RuntimeError):
                self.call('dispatch', '--phase', 'spec', '--input', str(self.input))
        request_id = json.loads((self.run / 'request.json').read_text())['request_id']
        output = self.call('dispatch', '--phase', 'spec', '--input', str(self.input))
        self.assertEqual(output['job_id'], request_id)

    def test_pending_cannot_be_replaced_or_switched(self):
        self.call('dispatch', '--phase', 'spec', '--input', str(self.input))
        with self.assertRaisesRegex(RuntimeError, 'pending request differs'):
            self.call('dispatch', '--phase', 'implement', '--input', str(self.input))
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


if __name__ == '__main__':
    unittest.main()
