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


class RequestFixture:
    # A throwaway repository, Codex home and profile file, cut off from the real ~/.claude.
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
            # The resolver reads these; without them a test would follow the real week's usage.
            'FABLE_BUDGET_MODE': 'conserve',
            'SHARED_BUDGET_MODE': 'ok',
        })
        environ.start()
        self.addCleanup(environ.stop)
        for key in ('CLAUDE_ACCOUNTS_FILE', 'USAGE_SESSIONS_DIR', 'CLAUDE_SECURESTORAGE_CONFIG_DIR'):
            os.environ.pop(key, None)

    def write_profile(self, account):
        roles = {role: {'executor': 'codex', 'account': account, 'effort': 'low'}
                 for role in m.CANONICAL_ROLES}
        self.profile_file.write_text(json.dumps({'version': 2, 'profiles': {'custom': {'roles': roles}}}))

    def write_mixed_profile(self):
        roles = {role: {'executor': 'codex', 'account': 'mapped', 'effort': role + '-effort'}
                 for role in m.CANONICAL_ROLES}
        for role in ('spec-review', 'impl-review', 'review', 'decider'):
            roles[role] = {'executor': 'claude', 'account': 'current', 'effort': 'high'}
        self.profile_file.write_text(json.dumps(
            {'version': 2, 'profiles': {'custom': {'roles': roles}}}))

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


