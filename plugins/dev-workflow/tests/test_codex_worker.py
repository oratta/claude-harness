import base64
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import shlex
import sys
import tempfile
import time
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/codex-worker.py'
DEVELOP = SCRIPT.parent / 'codex-develop.py'
spec = importlib.util.spec_from_file_location('codex_worker', SCRIPT)
worker_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker_module)
FAKE = r'''#!/usr/bin/env python3
import json,os,sys,time,subprocess
from pathlib import Path
runtime=Path(os.environ['CODEX_HOME']); job=runtime.name; home=(runtime/'auth.json').resolve().parent
special=home/('fixture-'+job+'.json'); config=json.loads((special if special.exists() else home/'fixture.json').read_text())
tmp=os.environ.get('TMPDIR')
# Names are written out here rather than imported from the worker, so the test observes
# the actual variables instead of whatever the implementation happens to list.
watched=['CODEX_HOME','TMPDIR','TMPPREFIX','OPENAI_API_KEY','CODEX_API_KEY','OPENAI_BASE_URL',
 'CODEX_AUTH_JSON','OPENAI_ORGANIZATION','OPENAI_PROJECT','GIT_DIR','GIT_WORK_TREE',
 'GIT_COMMON_DIR','GIT_INDEX_FILE','GH_TOKEN','GITHUB_TOKEN','HARNESS_FIXTURE_MARK']
info={'path':tmp,'prefix':os.environ.get('TMPPREFIX'),
 'env':{k:os.environ.get(k) for k in watched},
 'child':subprocess.check_output([sys.executable,'-c','import os;print(os.environ.get("TMPDIR", ""))'],text=True).strip()}
for line in sys.stdin:
 m=json.loads(line); method=m.get('method'); rid=m.get('id')
 m['fixtureTmp']=info
 for name in ('calls.jsonl','calls-'+job+'.jsonl'):
  with (home/name).open('a') as f:f.write(json.dumps(m)+'\n')
 if rid is None:continue
 if method=='account/rateLimits/read' and config.get('hold_rate_limits_until'):
  while not Path(config['hold_rate_limits_until']).exists():time.sleep(.02)
 if method==config.get('disconnect_before'):sys.exit(0)
 if method==config.get('reject'):
  print(json.dumps({'id':rid,'error':{'code':config.get('reject_code',-32000),'message':'rejected'}}),flush=True);continue
 if method=='account/read':r={'account':{'type':'chatgpt','email':config.get('email','worker@example.invalid')}}
 elif method=='account/rateLimits/read':r={'rateLimitsByLimitId':{'codex':{'primary':{'usedPercent':config.get('pct',1),'windowDurationMins':300,'resetsAt':int(time.time())+1000}}}}
 elif method=='model/list':
  pages=config.get('model_pages',[[{'id':'fixture-id','model':'fixture-model','hidden':False,'supportedReasoningEfforts':[{'reasoningEffort':'low','description':'Low'},{'reasoningEffort':'high','description':'High'}]}]])
  page=int(m.get('params',{}).get('cursor','0'));r={'data':pages[page]}
  if page+1<len(pages):r['nextCursor']=str(page+1)
 elif method=='thread/start':r={'thread':{'id':'thread',**config.get('thread_observed',{})}}
 elif method=='turn/start':r={'turn':{'id':'turn',**config.get('turn_observed',{})}}
 elif method=='thread/read':r={'thread':{'turns':[{'id':'turn','items':config.get('items',[{'type':'agentMessage','phase':'final_answer','text':'DONE'}])}]}}
 else:r={}
 print(json.dumps({'id':rid,'result':r}),flush=True)
 if method==config.get('deafen_after'):
  while True:time.sleep(60)
 if method=='turn/start':
  if config.get('disconnect'):sys.exit(0)
  if not config.get('quiet'):print(json.dumps({'method':'item/started','params':{'threadId':'thread','turnId':'turn'}}),flush=True)
  if config.get('usage'):print(json.dumps({'method':'thread/tokenUsage/updated','params':{'threadId':'thread','turnId':'turn','tokenUsage':config['usage']}}),flush=True)
  if config.get('wait'):continue
  print(json.dumps({'method':'turn/completed','params':{'threadId':'thread','turn':{'id':'turn','status':config.get('status','completed'),'items':[]}}}),flush=True)
 if method=='turn/interrupt':
  print(json.dumps({'method':'turn/completed','params':{'threadId':'thread','turn':{'id':'turn','status':'interrupted','items':[]}}}),flush=True)
'''

