import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unicodedata
import unittest

sys.dont_write_bytecode = True
SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/usage_view.py'
spec = importlib.util.spec_from_file_location('usage_view', SCRIPT)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

NOW = 2_000_000_000
HOUR = 3600
DAY = 86400
WEEK = 7 * DAY


def key_of(secure):
    if not secure:
        return 'default'
    return hashlib.sha256(unicodedata.normalize('NFC', secure).encode()).hexdigest()[:8]


class EffectiveValues(unittest.TestCase):
    # Rules for "the value usable now" (usage-session-records spec): the session record and
    # the probe snapshot are both lower bounds until their reset time, and 0% after it.
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.sessions = self.root / 'sessions'
        self.sessions.mkdir()
        self.accounts = self.root / 'accounts.json'
        self.snapshot = self.root / 'snapshot.json'
        self.secure_b = str(self.root / 'b-config')
        self.register([('a', None), ('b', self.secure_b)])

    def register(self, slots):
        self.accounts.write_text(json.dumps({'accounts': [
            {'id': sid, 'securestorage': secure} for sid, secure in slots]}))

    def record(self, secure, *, observed=NOW, five=None, five_reset=None,
               weekly=None, weekly_reset=None, key=None):
        name = key_of(secure)
        self.sessions.joinpath(name + '.json').write_text(json.dumps({
            'schema': 1, 'key': key if key is not None else name, 'observed_at': observed,
            'five_hour_pct': five, 'five_hour_resets_epoch': five_reset,
            'weekly_all_pct': weekly, 'weekly_resets_epoch': weekly_reset}))

    def snap(self, accounts, active=None):
        self.snapshot.write_text(json.dumps({'schema': 2, 'active': active,
                                             'accounts': accounts}))

    def view(self, active_secure=''):
        return m.build_view(accounts_file=str(self.accounts), sessions_dir=str(self.sessions),
                            snapshot_path=str(self.snapshot), now=NOW,
                            active_secure=active_secure)

    def test_b_record_is_not_read_as_a(self):
        self.record(self.secure_b, weekly=90, weekly_reset=NOW + DAY)
        accounts = self.view()['accounts']
        self.assertIsNone(accounts['a']['weekly_all_pct'])
        self.assertEqual(accounts['b']['weekly_all_pct'], 90)

    def test_past_reset_reads_as_zero_and_rolls_weekly_forward(self):
        self.record(None, weekly=80, weekly_reset=NOW - HOUR, five=95, five_reset=NOW - 600)
        a = self.view()['accounts']['a']
        self.assertEqual(a['weekly_all_pct'], 0)
        self.assertEqual(a['weekly_resets_epoch'], NOW - HOUR + WEEK)
        self.assertEqual(a['five_hour_pct'], 0)
        self.assertIsNone(a['five_hour_resets_epoch'])

    def test_weekly_reset_rolls_by_whole_weeks(self):
        self.record(None, weekly=80, weekly_reset=NOW - WEEK - HOUR)
        a = self.view()['accounts']['a']
        self.assertEqual(a['weekly_resets_epoch'], NOW - HOUR + WEEK)

    def test_old_value_before_reset_is_a_lower_bound(self):
        self.record(None, observed=NOW - 2 * DAY, weekly=40, weekly_reset=NOW + DAY)
        a = self.view()['accounts']['a']
        self.assertEqual(a['weekly_all_pct'], 40)
        self.assertEqual(a['weekly_observed_at'], NOW - 2 * DAY)

    def test_same_window_takes_the_newer_value(self):
        reset = NOW + 3 * DAY
        self.record(None, observed=NOW - 60, weekly=50, weekly_reset=reset)
        self.snap({'a': {'fetched_at': NOW - 5 * HOUR, 'weekly_all_pct': 55,
                         'weekly_resets_epoch': reset + 1800}})
        a = self.view()['accounts']['a']
        # A manual reset lowers the value without moving the reset time, so the size does not decide.
        self.assertEqual(a['weekly_all_pct'], 50)
        self.assertEqual(a['weekly_resets_epoch'], reset)
        self.assertEqual(a['weekly_observed_at'], NOW - 60)

    def test_newer_record_after_manual_reset_beats_old_full_snapshot(self):
        reset = NOW + 3 * DAY
        self.record(None, observed=NOW - 60, weekly=0, weekly_reset=reset)
        self.snap({'a': {'fetched_at': NOW - 2 * HOUR, 'weekly_all_pct': 100,
                         'weekly_resets_epoch': reset}})
        a = self.view()['accounts']['a']
        self.assertEqual(a['weekly_all_pct'], 0)
        self.assertEqual(a['weekly_observed_at'], NOW - 60)

    def test_newer_and_larger_value_is_taken(self):
        reset = NOW + 3 * DAY
        self.record(None, observed=NOW - 60, weekly=60, weekly_reset=reset)
        self.snap({'a': {'fetched_at': NOW - 2 * HOUR, 'weekly_all_pct': 40,
                         'weekly_resets_epoch': reset}})
        self.assertEqual(self.view()['accounts']['a']['weekly_all_pct'], 60)

    def test_newer_snapshot_beats_older_record_in_the_same_window(self):
        reset = NOW + 3 * DAY
        self.record(None, observed=NOW - 2 * HOUR, weekly=70, weekly_reset=reset)
        self.snap({'a': {'fetched_at': NOW - 60, 'weekly_all_pct': 0,
                         'weekly_resets_epoch': reset + 600}})
        a = self.view()['accounts']['a']
        self.assertEqual(a['weekly_all_pct'], 0)
        self.assertEqual(a['weekly_resets_epoch'], reset + 600)
        self.assertEqual(a['weekly_observed_at'], NOW - 60)

    def test_equal_observed_times_take_the_larger_value(self):
        reset = NOW + 3 * DAY
        self.record(None, observed=NOW - 60, weekly=50, weekly_reset=reset)
        self.snap({'a': {'fetched_at': NOW - 60, 'weekly_all_pct': 55,
                         'weekly_resets_epoch': reset + 1800}})
        a = self.view()['accounts']['a']
        self.assertEqual(a['weekly_all_pct'], 55)
        # The reset time also comes from the source of the larger value.
        self.assertEqual(a['weekly_resets_epoch'], reset + 1800)

    def test_missing_observed_time_takes_the_larger_value(self):
        reset = NOW + 3 * DAY
        self.record(None, observed=NOW - 60, weekly=50, weekly_reset=reset)
        self.snap({'a': {'weekly_all_pct': 55, 'weekly_resets_epoch': reset + 1800}})
        a = self.view()['accounts']['a']
        self.assertEqual(a['weekly_all_pct'], 55)
        self.assertEqual(a['weekly_resets_epoch'], reset + 1800)
        self.assertIsNone(a['weekly_observed_at'])

    def test_weekly_all_reset_mismatch_prefers_the_record(self):
        self.record(None, observed=NOW - 60, weekly=10, weekly_reset=NOW + 6 * DAY)
        self.snap({'a': {'fetched_at': NOW - 2 * DAY, 'weekly_all_pct': 90,
                         'weekly_resets_epoch': NOW - HOUR}})
        # The snapshot rolls to NOW - HOUR + WEEK: more than an hour from the record's reset.
        self.assertEqual(self.view()['accounts']['a']['weekly_all_pct'], 10)

    def test_later_window_wins_for_five_hour(self):
        self.record(None, observed=NOW - 60, five=5, five_reset=NOW + 4 * HOUR)
        self.snap({'a': {'fetched_at': NOW - 4 * HOUR, 'five_hour_pct': 70,
                         'five_hour_resets_epoch': NOW + 1 * HOUR}})
        a = self.view()['accounts']['a']
        self.assertEqual(a['five_hour_pct'], 5)
        self.assertEqual(a['five_hour_resets_epoch'], NOW + 4 * HOUR)

    def test_five_hour_reset_side_beats_null_side(self):
        self.record(None, observed=NOW - 60, five=95, five_reset=NOW - 600)
        self.snap({'a': {'fetched_at': NOW - HOUR, 'five_hour_pct': 20,
                         'five_hour_resets_epoch': NOW + HOUR}})
        a = self.view()['accounts']['a']
        self.assertEqual(a['five_hour_pct'], 20)
        self.assertEqual(a['five_hour_observed_at'], NOW - HOUR)

    def test_five_hour_null_reset_with_valid_pct_is_used(self):
        self.snap({'a': {'fetched_at': NOW - HOUR, 'five_hour_pct': 0,
                         'five_hour_resets_epoch': None}})
        a = self.view()['accounts']['a']
        self.assertEqual(a['five_hour_pct'], 0)
        self.assertIsNone(a['five_hour_resets_epoch'])

    def test_five_hour_null_reset_with_positive_pct_is_missing(self):
        # リセット時刻が null の 5 時間枠を使うのは pct 0 のときだけ。pct>0 を使うと 0% に戻る時が来ず
        # 下限として残り続けるので欠測にする
        self.record(None, observed=NOW - 6 * HOUR, five=95, five_reset=None)
        a = self.view()['accounts']['a']
        self.assertIsNone(a['five_hour_pct'])
        self.assertIsNone(a['five_hour_observed_at'])

    def test_five_hour_null_reset_positive_pct_does_not_beat_null_zero(self):
        self.record(None, observed=NOW - 60, five=3, five_reset=None)
        self.snap({'a': {'fetched_at': NOW - HOUR, 'five_hour_pct': 0,
                         'five_hour_resets_epoch': None}})
        a = self.view()['accounts']['a']
        self.assertEqual(a['five_hour_pct'], 0)
        self.assertEqual(a['five_hour_observed_at'], NOW - HOUR)

    def test_weekly_null_reset_is_missing(self):
        self.record(None, weekly=40, weekly_reset=None)
        self.assertIsNone(self.view()['accounts']['a']['weekly_all_pct'])

    def test_no_source_is_missing_not_zero(self):
        a = self.view()['accounts']['a']
        for field in ('five_hour_pct', 'five_hour_resets_epoch', 'weekly_all_pct',
                      'weekly_resets_epoch', 'fable_weekly_pct', 'observed_at'):
            self.assertIsNone(a[field], field)

    def test_out_of_range_or_non_number_is_missing(self):
        self.record(None, weekly=150, weekly_reset=NOW + DAY, five=True, five_reset=NOW + HOUR)
        a = self.view()['accounts']['a']
        self.assertIsNone(a['weekly_all_pct'])
        self.assertIsNone(a['five_hour_pct'])
        self.record(None, weekly=-1, weekly_reset=NOW + DAY)
        self.assertIsNone(self.view()['accounts']['a']['weekly_all_pct'])
        self.record(None, weekly='40', weekly_reset=NOW + DAY)
        self.assertIsNone(self.view()['accounts']['a']['weekly_all_pct'])

    def test_weekly_reset_mismatch_over_an_hour_takes_the_record(self):
        self.record(None, observed=NOW - 60, weekly=30, weekly_reset=NOW + 2 * DAY)
        self.snap({'a': {'fetched_at': NOW - HOUR, 'weekly_all_pct': 60,
                         'weekly_resets_epoch': NOW + 5 * DAY}})
        a = self.view()['accounts']['a']
        self.assertEqual(a['weekly_all_pct'], 30)
        self.assertEqual(a['weekly_resets_epoch'], NOW + 2 * DAY)
        self.assertEqual(a['observed_at'], NOW - 60)

    def test_weekly_mismatch_with_reset_record_follows_the_general_rule(self):
        self.record(None, observed=NOW - 2 * HOUR, weekly=80, weekly_reset=NOW - HOUR)
        self.snap({'a': {'fetched_at': NOW - 60, 'weekly_all_pct': 10,
                         'weekly_resets_epoch': NOW + 3 * DAY}})
        # The record rolls to NOW - HOUR + WEEK, the later window, so it wins at 0%.
        a = self.view()['accounts']['a']
        self.assertEqual(a['weekly_all_pct'], 0)
        self.assertEqual(a['weekly_resets_epoch'], NOW - HOUR + WEEK)

    def test_fable_comes_from_the_snapshot_only(self):
        self.snap({'a': {'fetched_at': NOW - DAY, 'fable_weekly_pct': 25,
                         'weekly_resets_epoch': NOW + DAY},
                   'b': {'fetched_at': NOW - DAY, 'fable_weekly_pct': 70,
                         'weekly_resets_epoch': NOW - HOUR}})
        accounts = self.view()['accounts']
        self.assertEqual(accounts['a']['fable_weekly_pct'], 25)
        self.assertEqual(accounts['a']['fable_resets_epoch'], NOW + DAY)
        self.assertEqual(accounts['a']['fable_observed_at'], NOW - DAY)
        self.assertEqual(accounts['b']['fable_weekly_pct'], 0)
        self.assertEqual(accounts['b']['fable_resets_epoch'], NOW - HOUR + WEEK)

    def test_inputs_outside_the_guarded_range_pass_through(self):
        # A future observed_at is used as is, the in-file key is not read, and a reset time
        # more than a week ahead is still a value before its reset.
        self.record(None, observed=NOW + DAY, weekly=40, weekly_reset=NOW + 9 * DAY,
                    key='someone-else')
        a = self.view()['accounts']['a']
        self.assertEqual(a['weekly_all_pct'], 40)
        self.assertEqual(a['weekly_resets_epoch'], NOW + 9 * DAY)
        self.assertEqual(a['observed_at'], NOW + DAY)

    def test_broken_files_are_treated_as_absent(self):
        self.sessions.joinpath('default.json').write_text('{"schema": 1, "weekly_all_')
        self.snapshot.write_text('not json')
        a = self.view()['accounts']['a']
        self.assertIsNone(a['weekly_all_pct'])

    def test_active_follows_launch_environment_then_snapshot_then_first(self):
        self.snap({}, active='b')
        self.assertEqual(self.view(active_secure=self.secure_b)['active'], 'b')
        self.assertEqual(self.view(active_secure='')['active'], 'a')
        self.register([('x', str(self.root / 'x')), ('b', self.secure_b)])
        self.assertEqual(self.view(active_secure=str(self.root / 'other'))['active'], 'b')
        self.snap({})
        self.assertEqual(self.view(active_secure=str(self.root / 'other'))['active'], 'x')

    def test_registry_resolution_matches_select_account(self):
        self.accounts.write_text(json.dumps({'accounts': [
            {'id': 'a', 'securestorage': None}, {'id': 'bad id'},
            {'id': 'n', 'securestorage': 5}, {'id': 'a'}, {'id': 'c', 'securestorage': 'x\ny'},
            {'id': 'd', 'securestorage': '/d'}]}))
        self.assertEqual(list(self.view()['accounts']), ['a', 'd'])
        self.accounts.write_text('[]')
        self.assertEqual(list(self.view()['accounts']), ['default'])

    def test_json_cli_prints_one_line(self):
        self.record(self.secure_b, observed=NOW - 60, weekly=45, weekly_reset=NOW + DAY,
                    five=3, five_reset=NOW + HOUR)
        self.snap({'b': {'fetched_at': NOW - HOUR, 'fable_weekly_pct': 25,
                         'weekly_resets_epoch': NOW + DAY}})
        env = {k: v for k, v in os.environ.items() if k != 'CLAUDE_SECURESTORAGE_CONFIG_DIR'}
        env |= {'CLAUDE_ACCOUNTS_FILE': str(self.accounts),
                'USAGE_SESSIONS_DIR': str(self.sessions),
                'USAGE_SNAPSHOT': str(self.snapshot),
                'CLAUDE_SECURESTORAGE_CONFIG_DIR': self.secure_b}
        result = subprocess.run([sys.executable, str(SCRIPT), '--json', '--now', str(NOW)],
                                env=env, capture_output=True, text=True, check=True)
        self.assertEqual(len(result.stdout.strip().splitlines()), 1)
        view = json.loads(result.stdout)
        self.assertEqual(set(view), {'now', 'active', 'accounts'})
        self.assertEqual(view['now'], NOW)
        self.assertEqual(view['active'], 'b')
        b = view['accounts']['b']
        self.assertEqual((b['weekly_all_pct'], b['five_hour_pct'], b['fable_weekly_pct']),
                         (45, 3, 25))
        self.assertEqual(b['observed_at'], NOW - 60)
        self.assertEqual(b['session_observed_at'], NOW - 60)
        self.assertEqual(b['probe_fetched_at'], NOW - HOUR)

    def test_default_sessions_dir_follows_claude_config_dir(self):
        config = self.root / 'config'
        (config / '.usage-sessions').mkdir(parents=True)
        (config / '.usage-sessions/default.json').write_text(json.dumps({
            'schema': 1, 'key': 'default', 'observed_at': NOW, 'five_hour_pct': 1,
            'five_hour_resets_epoch': NOW + HOUR, 'weekly_all_pct': 2,
            'weekly_resets_epoch': NOW + DAY}))
        env = {k: v for k, v in os.environ.items()
               if k not in ('USAGE_SESSIONS_DIR', 'CLAUDE_SECURESTORAGE_CONFIG_DIR')}
        env |= {'CLAUDE_CONFIG_DIR': str(config), 'CLAUDE_ACCOUNTS_FILE': str(self.accounts),
                'USAGE_SNAPSHOT': str(self.snapshot)}
        result = subprocess.run([sys.executable, str(SCRIPT), '--json', '--now', str(NOW)],
                                env=env, capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(result.stdout)['accounts']['a']['weekly_all_pct'], 2)