class ForegroundRequest(RequestFixture, unittest.TestCase):
    # The foreground route has no run and no ledger: CODEX_HOME comes from the caller's
    # table and an account missing from it is refused rather than replaced.
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
        self.assertEqual(request['model'], 'sol')
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

    def test_request_routes_claude_without_writing_codex_request(self):
        self.write_mixed_profile()
        for mode, value, model in (('FABLE_BUDGET_MODE', 'exhausted', 'opus'),
                                   ('SHARED_BUDGET_MODE', 'depleted', 'sonnet')):
            with self.subTest(mode=mode), patch.dict(os.environ, {mode: value}, clear=False):
                result = self.call('--account-home', 'mapped=' + str(self.home), phase='decider')
                self.assertEqual(result['status'], 'agent-required')
                self.assertEqual(tuple(result[key]
                                       for key in ('role', 'executor', 'account', 'model', 'effort')),
                                 ('decider', 'claude', 'current', model, 'high'))
                self.assertEqual(result['requested_model'], 'fable')
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
        base = {role: {'executor':'codex', 'account':'mapped', 'effort':'low'}
                for role in m.CANONICAL_ROLES}
        cases = [
            ('account', 'different Claude account execution is not supported yet',
             ('spec-review', {'executor':'claude', 'account':'reviewer'})),
            ('executor', 'executor must be claude or codex',
             ('implement', {'executor':'local'})),
            ('model on codex', 'invalid fields', ('implement', {'model':'sol'})),
            ('model on claude', 'invalid fields',
             ('spec-review', {'executor':'claude', 'account':'current', 'model':'opus'})),
            ('undefined cap', 'tier_cap is not a defined tier',
             ('implement', {'tier_cap':'特上'})),
            ('empty cap', 'empty or non-string', ('implement', {'tier_cap':''})),
        ]
        for index, (label, message, (role, updates)) in enumerate(cases):
            with self.subTest(case=label):
                roles = {name: dict(entry) for name, entry in base.items()}
                roles[role].update(updates)
                profile = self.root/('invalid-executor-' + str(index) + '.json')
                profile.write_text(json.dumps({'version':2, 'profiles':{'custom':{'roles':roles}}}))
                target = self.root/('invalid-request-' + str(index) + '.json')
                with self.assertRaisesRegex(RuntimeError, message):
                    self.call_profile('custom', profile_file=profile, out=target)
                self.assertFalse(target.exists())

    def test_tier_cap_is_accepted_on_either_executor(self):
        roles = {role: {'executor':'codex', 'account':'mapped', 'effort':'low', 'tier_cap':'中位'}
                 for role in m.CANONICAL_ROLES}
        roles['spec-review'] = {'executor':'claude', 'account':'current', 'effort':'high',
                                'tier_cap':'最安'}
        profile = self.root/'capped.json'
        profile.write_text(json.dumps({'version':2, 'profiles':{'custom':{'roles':roles}}}))
        self.assertEqual(self.call_profile('custom', profile_file=profile)['status'],
                         'request-written')

    def test_external_profile_is_strict_complete_and_uses_registered_accounts(self):
        roles = {role: {'executor':'codex', 'account':'mapped', 'effort':'future'}
                 for role in m.CANONICAL_ROLES}
        profile = self.root/'strict-profiles.json'
        profile.write_text(json.dumps({'version':2, 'profiles':{'custom':{'roles':roles}}}))
        result = self.call_profile('custom', profile_file=profile)
        self.assertEqual(result['status'], 'request-written')
        self.assertEqual(json.loads(self.out.read_text())['account'], 'mapped')

        invalids = [
            {'version':True, 'profiles':{'custom':{'roles':roles}}},
            {'version':1, 'profiles':{'custom':{'roles':roles}}},
            {'version':3, 'profiles':{'custom':{'roles':roles}}},
            {'version':2, 'extra':1, 'profiles':{'custom':{'roles':roles}}},
            {'version':2, 'profiles':{'custom':{'roles':{k:v for k,v in roles.items() if k != 'decider'}}}},
            {'version':2, 'profiles':{'custom':{'roles':dict(roles, decider=dict(roles['decider'], executor='local'))}}},
            {'version':2, 'profiles':{'custom':{'roles':dict(roles, decider=dict(roles['decider'], account='absent'))}}},
            '{"version":2,"version":2,"profiles":{}}',
        ]
        for index, value in enumerate(invalids):
            with self.subTest(invalid=index):
                profile.write_text(value if isinstance(value, str) else json.dumps(value))
                target = self.root/('strict-invalid-' + str(index) + '.json')
                with self.assertRaises((RuntimeError, ValueError)):
                    self.call_profile('custom', profile_file=profile, out=target)
                self.assertFalse(target.exists())

    def test_review_must_equal_impl_review_in_profile_and_snapshot(self):
        roles = {role: {'executor':'codex', 'account':'mapped', 'effort':'high'}
                 for role in m.CANONICAL_ROLES}
        roles['review'] = dict(roles['review'], effort='low')
        profile = self.root/'review-mismatch.json'
        profile.write_text(json.dumps({'version':2, 'profiles':{'custom':{'roles':roles}}}))
        with self.assertRaisesRegex(RuntimeError, 'review.*impl-review'):
            self.call_profile('custom', profile_file=profile)

        config = {'version':2, 'profile':'custom', 'roles':roles}
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
            self.assertEqual((config['roles']['spec-write']['effort'],
                              config['roles']['implement']['effort']), (values[1], values[3]))
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
                    self.assertEqual((request['role'], request['effort']),
                                     (role, config['roles'][role]['effort']))
                    if role in ('spec-write', 'implement'):
                        self.assertEqual(request['model'],
                                         values[0 if role == 'spec-write' else 2])
            self.assertEqual(m.execution_config_hash(config), hashlib.sha256(json.dumps(
                config, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()).hexdigest())

    def test_builtin_entries_hold_no_model_and_the_only_caps_are_the_economy_writers(self):
        path = SCRIPT.parents[1] / 'references/codex-role-profiles.json'
        self.assertIsNone(re.search(r'gpt-[0-9]', path.read_text()))
        document = json.loads(path.read_text())
        self.assertEqual(document['version'], 2)
        self.assertEqual(set(document['profiles']),
                         {'codex-standard', 'codex-economy', 'hybrid-standard',
                          'claude-write-codex-review', 'claude-default'})
        capped = set()
        for name, profile in document['profiles'].items():
            for role, entry in profile['roles'].items():
                with self.subTest(profile=name, role=role):
                    self.assertNotIn('model', entry)
                if 'tier_cap' in entry:
                    capped.add((name, role, entry['tier_cap']))
        self.assertEqual(capped, {('codex-economy', 'spec-write', '最安'),
                                  ('codex-economy', 'implement', '最安')})

    def test_claude_default_is_a_profile_that_needs_no_account_home(self):
        args = [str(SCRIPT), 'request', '--phase', 'decider', '--input', str(self.input),
                '--cwd', str(self.cwd), '--profile', 'claude-default', '--out', str(self.out)]
        with patch.object(sys, 'argv', args):
            result = m.main()
        self.assertEqual((result['status'], result['executor'], result['account'], result['model'],
                          result['effort']),
                         ('agent-required', 'claude', 'current', 'fable', 'high'))
        self.assertEqual(result['execution_config']['profile'], 'claude-default')
        self.assertFalse(self.out.exists())

    def test_automatic_claude_default_comes_from_the_same_profile(self):
        selection = {'selection_mode': 'automatic', 'configuration': 'claude-default',
                     'reason': 'no-provider-has-headroom',
                     'claude': {'account': None, 'margin': -5, 'fetched_at': None},
                     'codex': {'account': None, 'margin': None, 'fetched_at': None}}
        with patch.object(m, 'automatic_selection', return_value=('claude-default', selection)):
            result = self.call_automatic(phase='explore', accounts=('a',))
        self.assertEqual((result['status'], result['model'], result['effort']),
                         ('agent-required', 'haiku', 'low'))
        self.assertEqual(result['execution_config'], m.load_profile('claude-default', None, None))
        self.assertEqual(result['execution_config_hash'],
                         m.execution_config_hash(result['execution_config']))

    def test_family_names_and_exact_ids_are_written_to_the_request_unchanged(self):
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
        models = {'sonnet': '中位', 'haiku': '最安', 'sol': '上位', 'astra': '最上位'}
        for role, (executor, account, model, effort) in expected.items():
            entry = config['roles'][role]
            self.assertEqual((entry['executor'], entry['account'], entry['effort']),
                             (executor, account, effort))
            self.assertEqual(m.tier_model(executor, models[model])['model'], model)


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

    def test_codex_old_value_before_reset_is_a_lower_bound(self):
        now = 2_000_000
        for age in (300, 301, 86400, 5 * 86400):
            with self.subTest(age=age):
                self.assertAlmostEqual(
                    m.usage_margin(self.snapshot(10, now=now, age=age, minutes=10080), now),
                    10)

    def test_codex_window_past_reset_reads_as_zero_and_rolls_forward(self):
        now = 2_000_000
        week = 604800
        for passed, rolled in ((0, 1), (1, 1), (week - 1, 1), (week, 2), (3 * week + 5, 4)):
            with self.subTest(passed=passed):
                value = {'fetched_at': now - 10, 'windows': [
                    {'minutes': 10080, 'used_percent': 97, 'reset_at': now - passed}]}
                reset = now - passed + rolled * week
                expected = 100 * (1 - (reset - now) / week)
                self.assertAlmostEqual(m.usage_margin(value, now), expected)

    def test_codex_reset_beyond_seven_days_is_negative_not_missing(self):
        now = 2_000_000
        value = {'fetched_at': now, 'windows': [
            {'minutes': 10080, 'used_percent': 0, 'reset_at': now + 604800 + 3600}]}
        margin = m.usage_margin(value, now)
        self.assertIsNotNone(margin)
        self.assertLess(margin, 0)

    def test_codex_usage_margin_stays_fail_safe_for_invalid_input(self):
        now = 2_000_000
        good = self.snapshot(10, now=now, minutes=10080)
        self.assertIsNone(m.usage_margin(self.snapshot(10, now=now, minutes=300), now))
        # 未来の取得時刻は headroom の 60 秒の規則（60 秒先までは時計のずれとして使う）
        self.assertIsNone(m.usage_margin(self.snapshot(10, now=now, age=-61, minutes=10080), now))
        for age in (-60, -1):
            with self.subTest(age=age):
                self.assertAlmostEqual(
                    m.usage_margin(self.snapshot(10, now=now, age=age, minutes=10080), now), 10)
        self.assertIsNone(m.usage_margin({**good, 'fetched_at': '1'}, now))
        self.assertIsNone(m.usage_margin({**good, 'windows': 'x'}, now))
        for used in (-1, 101, float('nan'), True, None):
            with self.subTest(used=used):
                bad = {'fetched_at': now, 'windows': [
                    {'minutes': 10080, 'used_percent': used, 'reset_at': now + 100}]}
                self.assertIsNone(m.usage_margin(bad, now))
        for reset in (None, 1.5, True):
            with self.subTest(reset=reset):
                bad = {'fetched_at': now, 'windows': [
                    {'minutes': 10080, 'used_percent': 10, 'reset_at': reset}]}
                self.assertIsNone(m.usage_margin(bad, now))

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

    def test_off_launch_slot_gives_no_claude_margin(self):
        # オフ（enabled: false）のスロットで起動したセッションでは、headroom の行が off なので欠測
        now = 2_000_000
        secure = '/tmp/claude-a'
        (self.root / 'accounts.json').write_text(json.dumps({'accounts': [
            {'id': 'a', 'securestorage': secure, 'enabled': False},
            {'id': 'b', 'securestorage': None}]}))
        path = self.root / 'mirror-snapshot.json'
        path.write_text(json.dumps({
            'schema': 2, 'active': 'b', 'fetched_at': now, 'weekly_all_pct': 0,
            'weekly_resets_epoch': now + 302400,
            'accounts': {'a': self.snapshot(-5, now=now), 'b': self.snapshot(30, now=now)}}))
        with patch.dict(os.environ, {'CLAUDE_SECURESTORAGE_CONFIG_DIR': secure}, clear=False):
            evidence = m.claude_usage_evidence(path, now)
        self.assertEqual(evidence['account'], 'a')
        self.assertIsNone(evidence['margin'])

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

    def test_claude_future_observation_follows_the_60_second_rule(self):
        now = 2_000_000
        for age, expected in ((-60, 10), (-61, None)):
            with self.subTest(age=age):
                path = self.write_claude_snapshot({'default': self.snapshot(10, now=now, age=age)})
                evidence = m.claude_usage_evidence(path, now)
                if expected is None:
                    self.assertIsNone(evidence['margin'])
                else:
                    self.assertAlmostEqual(evidence['margin'], expected)

    def test_margins_come_from_the_headroom_rows(self):
        # 週の経過率と使用率からは出ない margin を返す行に差し替え、その値が証跡に出ることで
        # codex-develop.py が自分で数えず headroom の行を使っていることを確かめる
        now = 2_000_000
        snapshot_path = self.write_claude_snapshot({'default': self.snapshot(-40, now=now)})
        headroom = m.headroom

        def claude_rows(at, path=None):
            self.assertEqual((at, Path(path)), (now, snapshot_path))
            return [{'account': 'default', 'status': 'ok', 'margin': 12.345, 'observed_at': now - 7}]

        def codex_row(account, cache, at):
            self.assertEqual(account, 'a')
            return {'account': account, 'status': 'ok', 'margin': 6.789,
                    'observed_at': cache['fetched_at']}

        with patch.dict(os.environ, {'USAGE_SNAPSHOT': str(snapshot_path)}, clear=False), \
                patch.object(m, '_run_usage_probe'), \
                patch.object(m, 'read_codex_usages',
                             return_value={'a': self.snapshot(-40, now=now, minutes=10080)}), \
                patch.object(headroom, 'claude_rows', side_effect=claude_rows), \
                patch.object(headroom, 'codex_row', side_effect=codex_row):
            selected, evidence = m.automatic_selection({'a': '/a'}, now)
        self.assertEqual(selected, 'claude-write-codex-review')
        self.assertEqual(evidence['claude']['margin'], 12.345)
        self.assertEqual(evidence['claude']['fetched_at'], now - 7)
        self.assertEqual(evidence['codex']['margin'], 6.789)

    def test_invalid_headroom_setting_blocks_automatic_selection(self):
        now = 2_000_000
        snapshot_path = self.write_claude_snapshot({'default': self.snapshot(10, now=now)})
        for name in ('HEADROOM_7D_CAP_PCT', 'HEADROOM_NORMAL_RATE_PCT_PER_DAY'):
            with self.subTest(name=name), \
                    patch.dict(os.environ, {name: 'abc', 'USAGE_SNAPSHOT': str(snapshot_path)},
                               clear=False), \
                    patch.object(m, '_run_usage_probe'), \
                    patch.object(m, 'read_codex_usages', return_value={}):
                with self.assertRaisesRegex(RuntimeError, name):
                    self.call_automatic(accounts=('a',))
                self.assertFalse(self.out.exists())

    def test_invalid_headroom_setting_exits_2_with_blocked(self):
        env = dict(os.environ) | {'HEADROOM_7D_CAP_PCT': 'abc',
                                  'USAGE_SNAPSHOT': str(self.root / 'absent-snapshot.json')}
        home = self.root / 'codex-a'
        home.mkdir(exist_ok=True)
        done = subprocess.run([sys.executable, str(SCRIPT), 'request', '--phase', 'implement',
                               '--input', str(self.input), '--cwd', str(self.cwd),
                               '--account-home', 'a=' + str(home), '--out', str(self.out)],
                              env=env, capture_output=True, text=True, timeout=120)
        self.assertEqual(done.returncode, 2, done.stderr)
        result = json.loads(done.stdout)
        self.assertEqual(result['status'], 'blocked')
        self.assertIn('HEADROOM_7D_CAP_PCT', result['error'])
        self.assertFalse(self.out.exists())

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

    def _reset_credit_cache(self, limits_extra):
        # One home whose app-server answers account/read and account/rateLimits/read; the
        # rateLimitResetCredits part varies per test (codex-role-profiles: cache version 2).
        td = tempfile.TemporaryDirectory(); self.addCleanup(td.cleanup)
        root = Path(td.name).resolve(); config = root/'config'; config.mkdir()
        home = root/'home'; home.mkdir()
        claims = base64.urlsafe_b64encode(json.dumps({'email': 'test@example.invalid'}).encode()).decode().rstrip('=')
        (home/'auth.json').write_text(json.dumps(
            {'tokens': {'id_token': 'x.' + claims + '.x', 'account_id': 'account'}}))
        now = int(time.time())
        limits = {'rateLimits': {'primary': {'windowDurationMins': 10080, 'usedPercent': 10,
                                             'resetsAt': now + 604000}}} | limits_extra
        answers = [{}, {'account': {'type': 'chatgpt', 'email': 'test@example.invalid'}}, limits]
        with patch.object(m, '_rpc_requests', return_value=answers):
            values = m.read_codex_usages({'current': str(home)}, str(config), now)
        return values['current'], now

    def test_reset_credits_are_normalized_into_cache_version_2(self):
        credits = {'availableCount': 2, 'credits': [
            {'id': 'secret-1', 'status': 'available', 'expiresAt': 1800000000},
            {'id': 'secret-2', 'status': 'available', 'expiresAt': 1800003600},
            {'id': 'secret-3', 'status': 'used', 'expiresAt': 1700000000}]}
        value, _now = self._reset_credit_cache({'rateLimitResetCredits': credits})
        self.assertEqual(value['version'], 2)
        self.assertEqual(value['resets'], {'available_count': 2,
                                           'expires_at': [1800000000, 1800003600]})
        self.assertNotIn('secret', json.dumps(value))

    def test_cache_holds_only_the_known_top_level_fields(self):
        credits = {'availableCount': 1, 'credits': [
            {'id': 'secret-1', 'status': 'available', 'expiresAt': 1800000000, 'extra': 'x'}]}
        value, _now = self._reset_credit_cache({'rateLimitResetCredits': credits, 'other': 1})
        self.assertEqual(set(value), {'version', 'identity', 'fetched_at', 'windows', 'resets'})
        self.assertEqual(set(value['resets']), {'available_count', 'expires_at'})

    def test_zero_available_credits_are_written_as_known_zero(self):
        value, _now = self._reset_credit_cache(
            {'rateLimitResetCredits': {'availableCount': 0, 'credits': []}})
        self.assertEqual(value['resets'], {'available_count': 0, 'expires_at': []})

    def test_reset_credit_without_integer_expiry_is_kept_as_null(self):
        credits = {'availableCount': 2, 'credits': [
            {'id': 'x', 'status': 'available', 'expiresAt': None},
            {'id': 'y', 'status': 'available', 'expiresAt': '2026-10-30'}]}
        value, _now = self._reset_credit_cache({'rateLimitResetCredits': credits})
        self.assertEqual(value['resets'], {'available_count': 2, 'expires_at': [None, None]})

    def test_unreadable_reset_credits_leave_resets_out(self):
        for extra in ({}, {'rateLimitResetCredits': None},
                      {'rateLimitResetCredits': {'availableCount': '2', 'credits': []}},
                      {'rateLimitResetCredits': {'availableCount': -1, 'credits': []}},
                      {'rateLimitResetCredits': {'availableCount': True, 'credits': []}},
                      {'rateLimitResetCredits': {'availableCount': 1, 'credits': {}}}):
            with self.subTest(extra=extra):
                value, now = self._reset_credit_cache(extra)
                self.assertEqual(value['version'], 2)
                self.assertNotIn('resets', value)
                self.assertEqual(value['fetched_at'], now)
                self.assertEqual(value['windows'][0]['minutes'], 10080)

    def test_failed_fetch_keeps_previous_resets(self):
        td = tempfile.TemporaryDirectory(); self.addCleanup(td.cleanup)
        root = Path(td.name).resolve(); config = root/'config'; config.mkdir()
        home = root/'home'; home.mkdir()
        claims = base64.urlsafe_b64encode(json.dumps({'email': 'test@example.invalid'}).encode()).decode().rstrip('=')
        (home/'auth.json').write_text(json.dumps(
            {'tokens': {'id_token': 'x.' + claims + '.x', 'account_id': 'account'}}))
        now = int(time.time())
        result = {'identity': m._auth_identity(str(home)),
                  'windows': [{'minutes': 10080, 'used_percent': 10, 'reset_at': now + 604000}],
                  'resets': {'available_count': 1, 'expires_at': [now + 3600]}}
        with patch.object(m, 'probe_codex_account', return_value=result):
            m.read_codex_usages({'current': str(home)}, str(config), now)
        with patch.object(m, 'probe_codex_account', side_effect=RuntimeError('offline')):
            kept = m.read_codex_usages({'current': str(home)}, str(config), now + 200)
        self.assertEqual(kept['current']['resets'], {'available_count': 1, 'expires_at': [now + 3600]})
        self.assertEqual(kept['current']['fetched_at'], now)
        # a later successful fetch without the field drops the previous resets (unknown, not kept)
        result_without = {'identity': result['identity'], 'windows': result['windows']}
        with patch.object(m, 'probe_codex_account', return_value=result_without):
            fresh = m.read_codex_usages({'current': str(home)}, str(config), now + 400)
        self.assertEqual(fresh['current']['fetched_at'], now + 400)
        self.assertNotIn('resets', fresh['current'])
        stored = json.loads(m._cache_path(str(config), str(home)).read_text())
        self.assertNotIn('resets', stored)

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

    def test_usage_probe_timeout_covers_a_slow_codex_fetch(self):
        # headroom's --refresh-codex inside the probe: 3 requests of RPC_TIMEOUT each, 2 to stop
        # the app-server, and at least one Claude fetch (curl --max-time 10).
        with patch.object(m.subprocess, 'run') as run:
            m._run_usage_probe(self.root / 'snapshot.json')
        timeout = run.call_args.kwargs['timeout']
        self.assertEqual(timeout, m.USAGE_PROBE_TIMEOUT)
        self.assertGreaterEqual(timeout, 3 * m.RPC_TIMEOUT + 2 + 10)

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
            ('age-301', -5, 30, 301, 'codex-standard',
             'only-codex-has-headroom', 'codex', 'a'),
            ('age-one-day', 20, -5, 86400, 'claude-default',
             'only-claude-has-headroom', 'claude', 'current'),
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
                                   for key in ('executor','account','effort')),
                             (values[0], values[1], values[3]))
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
        common = 'skills/develop/references/roles/worker/common.md'
        sources = {'spec':[common, 'skills/develop/references/roles/worker/spec.md'],
                   'implement':[common, 'skills/develop/references/roles/worker/implement.md'],
                   'finish':[common, 'skills/develop/references/roles/worker/finish.md'],
                   'gate':['skills/develop/references/roles/gate-runner.md']}
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
                for source in sources[phase]:
                    self.assertIn('CANONICAL SOURCE ' + source + ' ', text)
                self.assertNotIn('CANONICAL SOURCE skills/develop/references/roles/worker.md ', text)
                self.assertIn('CANONICAL SOURCE skills/develop/references/decision-criteria.md', text)
                if phase == 'gate':
                    for doc in ('SKILL.md', 'declarations.md', 'stages/prepare.md', 'stages/review-run.md',
                                'stages/reviewer-brief.md', 'stages/triage.md', 'stages/pass.md', 'stages/hold.md'):
                        self.assertIn('CANONICAL SOURCE skills/pr-review-gate/' + doc, text)

    def test_reader_phases_return_the_verdict_for_the_coordinator_to_post(self):
        sources = {'spec-review':'skills/develop/references/roles/spec-reviewer.md',
                   'review':'skills/develop/references/roles/gate-runner.md',
                   'decider':'agents/decider.md',
                   'explore':'skills/develop/references/roles/worker/common.md',
                   'summarize':'skills/develop/references/roles/worker/common.md'}
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
                self.assertIn('CANONICAL SOURCE ' + sources[phase] + ' ', text)
                self.assertNotIn('CANONICAL SOURCE skills/develop/references/roles/worker.md ', text)
                if phase in ('explore', 'summarize'):
                    for stage in ('spec', 'implement', 'finish'):
                        self.assertNotIn('CANONICAL SOURCE skills/develop/references/roles/worker/' + stage + '.md', text)
                self.assertIn('CANONICAL SOURCE skills/develop/references/decision-criteria.md', text)
                if phase == 'review':
                    self.assertIn('CANONICAL SOURCE skills/pr-review-gate/stages/reviewer-brief.md', text)

    def test_review_phase_uses_gate_and_reviewer_contract_sources(self):
        target = self.root/'review-contract.json'
        self.call_profile('codex-standard', phase='review', out=target)
        text = json.loads(target.read_text())['prompt']
        self.assertIn('CANONICAL SOURCE skills/develop/references/roles/gate-runner.md', text)
        self.assertIn('CANONICAL SOURCE skills/pr-review-gate/stages/reviewer-brief.md', text)
        self.assertNotIn('CANONICAL SOURCE skills/pr-review-gate/SKILL.md', text)
        self.assertIn('変更点の一覧', text)
        self.assertIn('照合表', text)
        self.assertIn('ハンク被覆', text)
        self.assertIn('補足済み回数', text)
        self.assertIn('review-incomplete', text)

    def test_request_file_mode_is_0600(self):
        self.call('--account-home', 'mapped=' + str(self.home))
        self.assertEqual(stat.S_IMODE(self.out.stat().st_mode), 0o600)

    # --- Codex off (accounts.json "codex"."enabled": false; dev-workflow-develop spec) ---

    def write_registry(self, codex='absent'):
        document = {'schema': 1, 'accounts': [{'id': 'default', 'securestorage': None}]}
        if codex != 'absent':
            document['codex'] = codex
        path = self.root / 'registry.json'
        path.write_text(json.dumps(document))
        os.environ['CLAUDE_ACCOUNTS_FILE'] = str(path)
        return path

    def run_script(self, *extra):
        # A real process: the exit code and the blocked JSON are part of the contract.
        return subprocess.run(
            [sys.executable, str(SCRIPT), 'request', '--phase', 'implement',
             '--input', str(self.input), '--cwd', str(self.cwd), '--out', str(self.out), *extra],
            capture_output=True, text=True)

    def automatic_off_case(self, claude_margin, usages):
        now = 2_000_000
        snapshot_path = self.root / 'off-snapshot.json'
        accounts = ({} if claude_margin is None else
                    {'default': self.snapshot(claude_margin, now=now)})
        snapshot_path.write_text(json.dumps({'schema': 2, 'active': 'default',
                                             'accounts': accounts}))
        with patch.dict(os.environ, {'USAGE_SNAPSHOT': str(snapshot_path)}, clear=False), \
                patch.object(m, '_run_usage_probe'), \
                patch.object(m.time, 'time', return_value=now), \
                patch.object(m, 'probe_codex_account',
                             side_effect=AssertionError('codex probed')) as probe, \
                patch.object(m, 'read_codex_usages', **usages) as read:
            result = self.call_automatic()
        return result, read, probe

    def test_select_configuration_returns_claude_default_when_codex_is_off(self):
        for claude, codex in ((20, 30), (0, 0), (-5, 30), (-5, -5), (None, None), (20, None)):
            with self.subTest(claude=claude, codex=codex):
                self.assertEqual(m.select_configuration(claude, codex, codex_enabled=False),
                                 ('claude-default', 'codex-off'))
                self.assertEqual(m.select_configuration(claude, codex, codex_enabled=True),
                                 m.select_configuration(claude, codex))

    def test_codex_off_selects_claude_only_even_when_codex_has_more_headroom(self):
        self.write_registry({'enabled': False})
        result, read, probe = self.automatic_off_case(
            20, {'side_effect': AssertionError('codex usage read')})
        selection = result['selection']
        self.assertEqual((selection['configuration'], selection['reason']),
                         ('claude-default', 'codex-off'))
        self.assertEqual(selection['codex'], {'account': None, 'margin': None,
                                              'fetched_at': None, 'enabled': False})
        self.assertAlmostEqual(selection['claude']['margin'], 20)
        self.assertEqual((result['status'], result['executor']), ('agent-required', 'claude'))
        read.assert_not_called()
        probe.assert_not_called()
        self.assertFalse(self.out.exists())

    def test_codex_off_reason_wins_when_claude_has_no_headroom_either(self):
        self.write_registry({'enabled': False})
        for margin in (-5, None):
            with self.subTest(margin=margin):
                result, read, _ = self.automatic_off_case(
                    margin, {'side_effect': AssertionError('codex usage read')})
                self.assertEqual((result['selection']['configuration'],
                                  result['selection']['reason']),
                                 ('claude-default', 'codex-off'))
                read.assert_not_called()

    def test_codex_off_refuses_an_explicit_codex_profile(self):
        registry = self.write_registry({'enabled': False})
        result = self.run_script('--profile', 'codex-standard',
                                 '--account-home', 'current=' + str(self.home))
        self.assertEqual(result.returncode, 2)
        document = json.loads(result.stdout)
        self.assertEqual(document['status'], 'blocked')
        self.assertEqual(document['error'], 'codex is off: set "codex"."enabled" to true '
                                            'or remove it in ' + str(registry))
        self.assertFalse(self.out.exists())

    def test_codex_off_refuses_a_profile_with_only_some_codex_roles(self):
        registry = self.write_registry({'enabled': False})
        self.write_mixed_profile()
        result = self.run_script('--profile', 'custom', '--profile-file', str(self.profile_file),
                                 '--account-home', 'mapped=' + str(self.home))
        self.assertEqual(result.returncode, 2)
        self.assertEqual(json.loads(result.stdout)['error'],
                         'codex is off: set "codex"."enabled" to true '
                         'or remove it in ' + str(registry))
        self.assertFalse(self.out.exists())

    def test_codex_off_refuses_the_legacy_account_model_form(self):
        self.write_registry({'enabled': False})
        result = self.run_script('--account', 'current', '--model', 'fixture-model',
                                 '--account-home', 'current=' + str(self.home))
        self.assertEqual(result.returncode, 2)
        self.assertIn('codex is off', json.loads(result.stdout)['error'])
        self.assertFalse(self.out.exists())

    def test_codex_off_is_reported_before_the_account_table_checks(self):
        self.write_registry({'enabled': False})
        for extra in (('--profile', 'codex-standard'),
                      ('--account', 'unmapped', '--model', 'fixture-model')):
            with self.subTest(extra=extra):
                result = self.run_script(*extra)
                error = json.loads(result.stdout)['error']
                self.assertEqual(result.returncode, 2)
                self.assertIn('codex is off', error)
                self.assertNotIn('account is not', error)

    def test_codex_off_keeps_a_profile_without_codex_roles(self):
        self.write_registry({'enabled': False})
        roles = {role: {'executor': 'claude', 'account': 'current', 'effort': 'medium'}
                 for role in m.CANONICAL_ROLES}
        self.profile_file.write_text(json.dumps(
            {'version': 2, 'profiles': {'custom': {'roles': roles}}}))
        result = self.call()
        self.assertEqual((result['status'], result['executor']), ('agent-required', 'claude'))
        self.assertEqual(result['selection']['reason'], 'explicit-profile')

    def test_explicit_requests_are_unchanged_while_codex_is_on(self):
        for codex in ('absent', {'enabled': True}, {'enabled': 'false'}, False):
            with self.subTest(codex=codex):
                self.write_registry(codex)
                self.out.unlink(missing_ok=True)
                result = self.call('--account-home', 'mapped=' + str(self.home))
                self.assertEqual(result['status'], 'request-written')

    def test_automatic_selection_is_identical_without_the_off_setting(self):
        usages = {'a': self.snapshot(30, now=2_000_000, minutes=10080), 'b': None}
        outcomes = []
        for codex in ('none', 'absent', {'enabled': True}):
            if codex == 'none':
                os.environ['CLAUDE_ACCOUNTS_FILE'] = str(self.root / 'no-registry.json')
            else:
                self.write_registry(codex)
            self.out.unlink(missing_ok=True)
            result, read, _ = self.automatic_off_case(20, {'return_value': usages})
            read.assert_called_once()
            outcomes.append(result['selection'])
        self.assertEqual(outcomes[0], outcomes[1])
        self.assertEqual(outcomes[0], outcomes[2])
        self.assertEqual((outcomes[0]['configuration'], outcomes[0]['reason']),
                         ('claude-write-codex-review', 'both-providers-have-headroom'))
        self.assertEqual(set(outcomes[0]['codex']), {'account', 'margin', 'fetched_at'})


