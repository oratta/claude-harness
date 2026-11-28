"""Black-box contracts. Never launches an installed Claude executable."""
import importlib.util
import json
import os
from pathlib import Path
import signal
import sys
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch

PLUGIN = Path(__file__).resolve().parents[1]
LAUNCH = PLUGIN / 'scripts/claude-role-launch.py'
sys.path.insert(0, str(PLUGIN / 'scripts'))
sys.dont_write_bytecode = True


class LaunchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.repo = self.root / 'repo'
        self.repo.mkdir()
        subprocess.run(['git', 'init', '-q', str(self.repo)], check=True)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.fake = self.bin / 'claude'
        self.fake.write_text('''#!/usr/bin/env python3
import json,os,sys,time,subprocess
from pathlib import Path
if sys.argv[1:] == ['--version']:
 print('fixture-v1'); sys.exit(0)
a=sys.argv[1:]
with open(os.environ['CALLS'],'a') as f: f.write(json.dumps({'argv':a,'role':os.environ.get('DEVELOP_ROLE')})+'\\n')
sid=a[a.index('--session-id')+1] if '--session-id' in a else a[a.index('--resume')+1]
p=Path(os.environ['CLAUDE_CONFIG_DIR'])/'projects'/(''.join(c if c.isalnum() else '-' for c in os.getcwd()))/(sid+'.jsonl')
p.parent.mkdir(parents=True,exist_ok=True)
p.write_text(json.dumps({'sessionId':sid,'cwd':os.getcwd(),'type':'assistant','message':{'model':'claude-sonnet-4-6','usage':{'input_tokens':1,'output_tokens':1}}})+'\\n')
mode=os.environ.get('FAKE_MODE','ok')
if mode.startswith('probe'):
 p.write_text(json.dumps({'sessionId':sid,'type':'assistant','message':{
  'model':'claude-opus-4-6' if mode=='probe-model' else 'claude-sonnet-4-6',
  'content':[{'type':'tool_use','name':'Agent' if mode=='probe-agent' else 'Read'}]}})+'\\n')
if mode=='reject': print('unknown option --max-turns',file=sys.stderr); sys.exit(2)
if mode=='child' or os.environ.get('WITH_CHILD'):
 child=subprocess.Popen(['sleep','100'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 Path(os.environ['CHILD_PID']).write_text(str(child.pid))
if mode=='hang': time.sleep(100)
if mode=='killed': os.kill(os.getpid(),9)
ret={'type':'result','subtype':'success','session_id':sid,'is_error':False,'result':os.environ.get('RETURN','工程完了: 実装＋verify\\nfixture')}
if mode in ('limit','probe','probe-model','probe-agent'): ret.update(subtype='error_max_turns',is_error=True)
print(json.dumps(ret))
sys.exit(int(os.environ.get('FAKE_EXIT','0')))
''')
        self.fake.chmod(0o755)
        self.prompt = self.root / 'prompt'
        self.prompt.write_text('段: implement\nfixture')
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                        CLAUDE_CONFIG_DIR=str(self.root / 'config'), CALLS=str(self.root / 'calls'),
                        CHILD_PID=str(self.root / 'child'))
        self.args = ['python3', str(LAUNCH), '--担当', 'W', '--role', 'implement',
                     '--model', 'sonnet', '--cwd', str(self.repo), '--instructions', str(self.prompt),
                     '--max-turns', '3', '--record', '1857', '--session-records', str(self.root / 'sessions'),
                     '--plugin-dir', str(PLUGIN), '--verification', str(self.root / 'verified'),
                     '--timeout', '2']
        # Test the production identity matcher; the stub has no capability to attest real CLI behavior.
        spec = importlib.util.spec_from_file_location('launch', LAUNCH)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.module = module
        identity = module.identity(str(self.fake), PLUGIN)
        (self.root / 'verified').write_text(json.dumps({'identity': identity, 'approved': True,
            'role': 'implement', 'assignment': 'W', 'model': 'sonnet', 'mode': 'agent'}))

    def invoke(self, extra=(), **env):
        p = subprocess.run(self.args + list(extra), env=dict(self.env, **env), capture_output=True, text=True)
        self.assertTrue(p.stdout, p.stderr)
        return p.returncode, json.loads(p.stdout)

    def calls(self):
        path = self.root / 'calls'
        return [json.loads(s) for s in path.read_text().splitlines()] if path.exists() else []

    def test_exact_argv_and_registration(self):
        code, d = self.invoke()
        self.assertEqual(code, 0, d)
        self.assertTrue(d['cleanup']['ok'])
        self.assertEqual(d['requested_model'], 'sonnet')
        self.assertEqual(d['applied_models'], ['claude-sonnet-4-6'])
        self.assertEqual(d['phase_declaration'], '工程完了: 実装＋verify')
        sid = d['session_id']
        self.assertEqual(self.calls()[0], {'role':'implement','argv':[
            '-p','--model','sonnet','--max-turns','3','--output-format','json',
            '--plugin-dir',str(PLUGIN),'--agent','dev-workflow:worker',
            '--disallowedTools','Agent','--session-id',sid]})
        rec = json.loads((self.root/'sessions').read_text())
        self.assertEqual(rec['session_id'], sid)
        self.assertEqual(rec['records'], [1857])
        self.assertTrue(Path(rec['log_path']).is_file())
        self.assertEqual(rec['repo_common_dir'], str(self.repo / '.git'))

    def test_reject_before_cli(self):
        for extra in (['--model','unknown'], ['--model','fable'], ['--role','review'],
                      ['--max-turns','0'], ['--extra','--model=opus']):
            with self.subTest(extra=extra):
                p = subprocess.run(self.args+extra, env=self.env, capture_output=True)
                self.assertEqual(p.returncode, 1)
                self.assertEqual(self.calls(), [])

    def test_missing_or_stale_verification(self):
        (self.root/'verified').write_text('{}')
        code, d = self.invoke()
        self.assertEqual(code, 1)
        self.assertEqual(self.calls(), [])
        self.assertIn('verification', d['termination_reason'])

    def test_turn_limit_and_return_interruption(self):
        for env in ({'FAKE_MODE':'limit'}, {'FAKE_MODE':'limit','FAKE_EXIT':'1'},
                    {'RETURN':'工程中断: fixture'}, {'RETURN':'no declaration'},
                    {'FAKE_EXIT':'1'}, {'FAKE_MODE':'killed'}, {'FAKE_MODE':'hang'}):
            with self.subTest(env=env):
                code, d = self.invoke(**env)
                self.assertEqual(code, 2, d)
                self.assertTrue(d['phase_declaration'].startswith('工程中断:'))
                self.assertTrue(d['cleanup']['ok'], d)

    def test_resume_same_session_and_context_refusal(self):
        code, d = self.invoke()
        extra = ['--resume',d['session_id'],'--transcript',d['transcript_path']]
        code, resumed = self.invoke(extra)
        self.assertEqual(code, 0, resumed)
        self.assertIn('--resume', self.calls()[-1]['argv'])
        before = len(self.calls())
        Path(d['transcript_path']).write_text('')
        code, refused = self.invoke(extra)
        self.assertEqual(code, 2, refused)
        self.assertEqual(len(self.calls()), before)
        self.assertEqual(refused['termination_reason'], 'context_unavailable')

    def test_background_children_across_exit_paths(self):
        control = subprocess.Popen(['sleep','100'])
        def stop_control():
            control.kill()
            control.wait()
        self.addCleanup(stop_control)
        for mode in ('child','limit','killed','hang'):
            with self.subTest(mode=mode):
                code, d = self.invoke(FAKE_MODE=mode, WITH_CHILD='1')
                self.assertEqual(code, 0 if mode=='child' else 2, d)
                self.assertTrue(d['cleanup']['ok'], d)
                self.assertIsNone(control.poll())
                self.assert_dead_child()

    def assert_dead_child(self):
        pid = int((self.root/'child').read_text())
        p = subprocess.run(['ps','-o','stat=','-p',str(pid)], capture_output=True, text=True)
        self.assertTrue(p.returncode != 0 or p.stdout.strip().startswith('Z'), p.stdout)

    def test_signal_cleanup(self):
        for sig in (signal.SIGINT, signal.SIGTERM):
            with self.subTest(sig=sig):
                before = len(self.calls())
                p = subprocess.Popen(self.args, env=dict(self.env, FAKE_MODE='hang', WITH_CHILD='1'),
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                deadline = time.monotonic()+5
                while len(self.calls()) == before and time.monotonic()<deadline:
                    time.sleep(.02)
                p.send_signal(sig)
                out, err = p.communicate(timeout=8)
                self.assertEqual(p.returncode, 2, err)
                self.assertTrue(json.loads(out)['cleanup']['ok'])
                self.assert_dead_child()

    def attest(self, assignment, role, model='sonnet', mode='agent'):
        proof = dict(identity=self.module.identity(str(self.fake), PLUGIN), approved=True,
                     assignment=assignment, role=role, model=model, mode=mode)
        (self.root/'verified').write_text(json.dumps(proof))

    def test_models_roles_and_explicit_tools(self):
        for assignment, role, model, mode in (
                ('W','implement','opus','agent'), ('G','implement','sonnet','agent'),
                ('reviewer','review','sonnet','explicit'), ('R1','spec-review','sonnet','explicit'),
                ('decider','decider','fable','explicit')):
            with self.subTest(assignment=assignment):
                self.attest(assignment, role, model, mode)
                code, d = self.invoke(['--assignment',assignment,'--role',role,'--model',model,'--mode',mode])
                self.assertEqual(code, 0, d)
                argv = self.calls()[-1]['argv']
                self.assertEqual(argv[argv.index('--model')+1], model)
                self.assertEqual(argv[argv.index('--disallowedTools')+1], 'Agent')
                if mode == 'explicit':
                    self.assertNotIn('--agent', argv)
                    if assignment == 'decider':
                        self.assertEqual(argv[argv.index('--tools')+1], 'Read,Grep,Glob')
                if assignment not in ('W','G'):
                    self.assertIsNone(d['phase_declaration'])

    def test_verify_requires_limit_and_matching_model_and_tools(self):
        for mode, approved in (('ok',False), ('reject',False), ('hang',False),
                               ('probe-model',False), ('probe-agent',False), ('probe',True)):
            with self.subTest(mode=mode):
                code, d = self.invoke(['--verify'], FAKE_MODE=mode)
                self.assertEqual(code, 0 if approved else 2, d)
                self.assertEqual(d['verification_approved'], approved)
                self.assertEqual(json.loads((self.root/'verified').read_text())['approved'], approved)
                self.assertTrue(d['cleanup']['ok'])

    def test_resume_cap_and_wrong_session(self):
        code, d = self.invoke()
        transcript = Path(d['transcript_path'])
        transcript.write_text(json.dumps({'type':'assistant','message':{'model':'claude-sonnet-4-6',
            'usage':{'input_tokens':999999,'output_tokens':1}}})+'\n')
        before = len(self.calls())
        code, refused = self.invoke(['--resume',d['session_id'],'--transcript',str(transcript)])
        self.assertEqual(code, 2, refused)
        self.assertEqual(refused['context']['exit_code'], 2)
        self.assertEqual(len(self.calls()), before)
        code, refused = self.invoke(['--resume',d['session_id'],'--transcript',str(self.root/'other')])
        self.assertEqual(code, 1, refused)
        self.assertEqual(len(self.calls()), before)

    def test_table_missing_and_cleanup_failure(self):
        with patch.object(sys, 'argv', self.args[1:]), patch.dict(os.environ, self.env), \
                patch.object(self.module, 'read_table', return_value=None):
            with self.assertRaises(self.module.Refusal):
                self.module.run()
        self.assertEqual(self.calls(), [])
        with patch.object(sys, 'argv', self.args[1:]), patch.dict(os.environ, self.env), \
                patch.object(self.module, 'cleanup', return_value={'ok':False,'reason':'fixture'}):
            code, d = self.module.run()
        self.assertEqual(code, 2)
        self.assertEqual(d['termination_reason'], 'cleanup_failed')

    def test_parent_env_and_external_paths(self):
        original = os.environ.get('DEVELOP_ROLE')
        code, d = self.invoke(DEVELOP_ROLE='parent')
        self.assertEqual(code, 0, d)
        self.assertEqual(os.environ.get('DEVELOP_ROLE'), original)
        self.assertEqual(self.calls()[-1]['role'], 'implement')
        before = len(self.calls())
        code, d = self.invoke(['--session-records',str(self.repo/'forbidden')])
        self.assertEqual(code, 1, d)
        self.assertEqual(len(self.calls()), before)

    def test_live_check_opt_in_and_fixture_only_execution(self):
        script = PLUGIN/'scripts/claude-role-live-check.py'
        p = subprocess.run([sys.executable,str(script)],env=self.env,capture_output=True,text=True)
        self.assertEqual(p.returncode, 2)
        self.assertEqual(self.calls(), [])
        p = subprocess.run([sys.executable,str(script),'--execute','--case','capability'],
                           env=dict(self.env,FAKE_MODE='probe',TMPDIR=str(self.root)),capture_output=True,text=True)
        self.assertEqual(p.returncode, 0, p.stderr+p.stdout)
        summary=json.loads(p.stdout)
        self.assertTrue(summary['unchanged'])
        self.assertEqual(summary['plugin_dir'], str(PLUGIN))
        p = subprocess.run([sys.executable,str(script),'--execute','--case','normal',
                            '--verification',summary['verification']],env=dict(self.env,TMPDIR=str(self.root)),
                           capture_output=True,text=True)
        self.assertEqual(p.returncode, 0, p.stderr+p.stdout)
        self.assertTrue(json.loads(p.stdout)['unchanged'])


if __name__ == '__main__':
    unittest.main()
