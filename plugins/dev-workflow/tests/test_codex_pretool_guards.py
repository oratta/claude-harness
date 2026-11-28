"""Adapter contract tests. Commands are synthetic strings, never executed."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
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
                         'echo "failure" >&2',
                         'echo \'{"hookSpecificOutput":{"permissionDecision":"ask"}}\''):
                script.write_text('#!/bin/sh\ncat >/dev/null\n' + body + '\n')
                result = self.silent(payload(), env=env)
                self.assertIn('未検査', result.stderr)


if __name__ == '__main__':
    unittest.main()