class TierMap(RequestFixture, unittest.TestCase):
    # model-tier-map.json is the only place that turns a tier into a model name, so a broken
    # table stops the request instead of falling back to some other model.
    def write_map(self, value):
        path = self.root / 'tier-map.json'
        path.write_text(value if isinstance(value, str) else json.dumps(value, ensure_ascii=False))
        return path

    def valid_map(self):
        return json.loads((SCRIPT.parents[1] / 'references/model-tier-map.json').read_text())

    def test_the_bundled_table_has_the_agreed_values(self):
        table = m.load_tier_map()
        self.assertEqual(table['tiers'], ['最安', '中位', '上位', '最上位'])
        self.assertEqual(table['executors'], {
            'claude': {'最安': 'haiku', '中位': 'sonnet', '上位': 'opus', '最上位': 'fable'},
            'codex': {'最安': 'luna', '中位': 'sol', '上位': 'sol', '最上位': 'astra'}})

    def test_the_table_holds_no_model_id(self):
        path = SCRIPT.parents[1] / 'references/model-tier-map.json'
        self.assertIsNone(re.search(r'gpt-[0-9]', path.read_text()))

    def test_a_broken_table_is_refused(self):
        def edited(change):
            table = self.valid_map()
            change(table)
            return table
        cases = {
            'missing tier': edited(lambda t: t['executors']['codex'].pop('上位')),
            'unknown tier': edited(lambda t: t['executors']['codex'].update({'特上': 'x'})),
            'missing executor': edited(lambda t: t['executors'].pop('codex')),
            'unknown executor': edited(lambda t: t['executors'].update(
                {'local': dict(t['executors']['codex'])})),
            'unknown key': edited(lambda t: t.update({'extra': 1})),
            'other tiers': edited(lambda t: t.update({'tiers': ['最安']})),
            'other version': edited(lambda t: t.update({'version': 2})),
            'boolean version': edited(lambda t: t.update({'version': True})),
            'empty value': edited(lambda t: t['executors']['claude'].update({'中位': ''})),
            'not a string': edited(lambda t: t['executors']['claude'].update({'中位': 1})),
            'duplicate key': '{"version":1,"version":1}',
            'not json': '{',
            'not an object': '[]',
        }
        for name, value in cases.items():
            with self.subTest(case=name), self.assertRaises(RuntimeError):
                m.load_tier_map(self.write_map(value))
        with self.assertRaises(RuntimeError):
            m.load_tier_map(self.root / 'absent.json')

    def test_a_broken_table_blocks_the_request_without_a_request_file(self):
        table = self.valid_map()
        del table['executors']['codex']['上位']
        with patch.object(m, 'TIER_MAP', self.write_map(table)), self.assertRaises(RuntimeError):
            self.call_profile('codex-standard')
        self.assertFalse(self.out.exists())

    def run_tier_model(self, *extra):
        return subprocess.run([sys.executable, str(SCRIPT), 'tier-model', *extra],
                              text=True, capture_output=True, timeout=20)

    def test_tier_model_returns_every_tier_of_both_executors(self):
        for executor, models in (('claude', ('haiku', 'sonnet', 'opus', 'fable')),
                                 ('codex', ('luna', 'sol', 'sol', 'astra'))):
            for tier, model in zip(('最安', '中位', '上位', '最上位'), models):
                with self.subTest(executor=executor, tier=tier):
                    result = self.run_tier_model('--executor', executor, '--tier', tier)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(json.loads(result.stdout),
                                     {'executor': executor, 'tier': tier, 'model': model})

    def test_tier_model_refuses_an_undefined_tier_or_executor(self):
        for executor, tier in (('codex', '特上'), ('local', '中位')):
            with self.subTest(executor=executor, tier=tier):
                result = self.run_tier_model('--executor', executor, '--tier', tier)
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                self.assertEqual(json.loads(result.stdout)['status'], 'blocked')