class EnabledFlag(unittest.TestCase):
    # usage-account-registry "スロットを enabled でオフにできる": only the JSON false turns a
    # slot off, and an off slot stays a registry slot (order, the cap of 8, active).
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.sessions = self.root / 'sessions'
        self.sessions.mkdir()
        self.accounts = self.root / 'accounts.json'
        self.snapshot = self.root / 'snapshot.json'

    def register(self, entries):
        self.accounts.write_text(json.dumps({'schema': 1, 'accounts': entries}))

    def test_only_json_false_is_off_and_no_slot_is_dropped(self):
        values = [('f', False), ('t', True), ('s', 'false'), ('z', 0), ('n', None)]
        entries = [{'id': sid, 'securestorage': '/x/' + sid, 'enabled': value}
                   for sid, value in values]
        entries.insert(2, {'id': 'o', 'securestorage': '/x/o'})
        self.register(entries)
        slots = m.read_slots(str(self.accounts))
        self.assertEqual([sid for sid, _, _ in slots], ['f', 't', 'o', 's', 'z', 'n'])
        self.assertEqual([enabled for _, _, enabled in slots],
                         [False, True, True, True, True, True])

    def test_off_slot_counts_toward_the_cap_and_keeps_declared_order(self):
        entries = [{'id': f's{i}', 'securestorage': f'/x/{i}'} for i in range(9)]
        entries[0]['enabled'] = False
        self.register(entries)
        slots = m.read_slots(str(self.accounts))
        self.assertEqual([sid for sid, _, _ in slots], [f's{i}' for i in range(8)])
        self.assertEqual(slots[0], ('s0', '/x/0', False))

    def test_read_registry_keeps_its_two_column_shape(self):
        self.register([{'id': 'a', 'securestorage': None},
                       {'id': 'b', 'securestorage': '/x/b', 'enabled': False}])
        self.assertEqual(m.read_registry(str(self.accounts)), [('a', ''), ('b', '/x/b')])

    def test_unreadable_registry_falls_back_to_an_enabled_default_slot(self):
        self.assertEqual(m.read_slots(str(self.root / 'absent.json')), [('default', '', True)])
        self.assertEqual(m.read_registry(str(self.root / 'absent.json')), [('default', '')])

    def test_off_slot_stays_in_the_view_and_can_be_active(self):
        self.register([{'id': 'a', 'securestorage': None},
                       {'id': 'b', 'securestorage': '/x/b', 'enabled': False}])
        self.snapshot.write_text(json.dumps({'schema': 2, 'active': None, 'accounts': {
            'b': {'fetched_at': NOW - HOUR, 'five_hour_pct': 5,
                  'five_hour_resets_epoch': NOW + HOUR, 'weekly_all_pct': 40,
                  'weekly_resets_epoch': NOW + DAY}}}))
        view = m.build_view(accounts_file=str(self.accounts), sessions_dir=str(self.sessions),
                            snapshot_path=str(self.snapshot), now=NOW, active_secure='/x/b')
        self.assertEqual(list(view['accounts']), ['a', 'b'])
        self.assertEqual(view['accounts']['b']['weekly_all_pct'], 40)
        self.assertEqual(view['active'], 'b')


