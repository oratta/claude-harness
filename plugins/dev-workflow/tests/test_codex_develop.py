import importlib.util
import hashlib
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


class RoleProfiles(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.cwd = self.root / 'repo'
        self.cwd.mkdir()
        subprocess.run(['git', 'init', '-q', str(self.cwd)], check=True)
        subprocess.run(['git', '-C', str(self.cwd), '-c', 'user.name=Test',
                        '-c', 'user.email=test@example.invalid', 'commit',
                        '--allow-empty', '-qm', 'fixture'], check=True)
        self.run = self.root / 'run'
        self.worker_state = self.root / 'worker'
        self.input = self.root / 'input.txt'
        self.input.write_text('Do only this phase.')
        self.calls = []
        self.jobs = {}
        self.fake = patch.object(m, 'worker', self.worker)
        self.fake.start()
        self.addCleanup(self.fake.stop)
        self.accounts = patch.object(m, 'registered_accounts', return_value={'current', 'reviewer', 'builder'})
        self.accounts.start()
        self.addCleanup(self.accounts.stop)

    def call(self, *args):
        with patch.object(sys, 'argv', [str(SCRIPT), '--run-dir', str(self.run), *args]):
            return m.main()

    def worker(self, state, command, option, value):
        self.calls.append((command, value))
        if command == 'submit':
            request = json.loads(Path(value).read_text())
            self.jobs[request['request_id']] = request
            return {'job_id': request['request_id'], 'status': 'completed'}
        if command == 'result':
            request = self.jobs[value]
            return {'job_id': value, 'status': 'completed', 'text': 'done',
                    'error_kind': None, 'thread_id': 'thread-' + value,
                    'turn_id': 'turn-' + value,
                    'execution': {'version': 1, 'role': request['role'],
                                  'requested': {'executor': 'codex', 'account': request['account'],
                                                'model': request['model'],
                                                'effort': request.get('effort')},
                                  'effective': {'executor': 'codex', 'account': request['account'],
                                                'model': request['model'],
                                                'effort': request.get('effort')},
                                  'evidence': {'executor': 'transport', 'account': 'account/read',
                                               'model': 'turn/start', 'effort': 'turn/start'}}}
        return {'job_id': value, 'status': 'completed'}

    def init(self, name='codex-standard', profile_file=None):
        args = ['init', '--profile', name, '--cwd', str(self.cwd),
                '--worker-state', str(self.worker_state)]
        if profile_file:
            args += ['--profile-file', str(profile_file)]
        return self.call(*args)

    def test_builtin_profiles_resolve_all_roles_and_snapshot_hash(self):
        expected = {
            'codex-standard': ('gpt-5.6-sol', 'high', 'gpt-5.6-sol', 'medium'),
            'codex-economy': ('gpt-5.6-luna', 'medium', 'gpt-5.6-luna', 'medium'),
        }
        for index, (name, values) in enumerate(expected.items()):
            with self.subTest(profile=name):
                self.run = self.root / ('run-' + str(index))
                self.init(name)
                state = json.loads((self.run / 'run.json').read_text())
                config = state['execution_config']
                self.assertEqual((config['roles']['spec-write']['model'], config['roles']['spec-write']['effort'],
                                  config['roles']['implement']['model'], config['roles']['implement']['effort']), values)
                for role in ('spec-review', 'impl-review', 'review', 'decider'):
                    self.assertEqual((config['roles'][role]['model'], config['roles'][role]['effort']),
                                     ('gpt-6-astra', 'high'))
                for role in ('explore', 'summarize'):
                    self.assertEqual((config['roles'][role]['model'], config['roles'][role]['effort']),
                                     ('gpt-5.6-luna', 'low'))
                self.assertTrue(all(v['executor'] == 'codex' and v['account'] == 'current'
                                    for v in config['roles'].values()))
                encoded = json.dumps(config, ensure_ascii=False, sort_keys=True,
                                     separators=(',', ':')).encode()
                self.assertEqual(state['execution_config_hash'], hashlib.sha256(encoded).hexdigest())

    def test_profile_cli_rejects_legacy_mix_and_profile_file_alone(self):
        cases = [
            ('--profile with account', ['--profile', 'codex-standard', '--account', 'current', '--cwd', str(self.cwd)]),
            ('--profile with model', ['--profile', 'codex-standard', '--model', 'm', '--cwd', str(self.cwd)]),
            ('file alone', ['--profile-file', str(self.root / 'x.json'), '--cwd', str(self.cwd)]),
        ]
        for label, args in cases:
            with self.subTest(case=label):
                self.run = self.root / ('invalid-' + label.replace(' ', '-'))
                with self.assertRaises((RuntimeError, SystemExit)):
                    self.call('init', *args)
                self.assertFalse((self.run / 'run.json').exists())

    def test_external_profile_is_strict_complete_and_uses_registered_accounts(self):
        roles = {}
        for role in m.CANONICAL_ROLES:
            roles[role] = {'executor': 'codex', 'account': 'reviewer' if 'review' in role else 'builder',
                           'model': 'custom-model', 'effort': 'future'}
        profile = self.root / 'profiles.json'
        profile.write_text(json.dumps({'version': 1, 'profiles': {'custom': {'roles': roles}}}))
        self.init('custom', profile)
        state = json.loads((self.run / 'run.json').read_text())
        self.assertEqual(state['execution_config']['roles'], roles)

        invalids = [
            {'version': 2, 'profiles': {'custom': {'roles': roles}}},
            {'version': 1, 'extra': 1, 'profiles': {'custom': {'roles': roles}}},
            {'version': 1, 'profiles': {'custom': {'roles': {k: v for k, v in roles.items() if k != 'decider'}}}},
            {'version': 1, 'profiles': {'custom': {'roles': dict(roles, decider=dict(roles['decider'], executor='claude'))}}},
            {'version': 1, 'profiles': {'custom': {'roles': dict(roles, decider=dict(roles['decider'], account='absent'))}}},
        ]
        duplicate = '{"version":1,"version":1,"profiles":{}}'
        for index, value in enumerate(invalids + [duplicate]):
            with self.subTest(invalid=index):
                self.run = self.root / ('invalid-profile-' + str(index))
                profile.write_text(value if isinstance(value, str) else json.dumps(value))
                with self.assertRaises((RuntimeError, ValueError)):
                    self.init('custom', profile)
                self.assertFalse((self.run / 'run.json').exists())

    def test_snapshot_survives_external_file_change_and_dispatches_by_role(self):
        roles = {role: {'executor': 'codex', 'account': 'reviewer' if role == 'spec-review' else 'builder',
                        'model': role + '-model', 'effort': role + '-effort'}
                 for role in m.CANONICAL_ROLES}
        profile = self.root / 'profiles.json'
        profile.write_text(json.dumps({'version': 1, 'profiles': {'custom': {'roles': roles}}}))
        self.init('custom', profile)
        profile.unlink()
        output = self.call('dispatch', '--phase', 'spec-review', '--input', str(self.input))
        request = self.jobs[output['job_id']]
        self.assertEqual((request['role'], request['account'], request['model'], request['effort']),
                         ('spec-review', 'reviewer', 'spec-review-model', 'spec-review-effort'))
        state = json.loads((self.run / 'run.json').read_text())
        self.assertEqual(state['pending_execution'], roles['spec-review'] | {'role': 'spec-review'})
        self.assertEqual(state['pending_payload_hash'],
                         hashlib.sha256(json.dumps(request, sort_keys=True).encode()).hexdigest())

    def test_profile_retry_checks_snapshot_pending_and_preserves_old_prompt(self):
        self.init()
        with patch.object(m, 'worker', side_effect=RuntimeError('connection lost')):
            with self.assertRaises(RuntimeError):
                self.call('dispatch', '--phase', 'spec', '--input', str(self.input))
        request_path = self.run / 'request.json'
        old = json.loads(request_path.read_text())
        old['prompt'] = 'old profile prompt'
        request_path.write_text(json.dumps(old))
        state_path = self.run / 'run.json'
        state = json.loads(state_path.read_text())
        state['pending_payload_hash'] = hashlib.sha256(json.dumps(old, sort_keys=True).encode()).hexdigest()
        state_path.write_text(json.dumps(state))
        self.call('retry')
        self.assertEqual(self.jobs[old['request_id']]['prompt'], 'old profile prompt')
        for key, value in [('pending_payload_hash', 'bad'), ('execution_config_hash', 'bad')]:
            state = json.loads(state_path.read_text())
            state[key] = value
            state_path.write_text(json.dumps(state))
            with self.subTest(key=key), self.assertRaisesRegex(RuntimeError, 'mismatch'):
                self.call('retry')
            state[key] = (hashlib.sha256(json.dumps(old, sort_keys=True).encode()).hexdigest()
                          if key == 'pending_payload_hash' else m.execution_config_hash(state['execution_config']))
            state_path.write_text(json.dumps(state))

    def test_ack_records_verified_execution_identity_without_changing_payload_hash(self):
        self.init()
        output = self.call('dispatch', '--phase', 'implement', '--input', str(self.input))
        before = json.loads((self.run / 'run.json').read_text())['pending_payload_hash']
        self.call('ack')
        state = json.loads((self.run / 'run.json').read_text())
        item = state['history'][-1]
        self.assertEqual(item['execution']['role'], 'implement')
        self.assertEqual((item['job_id'], item['thread_id'], item['turn_id']),
                         (output['job_id'], 'thread-' + output['job_id'], 'turn-' + output['job_id']))
        request = json.loads((self.run / 'request.json').read_text())
        self.assertEqual(before, hashlib.sha256(json.dumps(request, sort_keys=True).encode()).hexdigest())

    def test_profiles_preserve_coordinator_phase_order_and_role_mapping(self):
        phases = ('spec', 'spec-review', 'spec', 'spec-review', 'implement', 'finish',
                  'gate', 'review', 'decider', 'implement', 'review', 'gate')
        expected_roles = ('spec-write', 'spec-review', 'spec-write', 'spec-review', 'implement',
                          'implement', 'implement', 'impl-review', 'decider', 'implement',
                          'impl-review', 'implement')
        for index, profile in enumerate(('codex-standard', 'codex-economy')):
            with self.subTest(profile=profile):
                self.run = self.root / ('workflow-' + str(index))
                self.init(profile)
                actual = []
                for phase in phases:
                    output = self.call('dispatch', '--phase', phase, '--input', str(self.input))
                    actual.append(self.jobs[output['job_id']]['role'])
                    self.call('ack')
                self.assertEqual(tuple(actual), expected_roles)
                state = json.loads((self.run / 'run.json').read_text())
                self.assertEqual(tuple(item['phase'] for item in state['history']), phases)
                self.assertNotIn('approved', state)

    def test_common_loader_is_origin_independent_and_finish_gate_use_implement(self):
        first = m.load_profile('codex-economy', None, str(self.worker_state))
        second = m.load_profile('codex-economy', None, str(self.worker_state))
        self.assertEqual(first, second)  # manual and future burn callers share this resolver
        self.init('codex-economy')
        for phase in ('finish', 'gate', 'explore', 'summarize'):
            output = self.call('dispatch', '--phase', phase, '--input', str(self.input))
            request = self.jobs[output['job_id']]
            expected = 'implement' if phase in ('finish', 'gate') else phase
            self.assertEqual(request['role'], expected)
            self.call('ack')


class ContinuationRecord(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.cwd = self.root / 'repo'
        self.cwd.mkdir()
        subprocess.run(['git', 'init', '-q', str(self.cwd)], check=True)
        subprocess.run(['git', '-C', str(self.cwd), '-c', 'user.name=Test',
                        '-c', 'user.email=test@example.invalid', 'commit',
                        '--allow-empty', '-qm', 'fixture'], check=True)
        self.run = self.root / 'run'
        self.run.mkdir(mode=0o700)
        m.write(self.run / 'run.json', {
            'account': 'acct', 'model': 'model', 'cwd': str(self.cwd),
            'worker_state': str(self.root / 'worker'), 'pending': None,
            'history': [],
        })

    def record(self, **overrides):
        values = {
            'executor': 'codex', 'account': 'acct', 'model': 'model',
            'run-dir': str(self.run), 'worker-state': str(self.root / 'worker'),
            'cwd': str(self.cwd),
        }
        values.update(overrides)
        return m.format_continuation_record(values)

    def test_record_round_trips_utf8_reserved_values(self):
        values = {
            'executor': 'codex', 'account': '名前 %=', 'model': 'model/β',
            'run-dir': str(self.run), 'worker-state': str(self.root / 'worker'),
            'cwd': str(self.cwd),
        }
        self.assertEqual(m.parse_continuation_record(m.format_continuation_record(values)), values)
        line = m.format_continuation_record(values)
        self.assertIn('%E5%90%8D%E5%89%8D', line)
        self.assertNotIn('名前', line)

    def test_latest_candidate_is_selected_and_invalid_latest_stops(self):
        old = self.record()
        comments = [{'id': 1, 'body': '<!-- unrelated -->'}, {'id': 4, 'body': old}]
        self.assertEqual(m.select_continuation_record(comments), m.parse_continuation_record(old))
        comments.append({'id': 5, 'body': old.replace('executor=codex', 'unknown=x executor=codex')})
        with self.assertRaisesRegex(m.ContinuationError, 'invalid'):
            m.select_continuation_record(comments)

    def test_latest_comment_with_multiple_candidates_stops(self):
        first = self.record()
        other = self.record(account='other')
        for second in (other, other.replace('account=', 'unknown=x account='), first):
            with self.subTest(second=second):
                with self.assertRaisesRegex(m.ContinuationError, 'multiple'):
                    m.select_continuation_record([{'id': 10, 'body': first + '\n' + second}])

    def test_latest_broken_marker_stops_without_falling_back(self):
        old = self.record()
        latest = self.record(account='other')
        for separator in ('\n', '\t', '', ':'):
            with self.subTest(separator=separator):
                broken = latest.replace(':v1 ', ':v1' + separator)
                with self.assertRaisesRegex(m.ContinuationError, 'invalid latest'):
                    m.select_continuation_record([
                        {'id': 1, 'body': old}, {'id': 10, 'body': broken},
                    ])

    def test_latest_single_candidate_ignores_older_ambiguity(self):
        old = self.record()
        latest = self.record(account='other')
        self.assertEqual(m.select_continuation_record([
            {'id': 10, 'body': latest},
            {'id': 1, 'body': old + '\n' + old},
            {'id': 11, 'body': 'Unrelated comment'},
        ]), m.parse_continuation_record(latest))

    def test_selected_source_and_run_values_must_match(self):
        record = m.parse_continuation_record(self.record())
        self.assertEqual(m.validate_continuation(record, self.run), record)
        with self.assertRaisesRegex(m.ContinuationError, 'mismatch'):
            m.validate_continuation(dict(record, model='other'), self.run)
        with self.assertRaisesRegex(m.ContinuationError, 'codex'):
            m.validate_continuation(dict(record, executor='claude'), self.run)

    def symlink_run(self):
        alias = self.root / 'alias'
        alias.symlink_to(self.root, target_is_directory=True)
        return alias / 'run'

    def test_symlink_run_path_restores_same_private_run(self):
        alias_run = self.symlink_run()
        record = m.parse_continuation_record(self.record(**{'run-dir': str(alias_run)}))
        self.assertNotEqual(str(alias_run), str(self.run.resolve()))
        self.assertTrue(alias_run.samefile(self.run))
        for run_dir in (alias_run, self.run.resolve()):
            with self.subTest(run_dir=run_dir):
                self.assertEqual(m.validate_continuation(record, run_dir), record)
        self.assertEqual(m.restore_continuation(issue_comments=[
            {'id': 1, 'body': self.record(**{'run-dir': str(alias_run)})},
        ]), record)

    def test_symlink_run_path_to_different_directory_stops(self):
        other = self.root / 'other-run'
        other.mkdir(mode=0o700)
        (other / 'run.json').write_text((self.run / 'run.json').read_text())
        alias = self.root / 'other-alias'
        alias.symlink_to(other, target_is_directory=True)
        record = m.parse_continuation_record(self.record(**{'run-dir': str(alias)}))
        with self.assertRaisesRegex(m.ContinuationError, 'run-dir mismatch'):
            m.validate_continuation(record, self.run)

    def test_symlink_run_path_preserves_permissions_and_ownership_checks(self):
        alias_run = self.symlink_run()
        comments = [{'id': 1, 'body': self.record(**{'run-dir': str(alias_run)})}]
        self.run.chmod(0o755)
        with self.assertRaises(m.ContinuationError):
            m.restore_continuation(issue_comments=comments)
        self.run.chmod(0o700)
        with patch.object(m.os, 'getuid', return_value=self.run.stat().st_uid + 1):
            with self.assertRaises(m.ContinuationError):
                m.restore_continuation(issue_comments=comments)

    def test_symlink_worker_state_and_cwd_restore_same_paths(self):
        (self.root / 'worker').mkdir()
        alias_root = self.symlink_run().parent
        state_path = self.run / 'run.json'
        original = json.loads(state_path.read_text())
        for key, state_key, name in [('worker-state', 'worker_state', 'worker'),
                                     ('cwd', 'cwd', 'repo')]:
            real = str((self.root / name).resolve())
            alias = str(alias_root / name)
            self.assertNotEqual(real, alias)
            self.assertTrue(Path(alias).samefile(real))
            for recorded, stored in [(alias, real), (real, alias)]:
                with self.subTest(key=key, recorded=recorded, stored=stored):
                    m.write(state_path, dict(original, **{state_key: stored}))
                    line = self.record(**{key: recorded})
                    self.assertEqual(m.restore_continuation(issue_comments=[
                        {'id': 1, 'body': line},
                    ]), m.parse_continuation_record(line))

    def test_symlink_worker_state_and_cwd_to_different_paths_stop(self):
        other = self.root / 'other'
        other.mkdir()
        alias = self.root / 'other-alias'
        alias.symlink_to(other, target_is_directory=True)
        state_path = self.run / 'run.json'
        original = json.loads(state_path.read_text())
        for key, state_key in [('worker-state', 'worker_state'), ('cwd', 'cwd')]:
            for recorded, stored in [(str(alias), original[state_key]),
                                     (original[state_key], str(alias))]:
                with self.subTest(key=key, recorded=recorded, stored=stored):
                    m.write(state_path, dict(original, **{state_key: stored}))
                    with self.assertRaisesRegex(m.ContinuationError, key + ' mismatch'):
                        m.restore_continuation(issue_comments=[
                            {'id': 1, 'body': self.record(**{key: recorded})},
                        ])

    def test_duplicate_keys_in_latest_record_stop_without_using_older_record(self):
        valid = self.record()
        for invalid in (valid.replace('model=model', 'account=model'),
                        valid.replace('account=acct', 'account=acct account=other')):
            with self.subTest(record=invalid):
                with self.assertRaisesRegex(m.ContinuationError, 'invalid latest'):
                    m.select_continuation_record([
                        {'id': 9, 'body': invalid}, {'id': 1, 'body': valid},
                    ])

    def test_restore_uses_only_issue_or_draft_pr_selected_source(self):
        valid = self.record()
        selected = [{'id': 8, 'body': valid},
                    {'id': 2, 'body': self.record(account='old')}]
        unselected = [{'id': 99, 'body': valid.replace('model=model', 'unknown=x')}]
        expected = m.parse_continuation_record(valid)
        self.assertEqual(m.restore_continuation(issue_comments=selected,
                                               draft_pr_comments=unselected), expected)
        self.assertEqual(m.restore_continuation(draft_pr_comments=selected), expected)
        # An existing issue with no usable record must not fall back to the PR.
        for issue in ([], unselected):
            with self.subTest(issue=issue):
                with self.assertRaises(m.ContinuationError):
                    m.restore_continuation(issue_comments=issue, draft_pr_comments=selected)
        with self.assertRaises(m.ContinuationError):
            m.restore_continuation(draft_pr_comments=unselected)

    def dispatch_restored(self, comments, instructions):
        record = m.restore_continuation(issue_comments=comments)
        with patch.object(sys, 'argv', [str(SCRIPT), '--run-dir', record['run-dir'],
                                      'dispatch', '--phase', 'implement',
                                      '--input', str(instructions)]):
            return m.main()

    def test_initial_record_restores_same_run_and_dispatch_identity(self):
        # Exercise init and dispatch, replacing only the external worker transport.
        self.run = self.root / 'initialized-run'
        with patch.object(sys, 'argv', [str(SCRIPT), '--run-dir', str(self.run), 'init',
                                      '--account', 'acct', '--model', 'model',
                                      '--worker-state', str(self.root / 'worker'),
                                      '--cwd', str(self.cwd)]):
            initialized = m.main()
        comments = [{'id': 1, 'body': self.record()}]
        instructions = self.root / 'additional-request.txt'
        instructions.write_text('Additional request: fix the reported defect.')
        with patch.object(m, 'worker', return_value={'status': 'completed'}) as worker:
            self.dispatch_restored(comments, instructions)
        state, command, option, request_path = worker.call_args.args
        self.assertEqual((command, option), ('submit', '--request'))
        self.assertEqual(Path(request_path).parent, Path(initialized['run_dir']))
        request = json.loads(Path(request_path).read_text())
        self.assertEqual((request['account'], request['model'], request['cwd']),
                         ('acct', 'model', str(self.cwd.resolve())))
        self.assertEqual(state['worker_state'], str((self.root / 'worker').resolve()))
        self.assertEqual(state['pending'], request['request_id'])
        self.assertIn(instructions.read_text(), request['prompt'])
        self.assertEqual(request['role'], 'implement')

    def test_run_json_mismatch_stops_before_delegation(self):
        comments = [{'id': 1, 'body': self.record()}]
        path = self.run / 'run.json'
        original = json.loads(path.read_text())
        instructions = self.root / 'additional-request.txt'
        instructions.write_text('Additional request')
        for key, record_key in [('account', 'account'), ('model', 'model'),
                                ('worker_state', 'worker-state'), ('cwd', 'cwd')]:
            with self.subTest(key=key), patch.object(m, 'worker') as worker:
                m.write(path, dict(original, **{key: 'different'}))
                with self.assertRaisesRegex(m.ContinuationError, record_key + ' mismatch'):
                    self.dispatch_restored(comments, instructions)
                worker.assert_not_called()
                self.assertFalse((self.run / 'request.json').exists())
                self.assertIsNone(json.loads(path.read_text())['pending'])
        path.unlink()
        with patch.object(m, 'worker') as worker:
            with self.assertRaisesRegex(m.ContinuationError, 'unavailable'):
                self.dispatch_restored(comments, instructions)
            worker.assert_not_called()

    def test_missing_or_malformed_record_fails_closed_without_fallback(self):
        with self.assertRaisesRegex(m.ContinuationError, 'not found'):
            m.select_continuation_record([])
        with self.assertRaisesRegex(m.ContinuationError, 'invalid'):
            m.parse_continuation_record('<!-- codex-develop-continuation:v1 executor=codex account= -->')


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