class TierRule(RequestFixture, unittest.TestCase):
    # model-tier-resolution: the tier comes from the phase and the request inputs alone.
    WRITERS = ('spec', 'implement', 'finish')

    def rule(self, phase, *pre_class, design=False, failure=None):
        return m.requested_tier(phase, list(pre_class), design, failure)

    def resolve(self, profile, phase, *extra):
        args = [str(SCRIPT), 'request', '--phase', phase, '--input', str(self.input),
                '--cwd', str(self.cwd), '--profile', profile,
                '--account-home', 'current=' + str(self.home), '--out', str(self.out), *extra]
        with patch.object(sys, 'argv', args):
            return m.main()

    def test_base_tier_of_every_phase(self):
        expected = {'spec': '中位', 'implement': '中位', 'finish': '中位', 'gate': '中位',
                    'spec-review': '上位', 'review': '上位', 'decider': '最上位',
                    'explore': '最安', 'summarize': '最安'}
        self.assertEqual(set(expected), set(m.PHASES))
        for phase, tier in expected.items():
            with self.subTest(phase=phase):
                self.assertEqual(self.rule(phase), tier)

    def test_writer_is_raised_to_the_upper_tier_and_no_further(self):
        for phase in self.WRITERS:
            for label, tier in (
                    *((name, self.rule(phase, name)) for name in ('sacred', 'merge', 'contract', 'billing')),
                    ('design', self.rule(phase, design=True)),
                    ('failure', self.rule(phase, failure='executor')),
                    ('all', self.rule(phase, 'merge', 'billing', design=True, failure='executor'))):
                with self.subTest(phase=phase, input=label):
                    self.assertEqual(tier, '上位')

    def test_writer_failure_alone_does_not_raise_and_never_lowers(self):
        for phase in self.WRITERS:
            for failure in ('first', 'judgment'):
                with self.subTest(phase=phase, failure=failure):
                    self.assertEqual(self.rule(phase, failure=failure), '中位')
                    self.assertEqual(self.rule(phase, 'merge', failure=failure), '上位')

    def test_gate_is_never_raised(self):
        self.assertEqual(self.rule('gate', 'merge', design=True, failure='executor'), '中位')

    def test_decider_failure_steps(self):
        self.assertEqual(self.rule('decider', failure='first'), '上位')
        self.assertEqual(self.rule('decider', failure='executor'), '上位')
        self.assertEqual(self.rule('decider', failure='judgment'), '最上位')
        self.assertEqual(self.rule('decider'), '最上位')

    def test_inputs_outside_the_rule_do_not_move_the_tier(self):
        for phase in ('explore', 'summarize'):
            self.assertEqual(self.rule(phase, 'merge', design=True, failure='executor'), '最安')
        self.assertEqual(self.rule('decider', 'merge', design=True), '最上位')
        self.assertEqual(self.rule('spec-review', 'sacred', design=True, failure='executor'), '上位')

    def test_undefined_inputs_are_refused_without_a_request_file(self):
        for extra in (('--pre-class', 'other'), ('--failure', 'other')):
            with self.subTest(extra=extra):
                result = subprocess.run(
                    [sys.executable, str(SCRIPT), 'request', '--phase', 'implement', '--input',
                     str(self.input), '--cwd', str(self.cwd), '--profile', 'codex-standard',
                     '--account-home', 'current=' + str(self.home), '--out', str(self.out), *extra],
                    text=True, capture_output=True, timeout=20)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.out.exists())

    def test_review_switches_to_the_decider_entry_and_keeps_the_phase_instructions(self):
        for name in ('merge', 'contract', 'billing'):
            with self.subTest(pre_class=name):
                self.out.unlink(missing_ok=True)
                result = self.resolve('claude-write-codex-review', 'review', '--pre-class', name)
                self.assertEqual((result['executor'], result['model'], result['role'], result['phase']),
                                 ('codex', 'astra', 'decider', 'review'))
                request = json.loads(self.out.read_text())
                self.assertEqual(request['role'], 'impl-review')
                self.assertEqual(request['model'], 'astra')
                self.assertIn('Codex delegated develop phase: review. Role: impl-review.',
                              request['prompt'])
                self.assertIn('skills/develop/references/roles/gate-runner.md', request['prompt'])
                self.assertNotIn('agents/decider.md', request['prompt'])

    def test_the_switched_review_keeps_the_sandbox_of_the_phase(self):
        self.resolve('codex-standard', 'review', '--pre-class', 'contract')
        role = json.loads(self.out.read_text())['role']
        self.assertIn(role, worker_module.NETWORK_ROLES)
        self.assertNotIn('decider', worker_module.NETWORK_ROLES)

    def test_spec_review_switches_too(self):
        result = self.resolve('codex-standard', 'spec-review', '--pre-class', 'billing')
        self.assertEqual((result['role'], result['model']), ('decider', 'astra'))
        self.assertEqual(json.loads(self.out.read_text())['role'], 'spec-review')

    def test_sacred_alone_does_not_switch(self):
        result = self.resolve('codex-standard', 'spec-review', '--pre-class', 'sacred')
        self.assertEqual((result['role'], result['model']), ('spec-review', 'sol'))

    def test_failure_does_not_reach_a_switched_review(self):
        result = self.resolve('codex-standard', 'review', '--pre-class', 'merge', '--failure', 'first')
        self.assertEqual((result['role'], result['model']), ('decider', 'astra'))

    def test_a_switched_review_on_a_claude_decider_is_returned_to_the_coordinator(self):
        result = self.resolve('hybrid-standard', 'review', '--pre-class', 'contract')
        self.assertEqual((result['status'], result['role'], result['executor'], result['model']),
                         ('agent-required', 'decider', 'claude', 'fable'))
        self.assertFalse(self.out.exists())


