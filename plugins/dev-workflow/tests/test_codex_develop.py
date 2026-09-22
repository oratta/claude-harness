import importlib.util
import hashlib
import json
import os
import re
import stat
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/codex-develop.py'
sys.path.insert(0, str(Path(__file__).resolve().parent))
spec = importlib.util.spec_from_file_location('develop', SCRIPT)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
# The adapter picks the role and codex-worker.py turns that role into a sandbox, so the two
# halves are only pinned together when one test reads both tables.
worker_spec = importlib.util.spec_from_file_location('codex_worker_roles', SCRIPT.parent / 'codex-worker.py')
worker_module = importlib.util.module_from_spec(worker_spec)
worker_spec.loader.exec_module(worker_module)


class ForegroundRequest(unittest.TestCase):
    # The foreground route has no run and no ledger: CODEX_HOME comes from the caller's
    # table and an account missing from it is refused rather than replaced.
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        # Resolved so the table's absolute paths compare equal to what the adapter records.
        self.root = Path(self.temp.name).resolve()
        self.cwd = self.root / 'repo'
        self.cwd.mkdir()
        subprocess.run(['git', 'init', '-q', str(self.cwd)], check=True)
        subprocess.run(['git', '-C', str(self.cwd), '-c', 'user.name=Test',
                        '-c', 'user.email=test@example.invalid', 'commit',
                        '--allow-empty', '-qm', 'fixture'], check=True)
        self.home = self.root / 'codex-home'
        self.home.mkdir()
        self.input = self.root / 'input.txt'
        self.input.write_text('Do only this phase.')
        self.out = self.root / 'request.json'
        self.profile_file = self.root / 'profiles.json'
        self.table = self.root / 'homes.json'
        self.write_profile('mapped')

    def write_profile(self, account):
        roles = {role: {'executor': 'codex', 'account': account,
                        'model': 'fixture-model', 'effort': 'low'}
                 for role in m.CANONICAL_ROLES}
        self.profile_file.write_text(json.dumps({'version': 1, 'profiles': {'custom': {'roles': roles}}}))

    def write_mixed_profile(self):
        roles = {role: {'executor': 'codex', 'account': 'mapped',
                        'model': role + '-model', 'effort': role + '-effort'}
                 for role in m.CANONICAL_ROLES}
        for role in ('spec-review', 'impl-review', 'review'):
            roles[role] = {'executor': 'claude', 'account': 'current',
                           'model': 'opus', 'effort': 'high'}
        roles['decider'] = {'executor': 'claude', 'account': 'current',
                            'model': 'fable', 'effort': 'high'}
        self.profile_file.write_text(json.dumps(
            {'version': 1, 'profiles': {'custom': {'roles': roles}}}))

    def call(self, *extra, phase='implement'):
        args = [str(SCRIPT), 'request', '--phase', phase, '--input', str(self.input),
                '--cwd', str(self.cwd), '--profile', 'custom',
                '--profile-file', str(self.profile_file), '--out', str(self.out), *extra]
        with patch.object(sys, 'argv', args):
            return m.main()

    def call_profile(self, profile, *, phase='implement', profile_file=None, out=None):
        target = out or self.out
        args = [str(SCRIPT), 'request', '--phase', phase, '--input', str(self.input),
                '--cwd', str(self.cwd), '--profile', profile,
                '--account-home', 'current=' + str(self.home),
                '--account-home', 'mapped=' + str(self.home), '--out', str(target)]
        if profile_file:
            args.extend(['--profile-file', str(profile_file)])
        with patch.object(sys, 'argv', args):
            return m.main()

    def test_request_resolves_the_home_without_legacy_state(self):
        source = SCRIPT.read_text()
        for value in ('continuation', 'run-dir', 'run.json', 'pending', 'sqlite3'):
            self.assertNotIn(value, source)
        result = self.call('--account-home', 'mapped=' + str(self.home))
        self.assertEqual(result['status'], 'request-written')
        self.assertEqual(result['codex_home'], str(self.home))
        request = json.loads(self.out.read_text())
        self.assertEqual(request['role'], 'implement')
        self.assertEqual(request['account'], 'mapped')
        self.assertEqual(request['model'], 'fixture-model')
        self.assertEqual(request['effort'], 'low')
        self.assertEqual(request['codex_home'], str(self.home))
        self.assertEqual(request['origin'], 'manual')
        self.assertIn('Dispatch HEAD: ', request['prompt'])

    def test_only_request_command_is_accepted(self):
        for command in ('init', 'dispatch', 'status', 'result', 'ack', 'cancel', 'retry'):
            with self.subTest(command=command):
                result = subprocess.run([sys.executable, str(SCRIPT), command],
                                        text=True, capture_output=True, timeout=20)
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                self.assertEqual(result.stdout, '')
                self.assertIn('usage:', result.stderr)

    def test_legacy_account_model_request_uses_explicit_account_home(self):
        args = [str(SCRIPT), 'request', '--phase', 'implement', '--input', str(self.input),
                '--cwd', str(self.cwd), '--account', 'mapped', '--model', 'legacy-model',
                '--account-home', 'mapped=' + str(self.home), '--out', str(self.out)]
        with patch.object(sys, 'argv', args):
            result = m.main()
        request = json.loads(self.out.read_text())
        self.assertEqual((result['status'], result['account'], result['model'], result['effort']),
                         ('request-written', 'mapped', 'legacy-model', None))
        self.assertEqual(request['codex_home'], str(self.home))
        self.assertNotIn('effort', request)

    def test_request_routes_claude_without_writing_codex_request_or_applying_budget_cap(self):
        self.write_mixed_profile()
        for mode, value in (('FABLE_BUDGET_MODE', 'exhausted'),
                            ('SHARED_BUDGET_MODE', 'depleted')):
            with self.subTest(mode=mode), patch.dict(os.environ, {mode: value}, clear=False):
                result = self.call('--account-home', 'mapped=' + str(self.home), phase='decider')
                self.assertEqual(result['status'], 'agent-required')
                self.assertEqual(tuple(result[key]
                                       for key in ('role', 'executor', 'account', 'model', 'effort')),
                                 ('decider', 'claude', 'current', 'fable', 'high'))
                self.assertEqual(result['head'], subprocess.check_output(
                    ['git', '-C', str(self.cwd), 'rev-parse', 'HEAD'], text=True).strip())
                self.assertFalse(self.out.exists())

    def test_every_phase_role_is_one_the_worker_accepts(self):
        self.assertLessEqual({role for role, _ in m.PHASES.values()}, set(worker_module.ROLES))

    def test_account_missing_from_the_table_is_refused_without_a_request(self):
        self.write_profile('absent')
        with self.assertRaises(RuntimeError):
            self.call('--account-home', 'mapped=' + str(self.home))
        self.assertFalse(self.out.exists())

    def test_the_two_ways_of_giving_the_table_are_never_combined(self):
        self.table.write_text(json.dumps({'mapped': str(self.home)}))
        with self.assertRaises(RuntimeError):
            self.call('--account-home', 'mapped=' + str(self.home), '--account-home-file', str(self.table))
        self.assertFalse(self.out.exists())
        self.assertEqual(self.call('--account-home-file', str(self.table))['codex_home'], str(self.home))

    def test_table_entries_must_be_existing_absolute_directories_named_once(self):
        for value in ('codex-home', str(self.root / 'absent'), str(self.input)):
            with self.subTest(value=value):
                self.table.write_text(json.dumps({'mapped': value}))
                with self.assertRaises(RuntimeError):
                    self.call('--account-home-file', str(self.table))
                self.assertFalse(self.out.exists())
        self.table.write_text('{"mapped":"/tmp","mapped":"/tmp"}')
        with self.assertRaises(RuntimeError):
            self.call('--account-home-file', str(self.table))
        for pairs in (['mapped=' + str(self.home), 'mapped=' + str(self.home)], ['mapped']):
            with self.subTest(pairs=pairs):
                with self.assertRaises(RuntimeError):
                    self.call(*[part for name in pairs for part in ('--account-home', name)])
                self.assertFalse(self.out.exists())

    def test_executor_discriminated_validation_rejects_invalid_entries(self):
        base = {role: {'executor':'codex', 'account':'mapped',
                       'model':'fixture-model', 'effort':'low'}
                for role in m.CANONICAL_ROLES}
        cases = [
            ('model', 'Claude model must be one of',
             ('spec-review', {'executor':'claude', 'account':'current', 'model':'gpt-6-astra'})),
            ('account', 'different Claude account execution is not supported yet',
             ('spec-review', {'executor':'claude', 'account':'reviewer', 'model':'opus'})),
            ('executor', 'executor must be claude or codex',
             ('implement', {'executor':'local'})),
        ]
        for role in (value for value in m.CANONICAL_ROLES if value != 'decider'):
            cases.append(('fable-' + role, 'fable is only supported for decider',
                          (role, {'executor':'claude', 'account':'current', 'model':'fable'})))
        for index, (label, message, (role, updates)) in enumerate(cases):
            with self.subTest(case=label):
                roles = {name: dict(entry) for name, entry in base.items()}
                roles[role].update(updates)
                profile = self.root/('invalid-executor-' + str(index) + '.json')
                profile.write_text(json.dumps({'version':1, 'profiles':{'custom':{'roles':roles}}}))
                target = self.root/('invalid-request-' + str(index) + '.json')
                with self.assertRaisesRegex(RuntimeError, message):
                    self.call_profile('custom', profile_file=profile, out=target)
                self.assertFalse(target.exists())

    def test_external_profile_is_strict_complete_and_uses_registered_accounts(self):
        roles = {role: {'executor':'codex', 'account':'mapped',
                        'model':'custom-model', 'effort':'future'}
                 for role in m.CANONICAL_ROLES}
        profile = self.root/'strict-profiles.json'
        profile.write_text(json.dumps({'version':1, 'profiles':{'custom':{'roles':roles}}}))
        result = self.call_profile('custom', profile_file=profile)
        self.assertEqual(result['status'], 'request-written')
        self.assertEqual(json.loads(self.out.read_text())['account'], 'mapped')

        invalids = [
            {'version':True, 'profiles':{'custom':{'roles':roles}}},
            {'version':2, 'profiles':{'custom':{'roles':roles}}},
            {'version':1, 'extra':1, 'profiles':{'custom':{'roles':roles}}},
            {'version':1, 'profiles':{'custom':{'roles':{k:v for k,v in roles.items() if k != 'decider'}}}},
            {'version':1, 'profiles':{'custom':{'roles':dict(roles, decider=dict(roles['decider'], executor='local'))}}},
            {'version':1, 'profiles':{'custom':{'roles':dict(roles, decider=dict(roles['decider'], account='absent'))}}},
            '{"version":1,"version":1,"profiles":{}}',
        ]
        for index, value in enumerate(invalids):
            with self.subTest(invalid=index):
                profile.write_text(value if isinstance(value, str) else json.dumps(value))
                target = self.root/('strict-invalid-' + str(index) + '.json')
                with self.assertRaises((RuntimeError, ValueError)):
                    self.call_profile('custom', profile_file=profile, out=target)
                self.assertFalse(target.exists())

    def test_review_must_equal_impl_review_in_profile_and_snapshot(self):
        roles = {role: {'executor':'codex', 'account':'mapped',
                        'model':'same-model', 'effort':'high'}
                 for role in m.CANONICAL_ROLES}
        roles['review'] = dict(roles['review'], model='different-model')
        profile = self.root/'review-mismatch.json'
        profile.write_text(json.dumps({'version':1, 'profiles':{'custom':{'roles':roles}}}))
        with self.assertRaisesRegex(RuntimeError, 'review.*impl-review'):
            self.call_profile('custom', profile_file=profile)

        config = {'version':1, 'profile':'custom', 'roles':roles}
        state = {'execution_config':config, 'execution_config_hash':m.execution_config_hash(config)}
        with self.assertRaisesRegex(RuntimeError, 'review.*impl-review'):
            m.resolve_execution(state, 'review')

    def test_builtin_profiles_resolve_all_roles_and_snapshot_hash(self):
        expected = {
            'codex-standard': ('gpt-5.6-sol', 'high', 'gpt-5.6-sol', 'medium'),
            'codex-economy': ('gpt-5.6-luna', 'medium', 'gpt-5.6-luna', 'medium'),
        }
        for profile, values in expected.items():
            config = m.load_profile(profile, None, {'current'})
            self.assertEqual((config['roles']['spec-write']['model'], config['roles']['spec-write']['effort'],
                              config['roles']['implement']['model'], config['roles']['implement']['effort']), values)
            for role in m.CANONICAL_ROLES:
                with self.subTest(profile=profile, role=role):
                    self.assertEqual(m.resolve_execution({'execution_config': config,
                        'execution_config_hash': m.execution_config_hash(config)}, role),
                        {'role': role} | config['roles'][role])
                    phases = [phase for phase, entry in m.PHASES.items() if entry[0] == role]
                    if not phases:
                        continue
                    target = self.root/(profile + '-' + role + '.json')
                    result = self.call_profile(profile, phase=phases[0], out=target)
                    self.assertEqual(result['status'], 'request-written')
                    request = json.loads(target.read_text())
                    self.assertEqual((request['role'], request['model'], request['effort']),
                                     (role, config['roles'][role]['model'], config['roles'][role]['effort']))
            self.assertEqual(m.execution_config_hash(config), hashlib.sha256(json.dumps(
                config, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()).hexdigest())

    def test_mixed_profile_resolves_every_role_and_builtin_hybrid_is_exact(self):
        config = m.load_profile('hybrid-standard', None, {'current'})
        expected = {
            'spec-write': ('codex','current','gpt-5.6-sol','high'),
            'spec-review': ('claude','current','opus','high'),
            'implement': ('codex','current','gpt-5.6-sol','medium'),
            'impl-review': ('claude','current','opus','high'),
            'review': ('claude','current','opus','high'),
            'decider': ('claude','current','fable','high'),
            'explore': ('codex','current','gpt-5.6-luna','low'),
            'summarize': ('codex','current','gpt-5.6-luna','low'),
        }
        for role, values in expected.items():
            self.assertEqual(tuple(config['roles'][role][key]
                                   for key in ('executor','account','model','effort')), values)
            self.assertEqual(m.resolve_execution({'execution_config':config,
                'execution_config_hash':m.execution_config_hash(config)}, role),
                {'role':role} | config['roles'][role])
            phases = [phase for phase, entry in m.PHASES.items() if entry[0] == role]
            if not phases:
                continue
            target = self.root/('hybrid-' + role + '.json')
            result = self.call_profile('hybrid-standard', phase=phases[0], out=target)
            self.assertEqual((result['role'], result['executor'], result['model'], result['effort']),
                             (role, values[0], values[2], values[3]))
            self.assertEqual(target.exists(), values[0] == 'codex')
        self.assertEqual(config['roles']['review'], config['roles']['impl-review'])

    def test_profiles_preserve_coordinator_phase_order_and_role_mapping(self):
        expected = {'spec':'spec-write', 'spec-review':'spec-review', 'implement':'implement',
                    'finish':'implement', 'gate':'implement', 'review':'impl-review',
                    'decider':'decider', 'explore':'explore', 'summarize':'summarize'}
        for profile in ('codex-standard', 'codex-economy', 'hybrid-standard'):
            for phase, role in expected.items():
                with self.subTest(profile=profile, phase=phase):
                    target = self.root/(profile + '-' + phase + '-mapping.json')
                    result = self.call_profile(profile, phase=phase, out=target)
                    self.assertEqual(result['role'], role)
                    if result['executor'] == 'codex':
                        self.assertEqual(json.loads(target.read_text())['role'], role)

    def test_writer_phases_are_told_to_finish_their_own_github_work(self):
        sources = {'spec':'skills/develop/references/roles/worker.md',
                   'implement':'skills/develop/references/roles/worker.md',
                   'finish':'skills/develop/references/roles/worker.md',
                   'gate':'skills/develop/references/roles/gate-runner.md'}
        for phase in ('spec', 'implement', 'finish', 'gate'):
            with self.subTest(phase=phase):
                target = self.root/('writer-' + phase + '.json')
                self.call_profile('codex-standard', phase=phase, out=target)
                text = json.loads(target.read_text())['prompt']
                self.assertIn('commit yourself here', text)
                self.assertIn('do not return needs-coordinator for', text)
                self.assertNotIn('the coordinator posts it on your behalf', text)
                self.assertNotIn('no network access', text)
                self.assertIn('needs-reviewer/needs-decider', text)
                self.assertIn('Never merge or enable auto-merge', text)
                self.assertIn('CANONICAL SOURCE ' + sources[phase], text)
                self.assertIn('CANONICAL SOURCE skills/develop/references/decision-criteria.md', text)
                if phase == 'gate':
                    self.assertIn('CANONICAL SOURCE skills/pr-review-gate/SKILL.md', text)

    def test_reader_phases_return_the_verdict_for_the_coordinator_to_post(self):
        sources = {'spec-review':'skills/develop/references/roles/spec-reviewer.md',
                   'review':'skills/develop/references/roles/gate-runner.md',
                   'decider':'agents/decider.md',
                   'explore':'skills/develop/references/roles/worker.md',
                   'summarize':'skills/develop/references/roles/worker.md'}
        for phase in ('spec-review', 'review', 'decider', 'explore', 'summarize'):
            with self.subTest(phase=phase):
                target = self.root/('reader-' + phase + '.json')
                self.call_profile('codex-standard', phase=phase, out=target)
                text = json.loads(target.read_text())['prompt']
                self.assertIn('never write to GitHub, push, or commit', text)
                self.assertIn('the coordinator posts it on your behalf', text)
                self.assertNotIn('commit yourself here', text)
                self.assertNotIn('no network access', text)
                self.assertIn('needs-reviewer/needs-decider', text)
                self.assertIn('Never merge or enable auto-merge', text)
                self.assertIn('CANONICAL SOURCE ' + sources[phase], text)
                self.assertIn('CANONICAL SOURCE skills/develop/references/decision-criteria.md', text)
                if phase == 'review':
                    self.assertIn('CANONICAL SOURCE skills/pr-review-gate/SKILL.md', text)

    def test_review_phase_uses_gate_and_reviewer_contract_sources(self):
        target = self.root/'review-contract.json'
        self.call_profile('codex-standard', phase='review', out=target)
        text = json.loads(target.read_text())['prompt']
        self.assertIn('CANONICAL SOURCE skills/develop/references/roles/gate-runner.md', text)
        self.assertIn('CANONICAL SOURCE skills/pr-review-gate/SKILL.md', text)
        self.assertIn('変更点の一覧', text)
        self.assertIn('照合表', text)
        self.assertIn('ハンク被覆', text)
        self.assertIn('補足済み回数', text)
        self.assertIn('review-incomplete', text)

    def test_request_file_mode_is_0600(self):
        self.call('--account-home', 'mapped=' + str(self.home))
        self.assertEqual(stat.S_IMODE(self.out.stat().st_mode), 0o600)


class DocumentationContracts(unittest.TestCase):
    def setUp(self):
        self.root = SCRIPT.parents[1]
        self.adapter = (self.root / 'references/codex-develop.md').read_text()
        self.skill = (self.root / 'skills/develop/SKILL.md').read_text()

    def test_removed_transport_vocabulary_is_absent(self):
        documents = [
            self.root / 'scripts/CODEX-WORKER.md',
            self.root / 'docs/codex-develop.md',
            self.root / 'references/codex-develop.md',
        ]
        for path in documents:
            text = path.read_text()
            with self.subTest(path=path):
                self.assertIsNone(re.search(r'\b(?:ledger|ack|unknown|reap)\b', text))
                self.assertNotIn('継続記録', text)

    def test_executor_branch_is_documented_on_exactly_one_line(self):
        executor_lines = [line for line in self.adapter.splitlines() if 'executor' in line]
        self.assertEqual(len(executor_lines), 1)  # grep -c "executor" ... must print 1
        branch = executor_lines[0]
        for value in ('role', 'claude', 'Agent', 'codex', '前景'):
            self.assertIn(value, branch)
        self.assertIn('references/codex-develop.md', self.skill)
        self.assertIn('分岐を再掲せず', self.skill)

    def test_resume_rechecks_caps_and_hands_off_without_changing_requested_tuple(self):
        for name, document in (('adapter', self.adapter), ('skill', self.skill)):
            with self.subTest(document=name):
                for value in ('SendMessage', '上限', 'fresh thread', 'requested tuple',
                              '工程完了', '停止確認', 'FABLE_BUDGET_MODE',
                              'SHARED_BUDGET_MODE'):
                    self.assertIn(value, document)
        self.assertIn('exhausted', self.adapter)
        self.assertIn('depleted', self.adapter)
        self.assertIn('requested model / applied model / reason', self.adapter)


if __name__ == '__main__':
    unittest.main()
