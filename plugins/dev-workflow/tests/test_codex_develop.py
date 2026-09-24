import importlib.util
import base64
import hashlib
import io
import json
import os
import re
import stat
from pathlib import Path
import subprocess
import sys
import tempfile
import time
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
        # Claude の実効値はレジストリとセッション記録も読むので、実環境の ~/.claude から切り離す
        # usage-probe.sh の試行状態とロックは $HOME/.claude 固定の既定なので明示で向け、
        # 存在しない応答ファイルでテスト経路に入れて実 API を叩かせない
        environ = patch.dict(os.environ, {
            'CLAUDE_CONFIG_DIR': str(self.root),
            'USAGE_PROBE_STATE': str(self.root / '.usage-probe-state'),
            'USAGE_PROBE_LOCK': str(self.root / '.usage-probe.lock'),
            'USAGE_PROBE_RESPONSE_FILE': str(self.root / 'nonexistent.json'),
        })
        environ.start()
        self.addCleanup(environ.stop)
        for key in ('CLAUDE_ACCOUNTS_FILE', 'USAGE_SESSIONS_DIR', 'CLAUDE_SECURESTORAGE_CONFIG_DIR'):
            os.environ.pop(key, None)

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

    def call_automatic(self, *, phase='implement', accounts=('a', 'b'), out=None):
        target = out or self.out
        args = [str(SCRIPT), 'request', '--phase', phase, '--input', str(self.input),
                '--cwd', str(self.cwd), '--out', str(target)]
        for account in accounts:
            home = self.root / ('codex-' + account)
            home.mkdir(exist_ok=True)
            args.extend(['--account-home', account + '=' + str(home)])
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
            'codex-standard': ('sol', 'high', 'sol', 'medium'),
            'codex-economy': ('luna', 'medium', 'luna', 'medium'),
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

    def test_builtin_codex_entries_name_families_not_model_ids(self):
        # The families resolve to the newest listed version at dispatch time, so the table
        # never needs editing when a new generation ships.
        table = Path(m.__file__).resolve().parents[1]/'references/codex-role-profiles.json'
        self.assertIsNone(re.search(r'gpt-[0-9]', table.read_text()))
        for name, values in (('codex-standard', ('sol', 'sol')), ('codex-economy', ('luna', 'luna'))):
            config = m.load_profile(name, None, {'current'})
            expected = {'spec-write': values[0], 'implement': values[1], 'explore': 'luna',
                        'summarize': 'luna', 'spec-review': 'sol', 'impl-review': 'sol',
                        'review': 'sol', 'decider': 'astra'}
            self.assertEqual({role: entry['model'] for role, entry in config['roles'].items()}, expected)
            self.assertTrue(all(entry['executor'] == 'codex' and entry['account'] == 'current'
                                for entry in config['roles'].values()))

    def test_family_names_and_exact_ids_are_written_to_the_request_unchanged(self):
        roles = {role: {'executor':'codex', 'account':'mapped', 'model':'sol', 'effort':'high'}
                 for role in m.CANONICAL_ROLES}
        roles['spec-write'] = dict(roles['spec-write'], model='gpt-5.6-sol')
        profile = self.root/'mixed-models.json'
        profile.write_text(json.dumps({'version':1, 'profiles':{'custom':{'roles':roles}}}))
        for phase, model in (('implement', 'sol'), ('spec', 'gpt-5.6-sol')):
            with self.subTest(phase=phase):
                target = self.root/('mixed-' + phase + '.json')
                result = self.call_profile('custom', phase=phase, profile_file=profile, out=target)
                self.assertEqual(result['status'], 'request-written')
                self.assertEqual(json.loads(target.read_text())['model'], model)
        for model in ('sol', 'gpt-6-astra'):
            with self.subTest(legacy=model):
                target = self.root/('legacy-' + model + '.json')
                args = [str(SCRIPT), 'request', '--phase', 'implement', '--input', str(self.input),
                        '--cwd', str(self.cwd), '--account', 'mapped', '--model', model,
                        '--account-home', 'mapped=' + str(self.home), '--out', str(target)]
                with patch.object(sys, 'argv', args):
                    result = m.main()
                self.assertEqual((result['status'], result['model']), ('request-written', model))
                self.assertEqual(json.loads(target.read_text())['model'], model)

    def test_reverse_hybrid_profile_resolves_every_canonical_role(self):
        config = m.load_profile('claude-write-codex-review', None, {'current'})
        expected = {
            'spec-write': ('claude', 'current', 'sonnet', 'medium'),
            'implement': ('claude', 'current', 'sonnet', 'medium'),
            'explore': ('claude', 'current', 'haiku', 'low'),
            'summarize': ('claude', 'current', 'haiku', 'low'),
            'spec-review': ('codex', 'current', 'sol', 'high'),
            'impl-review': ('codex', 'current', 'sol', 'high'),
            'review': ('codex', 'current', 'sol', 'high'),
            'decider': ('codex', 'current', 'astra', 'high'),
        }
        self.assertEqual(set(config['roles']), set(m.CANONICAL_ROLES))
        for role, values in expected.items():
            self.assertEqual(tuple(config['roles'][role][key]
                                   for key in ('executor', 'account', 'model', 'effort')), values)


    def snapshot(self, margin, *, now=2_000_000, age=0, minutes=None):
        reset = now + 302400
        used = 50 - margin
        value = {'fetched_at': now - age, 'weekly_all_pct': used,
                 'weekly_resets_epoch': reset}
        if minutes is not None:
            value = {'fetched_at': now - age, 'windows': [
                {'minutes': minutes, 'used_percent': used, 'reset_at': reset}]}
        return value

    def test_selection_table_and_zero_boundary(self):
        cases = [
            (20, 10, 'claude-write-codex-review'),
            (20, -5, 'claude-default'),
            (-5, 30, 'codex-standard'),
            (-5, -5, 'claude-default'),
            (0, 0, 'claude-write-codex-review'),
        ]
        for claude, codex, expected in cases:
            with self.subTest(claude=claude, codex=codex):
                selected, reason = m.select_configuration(claude, codex)
                self.assertEqual(selected, expected)
                self.assertIsInstance(reason, str)

    def write_claude_snapshot(self, accounts, active='default'):
        path = self.root / 'claude-snapshot.json'
        path.write_text(json.dumps({'schema': 2, 'active': active, 'accounts': accounts}))
        return path

    def write_session_record(self, key, *, observed, weekly, reset):
        sessions = self.root / '.usage-sessions'
        sessions.mkdir(exist_ok=True)
        (sessions / (key + '.json')).write_text(json.dumps({
            'schema': 1, 'key': key, 'observed_at': observed,
            'five_hour_pct': None, 'five_hour_resets_epoch': None,
            'weekly_all_pct': weekly, 'weekly_resets_epoch': reset}))

    def test_freshness_reset_and_weekly_window_are_fail_safe(self):
        now = 2_000_000
        self.assertIsNotNone(m.usage_margin(self.snapshot(10, now=now, age=300,
                                                        minutes=10080), now, codex=True))
        self.assertIsNone(m.usage_margin(self.snapshot(10, now=now, age=301,
                                                     minutes=10080), now, codex=True))
        self.assertIsNone(m.usage_margin(self.snapshot(10, now=now,
                                                      minutes=300), now, codex=True))

    def test_active_claude_slot_uses_launch_environment_before_snapshot_mirror(self):
        now = 2_000_000
        secure = '/tmp/claude-a'
        (self.root / 'accounts.json').write_text(json.dumps({'accounts': [
            {'id': 'a', 'securestorage': secure}, {'id': 'b', 'securestorage': None}]}))
        path = self.root / 'mirror-snapshot.json'
        path.write_text(json.dumps({
            'schema': 2, 'active': 'b', 'fetched_at': now, 'weekly_all_pct': 0,
            'weekly_resets_epoch': now + 302400,
            'accounts': {'a': self.snapshot(-5, now=now), 'b': self.snapshot(30, now=now)}}))
        with patch.dict(os.environ, {'CLAUDE_SECURESTORAGE_CONFIG_DIR': secure}, clear=False):
            evidence = m.claude_usage_evidence(path, now)
        self.assertEqual(evidence['account'], 'a')
        self.assertAlmostEqual(evidence['margin'], -5)

    def test_claude_margin_comes_from_session_record_while_probe_keeps_failing(self):
        # 429 が続いて snapshot が無いままでも、起動 account の鍵のセッション記録で評価する
        now = 2_000_000
        observed = now - 3600
        self.write_session_record('default', observed=observed, weekly=20, reset=now + 302400)
        evidence = m.claude_usage_evidence(self.root / 'absent-snapshot.json', now)
        self.assertEqual(evidence['account'], 'default')
        self.assertAlmostEqual(evidence['margin'], 30)
        self.assertEqual(evidence['fetched_at'], observed)

    def test_claude_old_value_is_used_until_its_reset(self):
        now = 2_000_000
        path = self.write_claude_snapshot({'default': self.snapshot(10, now=now, age=86400)})
        evidence = m.claude_usage_evidence(path, now)
        self.assertAlmostEqual(evidence['margin'], 10)
        self.assertEqual(evidence['fetched_at'], now - 86400)
        # リセット時刻を過ぎた値は 0% として読む（週経過は次の週の頭から数える）
        path = self.write_claude_snapshot({'default': self.snapshot(10, now=now, age=86400) |
                                           {'weekly_resets_epoch': now}})
        evidence = m.claude_usage_evidence(path, now)
        self.assertAlmostEqual(evidence['margin'], 0)

    def test_claude_margin_is_missing_without_any_value(self):
        now = 2_000_000
        evidence = m.claude_usage_evidence(self.root / 'absent-snapshot.json', now)
        self.assertIsNone(evidence['margin'])
        self.assertIsNone(evidence['fetched_at'])

    def test_explicit_profile_never_reads_automatic_snapshots(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td).resolve()
            cwd, home = root/'repo', root/'home'
            cwd.mkdir(); home.mkdir()
            subprocess.run(['git', 'init', '-q', str(cwd)], check=True)
            subprocess.run(['git', '-C', str(cwd), '-c', 'user.name=T',
                            '-c', 'user.email=t@example.invalid', 'commit',
                            '--allow-empty', '-qm', 'fixture'], check=True)
            inp, out = root/'input', root/'out'; inp.write_text('x')
            args = [str(SCRIPT), 'request', '--phase', 'implement', '--input', str(inp),
                    '--cwd', str(cwd), '--profile', 'codex-standard',
                    '--account-home', 'current=' + str(home), '--out', str(out)]
            with patch.object(sys, 'argv', args), \
                    patch.object(m, 'automatic_selection', side_effect=AssertionError('read')):
                self.assertEqual(m.main()['status'], 'request-written')

    def test_automatic_request_without_table_uses_codex_home_as_current_candidate(self):
        target = self.root / 'automatic-env-home.json'
        args = [str(SCRIPT), 'request', '--phase', 'implement', '--input', str(self.input),
                '--cwd', str(self.cwd), '--out', str(target)]
        selection = {'selection_mode': 'automatic', 'configuration': 'claude-default',
                     'reason': 'only-claude-has-headroom',
                     'claude': {'account': 'active', 'margin': 10, 'fetched_at': 2_000_000},
                     'codex': {'account': None, 'margin': None, 'fetched_at': None}}
        with patch.dict(os.environ, {'CODEX_HOME': str(self.home)}, clear=False), \
                patch.object(m, 'automatic_selection', return_value=('claude-default', selection)) as automatic, \
                patch.object(sys, 'argv', args):
            m.main()
        automatic.assert_called_once_with({'current': str(self.home)})

    def test_automatic_request_without_table_leaves_codex_missing_when_default_home_absent(self):
        absent_home = self.root / 'home-without-codex'
        absent_home.mkdir()
        target = self.root / 'automatic-missing-home.json'
        args = [str(SCRIPT), 'request', '--phase', 'implement', '--input', str(self.input),
                '--cwd', str(self.cwd), '--out', str(target)]
        selection = {'selection_mode': 'automatic', 'configuration': 'claude-default',
                     'reason': 'no-provider-has-headroom',
                     'claude': {'account': None, 'margin': None, 'fetched_at': None},
                     'codex': {'account': None, 'margin': None, 'fetched_at': None}}
        with patch.dict(os.environ, {}, clear=True), \
                patch.object(Path, 'home', return_value=absent_home), \
                patch.object(m, 'automatic_selection', return_value=('claude-default', selection)) as automatic, \
                patch.object(sys, 'argv', args):
            result = m.main()
        automatic.assert_called_once_with({})
        self.assertIsNone(result['selection']['codex']['margin'])

    def test_explicit_profile_without_table_does_not_use_default_codex_home(self):
        # The profile itself requests the 'current' account (not 'mapped'), so a bug that
        # completes an empty table with CODEX_HOME's default_automatic_account_home() would
        # make 'current' look registered and silently let this request through.
        self.write_profile('current')
        with patch.dict(os.environ, {'CODEX_HOME': str(self.home)}, clear=False):
            with self.assertRaisesRegex(RuntimeError, 'account is not registered'):
                self.call()
        self.assertFalse(self.out.exists())

    def test_codex_cache_is_per_home_sanitized_and_preserved_on_failure(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td).resolve(); config = root/'config'; config.mkdir()
            homes = {'a': str((root/'a').resolve()), 'b': str((root/'b').resolve())}
            claims = base64.urlsafe_b64encode(json.dumps({'email': 'test@example.invalid'}).encode()).decode().rstrip('=')
            for home in homes.values():
                Path(home).mkdir()
                (Path(home)/'auth.json').write_text(json.dumps(
                    {'tokens': {'id_token': 'x.' + claims + '.x', 'account_id': 'account'}}))
            now = int(time.time())
            result = {'identity': m._auth_identity(next(iter(homes.values()))),
                      'windows': [{'minutes': 10080, 'used_percent': 10,
                                   'reset_at': now + 604000}]}
            with patch.object(m, 'probe_codex_account', return_value=result):
                values = m.read_codex_usages(homes, str(config), now)
            self.assertEqual(list(values), ['a', 'b'])
            cache_files = sorted((config/'codex-usage').glob('*.json'))
            self.assertEqual(len(cache_files), 2)
            for path in cache_files:
                text = path.read_text()
                self.assertNotIn(str(root), text)
                self.assertNotIn('raw', text)
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            with patch.object(m, 'probe_codex_account', side_effect=RuntimeError('offline')):
                preserved = m.read_codex_usages(homes, str(config), now + 200)
            self.assertEqual(preserved['a']['fetched_at'], now)
            self.assertEqual(preserved['b']['fetched_at'], now)

    def test_automatic_codex_account_is_bound_to_every_codex_role(self):
        config = m.load_profile('claude-write-codex-review', None, {'a', 'b', 'current'})
        bound = m.bind_codex_account(config, 'b', {'a', 'b', 'current'})
        for role, entry in bound['roles'].items():
            self.assertEqual(entry['account'], 'b' if entry['executor'] == 'codex' else 'current')
        state = {'execution_config': bound,
                 'execution_config_hash': m.execution_config_hash(bound)}
        self.assertEqual(m.resolve_execution(state, 'review')['account'], 'b')

    def test_automatic_profile_is_validated_after_representative_account_binding(self):
        selection = {'selection_mode': 'automatic', 'configuration': 'codex-standard',
                     'reason': 'only-codex-has-headroom',
                     'claude': {'account': None, 'margin': -5, 'fetched_at': None},
                     'codex': {'account': 'a', 'margin': 30, 'fetched_at': 2_000_000}}
        with patch.object(m, 'automatic_selection', return_value=('codex-standard', selection)):
            result = self.call_automatic(accounts=('a',))
        self.assertEqual((result['status'], result['account'], result['selection']['reason']),
                         ('request-written', 'a', 'only-codex-has-headroom'))
        self.assertTrue(all(entry['account'] == 'a'
                            for entry in result['execution_config']['roles'].values()))

    def test_automatic_selection_refreshes_claude_snapshot_with_the_reader_path(self):
        now = 2_000_000
        snapshot_path = self.root / 'selected-snapshot.json'
        snapshot_path.write_text(json.dumps({'schema': 2, 'active': 'default', 'accounts': {
            'default': self.snapshot(20, now=now)}}))
        with patch.dict(os.environ, {'CLAUDE_CONFIG_DIR': str(self.root),
                                     'USAGE_SNAPSHOT': str(snapshot_path)}, clear=False), \
                patch.object(m, '_run_usage_probe') as probe, \
                patch.object(m, 'read_codex_usages', return_value={}):
            selected, evidence = m.automatic_selection({}, now)
        probe.assert_called_once_with(snapshot_path)
        self.assertEqual(selected, 'claude-default')
        self.assertEqual(evidence['reason'], 'only-claude-has-headroom')

    def test_quota_parser_uses_only_the_standard_codex_bucket(self):
        now = 2_000_000
        other = {'secondary': {'windowDurationMins': 10080, 'usedPercent': 0,
                               'resetsAt': now + 302400}}
        codex = {'secondary': {'windowDurationMins': 10080, 'usedPercent': 90,
                               'resetsAt': now + 302400}}
        windows = m._quota_windows({'rateLimitsByLimitId': {'other': other, 'codex': codex}})
        self.assertEqual(windows, [{'minutes': 10080, 'used_percent': 90,
                                    'reset_at': now + 302400}])
        self.assertEqual(m._quota_windows({'rateLimits': other | {'limitId': 'other'}}), [])
        self.assertEqual(m._quota_windows({'rateLimits': codex | {'limitId': 'codex'}}),
                         [{'minutes': 10080, 'used_percent': 90,
                           'reset_at': now + 302400}])

    def test_rpc_consumes_buffered_complete_lines_before_waiting(self):
        read_fd, write_fd = os.pipe()
        messages = [
            {'method': 'server/ready', 'params': {}},
            {'id': 1, 'result': {'one': 1}},
            {'id': 2, 'result': {'two': 2}},
            {'id': 3, 'result': {'three': 3}},
        ]
        os.write(write_fd, b''.join(json.dumps(value).encode() + b'\n' for value in messages))

        class Input(io.BytesIO):
            def write(self, value):
                return super().write(value.encode() if isinstance(value, str) else value)

        class Process:
            def __init__(self):
                self.stdin = Input()
                self.stdout = os.fdopen(read_fd, 'rb')

            def terminate(self):
                os.close(write_fd)

            def wait(self, timeout=None):
                return 0

            def kill(self):
                pass

        process = Process()
        self.addCleanup(process.stdout.close)
        with patch.object(m.subprocess, 'Popen', return_value=process):
            result = m._rpc_requests('/account', [('initialize', {}), ('account/read', {}),
                                                   ('account/rateLimits/read', {})], timeout=0.05)
        self.assertEqual(result, [{'one': 1}, {'two': 2}, {'three': 3}])

    def test_corrupt_cache_isolated_to_its_account(self):
        now = 2_000_000
        config = self.root / 'cache-config'
        config.mkdir()
        homes = {}
        claims = base64.urlsafe_b64encode(
            json.dumps({'email': 'test@example.invalid'}).encode()).decode().rstrip('=')
        for name in ('a', 'b'):
            home = self.root / ('isolated-' + name)
            home.mkdir()
            (home / 'auth.json').write_text(json.dumps(
                {'tokens': {'id_token': 'x.' + claims + '.x', 'account_id': 'account'}}))
            homes[name] = str(home)
        cache_a = m._cache_path(config, homes['a'])
        cache_a.parent.mkdir()
        cache_a.write_text('[]')
        valid = {'identity': m._auth_identity(homes['b']),
                 'windows': [{'minutes': 10080, 'used_percent': 10,
                              'reset_at': now + 302400}]}

        def probe(home):
            if home == homes['a']:
                raise RuntimeError('offline')
            return valid

        with patch.object(m, 'probe_codex_account', side_effect=probe):
            values = m.read_codex_usages(homes, str(config), now)
        self.assertIsNone(values['a'])
        self.assertEqual(values['b']['windows'], valid['windows'])

    def test_acceptance_selection_cases_flow_through_build_request(self):
        now = 2_000_000
        snapshot_path = self.root / 'acceptance-snapshot.json'
        cases = [
            ('both-headroom', 20, 10, 0, 'claude-write-codex-review',
             'both-providers-have-headroom', 'claude', 'current'),
            ('codex-blocked', 20, -5, 0, 'claude-default',
             'only-claude-has-headroom', 'claude', 'current'),
            ('claude-blocked', -5, 30, 0, 'codex-standard',
             'only-codex-has-headroom', 'codex', 'a'),
            ('both-blocked', -5, -5, 0, 'claude-default',
             'no-provider-has-headroom', 'claude', 'current'),
            ('age-300', -5, 30, 300, 'codex-standard',
             'only-codex-has-headroom', 'codex', 'a'),
            ('age-301', -5, 30, 301, 'claude-default',
             'no-provider-has-headroom', 'claude', 'current'),
            ('missing', None, None, 0, 'claude-default',
             'no-provider-has-headroom', 'claude', 'current'),
        ]
        for label, claude_margin, codex_margin, age, configuration, reason, executor, account in cases:
            with self.subTest(case=label):
                if claude_margin is None:
                    snapshot = {'schema': 2, 'accounts': {}}
                    usages = {'a': None, 'b': None}
                else:
                    snapshot = {'schema': 2, 'active': 'default', 'accounts': {
                        'default': self.snapshot(claude_margin, now=now, age=age)}}
                    usages = {'a': self.snapshot(codex_margin, now=now, age=age,
                                                  minutes=10080), 'b': None}
                snapshot_path.write_text(json.dumps(snapshot))
                target = self.root / ('acceptance-' + label + '.json')
                with patch.dict(os.environ, {'CLAUDE_CONFIG_DIR': str(self.root),
                                             'USAGE_SNAPSHOT': str(snapshot_path)}, clear=False), \
                        patch.object(m, '_run_usage_probe'), \
                        patch.object(m.time, 'time', return_value=now), \
                        patch.object(m, 'read_codex_usages', return_value=usages):
                    result = self.call_automatic(out=target)
                self.assertEqual(result['selection']['configuration'], configuration)
                self.assertEqual(result['selection']['reason'], reason)
                self.assertEqual(result['executor'], executor)
                self.assertEqual(result['account'], account)
                self.assertEqual(target.exists(), executor == 'codex')

    def test_best_codex_account_uses_margin_then_declaration_order(self):
        now = 2_000_000
        values = {
            'a': self.snapshot(30, now=now, minutes=10080),
            'b': self.snapshot(10, now=now, minutes=10080),
        }
        with tempfile.TemporaryDirectory() as td, \
                patch.dict(os.environ, {'CLAUDE_CONFIG_DIR': td}, clear=False), \
                patch.object(m, 'read_codex_usages', return_value=values):
            selected, evidence = m.automatic_selection({'a': '/a', 'b': '/b'}, now)
        self.assertEqual(selected, 'codex-standard')
        self.assertEqual(evidence['codex']['account'], 'a')
        values['b'] = self.snapshot(30, now=now, minutes=10080)
        with tempfile.TemporaryDirectory() as td, \
                patch.dict(os.environ, {'CLAUDE_CONFIG_DIR': td}, clear=False), \
                patch.object(m, 'read_codex_usages', return_value=values):
            _, evidence = m.automatic_selection({'a': '/a', 'b': '/b'}, now)
        self.assertEqual(evidence['codex']['account'], 'a')

    def test_mixed_profile_resolves_every_role_and_builtin_hybrid_is_exact(self):
        config = m.load_profile('hybrid-standard', None, {'current'})
        expected = {
            'spec-write': ('codex','current','sol','high'),
            'spec-review': ('claude','current','opus','high'),
            'implement': ('codex','current','sol','medium'),
            'impl-review': ('claude','current','opus','high'),
            'review': ('claude','current','opus','high'),
            'decider': ('claude','current','fable','high'),
            'explore': ('codex','current','luna','low'),
            'summarize': ('codex','current','luna','low'),
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

    def test_automatic_selection_contracts_are_documented_without_statusline_dependency(self):
        source = SCRIPT.read_text()
        self.assertNotIn('statusline-codex', source)
        self.assertNotIn('.statusline-codex', source)
        decision = (self.root / 'skills/develop/references/decision-criteria.md').read_text()
        self.assertIn('<= 300', decision)
        self.assertIn('> 300', decision)
        self.assertIn('#374', decision)
        for text in (self.adapter, self.skill,
                     (self.root / 'docs/codex-develop.md').read_text()):
            self.assertIn('claude-write-codex-review', text)
            self.assertIn('300', text)
            self.assertIn('margin', text)

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
