"""headroom.py: one place that counts how much each account has left (dev-workflow-headroom).

The surplus cases mirror the Claude cases of flatmate's scripts/test_account_allocation.py
(Surplus / TicketSurplus): weekly use 40%, 24 hours to the weekly reset, cap 90 -> 43.3 without
reset tickets (ClaudeTickets, Codex), and the rest in FlatmateClaudeCases. Cases about flatmate's
own eligibility threshold, ranking and ticket-file statuses have no counterpart here.
"""
import base64
from datetime import datetime, timezone
import hashlib
import importlib.util
import inspect
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
SCRIPTS = Path(__file__).resolve().parents[1] / 'scripts'
SCRIPT = SCRIPTS / 'headroom.py'
spec = importlib.util.spec_from_file_location('headroom', SCRIPT)
h = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)

NOW = 1800000000
HOUR = 3600
WEEK = 604800
KEYS = {'provider', 'account', 'label', 'status', 'observed_at', 'five_hour_pct', 'used_pct',
        'elapsed_pct', 'weekly_reset_at', 'rocket', 'tickets', 'capacity_pct', 'left_pct',
        'deadline_at', 'deadline_reason', 'forecast', 'surplus_pct', 'margin'}


def iso(epoch):
    return datetime.fromtimestamp(epoch, timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


class Env:
    """A config dir with a registry, a probe snapshot and (optionally) a Codex home and cache."""

    def __init__(self, test):
        self.temp = tempfile.TemporaryDirectory()
        test.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.config = self.root / 'config'
        self.config.mkdir()
        self.sessions = self.config / '.usage-sessions'
        self.sessions.mkdir()
        self.user_home = self.root / 'user'
        self.user_home.mkdir()
        self.codex_home = None
        self.slots = []
        self.entries = {}
        self.codex_enabled = None
        self.env = {'CLAUDE_CONFIG_DIR': str(self.config), 'HOME': str(self.user_home),
                    'CLAUDE_ACCOUNTS_FILE': str(self.config / 'accounts.json'),
                    'USAGE_SESSIONS_DIR': str(self.sessions),
                    'USAGE_SNAPSHOT': str(self.config / '.usage-snapshot'),
                    'CLAUDE_SECURESTORAGE_CONFIG_DIR': ''}
        self.patch = patch.dict(os.environ, self.env, clear=True)
        self.patch.start()
        test.addCleanup(self.patch.stop)

    def claude(self, slot, used=40, hours_left=24, fetched_at=NOW - HOUR, five=10, grants='absent',
               enabled=True, label=None):
        entry = {'enabled': enabled, 'id': slot, 'label': label or slot.upper(),
                 'securestorage': '' if not self.slots else '/s/' + slot}
        if enabled is True:
            entry.pop('enabled')
        self.slots.append(entry)
        value = {'label': label or slot.upper(), 'fetched_at': fetched_at,
                 'five_hour_pct': five, 'five_hour_resets_epoch': NOW + 2 * HOUR,
                 'weekly_all_pct': used, 'weekly_resets_epoch': NOW + hours_left * HOUR}
        if grants != 'absent':
            value['reset_grants'] = grants
        self.entries[slot] = value
        self.flush()

    def codex(self, used=40, hours_left=24, fetched_at=NOW - HOUR, five=None, resets='absent',
              identity_email='test@example.invalid'):
        self.codex_home = self.root / 'codex'
        self.codex_home.mkdir(exist_ok=True)
        claims = base64.urlsafe_b64encode(json.dumps({'email': 'test@example.invalid'}).encode()).decode().rstrip('=')
        (self.codex_home / 'auth.json').write_text(json.dumps(
            {'tokens': {'id_token': 'x.' + claims + '.x', 'account_id': 'account'}}))
        os.environ['CODEX_HOME'] = str(self.codex_home)
        windows = [{'minutes': 10080, 'used_percent': used, 'reset_at': NOW + hours_left * HOUR}]
        if five is not None:
            windows.append({'minutes': 300, 'used_percent': five[0], 'reset_at': five[1]})
        cache = {'version': 2, 'fetched_at': fetched_at, 'windows': windows,
                 'identity': {'email_hash': hashlib.sha256(identity_email.encode()).hexdigest(),
                              'account_id_hash': hashlib.sha256(b'account').hexdigest()}}
        if resets != 'absent':
            cache['resets'] = resets
        digest = hashlib.sha256(str(self.codex_home.resolve()).encode()).hexdigest()
        path = self.config / 'codex-usage' / (digest + '.json')
        path.parent.mkdir(exist_ok=True)
        path.write_text(json.dumps(cache))
        return path

    def flush(self):
        registry = {'accounts': self.slots}
        if self.codex_enabled is not None:
            registry['codex'] = {'enabled': self.codex_enabled}
        (self.config / 'accounts.json').write_text(json.dumps(registry))
        (self.config / '.usage-snapshot').write_text(json.dumps(
            {'schema': 2, 'active': self.slots[0]['id'] if self.slots else None,
             'accounts': self.entries}))

    def row(self, result, provider, account):
        rows = [r for r in result['accounts'] if r['provider'] == provider and r['account'] == account]
        assert len(rows) == 1, result
        return rows[0]


def grants(*pairs):
    return [{'resets_left': count, 'ends_at': iso(NOW + hours * HOUR) if hours is not None else None,
             'paused': False} for hours, count in pairs]


class ClaudeTickets(unittest.TestCase):
    def test_capacity_follows_ticket_count(self):
        cases = [([], 100, None, 43.333), (grants((12, 1)), 200, 1, 136.667),
                 (grants((6, 1), (12, 1)), 300, 2, 228.333), (grants((30, 1)), 100, None, 43.333)]
        for value, capacity, rocket, surplus in cases:
            with self.subTest(grants=value):
                env = Env(self)
                env.claude('a', grants=value)
                row = env.row(h.compute(NOW), 'claude', 'a')
                self.assertEqual(row['status'], 'ok')
                self.assertEqual(row['capacity_pct'], capacity)
                if rocket is None:
                    self.assertIsNone(row['rocket'])
                else:
                    self.assertEqual(row['rocket']['count'], rocket)
                self.assertAlmostEqual(row['surplus_pct'], surplus, places=2)
                self.assertEqual(row['deadline_reason'], 'weekly_reset')
                self.assertEqual(row['deadline_at'], NOW + 24 * HOUR)

    def test_bundle_counts_resets_left_and_null_expiry_only_in_tickets(self):
        env = Env(self)
        env.claude('a', grants=grants((12, 2), (None, 3)) + [
            {'resets_left': 4, 'ends_at': iso(NOW + 6 * HOUR), 'paused': True},
            {'resets_left': 0, 'ends_at': iso(NOW + 6 * HOUR), 'paused': False},
            {'resets_left': 1, 'ends_at': iso(NOW - HOUR), 'paused': False}])
        row = env.row(h.compute(NOW), 'claude', 'a')
        self.assertEqual(row['rocket'], {'count': 2, 'earliest_expiry': NOW + 12 * HOUR})
        self.assertEqual(row['tickets'], {'count': 5, 'earliest_expiry': NOW + 12 * HOUR})
        self.assertEqual(row['capacity_pct'], 300)
        self.assertEqual(row['left_pct'], 60 + 200)
        self.assertAlmostEqual(row['surplus_pct'], 50 - 40 / 144 * 12 + 180, places=6)

    def test_unknown_grants_count_as_zero_with_null_tickets(self):
        for value in ('absent', None, {'resets_left': 1}, [{'resets_left': 'x'}],
                      [{'resets_left': 1, 'ends_at': 'tomorrow'}]):
            with self.subTest(grants=value):
                env = Env(self)
                env.claude('a', grants=value)
                row = env.row(h.compute(NOW), 'claude', 'a')
                self.assertIsNone(row['tickets'])
                self.assertIsNone(row['rocket'])
                self.assertEqual(row['capacity_pct'], 100)
                self.assertAlmostEqual(row['surplus_pct'], 43.333, places=2)

    def test_empty_grants_are_known_zero(self):
        env = Env(self)
        env.claude('a', grants=[])
        row = env.row(h.compute(NOW), 'claude', 'a')
        self.assertEqual(row['tickets'], {'count': 0, 'earliest_expiry': None})


class Items(unittest.TestCase):
    def test_every_row_has_every_key_and_values(self):
        env = Env(self)
        env.claude('a', grants=grants((12, 1)))
        result = h.compute(NOW)
        self.assertEqual(set(result), {'schema', 'computed_at', 'settings', 'best',
                                       'best_by_provider', 'accounts'})
        self.assertEqual(result['schema'], 1)
        self.assertEqual(result['computed_at'], NOW)
        row = env.row(result, 'claude', 'a')
        self.assertEqual(set(row), KEYS)
        self.assertEqual(row['label'], 'A')
        self.assertEqual(row['observed_at'], NOW - HOUR)
        self.assertEqual(row['five_hour_pct'], 10)
        self.assertEqual(row['used_pct'], 40)
        self.assertEqual(row['weekly_reset_at'], NOW + 24 * HOUR)
        self.assertAlmostEqual(row['elapsed_pct'], 100 * (1 - 24 * HOUR / WEEK))
        self.assertAlmostEqual(row['margin'], 100 * (1 - 24 * HOUR / WEEK) - 40)
        self.assertEqual(row['left_pct'], 160)
        self.assertEqual(row['forecast']['kind'], 'spare')
        self.assertAlmostEqual(row['forecast']['pct'], 160 - 40 / 144 * 24)

    def test_forecast_exhaust(self):
        env = Env(self)
        env.claude('a', used=95, hours_left=48)
        row = env.row(h.compute(NOW), 'claude', 'a')
        rate = 95 / 120
        self.assertEqual(row['forecast']['kind'], 'exhaust')
        self.assertAlmostEqual(row['forecast']['at'], NOW + 5 / rate * HOUR)
        self.assertEqual(row['surplus_pct'], 0)

    def test_normal_rate_override(self):
        env = Env(self)
        env.claude('a')
        with patch.dict(os.environ, {'HEADROOM_NORMAL_RATE_PCT_PER_DAY': '24'}):
            result = h.compute(NOW)
        self.assertAlmostEqual(env.row(result, 'claude', 'a')['surplus_pct'], 50 - 24)
        self.assertEqual(result['settings'], {'cap_7d_pct': 90, 'normal_rate_pct_per_day': 24})


class FlatmateClaudeCases(unittest.TestCase):
    """The rest of flatmate's Surplus / TicketSurplus Claude cases (same inputs, same surplus)."""

    def surplus(self, rate=None, cap=None, **claude):
        env = Env(self)
        env.claude('a', **claude)
        extra = {}
        if rate is not None:
            extra['HEADROOM_NORMAL_RATE_PCT_PER_DAY'] = rate
        if cap is not None:
            extra['HEADROOM_7D_CAP_PCT'] = cap
        with patch.dict(os.environ, extra):
            return env.row(h.compute(NOW), 'claude', 'a')

    def test_normal_work_need_removes_surplus(self):
        self.assertEqual(self.surplus(rate='30', used=60, hours_left=100)['surplus_pct'], 0)

    def test_surplus_at_zero_rate_is_to_cap(self):
        self.assertAlmostEqual(self.surplus(rate='0', used=70, hours_left=10)['surplus_pct'], 20)

    def test_used_zero_and_far_reset_are_accepted(self):
        row = self.surplus(used=0, hours_left=200)
        self.assertEqual(row['status'], 'ok')
        self.assertEqual(row['left_pct'], 100)
        self.assertEqual(row['surplus_pct'], 90)

    def test_cap_setting(self):
        self.assertAlmostEqual(self.surplus(rate='0', cap='80', used=50, hours_left=10)['surplus_pct'], 30)

    def test_same_expiry_two_tickets_differ_by_one_ticket_amount(self):
        one = self.surplus(grants=grants((12, 1)))['surplus_pct']
        two = self.surplus(grants=grants((12, 2)))
        split = self.surplus(grants=grants((12, 1), (12, 1)))
        self.assertAlmostEqual(one, 136.667, places=2)
        self.assertAlmostEqual(two['surplus_pct'], 226.667, places=2)
        self.assertAlmostEqual(two['surplus_pct'] - one, 90, places=6)
        self.assertEqual(two['rocket']['count'], 2)
        self.assertAlmostEqual(split['surplus_pct'], 226.667, places=2)
        self.assertEqual(split['rocket']['count'], 2)

    def test_ticket_can_give_surplus_where_there_was_none(self):
        self.assertEqual(self.surplus(used=80)['surplus_pct'], 0)
        self.assertAlmostEqual(self.surplus(used=80, grants=grants((12, 1)))['surplus_pct'], 93.333,
                               places=2)

    def test_five_hour_limit_is_not_changed_by_tickets(self):
        env = Env(self)
        env.claude('a', used=80, five=97, grants=grants((12, 1)))
        result = h.compute(NOW)
        self.assertGreater(env.row(result, 'claude', 'a')['surplus_pct'], 10)
        self.assertIsNone(result['best'])

    def test_zero_and_no_expiry_tickets_keep_the_surplus_without_tickets(self):
        for value in ([], grants((None, 2))):
            with self.subTest(grants=value):
                row = self.surplus(grants=value)
                self.assertAlmostEqual(row['surplus_pct'], 43.333, places=2)
                self.assertIsNone(row['rocket'])


class Status(unittest.TestCase):
    def test_old_value_is_ok_and_rolled_value_is_ok(self):
        env = Env(self)
        env.claude('a', fetched_at=NOW - 2 * 86400)
        env.claude('b', used=70, hours_left=-1, fetched_at=NOW - 3 * 86400)
        result = h.compute(NOW)
        self.assertEqual(env.row(result, 'claude', 'a')['status'], 'ok')
        self.assertEqual(env.row(result, 'claude', 'a')['used_pct'], 40)
        rolled = env.row(result, 'claude', 'b')
        self.assertEqual(rolled['status'], 'ok')
        self.assertEqual(rolled['used_pct'], 0)
        self.assertEqual(rolled['weekly_reset_at'], NOW - HOUR + WEEK)

    def test_future_fetch_beyond_60_seconds_is_stale(self):
        env = Env(self)
        env.claude('a', fetched_at=NOW + 61)
        env.claude('b', fetched_at=NOW + 60)
        result = h.compute(NOW)
        stale = env.row(result, 'claude', 'a')
        self.assertEqual(stale['status'], 'stale')
        for key in ('observed_at', 'five_hour_pct', 'used_pct', 'elapsed_pct', 'weekly_reset_at'):
            self.assertIsNotNone(stale[key], key)
        for key in ('rocket', 'tickets', 'capacity_pct', 'left_pct', 'deadline_at',
                    'deadline_reason', 'forecast', 'surplus_pct', 'margin'):
            self.assertIsNone(stale[key], key)
        self.assertEqual(env.row(result, 'claude', 'b')['status'], 'ok')
        self.assertEqual(result['best'], {'provider': 'claude', 'account': 'b'})

    def test_missing_and_off(self):
        env = Env(self)
        env.claude('a')
        env.claude('b', enabled=False)
        env.slots.append({'id': 'c', 'securestorage': '/s/c'})
        env.flush()
        result = h.compute(NOW)
        off = env.row(result, 'claude', 'b')
        missing = env.row(result, 'claude', 'c')
        self.assertEqual(off['status'], 'off')
        self.assertEqual(missing['status'], 'missing')
        for row in (off, missing):
            for key in KEYS - {'provider', 'account', 'label', 'status'}:
                self.assertIsNone(row[key], key)
        self.assertEqual([r['account'] for r in result['accounts']], ['a', 'b', 'c'])
        self.assertEqual(result['best'], {'provider': 'claude', 'account': 'a'})


class Codex(unittest.TestCase):
    def test_ticket_before_reset_sets_deadline(self):
        env = Env(self)
        env.claude('a')
        env.codex(resets={'available_count': 2, 'expires_at': [NOW + 6 * HOUR, None]})
        row = env.row(h.compute(NOW), 'codex', 'current')
        self.assertEqual(row['status'], 'ok')
        self.assertEqual(row['label'], 'current')
        self.assertEqual(row['capacity_pct'], 100)
        self.assertEqual(row['left_pct'], 60)
        self.assertEqual(row['deadline_reason'], 'ticket_expiry')
        self.assertEqual(row['deadline_at'], NOW + 6 * HOUR)
        self.assertAlmostEqual(row['surplus_pct'], 48.333, places=2)
        self.assertEqual(row['rocket'], {'count': 1, 'earliest_expiry': NOW + 6 * HOUR})
        self.assertEqual(row['tickets'], {'count': 2, 'earliest_expiry': NOW + 6 * HOUR})
        start = NOW + 24 * HOUR - WEEK
        self.assertAlmostEqual(row['elapsed_pct'], 100 * (NOW - start) / (NOW + 6 * HOUR - start))
        self.assertAlmostEqual(row['margin'], 100 * (1 - 24 * HOUR / WEEK) - 40)

    def test_ticket_after_reset_does_not_change_deadline(self):
        env = Env(self)
        env.claude('a')
        env.codex(resets={'available_count': 1, 'expires_at': [NOW + 30 * HOUR]})
        row = env.row(h.compute(NOW), 'codex', 'current')
        self.assertEqual(row['deadline_reason'], 'weekly_reset')
        self.assertIsNone(row['rocket'])
        self.assertAlmostEqual(row['surplus_pct'], 43.333, places=2)

    def test_credits_expired_since_the_fetch_are_not_held(self):
        env = Env(self)
        env.claude('a')
        env.codex(resets={'available_count': 3,
                          'expires_at': [NOW - HOUR, NOW, NOW + 6 * HOUR]})
        row = env.row(h.compute(NOW), 'codex', 'current')
        self.assertEqual(row['tickets'], {'count': 1, 'earliest_expiry': NOW + 6 * HOUR})
        self.assertEqual(row['rocket'], {'count': 1, 'earliest_expiry': NOW + 6 * HOUR})

    def test_held_count_never_goes_below_zero(self):
        env = Env(self)
        env.claude('a')
        env.codex(resets={'available_count': 1, 'expires_at': [NOW - 2 * HOUR, NOW - HOUR]})
        row = env.row(h.compute(NOW), 'codex', 'current')
        self.assertEqual(row['tickets'], {'count': 0, 'earliest_expiry': None})

    def test_deadline_at_or_before_the_week_start_does_not_divide_by_zero(self):
        # the reset is 200 hours away, so the week starts 32 hours from now
        for hours, expected in ((32, 0.0), (12, 0.0)):
            with self.subTest(expiry_hours=hours):
                env = Env(self)
                env.claude('a')
                env.codex(hours_left=200, resets={'available_count': 1,
                                                  'expires_at': [NOW + hours * HOUR]})
                row = env.row(h.compute(NOW), 'codex', 'current')
                self.assertEqual(row['deadline_reason'], 'ticket_expiry')
                self.assertEqual(row['elapsed_pct'], expected)

    def test_missing_resets_give_null_tickets(self):
        env = Env(self)
        env.claude('a')
        env.codex()
        row = env.row(h.compute(NOW), 'codex', 'current')
        self.assertIsNone(row['tickets'])
        self.assertAlmostEqual(row['surplus_pct'], 43.333, places=2)

    def test_five_hour_window(self):
        for five, expected in (((92, NOW + HOUR), 92), ((92, NOW - 1), 0), (None, None)):
            with self.subTest(five=five):
                env = Env(self)
                env.claude('a')
                env.codex(five=five)
                self.assertEqual(env.row(h.compute(NOW), 'codex', 'current')['five_hour_pct'], expected)

    def test_identity_mismatch_and_absent_cache_are_missing(self):
        env = Env(self)
        env.claude('a')
        env.codex(identity_email='other@example.invalid')
        self.assertEqual(env.row(h.compute(NOW), 'codex', 'current')['status'], 'missing')
        env.codex().unlink()
        self.assertEqual(env.row(h.compute(NOW), 'codex', 'current')['status'], 'missing')

    def test_future_fetch_is_stale(self):
        env = Env(self)
        env.claude('a')
        env.codex(fetched_at=NOW + 120)
        self.assertEqual(env.row(h.compute(NOW), 'codex', 'current')['status'], 'stale')

    def test_codex_off(self):
        env = Env(self)
        env.codex_enabled = False
        env.claude('a')
        env.codex()
        row = env.row(h.compute(NOW), 'codex', 'current')
        self.assertEqual(row['status'], 'off')
        self.assertIsNone(row['used_pct'])

    def test_no_default_home_means_no_codex_row(self):
        env = Env(self)
        env.claude('a')
        result = h.compute(NOW)
        self.assertEqual([r['provider'] for r in result['accounts']], ['claude'])
        self.assertIsNone(result['best_by_provider']['codex'])


class Best(unittest.TestCase):
    def test_high_five_hour_is_skipped(self):
        env = Env(self)
        env.claude('a', used=10, five=92)
        env.claude('b', used=40, five=None)
        result = h.compute(NOW)
        self.assertEqual(result['best'], {'provider': 'claude', 'account': 'b'})

    def test_codex_best_and_claude_best_by_provider(self):
        env = Env(self)
        env.claude('a', used=60)
        env.claude('b', used=50)
        env.codex(used=10)
        result = h.compute(NOW)
        self.assertEqual(result['best'], {'provider': 'codex', 'account': 'current'})
        self.assertEqual(result['best_by_provider'],
                         {'claude': {'provider': 'claude', 'account': 'b'},
                          'codex': {'provider': 'codex', 'account': 'current'}})

    def test_ties_prefer_claude_then_declared_order(self):
        env = Env(self)
        env.claude('a')
        env.claude('b')
        env.codex()
        result = h.compute(NOW)
        self.assertEqual(result['best'], {'provider': 'claude', 'account': 'a'})

    def test_cap_changes_surplus_and_best(self):
        # Cap 90: b (lighter use) has more left. Cap 30: both are past the cap, both surpluses
        # drop to 0 and the tie goes to the declared order, so a becomes best.
        env = Env(self)
        env.claude('a', used=60)
        env.claude('b', used=40)
        first = h.compute(NOW)
        with patch.dict(os.environ, {'HEADROOM_7D_CAP_PCT': '30'}):
            second = h.compute(NOW)
        self.assertEqual(first['best'], {'provider': 'claude', 'account': 'b'})
        self.assertEqual(second['best'], {'provider': 'claude', 'account': 'a'})
        self.assertEqual(first['settings']['cap_7d_pct'], 90)
        self.assertEqual(second['settings']['cap_7d_pct'], 30)
        self.assertAlmostEqual(env.row(first, 'claude', 'b')['surplus_pct'], 43.333, places=2)
        self.assertEqual(env.row(second, 'claude', 'b')['surplus_pct'], 0)


class Settings(unittest.TestCase):
    def test_compute_takes_only_now(self):
        self.assertEqual(list(inspect.signature(h.compute).parameters), ['now'])

    def test_invalid_values_raise(self):
        env = Env(self)
        env.claude('a')
        for name, value in (('HEADROOM_7D_CAP_PCT', 'abc'), ('HEADROOM_7D_CAP_PCT', '120'),
                            ('HEADROOM_7D_CAP_PCT', '-1'), ('HEADROOM_NORMAL_RATE_PCT_PER_DAY', 'nan'),
                            ('HEADROOM_NORMAL_RATE_PCT_PER_DAY', '101')):
            with self.subTest(name=name, value=value), patch.dict(os.environ, {name: value}):
                with self.assertRaises(h.ConfigError):
                    h.compute(NOW)


class Cli(unittest.TestCase):
    def run_cli(self, *args, extra=None):
        env = dict(os.environ) | (extra or {})
        return subprocess.run([sys.executable, '-I', str(SCRIPT), *args], env=env,
                              capture_output=True, text=True)

    def test_json_prints_one_line_without_writing(self):
        env = Env(self)
        env.claude('a')
        done = self.run_cli('--json', '--now', str(NOW))
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(len(done.stdout.strip().splitlines()), 1)
        self.assertEqual(json.loads(done.stdout)['schema'], 1)
        self.assertFalse((env.config / '.headroom.json').exists())

    def test_write_is_schema_1_and_leaves_no_temp_file(self):
        env = Env(self)
        env.claude('a')
        done = self.run_cli('write', '--now', str(NOW))
        self.assertEqual(done.returncode, 0, done.stderr)
        written = json.loads((env.config / '.headroom.json').read_text())
        self.assertEqual(written['schema'], 1)
        self.assertEqual(written['computed_at'], NOW)
        self.assertEqual(set(written['accounts'][0]), KEYS)
        self.assertEqual(sorted(p.name for p in env.config.iterdir() if 'headroom' in p.name),
                         ['.headroom.json'])

    def test_cap_argument_and_unknown_arguments_are_refused(self):
        env = Env(self)
        env.claude('a')
        for args in (('--json', '--cap', '80'), ('write', '--cap', '80'), ('write', '--bogus'),
                     ('--json', '--now', 'soon'), ()):
            with self.subTest(args=args):
                done = self.run_cli(*args)
                self.assertEqual(done.returncode, 2)
                self.assertEqual(done.stdout, '')
                self.assertFalse((env.config / '.headroom.json').exists())

    def test_invalid_setting_writes_nothing(self):
        env = Env(self)
        env.claude('a')
        (env.config / '.headroom.json').write_text('{"schema": 1, "old": true}')
        for value in ('abc', '120'):
            with self.subTest(value=value):
                done = self.run_cli('write', extra={'HEADROOM_7D_CAP_PCT': value})
                self.assertEqual(done.returncode, 2)
                self.assertEqual(done.stdout, '')
                self.assertEqual(json.loads((env.config / '.headroom.json').read_text())['old'], True)

    def test_refresh_codex_calls_read_codex_usages_only_when_on_with_home(self):
        env = Env(self)
        env.claude('a')
        calls = []
        real = h._codex_module()
        fake = type('M', (), {
            'default_automatic_account_home': staticmethod(real.default_automatic_account_home),
            'read_codex_usages': staticmethod(
                lambda mapping, config_dir, now: calls.append((mapping, config_dir, now)) or {})})
        with patch.object(h, '_codex_module', return_value=fake):
            h.refresh_codex(NOW)
            self.assertEqual(calls, [])
            env.codex()
            h.refresh_codex(NOW)
            self.assertEqual(calls, [({'current': str(env.codex_home)}, str(env.config), NOW)])
            env.codex_enabled = False
            env.flush()
            h.refresh_codex(NOW)
            self.assertEqual(len(calls), 1)


if __name__ == '__main__':
    unittest.main()