class BudgetModeDerivation(RequestFixture, unittest.TestCase):
    # usage_view.budget_modes is a copy of the formula in session-tripwires.sh, which stays
    # untouched, so the tripwire script itself is the expected value in the last test.
    NOW = 2_000_000
    DAY = 86400

    def slot(self, fable=None, weekly=None, fable_resets=None, weekly_resets=None):
        return {'fable_weekly_pct': fable, 'weekly_all_pct': weekly,
                'fable_resets_epoch': fable_resets, 'weekly_resets_epoch': weekly_resets}

    def test_explicit_env_wins_over_the_effective_values(self):
        slot = self.slot(fable=95, weekly=95, weekly_resets=self.NOW + self.DAY)
        self.assertEqual(m.usage_view.budget_modes(
            slot, self.NOW, {'FABLE_BUDGET_MODE': 'reserve', 'SHARED_BUDGET_MODE': 'ok'}),
            {'fable': 'reserve', 'shared': 'ok'})

    def test_effective_values_give_exhausted_and_throttled(self):
        slot = self.slot(fable=95, weekly=60, weekly_resets=self.NOW + 6 * self.DAY)
        self.assertEqual(m.usage_view.budget_modes(slot, self.NOW, {}),
                         {'fable': 'exhausted', 'shared': 'throttled'})

    def test_no_data_gives_conserve_and_ok(self):
        for slot in (None, {}, self.slot()):
            with self.subTest(slot=slot):
                self.assertEqual(m.usage_view.budget_modes(slot, self.NOW, {}),
                                 {'fable': 'conserve', 'shared': 'ok'})

    def test_unknown_explicit_values_read_as_the_safe_side(self):
        self.assertEqual(m.usage_view.budget_modes(
            None, self.NOW, {'FABLE_BUDGET_MODE': 'foo', 'SHARED_BUDGET_MODE': 'bar'}),
            {'fable': 'conserve', 'shared': 'throttled'})

    def test_blank_explicit_values_are_not_set(self):
        self.assertEqual(m.usage_view.budget_modes(
            None, self.NOW, {'FABLE_BUDGET_MODE': ' ', 'SHARED_BUDGET_MODE': ''}),
            {'fable': 'conserve', 'shared': 'ok'})

    def test_same_values_as_session_tripwires(self):
        script = SCRIPT.parent / 'session-tripwires.sh'
        snapshot = self.root / 'parity-snapshot.json'
        env = {key: value for key, value in os.environ.items()
               if key not in ('FABLE_BUDGET_MODE', 'SHARED_BUDGET_MODE')}
        env.update(CLAUDE_PLUGIN_ROOT=str(SCRIPT.parents[1]), TRIPWIRES_SCOPE='subagent-budget',
                   USAGE_SNAPSHOT=str(snapshot), USAGE_PROBE_NOW=str(self.NOW),
                   CLAUDE_ACCOUNTS_FILE=str(self.root / 'no-registry.json'))
        for fable, weekly, days in ((95, 60, 6), (91, 91, 1), (90, 90, 1), (10, 20, 1),
                                    (50, 10, 1), (50, 10, 6), (None, 60, 6), (20, None, 1),
                                    (14, 14, 6), (15, 15, 6), (None, None, None)):
            with self.subTest(fable=fable, weekly=weekly, days=days):
                entry = {'fetched_at': self.NOW - 60}
                if fable is not None:
                    entry['fable_weekly_pct'] = fable
                if weekly is not None:
                    entry['weekly_all_pct'] = weekly
                if days is not None:
                    entry['weekly_resets_epoch'] = self.NOW + days * self.DAY
                snapshot.write_text(json.dumps(
                    {'schema': 2, 'active': 'default', 'accounts': {'default': entry}}))
                output = subprocess.run([str(script)], env=env, text=True, capture_output=True,
                                        timeout=20).stdout
                expected = {
                    'fable': re.search(r'FABLE_BUDGET_MODE: (\w+)', output).group(1),
                    'shared': re.search(r'SHARED_BUDGET_MODE: (\w+)', output).group(1)}
                with patch.dict(os.environ, {'USAGE_SNAPSHOT': str(snapshot),
                                             'CLAUDE_ACCOUNTS_FILE': env['CLAUDE_ACCOUNTS_FILE']}):
                    os.environ.pop('FABLE_BUDGET_MODE')
                    os.environ.pop('SHARED_BUDGET_MODE')
                    self.assertEqual(m.read_budget_modes(self.NOW), expected)


