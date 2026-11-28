"""Exercise deployed commands with synthetic payloads; never launch Codex."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT/'plugins/dev-workflow/scripts/codex-hook-runtime.py'


def load(path):
    spec = importlib.util.spec_from_file_location('hook_runtime', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class RuntimeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='hook runtime ')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.target = self.root/'runtime'
        self.target.mkdir()
        self.module = load(SCRIPT)

    def test_preserves_minimal_auth_config_and_pins_parent_paths(self):
        auth = self.root/'auth.json'; auth.write_text('{}')
        (self.target/'auth.json').symlink_to(auth)
        (self.target/'config.toml').write_text(self.module.MINIMAL_CONFIG)
        before = (self.target/'config.toml').read_bytes()
        for inherited in ({}, {k: '/wrong/source' for k in self.module.guard_environment()}):
            target = self.root/('copy'+str(len(list(self.root.iterdir())))); target.mkdir()
            clean = {k:v for k,v in os.environ.items() if k not in self.module.guard_environment()}
            with patch.dict(os.environ, dict(clean, **inherited), clear=True):
                result = self.module.prepare(target)
            self.assertEqual(result, self.module.guard_environment())
            self.assertTrue(all(Path(v).is_absolute() for v in result.values()))
        self.module.prepare(self.target)
        self.assertTrue((self.target/'auth.json').is_symlink())
        self.assertEqual((self.target/'config.toml').read_bytes(), before)
        self.assertEqual(auth.read_text(), '{}')

    def test_refuses_existing_settings_and_nonabsolute_target_without_mutation(self):
        for name, content in [('hooks.json', '{}'), ('requirements.toml', ''),
                              ('config.toml', '[mcp_servers.external]\n'), ('other', '')]:
            with self.subTest(name=name):
                path = self.target/name; path.write_text(content)
                with self.assertRaisesRegex(ValueError, 'hook_runtime_target'):
                    self.module.prepare(self.target)
                self.assertEqual(list(self.target.iterdir()), [path])
                path.unlink()
        with self.assertRaises(ValueError):
            self.module.prepare(Path('relative'))
        linked = self.root/'linked'; linked.symlink_to(self.target)
        with self.assertRaises(ValueError):
            self.module.prepare(linked)

    def test_missing_dependencies_or_executables_fail_before_writing(self):
        with patch.object(self.module, 'guard_environment', return_value=dict(
                self.module.guard_environment(), DEV_WORKFLOW_CODEX_GUARD_DIR=str(self.root/'missing'))):
            with self.assertRaisesRegex(ValueError, 'hook_runtime_dependency'):
                self.module.prepare(self.target)
        which = shutil.which
        for missing in ('bash', 'python3'):
            with patch.object(self.module.shutil, 'which',
                              side_effect=lambda name: None if name == missing else which(name)):
                with self.assertRaisesRegex(ValueError, 'hook_runtime_executable_missing_'+missing):
                    self.module.prepare(self.target)
        self.assertEqual(list(self.target.iterdir()), [])

    def test_relocated_source_missing_each_dependency_and_definition(self):
        moved = self.root/'moved'
        paths = ['plugins/dev-workflow/scripts/codex-hook-runtime.py',
                 'plugins/dev-workflow/hooks/codex/hooks.json',
                 'plugins/dev-workflow/hooks/codex/pretool-guard.py',
                 'plugins/dev-workflow/scripts/git-destructive-guard.sh',
                 'plugins/dev-workflow/scripts/git-guard-scratchpad.py',
                 'plugins/dev-workflow/scripts/unattended-ask-guard.sh',
                 'plugins/capability-registry/scripts/secret-guard.sh',
                 'plugins/capability-registry/scripts/secret-guard.py']
        for rel in paths:
            dst = moved/rel; dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT/rel, dst)
        module = load(moved/paths[0])
        for rel in paths[1:]:
            path = moved/rel; data = path.read_bytes(); path.unlink()
            with self.subTest(path=rel), self.assertRaises(ValueError):
                module.prepare(self.target)
            path.write_bytes(data)
        env = module.prepare(self.target)
        self.assertTrue(all(str(moved) in p for p in env.values()))
        self.assert_payloads(env)

    def assert_payloads(self, env):
        hook = json.loads((self.target/'hooks.json').read_text())['hooks']['PreToolUse'][0]['hooks'][0]
        cases = [('Bash', 'git reset --hard HEAD', {}, True),
                 ('Bash', 'cat .env', {}, True),
                 ('request_user_input', '', {'DEV_WORKFLOW_UNATTENDED': '1'}, True),
                 ('Bash', 'git status --porcelain', {}, False),
                 ('Bash', 'git push origin feature', {}, False),
                 ('Bash', 'cat .env', {'CAPABILITY_REGISTRY_SECRET_GUARD': 'off'}, False),
                 ('Bash', 'git reset --hard HEAD', {'DEV_WORKFLOW_GIT_GUARD': 'off'}, False),
                 ('request_user_input', '', {'DEV_WORKFLOW_UNATTENDED': '0'}, False)]
        clean = {k:v for k,v in os.environ.items()
                 if not k.startswith(('DEV_WORKFLOW_', 'CAPABILITY_REGISTRY_'))}
        for tool, command, extra, denied in cases:
            payload = {'hook_event_name':'PreToolUse', 'tool_name':tool,
                       'tool_input':{'command':command}}
            with self.subTest(tool=tool, command=command, extra=extra):
                result = subprocess.run(hook['command'], shell=True, cwd=self.root,
                    env=dict(clean, **env, **extra), input=json.dumps(payload),
                    capture_output=True, text=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stderr, '')
                if denied:
                    self.assertEqual(json.loads(result.stdout)['hookSpecificOutput']['permissionDecision'], 'deny')
                else:
                    self.assertEqual(result.stdout, '')

    def test_deployed_command_denies_and_allows_without_executing_payloads(self):
        self.assert_payloads(self.module.prepare(self.target))


if __name__ == '__main__':
    unittest.main()
