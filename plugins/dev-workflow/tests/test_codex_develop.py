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
        subprocess.run(['git', '-C', str(self.cwd), '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '--allow-empty', '-qm', 'fixture'], check=True)
        (self.cwd / 'spec.md').write_text('Acceptance specification')
        subprocess.run(['git', '-C', str(self.cwd), 'add', 'spec.md'], check=True)
        subprocess.run(['git', '-C', str(self.cwd), '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'spec'], check=True)
        self.run = self.root / 'run'
        self.input = self.root / 'input.txt'
        self.input.write_text('Prepare only the requested phase. No merge.')
        self.calls = []
        self.jobs = {}
        self.fake = patch.object(m, 'worker', self.worker)
        self.fake.start()
        self.addCleanup(self.fake.stop)
        self.call('init', '--account', 'spare', '--model', 'explicit-model', '--cwd', str(self.cwd), '--worker-state', str(self.root / 'worker'), '--spec-path', 'spec.md', '--required-check', json.dumps([sys.executable, '-c', 'pass']))

    def call(self, *args):
        with patch.object(sys, 'argv', [str(SCRIPT), '--run-dir', str(self.run), *args]):
            return m.main()

    def worker(self, state, command, option, value):
        self.calls.append((command, value))
        if command == 'submit':
            req = json.loads(Path(value).read_text())
            self.jobs[req['request_id']] = req
            return {'job_id': req['request_id'], 'status': 'completed'}
        return {'job_id': value, 'status': 'completed', 'text': '仕様レビュー: APPROVE\nレビュー: APPROVE'}

    def test_complete_loop_with_revision_and_fixed_account(self):
        phases = ['spec', 'spec-review', 'spec', 'spec-review', 'implement', 'finish', 'gate', 'review', 'decider', 'implement', 'review', 'gate']
        ids = []
        for phase in phases:
            if phase in ('finish', 'gate'):
                self.call('check')
            output = self.call('dispatch', '--phase', phase, '--input', str(self.input))
            ids.append(output['job_id'])
            self.call('result')
            self.call('ack')
            if phase in ('spec-review', 'review'):
                self.call('accept-review')
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

    def test_implementation_cannot_skip_spec_review(self):
        with self.assertRaisesRegex(RuntimeError, 'specification approval'):
            self.call('dispatch', '--phase', 'implement', '--input', str(self.input))

    def test_changed_head_invalidates_review(self):
        self.call('dispatch', '--phase', 'spec-review', '--input', str(self.input))
        self.call('ack')
        subprocess.run(['git', '-C', str(self.cwd), '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '--allow-empty', '-qm', 'changed'], check=True)
        with self.assertRaisesRegex(RuntimeError, 'HEAD changed'):
            self.call('accept-review')

    def test_specification_changes_require_new_review(self):
        self.call('dispatch', '--phase', 'spec-review', '--input', str(self.input))
        self.call('ack')
        self.call('accept-review')
        (self.cwd / 'spec.md').write_text('Changed acceptance')
        with self.assertRaisesRegex(RuntimeError, 'specification changed'):
            self.call('dispatch', '--phase', 'implement', '--input', str(self.input))

    def test_dirty_review_cannot_be_accepted(self):
        self.call('dispatch', '--phase', 'spec-review', '--input', str(self.input))
        self.call('ack')
        (self.cwd / 'untracked.txt').write_text('new change')
        with self.assertRaisesRegex(RuntimeError, 'HEAD changed'):
            self.call('accept-review')

    def test_archive_move_preserves_only_identical_content(self):
        self.call('dispatch', '--phase', 'spec-review', '--input', str(self.input))
        self.call('ack')
        self.call('accept-review')
        archive = self.cwd / 'archive'
        archive.mkdir()
        (self.cwd / 'spec.md').rename(archive / 'spec.md')
        subprocess.run(['git', '-C', str(self.cwd), 'add', '-A'], check=True)
        subprocess.run(['git', '-C', str(self.cwd), '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'archive'], check=True)
        self.call('relocate-spec', '--from-path', 'spec.md', '--to-path', 'archive/spec.md')
        self.call('dispatch', '--phase', 'implement', '--input', str(self.input))

    def test_failed_required_check_blocks_finish(self):
        self.call('dispatch', '--phase', 'spec-review', '--input', str(self.input))
        self.call('ack')
        self.call('accept-review')
        path = self.run / 'run.json'
        state = json.loads(path.read_text())
        state['required_checks'] = [[sys.executable, '-c', 'raise SystemExit(1)']]
        path.write_text(json.dumps(state))
        self.assertEqual(self.call('check')['status'], 'failed')
        with self.assertRaisesRegex(RuntimeError, 'required checks'):
            self.call('dispatch', '--phase', 'finish', '--input', str(self.input))

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
            self.call('dispatch', '--phase', 'spec-review', '--input', str(self.input))
        with self.assertRaisesRegex(RuntimeError, 'run exists'):
            self.call('init', '--account', 'other', '--model', 'm', '--cwd', str(self.cwd), '--worker-state', str(self.root), '--spec-path', 'spec.md')

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
