"""Adapter contract tests. Commands are synthetic strings, never executed."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[3]
HOOK = ROOT / 'plugins/dev-workflow/hooks/codex/pretool-guard.py'
FIXTURES = Path(__file__).parent / 'fixtures/codex-pretool'
PATH_VARS = ('DEV_WORKFLOW_CODEX_GIT_GUARD', 'DEV_WORKFLOW_CODEX_SECRET_GUARD',
             'DEV_WORKFLOW_CODEX_ASK_GUARD')


def payload(command='git status', tool='Bash'):
    return {'hook_event_name': 'PreToolUse', 'tool_name': tool,
            'tool_input': {'command': command}}


class GuardTests(unittest.TestCase):
    def invoke(self, data, env=None, cwd=None, raw=False):
        clean = {k: v for k, v in os.environ.items()
                 if not k.startswith(('DEV_WORKFLOW_', 'CAPABILITY_REGISTRY_'))}
        clean.update(env or {})
        result = subprocess.run([sys.executable, '-I', str(HOOK)],
                                input=data if raw else json.dumps(data), text=True,
                                capture_output=True, env=clean, cwd=cwd, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def silent(self, data, **kwargs):
        result = self.invoke(data, **kwargs)
        self.assertEqual(result.stdout, '', result.stdout)
        return result

    def deny(self, data, **kwargs):
        result = self.invoke(data, **kwargs)
        out = json.loads(result.stdout)
        self.assertEqual(set(out), {'hookSpecificOutput'})
        decision = out['hookSpecificOutput']
        self.assertEqual(set(decision), {'hookEventName', 'permissionDecision',
                                         'permissionDecisionReason'})
        self.assertEqual(decision['hookEventName'], 'PreToolUse')
        self.assertEqual(decision['permissionDecision'], 'deny')
        self.assertTrue(decision['permissionDecisionReason'].strip())
        self.assertNotIn('AskUserQuestion', result.stdout)
        return decision['permissionDecisionReason']

    def test_registration(self):
        hooks = json.loads(HOOK.with_name('hooks.json').read_text())['hooks']['PreToolUse']
        self.assertEqual(len(hooks), 1)
        self.assertIn(hooks[0].get('matcher', ''), ('', '*'))
        command = hooks[0]['hooks'][0]['command']
        self.assertIn('python3 -I', command)
        self.assertIn('pretool-guard.py', command)

    def test_registered_command_with_absolute_directory(self):
        command = json.loads(HOOK.with_name('hooks.json').read_text())['hooks']['PreToolUse'][0]['hooks'][0]['command']
        with tempfile.TemporaryDirectory(prefix='codex hook ') as directory:
            (Path(directory) / HOOK.name).symlink_to(HOOK)
            env = {k: v for k, v in os.environ.items()
                   if not k.startswith(('DEV_WORKFLOW_', 'CAPABILITY_REGISTRY_'))}
            env['DEV_WORKFLOW_CODEX_GUARD_DIR'] = directory
            result = subprocess.run(['sh', '-c', command], input=json.dumps(payload('git reset --hard')),
                                    text=True, capture_output=True, env=env, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)['hookSpecificOutput']['permissionDecision'], 'deny')

    def test_registered_command_with_unavailable_directory(self):
        command = json.loads(HOOK.with_name('hooks.json').read_text())['hooks']['PreToolUse'][0]['hooks'][0]['command']
        with tempfile.TemporaryDirectory() as directory:
            for guard_dir in (None, '', str(Path(directory) / 'missing'), directory):
                for data in (payload(tool='apply_patch'), payload('git reset --hard')):
                    with self.subTest(directory=guard_dir, tool=data['tool_name']):
                        env = {k: v for k, v in os.environ.items()
                               if not k.startswith(('DEV_WORKFLOW_', 'CAPABILITY_REGISTRY_'))}
                        if guard_dir is not None:
                            env['DEV_WORKFLOW_CODEX_GUARD_DIR'] = guard_dir
                        result = subprocess.run(['sh', '-c', command], input=json.dumps(data),
                                                text=True, capture_output=True, env=env, timeout=30)
                        self.assertEqual(result.returncode, 0, result.stderr)
                        self.assertEqual(result.stdout, '')
                        self.assertIn('未検査', result.stderr)

    def test_input_selection(self):
        for data in (None, [], 1, 'Bash', {}, payload(tool='Read'),
                     payload(tool='mcp__question'), payload(tool='request_permissions'),
                     dict(payload(), hook_event_name='PostToolUse'),
                     dict(payload(), tool_input=None), dict(payload(), tool_input=[]),
                     dict(payload(), tool_input={'command': 42}),
                     dict(payload(), tool_input={})):
            with self.subTest(data=data):
                self.silent(data)
        self.silent('{bad', raw=True)
        for name in ('bash', 'apply_patch', 'request_user_input'):
            self.silent(json.loads((FIXTURES / (name + '.json')).read_text()))
        self.silent(payload('git reset --hard; cat .env', tool='apply_patch'))

    def test_missing_dependencies(self):
        for var in PATH_VARS[:2]:
            with self.subTest(var=var):
                result = self.silent(payload(), env={var: '/nonexistent/guard.sh'})
                self.assertIn('未検査', result.stderr)
                result = self.silent(payload(), env={var: 'relative/guard.sh'})
                self.assertIn('未検査', result.stderr)
        result = self.silent(payload(tool='request_user_input'), env={
            PATH_VARS[2]: '/nonexistent/guard.sh', 'DEV_WORKFLOW_UNATTENDED': '1'})
        self.assertIn('未検査', result.stderr)

    def test_normalized_input_and_dependency_failures(self):
        with tempfile.TemporaryDirectory() as directory:
            script = Path(directory) / 'guard.sh'
            captured = Path(directory) / 'input.json'
            script.write_text('#!/bin/sh\ncat > "$CAPTURE"\n')
            env = {PATH_VARS[0]: str(script), 'CAPTURE': str(captured),
                   'CAPABILITY_REGISTRY_SECRET_GUARD': 'off'}
            data = dict(payload(), agent_id='fake', permission_mode='bypassPermissions',
                        cwd='/untrusted', session_id='untrusted')
            self.silent(data, env=env, cwd=directory)
            self.assertEqual(json.loads(captured.read_text()),
                             {'tool_name': 'Bash', 'tool_input': {'command': 'git status'}})
            for body in ('exit 3', 'echo invalid-json',
                         "echo '{\"hookSpecificOutput\":[]}'",
                         'echo "failure" >&2',
                         'echo \'{"hookSpecificOutput":{"permissionDecision":"ask"}}\''):
                script.write_text('#!/bin/sh\ncat >/dev/null\n' + body + '\n')
                result = self.silent(payload(), env=env)
                self.assertIn('未検査', result.stderr)

    def test_git_deny_and_safe_cases(self):
        denied = (
            'git checkout -- a.txt', 'git checkout .', 'git restore a.txt',
            'git restore --worktree --staged a.txt', 'git reset --hard',
            'git clean -fd', 'git push origin main', 'git push upstream master',
            'git push --force origin feature', 'git push --force-with-lease origin feature',
            'git push --force-with-lease=feature:abc origin feature',
            'git push origin +feature', 'git branch -D feature',
            'git branch -df feature', 'git commit --no-verify -m x',
            'git commit --no-gpg-sign -m x', 'git commit -anm x',
            'git -C repo reset --hard', 'env -u FOO git reset --hard',
            'command git reset --hard', 'FOO=1 git clean -xdf',
            'cd repo && git reset --hard', 'echo $(git reset --hard)',
            "bash -c 'git push -f origin feature'",
            'git push -n --no-dry-run origin main',
            'git clean -n --no-dry-run -f',
            'DEV_WORKFLOW_GIT_GUARD=off git reset --hard')
        safe = (
            'git status', 'git diff', 'git log', 'git commit -m x',
            'git push origin feature', 'git push -u other feature/x',
            'git restore --staged a.txt', 'git clean -nf',
            'git push --dry-run --force origin main',
            'git push --no-dry-run -n origin main',
            'git clean -f --no-dry-run -n', 'git checkout feature',
            'echo "git reset --hard"', 'git commit -m "--no-verify"',
            "cat <<'EOF'\ngit reset --hard\nEOF")
        for command in denied:
            with self.subTest(deny=command):
                self.deny(payload(command))
        for command in safe:
            with self.subTest(safe=command):
                self.silent(payload(command))

    def test_git_bypasses_and_no_execution(self):
        with tempfile.TemporaryDirectory() as directory:
            sentinel = Path(directory) / 'executed'
            # A permit-shaped file is deliberately present in an isolated store.
            store = Path(directory) / 'dev-workflow-git-guard' / 'permits'
            store.mkdir(parents=True)
            command = 'git reset --hard; touch ' + str(sentinel)
            key = hashlib.sha256('\0'.join(('fake-session', 'fake-child', directory, command)).encode()).hexdigest()
            permit = store / (key + '.json')
            permit.write_text(json.dumps({'session_id': 'fake-session', 'agent_id': 'fake-child',
                'cwd': directory, 'command': command, 'expires_at': time.time() + 900}))
            permit.chmod(0o600)
            store.chmod(0o700)
            store.parent.chmod(0o700)
            before = {str(p): p.read_bytes() for p in Path(directory).rglob('*') if p.is_file()}
            for mode in ('default', 'bypassPermissions', 'dontAsk', None):
                for attempt in range(3):
                    data = dict(payload('git reset --hard; touch ' + str(sentinel)),
                                agent_id='fake-child', session_id='fake-session',
                                permission_mode=mode, cwd=directory)
                    reason = self.deny(data, env={'TMPDIR': directory,
                        'DEV_WORKFLOW_GIT_GUARD_FORCE': 'ask',
                        'DEV_WORKFLOW_GIT_GUARD_NO_ASK': '0'})
                    self.assertIn('主が自分で実行', reason)
                    self.assertIn('本体', reason)
            self.assertFalse(sentinel.exists())
            self.assertEqual(before, {str(p): p.read_bytes() for p in Path(directory).rglob('*') if p.is_file()})
        self.silent(payload('git reset --hard'), env={'DEV_WORKFLOW_GIT_GUARD': 'off'})

    def test_dependency_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            script = Path(directory) / 'guard.sh'
            script.write_text('cat >/dev/null\n[ "$DEV_WORKFLOW_GIT_GUARD_NO_ASK" = 1 ] && [ -z "${DEV_WORKFLOW_GIT_GUARD_FORCE+x}" ] || exit 1\n')
            result = self.silent(payload(), env={PATH_VARS[0]: str(script),
                'DEV_WORKFLOW_GIT_GUARD_FORCE': 'ask', 'DEV_WORKFLOW_GIT_GUARD_NO_ASK': '0'})
            self.assertEqual(result.stderr, '')

    def test_secret_positive_and_negative_cases(self):
        denied = ('echo "$GH_TOKEN"', 'printf %s ${MY_API_KEY}', 'printenv', 'env',
                  'cat .env', 'cat ~/.npmrc', 'op read op://vault/item/field',
                  'op item get example --fields password',
                  'security find-generic-password -w -s example',
                  'CAPABILITY_REGISTRY_SECRET_GUARD=off cat .env')
        safe = ('echo "${GH_TOKEN:+SET}"', 'echo "${#GH_TOKEN}"', 'cat .env.example',
                'env FOO=1 ls', 'TOKEN="$(op read op://vault/item/field)" cmd')
        for command in denied:
            with self.subTest(deny=command):
                self.deny(payload(command))
        for command in safe:
            with self.subTest(safe=command):
                self.silent(payload(command))

    def test_independent_off_and_combined_deny(self):
        git_off = {'DEV_WORKFLOW_GIT_GUARD': 'off'}
        secret_off = {'CAPABILITY_REGISTRY_SECRET_GUARD': 'off'}
        self.deny(payload('cat .env'), env=git_off)
        self.deny(payload('git reset --hard'), env=secret_off)
        self.silent(payload('cat .env'), env=secret_off)
        for env in ({}, git_off, secret_off):
            self.deny(payload('git reset --hard; cat .env'), env=env)
        self.silent(payload('git reset --hard; cat .env'), env=dict(git_off, **secret_off))
        for var in PATH_VARS[:2]:
            result = self.invoke(payload('git reset --hard; cat .env'),
                                 env={var: '/missing/guard.sh'})
            self.assertEqual(json.loads(result.stdout)['hookSpecificOutput']['permissionDecision'], 'deny')
            self.assertIn('未検査', result.stderr)

    def test_measured_question_and_unattended_marks(self):
        data = json.loads((FIXTURES / 'request_user_input.json').read_text())
        for mark in (None, '', ' \t\n', ' 0 ', '1', ' true ', 'yes', 'false'):
            env = {'DEV_WORKFLOW_GIT_GUARD': 'off',
                   'DEV_WORKFLOW_GIT_GUARD_FORCE': 'ask',
                   'DEV_WORKFLOW_GIT_GUARD_NO_ASK': '0',
                   'CAPABILITY_REGISTRY_SECRET_GUARD': 'off'}
            if mark is not None:
                env['DEV_WORKFLOW_UNATTENDED'] = mark
            with self.subTest(mark=mark):
                if mark is None or mark.strip() in ('', '0'):
                    self.silent(data, env=env)
                else:
                    reason = self.deny(data, env=env)
                    for text in ('打ち直さず', '連絡先', 'needs-approval', '本体への return'):
                        self.assertIn(text, reason)
        # These names/paths are unconfirmed, not measured successes.
        for tool in ('request_user_input_async', 'functions.request_user_input',
                     'functions.request_user_input_async', 'ask_user',
                     'mcp__ask_question', 'request_permissions', 'exec'):
            self.silent(dict(data, tool_name=tool), env={'DEV_WORKFLOW_UNATTENDED': '1'})
        self.silent(dict(data, hook_event_name='PostToolUse'),
                    env={'DEV_WORKFLOW_UNATTENDED': '1'})

    def test_fixture_provenance(self):
        meta = json.loads((FIXTURES / 'metadata.json').read_text())
        self.assertEqual(meta['version'], 'codex-cli 0.163.0')
        self.assertIn('7235173851', meta['source'])
        self.assertEqual(set(meta['provenance']), {'bash', 'apply_patch', 'request_user_input'})
        self.assertIn('request_user_input_async', meta['unconfirmed'])


if __name__ == '__main__':
    unittest.main()
