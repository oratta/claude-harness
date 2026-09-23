"""Run with scripts/test.sh python-suites (runs every plugins/*/tests/test_*.py)."""
import importlib.util
import json
import os
import re
import subprocess
import time
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('codex', Path(__file__).parents[1] / 'scripts/statusline-codex.py')
codex = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(codex)


def window(pct=45, minutes=10080, reset=2000000000):
    return {'usedPercent': pct, 'windowDurationMins': minutes, 'resetsAt': reset}


class QuotaTests(unittest.TestCase):
    def test_reset_metadata_validation(self):
        self.assertIsNone(codex.reset_credits(None))
        self.assertIsNone(codex.reset_credits({'availableCount': True}))
        data = codex.reset_credits({'availableCount': 3, 'credits': [
            {'status': 'used', 'expiresAt': 1, 'id': 'secret'},
            {'status': 'available', 'expiresAt': 2000000000, 'id': 'secret'},
            {'status': 'available', 'expiresAt': None}]})
        self.assertEqual(data['availableCount'], 3)
        self.assertEqual(len(data['credits']), 1)
        self.assertNotIn('secret', json.dumps(data))

    def test_weekly_only_and_zero(self):
        self.assertEqual(codex.windows({'rateLimits': {'primary': window(0)}}),
                         [{'pct': 0, 'minutes': 10080, 'reset': 2000000000}])

    def test_no_spark_fallback(self):
        self.assertEqual(codex.windows({'rateLimitsByLimitId': {'spark': {'primary': window()}},
                                       'rateLimits': {'primary': window()}}), [])
        self.assertEqual(codex.windows({'rateLimits': {'limitId': 'spark', 'primary': window()}}), [])

    def test_reject_invalid_fields(self):
        for w in [window(True), window(float('nan')), window(101), window(-1),
                  window(minutes=0), window(minutes='300'), window(reset=None)]:
            with self.subTest(window=w):
                self.assertEqual(codex.windows({'rateLimits': {'primary': w}}), [])

    def test_rpc_protocol_and_filtering(self):
        with tempfile.TemporaryDirectory() as tmp:
            executable = Path(tmp) / 'codex'
            executable.write_text('''#!/usr/bin/env python3
import json, sys
init=json.loads(sys.stdin.readline()); assert init['method']=='initialize'
print(json.dumps({'id':1,'result':{}}),flush=True)
assert json.loads(sys.stdin.readline())['method']=='initialized'
assert json.loads(sys.stdin.readline())['method']=='account/rateLimits/read'
print(json.dumps({'method':'notification'}),flush=True)
print(json.dumps({'id':2,'result':{'rateLimitsByLimitId':{'codex':{'secondary':{'usedPercent':45,'windowDurationMins':10080,'resetsAt':2000000000}},'spark':{'primary':{'usedPercent':99}}}}}),flush=True)
sys.stdin.read()
''')
            executable.chmod(0o700)
            self.assertEqual(codex.fetch(str(executable))['windows'][0]['pct'], 45)

    def test_rpc_timeout(self):
        with tempfile.TemporaryDirectory() as tmp:
            executable = Path(tmp) / 'codex'
            executable.write_text('#!/usr/bin/env python3\nimport time\ntime.sleep(5)\n')
            executable.chmod(0o700)
            with patch.object(codex, 'TIMEOUT', 0.05):
                with self.assertRaises(TimeoutError):
                    codex.fetch(str(executable))

    def test_switch_invalidates_and_retry_keeps_only_same_account(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, {'CODEX_HOME': tmp}):
            auth = Path(tmp) / 'auth.json'
            auth.write_text(json.dumps({'tokens': {'account_id': 'a'}}))
            key = codex.identity()
            auth.write_text(json.dumps({'tokens': {'account_id': 'b'}}))
            other = codex.identity()
            self.assertNotEqual(key, other)
            cache = Path(tmp) / 'cache'
            codex.atomic(cache, {'identity': key, 'windows': [{'pct': 90}], 'fetched_at': 5})
            with patch.object(codex, 'fetch', side_effect=TimeoutError):
                codex.refresh(cache, '/missing', other)
            doc = codex.read_json(cache)
            self.assertEqual(doc['windows'], [])
            self.assertEqual(doc['identity'], other)
            self.assertGreater(doc['next_attempt'], 0)
            self.assertEqual(cache.stat().st_mode & 0o777, 0o600)
            with patch.object(codex, 'fetch') as fetch:
                codex.refresh(cache, '/missing', other)
                fetch.assert_not_called()

    def test_refresh_persists_reset_metadata_and_keeps_it_on_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = Path(tmp) / 'cache'
            result = {'windows': [], 'resets': {'availableCount': 3, 'credits': [
                {'status': 'available', 'expiresAt': 2000000000}]}}
            with patch.object(codex, 'fetch', return_value=result), patch.object(codex, 'identity', return_value='a'):
                codex.refresh(cache, 'codex', 'a')
            doc = codex.read_json(cache)
            self.assertEqual(doc['resets'], result['resets'])
            fetched = doc['fetched_at']
            doc['next_attempt'] = 0
            codex.atomic(cache, doc)
            with patch.object(codex, 'fetch', side_effect=TimeoutError):
                codex.refresh(cache, 'codex', 'a')
            doc = codex.read_json(cache)
            self.assertEqual(doc['resets'], result['resets'])
            self.assertEqual(doc['fetched_at'], fetched)

    def test_account_switch_during_fetch_cannot_publish_old_values(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = Path(tmp) / 'cache'
            with patch.object(codex, 'fetch', return_value={'windows': [{'pct': 50}], 'resets': None}), patch.object(codex, 'identity', return_value='new'):
                codex.refresh(cache, 'codex', 'old')
            self.assertEqual(codex.read_json(cache)['windows'], [])


class RenderTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.folder = Path(self.tmp.name)
        self.env = dict(os.environ, CODEX_HOME=self.tmp.name,
                        CLAUDE_CONFIG_DIR=self.tmp.name, STATUSLINE_CODEX_BIN='/usr/bin/true',
                        STATUSLINE_API_PACE='0', STATUSLINE_SESSION_COST='0',
                        CLAUDE_SECURESTORAGE_CONFIG_DIR='', STATUSLINE_CODEX='1')
        (self.folder / 'auth.json').write_text(json.dumps({'tokens': {'account_id': 'test'}}))
        (self.folder / 'accounts.json').write_text(json.dumps({'accounts': [
            {'id': 'a', 'label': 'A'}, {'id': 'b', 'label': 'B', 'securestorage': '/other'}]}))
        self.env['CLAUDE_ACCOUNTS_FILE'] = str(self.folder / 'accounts.json')
        self.now = int(time.time())
        with patch.dict(os.environ, self.env):
            self.key = codex.identity()
        self.write_cache([{'pct': 46, 'minutes': 10080, 'reset': self.now + 86400}])

    def write_cache(self, data):
        codex.atomic(self.folder / '.statusline-codex', {'identity': self.key,
                     'next_attempt': self.now + 180, 'fetched_at': self.now, 'windows': data})

    def render(self, enabled=True, raw=False):
        env = dict(self.env, STATUSLINE_CODEX='1' if enabled else '0')
        result = subprocess.run(['bash', str(Path(__file__).parents[1] / 'scripts/statusline.sh')],
                                input=json.dumps({'workspace': {'current_dir': self.tmp.name},
                                      'model': {'display_name': 'Test'}}), env=env,
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, '')
        return result.stdout if raw else re.sub(r'\x1b\[[0-9;]*m', '', result.stdout)

    def test_reset_count_expiry_and_colors(self):
        cache = self.folder / '.statusline-codex'
        for seconds, color in [(4*86400, '\x1b[2m'), (3*86400, '\x1b[33m'),
                               (86400, '\x1b[31m'), (-1, '\x1b[31m')]:
            doc = codex.read_json(cache)
            doc['resets'] = {'availableCount': 3, 'credits': [
                {'status': 'available', 'expiresAt': self.now + seconds},
                {'status': 'available', 'expiresAt': self.now + 10*86400}]}
            codex.atomic(cache, doc)
            output = self.render(raw=True)
            self.assertIn(color + 'リセット3回', output)
            self.assertEqual(output.count('Codex'), 1)
            self.assertIn('期限経過（更新待ち）' if seconds < 0 else '最短あと', output)

    def test_reset_unknown_and_zero_are_distinct(self):
        cache = self.folder / '.statusline-codex'
        for count in (0, 3):
            doc = codex.read_json(cache)
            doc.update(windows=[], resets={'availableCount': count, 'credits': None})
            codex.atomic(cache, doc)
            out = self.render()
            self.assertIn('リセット{}回'.format(count), out)
            self.assertEqual('期限不明' in out, count > 0)
            self.assertIn('取得待ち', out)

    def test_weekly_only_appends_exactly_one_row_and_pending_claude(self):
        lines = self.render().splitlines()
        self.assertIn('取得待ち', lines[-2])
        self.assertTrue(lines[-1].startswith('  Codex  7d All'))
        self.assertIn('46%', lines[-1])
        self.assertIn('~', lines[-1])
        self.assertIn('0m前', lines[-1])
        self.assertNotIn('Codex', self.render(False))

    def test_both_windows_on_one_line(self):
        self.write_cache([{'pct': 0, 'minutes': 300, 'reset': self.now + 18000},
                          {'pct': 46, 'minutes': 10080, 'reset': self.now + 86400}])
        lines = [line for line in self.render().splitlines() if 'Codex' in line]
        self.assertEqual(len(lines), 1)
        self.assertIn('5h', lines[0])
        self.assertIn('7d', lines[0])
        self.assertIn('  0%', lines[0])

    def test_pending_never_fakes_zero_quota(self):
        self.write_cache([])
        line = self.render().splitlines()[-1]
        self.assertIn('Codex', line)
        self.assertIn('取得待ち', line)
        self.assertNotIn('%', line)

    def test_corrupt_retry_timestamp_recovers_instead_of_hiding_forever(self):
        for bad in ('bad', None, True, self.now + 999999):
            codex.atomic(self.folder / '.statusline-codex',
                         {'identity': self.key, 'next_attempt': bad, 'windows': []})
            with patch.dict(os.environ, self.env), patch.object(codex.subprocess, 'Popen') as spawn:
                with patch('builtins.print') as output:
                    codex.main()
                    spawn.assert_called_once()
                    output.assert_called_with('pending')
            with patch.dict(os.environ, self.env), patch.object(codex, 'fetch', return_value={'windows': [], 'resets': None}):
                codex.refresh(self.folder / '.statusline-codex', '/unused', self.key)
            self.assertIsInstance(codex.read_json(self.folder / '.statusline-codex')['next_attempt'], int)

    def test_stale_read_spawns_detached_without_fetching(self):
        codex.atomic(self.folder / '.statusline-codex', {'identity': self.key, 'next_attempt': 0})
        with patch.dict(os.environ, self.env), patch.object(codex.subprocess, 'Popen') as spawn:
            with patch.object(codex, 'fetch') as fetch, patch('builtins.print'):
                codex.main()
                fetch.assert_not_called()
                self.assertTrue(spawn.call_args.kwargs['start_new_session'])
                self.assertEqual(spawn.call_args.kwargs['stdout'], subprocess.DEVNULL)


class MoneyFormattingTests(unittest.TestCase):
    def test_grouping_does_not_depend_on_builtin_printf_locale(self):
        script = (Path(__file__).parents[1] / 'scripts/statusline.sh').read_text()
        function = script[script.index('fmt_money() {'):script.index('\n# API-equivalent monthly cost')]
        for locale in ('C', 'C.UTF-8', 'en_US.UTF-8'):
            for usd, rate, expected in [('12.34', '150', '¥1,851'), ('0', '150', '¥0'),
                                        ('12345.67', '100', '¥1,234,567'), ('1', '1', '¥1')]:
                with self.subTest(locale=locale, usd=usd):
                    result = subprocess.run(['/bin/bash', '-c', function + '\nfmt_money "$1" "$2" JPY',
                                             'test', usd, rate],
                                            env=dict(os.environ, LC_ALL=locale), text=True,
                                            capture_output=True)
                    self.assertEqual(result.returncode, 0)
                    self.assertEqual(result.stdout, expected)


if __name__ == '__main__':
    unittest.main()