class BudgetFixture(RequestFixture):
    def resolve(self, phase, *extra, profile='claude-default', fable='conserve', shared='ok'):
        args = [str(SCRIPT), 'request', '--phase', phase, '--input', str(self.input),
                '--cwd', str(self.cwd), '--profile', profile,
                '--account-home', 'current=' + str(self.home), '--out', str(self.out), *extra]
        environment = {'FABLE_BUDGET_MODE': fable, 'SHARED_BUDGET_MODE': shared}
        with patch.object(sys, 'argv', args), patch.dict(os.environ, environment):
            return m.main()


class BudgetApplication(BudgetFixture, unittest.TestCase):
    # model-tier-resolution: the modes act on the tier before the cap of the configuration.
    def test_depleted_holds_every_role_at_the_middle_tier(self):
        for profile in ('claude-default', 'codex-standard'):
            for phase in m.PHASES:
                with self.subTest(profile=profile, phase=phase):
                    self.assertEqual(self.resolve(phase, profile=profile, shared='depleted')['tier'],
                                     '最安' if phase in ('explore', 'summarize') else '中位')

    def test_throttled_keeps_what_was_raised_at_the_upper_tier(self):
        cases = ((('spec-review',), '中位'), (('review',), '中位'), (('gate',), '中位'),
                 (('implement', '--pre-class', 'merge'), '上位'),
                 (('implement', '--failure', 'executor'), '上位'),
                 (('spec-review', '--pre-class', 'contract'), '上位'),
                 (('decider',), '上位'), (('decider', '--failure', 'first'), '上位'),
                 (('explore',), '最安'), (('implement',), '中位'))
        for arguments, tier in cases:
            with self.subTest(arguments=arguments):
                self.assertEqual(self.resolve(*arguments, shared='throttled')['tier'], tier)

    def test_exhausted_caps_every_route_at_the_upper_tier(self):
        for extra in ((), ('--unmanned',)):
            with self.subTest(extra=extra):
                self.assertEqual(self.resolve('decider', *extra, fable='exhausted')['tier'], '上位')

    def test_reserve_caps_only_unmanned_runs(self):
        self.assertEqual(self.resolve('decider', '--unmanned', fable='reserve')['tier'], '上位')
        self.assertEqual(self.resolve('decider', fable='reserve')['tier'], '最上位')

    def test_abundant_raises_nothing(self):
        for phase in m.PHASES:
            with self.subTest(phase=phase):
                self.assertEqual(self.resolve(phase, fable='abundant')['tier'],
                                 self.resolve(phase, fable='conserve')['tier'])

    def test_unknown_values_act_like_conserve_and_throttled(self):
        result = self.resolve('spec-review', fable='foo', shared='bar')
        self.assertEqual(result['tier'], self.resolve('spec-review', shared='throttled')['tier'])
        self.assertEqual(result['budget_modes'], {'fable': 'conserve', 'shared': 'throttled'})

    def test_the_configuration_does_not_change_the_applied_tier(self):
        for profile in ('claude-default', 'codex-standard', 'codex-economy', 'hybrid-standard',
                        'claude-write-codex-review'):
            with self.subTest(profile=profile):
                result = self.resolve('decider', profile=profile, fable='exhausted')
                self.assertEqual((result['requested_tier'], result['tier']), ('最上位', '上位'))

    def test_an_explicit_profile_does_not_run_the_probe_and_unreadable_usage_does_not_stop(self):
        os.environ.pop('FABLE_BUDGET_MODE')
        os.environ.pop('SHARED_BUDGET_MODE')
        with patch.object(m, '_run_usage_probe') as probe, \
                patch.object(m.usage_view, 'build_view', side_effect=OSError('unreadable')), \
                patch.object(sys, 'argv', [
                    str(SCRIPT), 'request', '--phase', 'decider', '--input', str(self.input),
                    '--cwd', str(self.cwd), '--profile', 'claude-default', '--out', str(self.out)]):
            result = m.main()
        probe.assert_not_called()
        self.assertEqual(result['budget_modes'], {'fable': 'conserve', 'shared': 'ok'})
        self.assertEqual(result['model'], 'fable')

    def test_the_modes_do_not_change_the_recorded_configuration(self):
        calm = self.resolve('decider')
        tight = self.resolve('decider', fable='exhausted', shared='depleted')
        self.assertEqual(calm['execution_config'], tight['execution_config'])
        self.assertEqual(calm['execution_config_hash'], tight['execution_config_hash'])