class ForegroundTest(unittest.TestCase):
    # The foreground path keeps no ledger, so this fixture registers nothing: any
    # ledger.sqlite or ownership.sqlite appearing under the root is a defect.
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.home = self.profile('profile', 'worker@example.invalid')
        self.other = self.profile('other', 'other@example.invalid')
        binary = self.root/'bin';binary.mkdir()
        (binary/'codex').write_text(FAKE);(binary/'codex').chmod(0o700)
        self.env = dict(os.environ, HOME=str(self.root), PATH=str(binary)+os.pathsep+os.environ['PATH'])
        self.repo = self.root/'repo';self.repo.mkdir()
        self.git(self.repo,'init','-q','-b','main')
        self.git(self.repo,'-c','user.name=Fixture','-c','user.email=f@invalid','commit','--allow-empty','-qm','initial')
        self.cwd = self.root/'work-feature'
        self.git(self.repo,'worktree','add','-qb','feature',str(self.cwd))

    def profile(self, name, email):
        home = self.root/name;home.mkdir()
        claim = base64.urlsafe_b64encode(json.dumps({'email':email}).encode()).decode().rstrip('=')
        (home/'auth.json').write_text(json.dumps({'tokens':{'id_token':'a.'+claim+'.b','account_id':'fixture-'+name}}))
        (home/'fixture.json').write_text('{}')
        return home

    def git(self, cwd, *args):
        return subprocess.run(['git','-C',str(cwd),*args],check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)

    def tearDown(self):
        self.tmp.cleanup()

    def config(self, job='one', home=None, **kwargs):
        (home or self.home).joinpath('fixture-'+job+'.json').write_text(json.dumps(kwargs))

    def calls(self, job='one', home=None):
        p = (home or self.home)/('calls-'+job+'.jsonl')
        return [json.loads(s) for s in p.read_text().splitlines()] if p.exists() else []

    def request(self, job='one', **fields):
        data = {'request_id':job,'origin':'manual','account':'test','cwd':str(self.cwd),
                'model':'fixture-model','role':'implement','prompt':'fixture',
                'codex_home':str(self.home)}
        data.update(fields)
        path = self.root/(job+'.json');path.write_text(json.dumps(data))
        return path

    def command(self, job='one', **fields):
        return [sys.executable,str(SCRIPT),'run','--request',str(self.request(job,**fields))]

    def run_cli(self, job='one', code=0, timeout=40, **fields):
        p = subprocess.run(self.command(job,**fields),env=self.env,text=True,capture_output=True,timeout=timeout)
        lines = [s for s in p.stdout.splitlines() if s.strip()]
        self.assertEqual(len(lines),1,p.stdout+p.stderr)
        self.assertEqual(p.returncode,code,p.stdout+p.stderr)
        return json.loads(lines[0])

    def ledgers(self):
        return sorted(str(p.relative_to(self.root)) for name in ('ledger.sqlite','ownership.sqlite')
                      for p in self.root.rglob(name))

    def await_turn(self, job='one', home=None, deadline=20):
        stop = time.monotonic()+deadline
        while time.monotonic() < stop:
            if any(m.get('method')=='turn/start' for m in self.calls(job,home)):
                return
            time.sleep(.05)
        self.fail('turn never started')

    def children(self, pid):
        out = subprocess.run(['pgrep','-P',str(pid)],text=True,capture_output=True)
        return [int(s) for s in out.stdout.split()]

    def alive(self, pid):
        try:
            os.kill(pid, 0)
        except OSError:
            return False
        return True

    def test_removed_lifecycle_surface_is_rejected_and_not_imported(self):
        source = SCRIPT.read_text()
        for value in ('sqlite3', 'start_new_session', 'account_slots', 'cwd_locked', 'heartbeat'):
            self.assertNotIn(value, source)
        for command in ('register', 'submit', 'status', 'result', 'cancel', 'ack', 'send', 'reap'):
            with self.subTest(command=command):
                p = subprocess.run([sys.executable, str(SCRIPT), command],
                                   env=self.env, text=True, capture_output=True, timeout=20)
                self.assertEqual(p.returncode, 2, p.stdout + p.stderr)
                self.assertEqual(p.stdout, '')
                self.assertIn('usage:', p.stderr)
        self.assertEqual(self.ledgers(), [])

    def test_model_and_effort_are_validated_before_thread_start(self):
        self.config(model_pages=[
            [{'id':'fixture-model','model':'other-model','supportedReasoningEfforts':[]}],
            [{'id':'different-id','model':'fixture-model','hidden':True,
              'supportedReasoningEfforts':[{'reasoningEffort':'future','description':'New'}]}]])
        result = self.run_cli(effort='future')
        self.assertEqual(result['status'], 'completed')
        calls = self.calls()
        self.assertEqual([m['params'] for m in calls if m.get('method') == 'model/list'],
                         [{'includeHidden':True},{'includeHidden':True,'cursor':'1'}])
        thread = next(m['params'] for m in calls if m.get('method') == 'thread/start')
        turn = next(m['params'] for m in calls if m.get('method') == 'turn/start')
        self.assertNotIn('effort', thread)
        self.assertEqual(turn['effort'], 'future')

        self.config('unsupported', model_pages=[[{
            'id':'fixture-id','model':'fixture-model',
            'supportedReasoningEfforts':[{'reasoningEffort':'low','description':'Low'}]}]])
        rejected = self.run_cli('unsupported', code=2, effort='ultra')
        self.assertEqual(rejected['error_kind'], 'unsupported_model_effort')
        self.assertFalse(any(m.get('method') in ('thread/start','turn/start')
                             for m in self.calls('unsupported')))

    def test_role_policy_quota_auth_and_runtime_cleanup_remain_foreground(self):
        for role in worker_module.ROLES:
            job = 'role-' + role
            result = self.run_cli(job, role=role)
            self.assertEqual(result['status'], 'completed')
            calls = self.calls(job)
            thread = next(m['params'] for m in calls if m.get('method') == 'thread/start')
            turn = next(m['params'] for m in calls if m.get('method') == 'turn/start')
            expected = 'danger-full-access' if role in ('implement', 'spec-write') else 'read-only'
            self.assertEqual(thread['sandbox'], expected)
            if expected == 'read-only':
                self.assertNotIn('writableRoots', turn['sandboxPolicy'])

        self.config('quota', pct=100)
        quota = self.run_cli('quota', code=2)
        self.assertEqual(quota['error_kind'], 'quota_exhausted')
        self.assertFalse(any(m.get('method') == 'turn/start' for m in self.calls('quota')))

        self.config('mismatch', email='other@example.invalid')
        mismatch = self.run_cli('mismatch', code=2)
        self.assertEqual(mismatch['error_kind'], 'server_identity_mismatch')
        self.assertFalse(any(m.get('method') == 'turn/start' for m in self.calls('mismatch')))
        self.assertEqual(self.ledgers(), [])

    def test_foreground_run_completes_without_a_ledger(self):
        self.config(usage={'inputTokens':12,'outputTokens':3},
                    thread_observed={'model':'thread-model','effort':'high'},
                    turn_observed={'model':'turn-model','effort':'low'})
        r = self.run_cli(effort='low')
        self.assertEqual(self.ledgers(), [])
        self.assertEqual(r['text'],'DONE')
        self.assertEqual(r['status'],'completed')
        self.assertEqual(r['usage'],{'inputTokens':12,'outputTokens':3})
        self.assertEqual(r['thread_id'],'thread')
        self.assertEqual(r['turn_id'],'turn')
        self.assertIsNone(r['error_kind'])
        execution = r['execution']
        self.assertEqual(execution['version'],1)
        self.assertEqual(execution['role'],'implement')
        self.assertEqual(execution['requested'],
                         {'executor':'codex','account':'test','model':'fixture-model','effort':'low'})
        # The turn observation wins over the thread observation, and each value names its source.
        self.assertEqual(execution['effective']['model'],'turn-model')
        self.assertEqual(execution['effective']['effort'],'low')
        self.assertEqual(execution['evidence']['model'],'turn/start:result.turn.model')
        self.assertEqual(execution['evidence']['effort'],'turn/start:result.turn.effort')
        self.assertEqual(execution['evidence']['executor'],'transport:codex-app-server')

    def develop(self, *args, code=0):
        p = subprocess.run([sys.executable,str(DEVELOP),*args],env=self.env,text=True,capture_output=True,timeout=60)
        self.assertEqual(p.returncode,code,p.stdout+p.stderr)
        return json.loads(p.stdout.splitlines()[-1])

    def test_request_built_by_the_adapter_runs_exactly_as_written(self):
        roles = {role:{'executor':'codex','account':'personal','model':'fixture-model','effort':'low'}
                 for role in worker_module.ROLES}
        profile = self.root/'profiles.json'
        profile.write_text(json.dumps({'version':1,'profiles':{'custom':{'roles':roles}}}))
        instructions = self.root/'input.txt';instructions.write_text('Do only this phase.')
        out = self.root/'request.json'
        built = self.develop('request','--phase','implement','--input',str(instructions),
                             '--cwd',str(self.cwd),'--profile','custom','--profile-file',str(profile),
                             '--account-home','personal='+str(self.home),'--out',str(out))
        self.assertEqual(built['codex_home'],str(self.home.resolve()))
        request = json.loads(out.read_text())
        self.assertEqual([request['role'],request['model'],request['effort'],request['codex_home']],
                         ['implement','fixture-model','low',str(self.home.resolve())])
        p = subprocess.run([sys.executable,str(SCRIPT),'run','--request',str(out)],
                           env=self.env,text=True,capture_output=True,timeout=40)
        self.assertEqual(p.returncode,0,p.stdout+p.stderr)
        result = json.loads([s for s in p.stdout.splitlines() if s.strip()][-1])
        self.assertEqual(self.ledgers(),[])
        self.assertEqual(result['status'],'completed')
        self.assertEqual(result['text'],'DONE')
        self.assertEqual(result['execution']['role'],'implement')
        self.assertEqual(result['execution']['requested'],
                         {'executor':'codex','account':'personal','model':'fixture-model','effort':'low'})
        # The fixture advertises no thread/turn observation, so the effective side stays
        # unobserved instead of being filled in from the request.
        self.assertIsNone(result['execution']['effective']['model'])

    def test_foreground_result_carries_the_running_account_not_the_requested_name(self):
        # The caller's mapping pointed the name 'test' at another account's CODEX_HOME.
        self.config(home=self.other, email='other@example.invalid')
        r = self.run_cli(codex_home=str(self.other))
        self.assertEqual(r['status'],'completed')
        self.assertEqual(r['execution']['requested']['account'],'test')
        self.assertEqual(r['execution']['effective']['account'],'other@example.invalid')
        self.assertEqual(r['execution']['evidence']['account'],'account/read:account.email')
        self.assertEqual(self.ledgers(), [])

    def test_foreground_rejects_a_state_directory_argument(self):
        for args in (['run','--request',str(self.request()),'--state-dir',str(self.root)],
                     ['--state-dir',str(self.root),'run','--request',str(self.request())]):
            p = subprocess.run([sys.executable,str(SCRIPT),*args],env=self.env,text=True,
                               capture_output=True,timeout=20)
            # argparse must refuse the arguments; nothing may run and no result may appear.
            self.assertEqual(p.returncode,2,p.stdout+p.stderr)
            self.assertEqual(p.stdout,'')
            self.assertIn('usage:',p.stderr)
        self.assertEqual(self.calls(), [])

    def test_failures_before_the_turn_keep_the_same_shape(self):
        for job, config, kind in (
                ('mismatch',{'email':'someone@example.invalid'},'server_identity_mismatch'),
                ('quota',{'pct':100},'quota_exhausted'),
                ('thread',{'reject':'thread/start','reject_code':-32001},'server_rejected_start_-32001'),
                ('turn',{'reject':'turn/start','reject_code':-32002},'server_rejected_start_-32002')):
            self.config(job,**config)
            r = self.run_cli(job,code=2)
            self.assertEqual(r['error_kind'],kind,job)
            self.assertEqual(set(r),{'text','status','usage','execution','thread_id','turn_id','error_kind'})
            self.assertIsNone(r['status'],job)
            self.assertIsNone(r['text'],job)
            self.assertIsNone(r['usage'],job)
            self.assertEqual(r['execution']['requested']['model'],'fixture-model')
            started = any(m.get('method')=='turn/start' for m in self.calls(job))
            # Only the rejected turn/start reaches the server; the other three stop earlier.
            self.assertEqual(started, job=='turn', job)
        self.assertEqual(self.ledgers(), [])

    def test_losing_the_caller_ends_the_command_and_the_server(self):
        self.config(wait=True)
        # The real launch path puts a shell wrapper between the caller and the command, so the
        # test reproduces it: this process -> go-between -> sh -c -> run.
        script = ' '.join(shlex.quote(part) for part in self.command())+' ; exit 0'
        source = ('import subprocess,sys,time\n'
                  'subprocess.Popen(["sh","-c",sys.argv[1]])\n'
                  'time.sleep(600)\n')
        between = subprocess.Popen([sys.executable,'-c',source,script],env=self.env,
                                   stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        try:
            self.await_turn()
            shells = self.children(between.pid)
            self.assertEqual(len(shells),1,'expected one shell wrapper')
            runs = self.children(shells[0])
            self.assertEqual(len(runs),1,'expected one foreground command')
            run_pid = runs[0]
            servers = self.children(run_pid)
            self.assertEqual(len(servers),1,'expected one app-server child')
            server_pid = servers[0]
            between.kill();between.wait(timeout=10)
            start = time.monotonic()
            while time.monotonic()-start < 30 and (self.alive(run_pid) or self.alive(server_pid)):
                time.sleep(.1)
            self.assertFalse(self.alive(run_pid),'foreground command outlived its caller')
            self.assertFalse(self.alive(server_pid),'app-server outlived its caller')
        finally:
            if between.poll() is None:
                between.kill();between.wait(timeout=10)

    def test_sigterm_interrupts_the_turn_and_leaves_no_server(self):
        self.config(wait=True)
        process = subprocess.Popen(self.command(),env=self.env,text=True,
                                   stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        try:
            self.await_turn()
            servers = self.children(process.pid)
            self.assertEqual(len(servers),1,'expected one app-server child')
            process.terminate()
            out,err = process.communicate(timeout=30)
        finally:
            if process.poll() is None:
                process.kill();process.communicate(timeout=10)
        self.assertTrue(any(m.get('method')=='turn/interrupt' for m in self.calls()),
                        'no interrupt reached the app-server')
        deadline = time.monotonic()+10
        while self.alive(servers[0]) and time.monotonic() < deadline:
            time.sleep(.05)
        self.assertFalse(self.alive(servers[0]),'app-server outlived the command')
        lines = [s for s in out.splitlines() if s.strip()]
        self.assertEqual(len(lines),1,out+err)
        self.assertEqual(json.loads(lines[0])['status'],'interrupted')
        self.assertEqual(self.ledgers(), [])

    def test_a_stalled_send_still_stops_on_sigterm(self):
        # The server answers thread/start and then stops reading, so the next write fills the
        # pipe and never finishes. A write that cannot be given up on outlives every deadline.
        self.config(deafen_after='thread/start')
        process = subprocess.Popen(self.command(prompt='x'*(1<<20)),env=self.env,text=True,
                                   stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        try:
            limit = time.monotonic()+20
            while time.monotonic() < limit and not any(m.get('method')=='thread/start' for m in self.calls()):
                time.sleep(.05)
            self.assertTrue(any(m.get('method')=='thread/start' for m in self.calls()),
                            'thread/start never reached the app-server')
            servers = self.children(process.pid)
            self.assertEqual(len(servers),1,'expected one app-server child')
            time.sleep(1)
            start = time.monotonic()
            process.terminate()
            out,err = process.communicate(timeout=40)
            elapsed = time.monotonic()-start
        finally:
            if process.poll() is None:
                process.kill();process.communicate(timeout=10)
        self.assertLess(elapsed,20,'the command outlived the stop deadline')
        while self.alive(servers[0]) and time.monotonic()-start < 20:
            time.sleep(.05)
        self.assertFalse(self.alive(servers[0]),'app-server outlived the command')
        lines = [s for s in out.splitlines() if s.strip()]
        self.assertEqual(len(lines),1,out+err)
        self.assertEqual(json.loads(lines[0])['error_kind'],'stop_requested')
        self.assertEqual(self.ledgers(), [])

    def test_sigterm_interrupts_a_turn_that_has_said_nothing(self):
        # No item/started ever arrives, so nothing proves the turn is producing output. The
        # stop still has to reach the server as turn/interrupt.
        self.config(wait=True,quiet=True)
        process = subprocess.Popen(self.command(),env=self.env,text=True,
                                   stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        try:
            self.await_turn()
            servers = self.children(process.pid)
            self.assertEqual(len(servers),1,'expected one app-server child')
            process.terminate()
            out,err = process.communicate(timeout=30)
        finally:
            if process.poll() is None:
                process.kill();process.communicate(timeout=10)
        self.assertTrue(any(m.get('method')=='turn/interrupt' for m in self.calls()),
                        'no interrupt reached the app-server')
        deadline = time.monotonic()+10
        while self.alive(servers[0]) and time.monotonic() < deadline:
            time.sleep(.05)
        self.assertFalse(self.alive(servers[0]),'app-server outlived the command')
        lines = [s for s in out.splitlines() if s.strip()]
        self.assertEqual(len(lines),1,out+err)
        self.assertEqual(json.loads(lines[0])['status'],'interrupted')
        self.assertEqual(self.ledgers(), [])

    def test_request_accepts_the_legacy_account_and_model_pair(self):
        # The skill and the command both say either form may be used, so the older pair has to
        # produce the same request file, minus the per-role effort a profile would carry.
        instructions = self.root/'legacy-input.txt';instructions.write_text('Do only this phase.')
        out = self.root/'legacy-request.json'
        built = self.develop('request','--phase','implement','--input',str(instructions),
                             '--cwd',str(self.cwd),'--account','personal','--model','fixture-model',
                             '--account-home','personal='+str(self.home),'--out',str(out))
        self.assertEqual([built['account'],built['model'],built['effort'],built['role']],
                         ['personal','fixture-model',None,'implement'])
        request = json.loads(out.read_text())
        self.assertEqual([request['account'],request['model'],request['codex_home']],
                         ['personal','fixture-model',str(self.home.resolve())])
        self.assertNotIn('effort',request)

    def test_request_refuses_a_missing_half_or_doubled_execution_form(self):
        instructions = self.root/'form-input.txt';instructions.write_text('Do only this phase.')
        out = self.root/'form-request.json'
        base = ['request','--phase','implement','--input',str(instructions),'--cwd',str(self.cwd),
                '--account-home','personal='+str(self.home),'--out',str(out)]
        for extra in ([], ['--account','personal'], ['--model','fixture-model'],
                      ['--profile','codex-standard','--account','personal','--model','fixture-model'],
                      ['--profile-file',str(self.root/'profiles.json')]):
            r = self.develop(*base,*extra,code=2)
            self.assertEqual(r['status'],'blocked',extra)
            self.assertFalse(out.exists(),extra)

    def test_request_refuses_an_account_the_table_does_not_map(self):
        instructions = self.root/'unmapped-input.txt';instructions.write_text('Do only this phase.')
        out = self.root/'unmapped-request.json'
        r = self.develop('request','--phase','implement','--input',str(instructions),
                         '--cwd',str(self.cwd),'--account','absent','--model','fixture-model',
                         '--account-home','personal='+str(self.home),'--out',str(out),code=2)
        self.assertEqual(r['status'],'blocked')
        self.assertFalse(out.exists())

if __name__=='__main__':unittest.main()