class CodexEnabled(unittest.TestCase):
    # usage-account-registry "Codex を codex.enabled でオフにできる": Codex is off only when
    # the top-level "codex"."enabled" is the JSON false; every other input reads as on.
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.accounts = self.root / 'accounts.json'

    def write(self, document):
        self.accounts.write_text(json.dumps(document))

    def registry(self, **extra):
        return {'schema': 1, 'accounts': [{'id': 'a', 'securestorage': None}], **extra}

    def test_only_json_false_turns_codex_off(self):
        cases = [({'enabled': False}, False), ({'enabled': True}, True), ({}, True),
                 ({'enabled': 'false'}, True), ({'enabled': 0}, True),
                 ({'enabled': None}, True), (False, True)]
        for codex, expected in cases:
            with self.subTest(codex=codex):
                self.write(self.registry(codex=codex))
                self.assertIs(m.read_codex_enabled(str(self.accounts)), expected)

    def test_registry_without_the_key_is_on(self):
        self.write(self.registry())
        self.assertIs(m.read_codex_enabled(str(self.accounts)), True)

    def test_missing_broken_and_array_registries_are_on(self):
        self.assertIs(m.read_codex_enabled(str(self.root / 'absent.json')), True)
        self.accounts.write_text('{"codex": {"enabled": false')
        self.assertIs(m.read_codex_enabled(str(self.accounts)), True)
        self.accounts.write_text('[{"codex": {"enabled": false}}]')
        self.assertIs(m.read_codex_enabled(str(self.accounts)), True)

    def test_codex_key_does_not_change_the_slots(self):
        self.write(self.registry())
        slots, registry = m.read_slots(str(self.accounts)), m.read_registry(str(self.accounts))
        self.write(self.registry(codex={'enabled': False}))
        self.assertEqual(m.read_slots(str(self.accounts)), slots)
        self.assertEqual(m.read_registry(str(self.accounts)), registry)
        self.assertEqual(registry, [('a', '')])

    def run_cli(self, *argv):
        env = {k: v for k, v in os.environ.items() if k != 'CLAUDE_CONFIG_DIR'}
        env['CLAUDE_ACCOUNTS_FILE'] = str(self.accounts)
        return subprocess.run([sys.executable, str(SCRIPT), *argv], env=env,
                              capture_output=True, text=True)

    def test_cli_prints_one_line_and_always_exits_zero(self):
        self.write(self.registry(codex={'enabled': False}))
        result = self.run_cli('--codex-enabled')
        self.assertEqual((result.returncode, result.stdout), (0, 'off\n'))
        self.write(self.registry())
        result = self.run_cli('--codex-enabled')
        self.assertEqual((result.returncode, result.stdout), (0, 'on\n'))
        self.accounts.unlink()
        result = self.run_cli('--codex-enabled')
        self.assertEqual((result.returncode, result.stdout), (0, 'on\n'))

    def test_json_view_is_unchanged_by_the_codex_key(self):
        self.write(self.registry())
        before = self.run_cli('--json', '--now', str(NOW)).stdout
        self.write(self.registry(codex={'enabled': False}))
        after = self.run_cli('--json', '--now', str(NOW))
        self.assertEqual(after.returncode, 0)
        self.assertEqual(after.stdout, before)


if __name__ == '__main__':
    unittest.main()