class TierOutput(BudgetFixture, unittest.TestCase):
    def test_claude_applied_value_keeps_the_requested_one(self):
        result = self.resolve('decider', fable='exhausted')
        self.assertEqual({key: result[key] for key in (
            'requested_tier', 'tier', 'tier_reason', 'tier_cap', 'executed_tier',
            'requested_model', 'model', 'budget_modes')},
            {'requested_tier': '最上位', 'tier': '上位', 'tier_reason': 'FABLE_BUDGET_MODE=exhausted',
             'tier_cap': None, 'executed_tier': '上位', 'requested_model': 'fable', 'model': 'opus',
             'budget_modes': {'fable': 'exhausted', 'shared': 'ok'}})

    def test_both_modes_lowering_to_the_same_tier_name_the_shared_one(self):
        result = self.resolve('decider', fable='exhausted', shared='throttled')
        self.assertEqual((result['tier'], result['tier_reason']),
                         ('上位', 'SHARED_BUDGET_MODE=throttled'))

    def test_unchanged_reason_and_depleted_reason(self):
        self.assertEqual(self.resolve('implement')['tier_reason'], 'unchanged')
        self.assertEqual(self.resolve('review', shared='depleted')['tier_reason'],
                         'SHARED_BUDGET_MODE=depleted')

    def test_cap_lowers_the_executed_tier_only(self):
        for extra, tier in (((), '中位'), (('--pre-class', 'merge'), '上位')):
            with self.subTest(extra=extra):
                result = self.resolve('implement', *extra, profile='codex-economy')
                self.assertEqual((result['tier'], result['tier_cap'], result['executed_tier'],
                                  result['requested_model'], result['model']),
                                 (tier, '最安', '最安', 'sol', 'luna'))
                self.assertEqual(result['tier_reason'], 'unchanged')

    def test_gate_of_the_economy_profile_stays_on_the_cap(self):
        result = self.resolve('gate', profile='codex-economy')
        self.assertEqual((result['tier'], result['executed_tier'], result['model']),
                         ('中位', '最安', 'luna'))

    def test_a_cap_above_the_tier_changes_nothing(self):
        roles = {role: {'executor': 'codex', 'account': 'current', 'effort': 'low',
                        'tier_cap': '最上位'} for role in m.CANONICAL_ROLES}
        self.profile_file.write_text(json.dumps(
            {'version': 2, 'profiles': {'custom': {'roles': roles}}}))
        result = self.resolve('implement', '--profile-file', str(self.profile_file),
                              profile='custom')
        self.assertEqual((result['tier'], result['executed_tier'], result['model']),
                         ('中位', '中位', 'sol'))

    def test_the_request_file_gains_no_tier_field_and_the_worker_accepts_it(self):
        linked = self.root / 'linked'
        subprocess.run(['git', '-C', str(self.cwd), 'worktree', 'add', '-q', '-b', 'feature',
                        str(linked)], check=True)
        args = [str(SCRIPT), 'request', '--phase', 'implement', '--input', str(self.input),
                '--cwd', str(linked), '--profile', 'codex-standard', '--pre-class', 'merge',
                '--account-home', 'current=' + str(self.home), '--out', str(self.out)]
        with patch.object(sys, 'argv', args):
            result = m.main()
        request = json.loads(self.out.read_text())
        self.assertEqual(set(request), {'request_id', 'origin', 'account', 'cwd', 'model', 'role',
                                        'prompt', 'effort', 'codex_home'})
        self.assertEqual(request['model'], result['model'])
        request.pop('codex_home')
        self.assertEqual(worker_module.validate_request(request)['model'], 'sol')


class LegacyForm(RequestFixture, unittest.TestCase):
    def legacy(self, model, *extra, phase='implement'):
        args = [str(SCRIPT), 'request', '--phase', phase, '--input', str(self.input),
                '--cwd', str(self.cwd), '--account', 'mapped', '--model', model,
                '--account-home', 'mapped=' + str(self.home), '--out', str(self.out), *extra]
        with patch.object(sys, 'argv', args):
            return m.main()

    def test_the_legacy_form_goes_around_the_tiers(self):
        result = self.legacy('gpt-6-sol', '--pre-class', 'merge', '--design-judgment', '--failure',
                             'executor', '--unmanned', phase='review')
        self.assertEqual((result['role'], result['model'], result['requested_model']),
                         ('impl-review', 'gpt-6-sol', 'gpt-6-sol'))
        for key in ('requested_tier', 'tier', 'tier_reason', 'tier_cap', 'executed_tier',
                    'budget_modes'):
            with self.subTest(key=key):
                self.assertIsNone(result[key])
        request = json.loads(self.out.read_text())
        self.assertEqual((request['role'], request['model']), ('impl-review', 'gpt-6-sol'))

    def test_family_names_and_exact_ids_pass_unchanged(self):
        for model in ('sol', 'gpt-6-astra'):
            with self.subTest(model=model):
                self.assertEqual(self.legacy(model)['model'], model)

    def test_the_legacy_form_ignores_a_broken_table_and_the_modes(self):
        with patch.object(m, 'TIER_MAP', self.root / 'absent.json'), \
                patch.dict(os.environ, {'SHARED_BUDGET_MODE': 'depleted'}):
            self.assertEqual(self.legacy('astra', phase='decider')['model'], 'astra')


class ProfileFormatDocument(RequestFixture, unittest.TestCase):
    def test_the_documented_external_profile_resolves(self):
        document = (SCRIPT.parents[1] / 'references/codex-develop-explicit.md').read_text()
        example = re.search(r'```json\n(.*?)```', document, re.S).group(1)
        self.profile_file.write_text(example)
        result = self.call_profile('custom', profile_file=self.profile_file)
        self.assertEqual((result['status'], result['account'], result['model']),
                         ('request-written', 'mapped', 'luna'))
        self.assertEqual(self.call_profile('custom', phase='review',
                                           profile_file=self.profile_file)['model'], 'opus')


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
        self.assertNotIn('<= 300', decision)
        self.assertNotIn('> 300', decision)
        self.assertIn('リセット時刻', decision)
        for text in (self.adapter, self.skill,
                     (self.root / 'docs/codex-develop.md').read_text()):
            self.assertIn('claude-write-codex-review', text)
            self.assertNotIn('age 300', text)
            self.assertNotIn('<=300', text)
            self.assertIn('margin', text)

    def test_margin_formula_is_not_counted_here(self):
        # 週の秒数が残っていれば margin を自分で数えている（数えるのは headroom.py だけ）
        source = SCRIPT.read_text()
        self.assertNotIn('604800', source)
        self.assertNotIn('WEEK_SECONDS', source)
        self.assertNotIn('86400', source)
        self.assertIn('import headroom', source)

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

    def test_claude_roles_use_what_request_returned_and_resume_compares_tiers(self):
        for field in ('requested_model', 'tier_reason', 'executed_tier', 'tier_cap'):
            self.assertIn(f'`{field}`', self.adapter)
        self.assertIn('本体は上限を計算し直さない', self.adapter)
        self.assertNotIn('再計算', self.adapter)
        self.assertIn('sonnet 上限で haiku はそのまま', self.adapter)
        self.assertNotIn('applied=sonnet に固定', self.adapter)
        self.assertIn('同じ phase と入力（実行先オプションも同じ）で `request` を呼び直し', self.adapter)
        self.assertIn('呼び直しで書かれた依頼ファイルは使わず捨てる', self.adapter)
        for flag in ('--pre-class', '--design-judgment', '--failure', '--unmanned'):
            self.assertIn(flag, self.adapter)
            self.assertIn(flag, (self.root / 'docs/codex-develop.md').read_text())


if __name__ == '__main__':
    unittest.main()
