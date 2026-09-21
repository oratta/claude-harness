import base64
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import shlex
import sqlite3
import sys
import tempfile
import time
import unittest
from unittest import mock

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
 if method=='turn/start':
  if config.get('disconnect'):sys.exit(0)
  print(json.dumps({'method':'item/started','params':{'threadId':'thread','turnId':'turn'}}),flush=True)
  if config.get('usage'):print(json.dumps({'method':'thread/tokenUsage/updated','params':{'threadId':'thread','turnId':'turn','tokenUsage':config['usage']}}),flush=True)
  if config.get('wait'):continue
  print(json.dumps({'method':'turn/completed','params':{'threadId':'thread','turn':{'id':'turn','status':config.get('status','completed'),'items':[]}}}),flush=True)
 if method=='turn/interrupt':
  print(json.dumps({'method':'turn/completed','params':{'threadId':'thread','turn':{'id':'turn','status':'interrupted','items':[]}}}),flush=True)
'''

class WorkerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.state = self.root/'state';self.state.mkdir(mode=0o700)
        self.home = self.root/'profile';self.home.mkdir()
        claim = base64.urlsafe_b64encode(json.dumps({'email':'worker@example.invalid'}).encode()).decode().rstrip('=')
        (self.home/'auth.json').write_text(json.dumps({'tokens':{'id_token':'a.'+claim+'.b','account_id':'fixture-account'}}))
        (self.home/'fixture.json').write_text('{}')
        binary = self.root/'bin';binary.mkdir()
        (binary/'codex').write_text(FAKE);(binary/'codex').chmod(0o700)
        self.env = dict(os.environ, HOME=str(self.root), PATH=str(binary)+os.pathsep+os.environ['PATH'])
        self.repo = self.root/'repo';self.repo.mkdir()
        self.git(self.repo,'init','-q','-b','main')
        self.git(self.repo,'-c','user.name=Fixture','-c','user.email=f@invalid','commit','--allow-empty','-qm','initial')
        # Two worktrees, because account concurrency is only observable across distinct directories.
        self.cwd = self.worktree('feature')
        self.cwd2 = self.worktree('feature-2')
        self.cli('register','--account','test','--codex-home',str(self.home))

    def worktree(self, branch):
        path = self.root/('work-'+branch)
        self.git(self.repo,'worktree','add','-qb',branch,str(path))
        return path

    def ownership(self):
        return sqlite3.connect(self.root/'.local/state/claude-harness-codex/ownership.sqlite')

    def git(self, cwd, *args):
        return subprocess.run(['git','-C',str(cwd),*args],check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)

    def tearDown(self):
        # All fixture jobs must be terminal before removal.
        self.tmp.cleanup()

    def cli(self,*args,code=0):
        p = subprocess.run([sys.executable,str(SCRIPT),args[0],'--state-dir',str(self.state),*args[1:]],
            env=self.env,text=True,capture_output=True,timeout=10)
        self.assertEqual(p.returncode,code,p.stderr+p.stdout)
        return json.loads(p.stdout)

    def config(self,job=None,**kwargs):
        # Concurrent jobs share one authentication home, so per-job settings are keyed by job id.
        (self.home/(('fixture-'+job+'.json') if job else 'fixture.json')).write_text(json.dumps(kwargs))

    def limits(self):
        db=sqlite3.connect(self.state/'ledger.sqlite')
        try:return db.execute('SELECT max_concurrent,quota_margin_pct FROM accounts WHERE name=?',('test',)).fetchone()
        finally:db.close()

    def submit(self,job='one',code=0,**fields):
        data={'request_id':job,'origin':'manual','account':'test','cwd':str(self.cwd),
              'model':'fixture-model','role':'implement','prompt':'fixture'}
        data.update(fields)
        path=self.root/(job+'.json');path.write_text(json.dumps(data))
        return self.cli('submit','--request',str(path),code=code)

    def ledger_job_count(self):
        db=sqlite3.connect(self.state/'ledger.sqlite')
        try:return db.execute('SELECT count(*) FROM jobs').fetchone()[0]
        finally:db.close()

    def test_static_effort_and_identity_validation_creates_no_job(self):
        for job,fields,error in (
            ('empty',{'effort':''},'invalid_effort'),
            ('number',{'effort':3},'invalid_effort'),
            ('role',{'role':'unknown'},'unsupported_role'),
            ('account',{'account':'absent'},'account_not_registered')):
            self.assertEqual(self.submit(job,code=2,**fields)['error'],error)
            self.assertEqual(self.ledger_job_count(),0)
        self.assertFalse(self.calls())

    def test_model_list_all_pages_hidden_and_model_not_id(self):
        self.config(model_pages=[
            [{'id':'fixture-model','model':'other-model','supportedReasoningEfforts':[]}],
            [{'id':'different-id','model':'fixture-model','hidden':True,
              'supportedReasoningEfforts':[{'reasoningEffort':'future','description':'New'}]}]])
        self.submit(effort='future');r=self.wait()
        self.assertEqual(r['status'],'completed')
        calls=[m for m in self.calls() if m.get('method')=='model/list']
        self.assertEqual([m['params'] for m in calls],[{'includeHidden':True},{'includeHidden':True,'cursor':'1'}])
        thread=next(m['params'] for m in self.calls() if m.get('method')=='thread/start')
        turn=next(m['params'] for m in self.calls() if m.get('method')=='turn/start')
        self.assertNotIn('effort',thread);self.assertNotIn('config',thread)
        self.assertEqual(turn['effort'],'future')

    def test_model_validation_rejections_leave_failed_job_before_thread(self):
        self.cli('register','--account','test','--codex-home',str(self.home),'--max-concurrent','10')
        cases=(
            ('effort',{'model_pages':[[{'id':'luna','model':'gpt-5.6-luna','supportedReasoningEfforts':[{'reasoningEffort':'medium','description':'Medium'}]}]]},
             {'model':'gpt-5.6-luna','effort':'ultra'},'unsupported_model_effort'),
            ('missing',{'model_pages':[[]]},{'model':'missing-model'},'model_not_available'),
            ('duplicate',{'model_pages':[[{'id':'a','model':'fixture-model','supportedReasoningEfforts':[]},{'id':'b','model':'fixture-model','supportedReasoningEfforts':[]}]]},
             {},'model_not_unique'),
            ('malformed',{'model_pages':[[{'id':'a','model':'fixture-model','supportedReasoningEfforts':['high']}]]},
             {'effort':'high'},'model_list_invalid'),
            ('failure',{'reject':'model/list'}, {},'model_list_unavailable'))
        for job,config,fields,error in cases:
            self.config(job,**config);self.submit(job,cwd=str(self.worktree('case-'+job)),**fields);r=self.wait(job)
            self.assertEqual((r['status'],r['error_kind']),( 'failed',error))
            self.assertIsNone(r['thread_id']);self.assertIsNone(r['turn_id'])
            self.assertFalse(any(m.get('method') in ('thread/start','turn/start') for m in self.calls(job)))

    def test_model_list_transport_rejections_are_classified_without_hiding_validation(self):
        class Rpc:
            def __init__(self, error):
                self.error = error
            def request(self, method, params):
                raise self.error
        for reason in ('transport_disconnected', 'rpc_timeout'):
            with self.subTest(reason=reason), self.assertRaisesRegex(
                    worker_module.Rejected, '^model_list_unavailable$'):
                worker_module.advertised_model(Rpc(worker_module.Rejected(reason)), 'model', None)
        with self.assertRaisesRegex(worker_module.Rejected, '^other_rejection$'):
            worker_module.advertised_model(
                Rpc(worker_module.Rejected('other_rejection')), 'model', None)

    def test_legacy_request_omits_effort_from_turn(self):
        self.submit();self.assertEqual(self.wait()['status'],'completed')
        turn=next(m['params'] for m in self.calls() if m.get('method')=='turn/start')
        self.assertNotIn('effort',turn)

    def test_execution_metadata_is_public_and_turn_observation_wins(self):
        self.config(thread_observed={'model':'thread-model','effort':'low'},
                    turn_observed={'model':'fixture-model','effort':'high'})
        self.submit(role='review',effort='high');r=self.wait()
        self.assertEqual(r['execution'],{
            'version':1,'role':'review',
            'requested':{'executor':'codex','account':'test','model':'fixture-model','effort':'high'},
            'effective':{'executor':'codex','account':'test','model':'fixture-model','effort':'high'},
            'evidence':{'executor':'transport:codex-app-server','account':'account/read:account.email',
                        'model':'turn/start:result.turn.model','effort':'turn/start:result.turn.effort'}})
        self.assertEqual((r['job_id'],r['thread_id'],r['turn_id']),('one','thread','turn'))

    def test_execution_metadata_does_not_change_payload_hash_and_legacy_row_is_null(self):
        self.submit();self.wait()
        db=sqlite3.connect(self.state/'ledger.sqlite');db.row_factory=sqlite3.Row
        row=db.execute("SELECT payload,payload_hash FROM jobs WHERE id='one'").fetchone()
        self.assertEqual(row['payload_hash'],worker_module.digest(row['payload'].encode()))
        now=time.time()
        db.execute("INSERT INTO jobs(id,payload_hash,payload,account,cwd,status,created,updated) VALUES(?,?,?,?,?,?,?,?)",
                   ('legacy','hash','{}','test',str(self.cwd2),'failed',now,now));db.commit();db.close()
        self.assertIsNone(self.cli('status','--job','legacy')['execution'])

    def wait(self,job='one',status=None):
        deadline=time.monotonic()+8
        while time.monotonic()<deadline:
            r=self.cli('status','--job',job)
            if (status and r['status']==status) or (not status and r['status'] not in ('queued','running')):return r
            time.sleep(.03)
        self.fail('worker did not settle: '+str(r))

    def started(self,job='one'):
        deadline=time.monotonic()+8
        while time.monotonic()<deadline:
            if any(m.get('method')=='turn/start' for m in self.calls(job)):return
            time.sleep(.02)
        self.fail('turn did not start')

    def calls(self,job=None):
        p=self.home/(('calls-'+job+'.jsonl') if job else 'calls.jsonl')
        return [json.loads(s) for s in p.read_text().splitlines()] if p.exists() else []

    def tmp_info(self):
        self.assertTrue(self.calls(), 'App Server did not start')
        return self.calls()[-1]['fixtureTmp']

    def wait_cleanup(self, job='one'):
        # Terminal state alone does not prove that finally has completed.
        auth = self.state/'runtimes'/job/'auth.json'
        deadline = time.monotonic()+5
        while auth.is_symlink() and time.monotonic()<deadline:
            time.sleep(.02)
        self.assertFalse(auth.is_symlink(), 'worker cleanup did not finish')
        return self.cli('result', '--job', job)

    def test_all_role_policies_remain_restricted(self):
        self.env['TMPDIR'] = str(self.root)
        self.env['TMPPREFIX'] = str(self.root/'caller-zsh')
        for role in ('implement','spec-write','review','spec-review','impl-review','decider',
                     'explore','summarize'):
            self.submit(role, role=role)
            self.assertEqual(self.wait(role)['status'], 'completed')
            thread = [m['params'] for m in self.calls() if m.get('method')=='thread/start'][-1]
            turn = [m['params'] for m in self.calls() if m.get('method')=='turn/start'][-1]
            self.assertEqual(thread['approvalPolicy'], 'never')
            self.assertEqual(turn['approvalPolicy'], 'never')
            if role in ('implement','spec-write'):
                # A Claude subagent runs with no OS sandbox, so the writers run with none
                # either; writableRoots and the /tmp exclusions no longer apply to them.
                self.assertEqual(thread['sandbox'], 'danger-full-access')
                self.assertEqual(turn['sandboxPolicy'], {'type':'dangerFullAccess'})
            else:
                self.assertEqual(thread['sandbox'], 'read-only')
                # The reviewers mirror general subagents that read GitHub with gh; the
                # decider mirrors an agent with no shell, so it gets no reach at all.
                self.assertEqual(turn['sandboxPolicy'], {
                    'type':'readOnly', 'networkAccess':role!='decider'})
                self.assertNotIn('writableRoots', turn['sandboxPolicy'])
            # The temporary area is the caller's for every role: the worker owns none,
            # so there is nothing role-specific left to redirect or withhold.
            self.assertEqual(self.tmp_info()['path'], str(self.root))
            self.assertEqual(self.tmp_info()['prefix'], str(self.root/'caller-zsh'))
            self.wait_cleanup(role)
            self.cli('ack','--job',role)

    def test_child_inherits_parent_environment_except_the_dropped_names(self):
        dropped = ['OPENAI_API_KEY','CODEX_API_KEY','OPENAI_BASE_URL','CODEX_AUTH_JSON',
                   'OPENAI_ORGANIZATION','OPENAI_PROJECT',
                   'GIT_DIR','GIT_WORK_TREE','GIT_COMMON_DIR','GIT_INDEX_FILE']
        for name in dropped:
            self.env[name] = 'fixture-'+name.lower().replace('_','-')
        self.env['GIT_DIR'] = str(self.repo/'.git')
        self.env['GIT_WORK_TREE'] = str(self.repo)
        # An unrelated variable and the gh credential must reach the child, or the worker
        # cannot do what a Claude subagent does with the same parent environment.
        self.env['HARNESS_FIXTURE_MARK'] = 'reached'
        self.env['GH_TOKEN'] = 'fixture-gh-token'
        self.env['TMPPREFIX'] = str(self.root/'caller-zsh')
        self.submit()
        self.assertEqual(self.wait()['status'], 'completed')
        seen = self.tmp_info()['env']
        for name in dropped:
            self.assertIsNone(seen[name], name+' must not reach the child')
        self.assertEqual(seen['HARNESS_FIXTURE_MARK'], 'reached')
        self.assertEqual(seen['GH_TOKEN'], 'fixture-gh-token')
        self.assertEqual(seen['CODEX_HOME'], str((self.state/'runtimes/one').resolve()))
        # TMPDIR/TMPPREFIX are the caller's own values; the worker no longer decides them.
        self.assertEqual(seen['TMPDIR'], self.env.get('TMPDIR'))
        self.assertEqual(seen['TMPPREFIX'], str(self.root/'caller-zsh'))

    def test_child_gets_the_parent_temporary_area(self):
        # Two jobs of the same run share the caller's area: the worker creates nothing of
        # its own, records no job-tmp.json, and leaves no directory of its own behind.
        parent = self.root/'caller-tmp'; parent.mkdir()
        self.env['TMPDIR'] = str(parent)
        self.env['TMPPREFIX'] = str(parent/'zsh')
        for job, role in [('one','implement'), ('two','spec-write')]:
            self.submit(job, role=role)
            self.assertEqual(self.wait(job)['status'], 'completed')
            info = self.tmp_info()
            self.assertEqual(info['path'], str(parent))
            self.assertEqual(info['prefix'], str(parent/'zsh'))
            # The App Server's own children see it too, which is what a tool running
            # mktemp -d inside the job actually reads.
            self.assertEqual(info['child'], str(parent))
            self.wait_cleanup(job)
            self.assertFalse((self.state/'runtimes'/job/'job-tmp.json').exists())
            self.cli('ack','--job',job)
        self.assertEqual(list(parent.iterdir()), [])

    def test_absent_parent_temporary_area_is_not_invented(self):
        # launchd always puts TMPDIR in the parent on macOS, so this case only exists if
        # the caller's own value is removed first.
        self.env.pop('TMPDIR', None)
        self.env.pop('TMPPREFIX', None)
        self.submit()
        self.assertEqual(self.wait()['status'], 'completed')
        info = self.tmp_info()
        self.assertIsNone(info['path'])
        self.assertIsNone(info['prefix'])
        self.assertEqual(info['child'], '')

    def test_detached_complete_idempotence_and_ack(self):
        self.submit();r=self.wait();self.assertEqual(r['status'],'completed');self.assertEqual(r['text'],'DONE')
        self.submit();self.assertEqual(sum(m.get('method')=='turn/start' for m in self.calls()),1)
        self.cli('ack','--job','one');self.submit('two');self.assertEqual(self.wait('two')['status'],'completed')

    def test_commentary_approval_is_excluded_from_final(self):
        self.config(items=[{'type':'agentMessage','phase':'commentary','text':'仕様レビュー: APPROVE'},
                           {'type':'agentMessage','phase':'final_answer','text':'仕様レビュー: REQUEST_CHANGES\nBlocking defect remains.'}])
        self.submit(role='review');r=self.wait()
        self.assertEqual(r['status'],'completed')
        self.assertEqual(r['text'],'仕様レビュー: REQUEST_CHANGES\nBlocking defect remains.')

    def test_unknown_phase_is_not_review_evidence(self):
        self.config(items=[{'type':'agentMessage','text':'仕様レビュー: APPROVE'}])
        self.submit(role='review');r=self.wait()
        self.assertEqual(r['status'],'failed');self.assertEqual(r['error_kind'],'result_phase_unknown')
        self.assertEqual(r['text'],'')

    def test_multiple_finals_are_not_review_evidence(self):
        self.config(items=[{'type':'agentMessage','phase':'final_answer','text':'仕様レビュー: APPROVE'},
                           {'type':'agentMessage','phase':'final_answer','text':'仕様レビュー: REQUEST_CHANGES'}])
        self.submit(role='review');r=self.wait()
        self.assertEqual(r['status'],'failed');self.assertEqual(r['error_kind'],'result_final_not_unique')
        self.assertEqual(r['text'],'')

    def test_readonly_role_and_model(self):
        self.submit(role='review');self.wait()
        p=next(m['params'] for m in self.calls() if m.get('method')=='thread/start')
        self.assertEqual(p['sandbox'],'read-only');self.assertEqual(p['model'],'fixture-model')
        self.assertEqual(p['approvalPolicy'],'never')
        turn=next(m['params'] for m in self.calls() if m.get('method')=='turn/start')
        self.assertEqual(turn['sandboxPolicy'],{'type':'readOnly','networkAccess':True})

    def test_cancel_after_submit_process_exits(self):
        self.config(wait=True);self.submit()
        self.wait(status='running')
        self.cli('cancel','--job','one');self.assertEqual(self.wait()['status'],'interrupted')

    def test_disconnect_unknown_keeps_lock(self):
        self.config(disconnect=True);self.submit();self.assertEqual(self.wait()['status'],'unknown')
        self.cli('ack','--job','one',code=2)
        request=json.loads((self.root/'one.json').read_text());request['request_id']='two'
        (self.root/'two.json').write_text(json.dumps(request))
        r=self.cli('submit','--request',str(self.root/'two.json'),code=2)
        self.assertEqual(r['error'],'cwd_locked')

    def test_runtime_does_not_inherit_user_mcp(self):
        (self.home/'config.toml').write_text('[mcp_servers.external]\ncommand="danger"\n')
        self.submit();self.assertEqual(self.wait()['status'],'completed')
        runtime=self.state/'runtimes/one'
        self.assertNotIn('external',(runtime/'config.toml').read_text())
        deadline=time.monotonic()+3
        while (runtime/'auth.json').exists() and time.monotonic()<deadline:time.sleep(.02)
        self.assertFalse((runtime/'auth.json').exists())

    def test_project_config_is_rejected(self):
        (self.cwd/'.codex').mkdir();(self.cwd/'.codex/config.toml').write_text('[mcp_servers.external]\n')
        self.submit();r=self.wait();self.assertEqual(r['error_kind'],'unsupported_project_config')
        self.assertFalse(self.calls())

    def test_other_ledger_cannot_bypass_ownership(self):
        self.submit();self.wait()
        self.state=self.root/'other-state';self.state.mkdir(mode=0o700)
        self.cli('register','--account','test','--codex-home',str(self.home))
        r=self.cli('submit','--request',str(self.root/'one.json'),code=2)
        self.assertEqual(r['error'],'global_cwd_locked')

    def test_git_environment_cannot_redirect_validation(self):
        self.env['GIT_DIR']=str(self.root/'repo/.git')
        self.env['GIT_WORK_TREE']=str(self.root/'repo')
        self.submit();self.assertEqual(self.wait()['status'],'completed')

    def test_exhausted_quota_never_starts_turn(self):
        self.config(pct=100);self.submit();r=self.wait()
        self.assertEqual(r['error_kind'],'quota_exhausted')
        self.assertFalse(any(m.get('method')=='turn/start' for m in self.calls()))

    def test_account_mismatch_never_starts_turn(self):
        self.config(email='other@example.invalid');self.submit();r=self.wait()
        self.assertEqual(r['error_kind'],'server_identity_mismatch')
        self.assertFalse(any(m.get('method')=='turn/start' for m in self.calls()))

    def test_changed_auth_never_starts_server(self):
        with (self.home/'auth.json').open('a') as f:f.write(' ')
        self.submit();r=self.wait();self.assertEqual(r['error_kind'],'auth_profile_changed');self.assertFalse(self.calls())

    def test_duplicate_worker_cannot_overwrite_active_state(self):
        self.config(wait=True);self.submit();self.wait(status='running')
        subprocess.run([sys.executable,str(SCRIPT),'_worker','--state-dir',str(self.state),'--job','one'],
                       env=self.env,check=True,timeout=10)
        self.assertEqual(self.cli('status','--job','one')['status'],'running')
        self.cli('cancel','--job','one');self.assertEqual(self.wait()['status'],'interrupted')

    def test_concurrent_duplicate_starts_one_turn(self):
        data={'request_id':'one','origin':'manual','account':'test','cwd':str(self.cwd),
              'model':'fixture-model','role':'implement','prompt':'fixture'}
        path=self.root/'one.json';path.write_text(json.dumps(data))
        cmd=[sys.executable,str(SCRIPT),'submit','--state-dir',str(self.state),'--request',str(path)]
        processes=[subprocess.Popen(cmd,env=self.env,text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE) for _ in range(3)]
        for process in processes:
            out,err=process.communicate(timeout=10)
            self.assertEqual(process.returncode,0,out+err)
        self.wait()
        self.assertEqual(sum(m.get('method')=='turn/start' for m in self.calls()),1)

    def test_unknown_quota_is_not_permission(self):
        self.config(pct=None);self.submit();r=self.wait()
        self.assertEqual(r['error_kind'],'quota_unknown')
        self.assertFalse(any(m.get('method')=='turn/start' for m in self.calls()))

    def test_runtime_auth_link_switch_interrupts(self):
        self.config(wait=True);self.submit()
        deadline=time.monotonic()+5
        while not any(m.get('method')=='turn/start' for m in self.calls()) and time.monotonic()<deadline:time.sleep(.02)
        runtime=self.state/'runtimes/one/auth.json'
        other=self.root/'other-auth.json';other.write_text((self.home/'auth.json').read_text())
        runtime.unlink();runtime.symlink_to(other)
        r=self.wait();self.assertEqual(r['status'],'interrupted');self.assertEqual(r['error_kind'],'auth_profile_changed')

    def test_external_unknown_does_not_resume(self):
        self.config(wait=True);self.submit()
        deadline=time.monotonic()+5
        while not any(m.get('method')=='turn/start' for m in self.calls()) and time.monotonic()<deadline:time.sleep(.02)
        # State transition is tested without waiting 30 real seconds.
        db=sqlite3.connect(self.state/'ledger.sqlite')
        db.execute("UPDATE jobs SET updated=?,status='unknown' WHERE id='one'",(time.time()-40,));db.commit();db.close()
        r=self.wait();self.assertEqual(r['status'],'unknown');self.cli('ack','--job','one',code=2)
        time.sleep(.3)

    def test_main_checkout_and_unsupported_origin(self):
        data={'request_id':'one','origin':'manual','account':'test','cwd':str(self.root/'repo'),
              'model':'fixture','role':'implement','prompt':'fixture'}
        path=self.root/'bad.json';path.write_text(json.dumps(data))
        self.assertEqual(self.cli('submit','--request',str(path),code=2)['error'],'feature_branch_required')
        data.update(cwd=str(self.cwd),origin='burn');path.write_text(json.dumps(data))
        self.assertEqual(self.cli('submit','--request',str(path),code=2)['error'],'unsupported_origin')

    def test_register_limits_are_validated(self):
        home=str(self.home)
        self.assertEqual(self.cli('register','--account','test','--codex-home',home,'--max-concurrent','0',
                                  code=2)['error'],'invalid_max_concurrent')
        self.assertEqual(self.cli('register','--account','test','--codex-home',home,'--quota-margin-pct','101',
                                  code=2)['error'],'invalid_quota_margin_pct')

    def test_register_without_options_restores_defaults(self):
        self.cli('register','--account','test','--codex-home',str(self.home),'--max-concurrent','7','--quota-margin-pct','12')
        self.assertEqual(self.limits(),(7,12.0))
        self.cli('register','--account','test','--codex-home',str(self.home))
        self.assertEqual(self.limits(),(3,5.0))

    def test_two_worktrees_share_one_account(self):
        self.cli('register','--account','test','--codex-home',str(self.home),'--max-concurrent','2')
        self.config(wait=True)
        self.submit('one');self.submit('two',cwd=str(self.cwd2))
        self.wait('one',status='running');self.wait('two',status='running')
        third=self.worktree('feature-3')
        self.assertEqual(self.submit('three',cwd=str(third),code=2)['error'],'account_slots_exhausted')
        for job in ('one','two'):
            self.cli('cancel','--job',job);self.assertEqual(self.wait(job)['status'],'interrupted')

    def test_other_ledger_slots_beyond_range_count_toward_the_limit(self):
        # The limit is a count of occupied slots, not a search for a free number below it.
        self.cli('register','--account','test','--codex-home',str(self.home),'--max-concurrent','3')
        third=self.worktree('feature-3');fourth=self.worktree('feature-4')
        self.config(wait=True)
        for job,cwd in (('one',self.cwd),('two',self.cwd2),('three',third)):
            self.submit(job,cwd=str(cwd));self.wait(job,status='running')
        self.cli('cancel','--job','one');self.assertEqual(self.wait('one')['status'],'interrupted')
        self.cli('ack','--job','one')
        first=self.state
        self.state=self.root/'other-state';self.state.mkdir(mode=0o700)
        self.cli('register','--account','test','--codex-home',str(self.home),'--max-concurrent','2')
        self.assertEqual(self.submit('four',cwd=str(fourth),code=2)['error'],'account_slots_exhausted')
        self.state=first
        for job in ('two','three'):
            self.cli('cancel','--job',job);self.assertEqual(self.wait(job)['status'],'interrupted')

    def test_same_worktree_second_job_is_rejected(self):
        self.config(wait=True);self.submit();self.wait(status='running')
        self.assertEqual(self.submit('two',code=2)['error'],'cwd_locked')
        self.cli('cancel','--job','one');self.assertEqual(self.wait()['status'],'interrupted')

    def test_missing_ledger_slot_is_skipped_not_fatal(self):
        self.submit();self.wait();self.cli('ack','--job','one')
        db=self.ownership()
        key=db.execute('SELECT account_key FROM account_slots').fetchone()[0]
        db.execute('UPDATE account_slots SET ledger=?,job=? WHERE account_key=? AND slot=0',
                   (str(self.root/'gone/ledger.sqlite'),'ghost',key))
        db.commit();db.close()
        self.submit('two',cwd=str(self.cwd2));self.assertEqual(self.wait('two')['status'],'completed')
        db=self.ownership()
        slots=dict(db.execute('SELECT slot,job FROM account_slots WHERE account_key=?',(key,)).fetchall());db.close()
        self.assertEqual(slots,{0:'ghost',1:'two'})
        self.assertEqual([s['reason'] for s in self.cli('reap','--older-than','0')['kept']],['ledger_missing'])

    @unittest.skipIf(os.getuid()==0,'file permissions do not restrict root')
    def test_unreadable_ledger_slot_is_kept_not_fatal(self):
        # An unreadable ledger is as unobservable as a missing one: hold the slot, never fail everything else.
        locked=self.root/'locked.sqlite';locked.write_bytes(b'');locked.chmod(0o000)
        self.submit();self.wait();self.cli('ack','--job','one')
        db=self.ownership()
        key=db.execute('SELECT account_key FROM account_slots').fetchone()[0]
        db.execute('UPDATE account_slots SET ledger=?,job=? WHERE account_key=? AND slot=0',(str(locked),'ghost',key))
        db.commit();db.close()
        self.submit('two',cwd=str(self.cwd2));self.assertEqual(self.wait('two')['status'],'completed')
        r=self.cli('reap','--older-than','0')
        self.assertEqual([s['reason'] for s in r['kept']],['ledger_missing'])
        self.assertEqual([(s['job'],s['reason']) for s in r['released']],[('two','stale_unacked')])
        self.cli('ack','--job','two')
        db=self.ownership()
        db.execute("UPDATE owners SET ledger=? WHERE key LIKE 'cwd:%'",(str(locked),));db.commit();db.close()
        self.assertEqual(self.submit('three',cwd=str(self.cwd2),code=2)['error'],'global_owner_unknown')

    def test_legacy_account_owner_row_is_migrated(self):
        self.cli('register','--account','test','--codex-home',str(self.home),'--max-concurrent','1')
        self.config(wait=True);self.submit();self.wait(status='running')
        db=self.ownership()
        key,ledger,job=db.execute('SELECT account_key,ledger,job FROM account_slots').fetchone()
        db.execute('DELETE FROM account_slots')
        db.execute('INSERT INTO owners VALUES(?,?,?)',(key,ledger,job));db.commit();db.close()
        self.assertEqual(self.submit('two',cwd=str(self.cwd2),code=2)['error'],'account_slots_exhausted')
        self.cli('cancel','--job','one');self.wait();self.cli('ack','--job','one')
        self.config('two');self.submit('two',cwd=str(self.cwd2))
        self.assertEqual(self.wait('two')['status'],'completed')
        db=self.ownership()
        self.assertIsNone(db.execute('SELECT 1 FROM owners WHERE key=?',(key,)).fetchone())
        self.assertEqual(db.execute('SELECT slot,job FROM account_slots WHERE account_key=?',(key,)).fetchall(),[(0,'two')])
        db.close()

    def test_quota_headroom_blocks_when_margin_does_not_fit(self):
        self.cli('register','--account','test','--codex-home',str(self.home),'--quota-margin-pct','40')
        self.config(pct=55);self.submit('one')
        self.assertEqual(self.wait('one')['status'],'completed')
        self.cli('ack','--job','one')
        self.config(pct=70);self.submit('two',cwd=str(self.cwd2));r=self.wait('two')
        self.assertEqual(r['error_kind'],'quota_headroom_insufficient')
        self.assertFalse(any(m.get('method')=='turn/start' for m in self.calls('two')))

    def test_slot_reserved_during_rate_limit_read_enters_the_headroom_check(self):
        # A slot taken while the window read was in flight must still be counted by the reader.
        self.cli('register','--account','test','--codex-home',str(self.home),'--max-concurrent','2','--quota-margin-pct','10')
        gate=self.root/'release-rate-limit'
        self.config('one',pct=85,hold_rate_limits_until=str(gate))
        self.config('two',pct=80,wait=True)
        self.submit('one')
        deadline=time.monotonic()+8
        while not any(m.get('method')=='account/rateLimits/read' for m in self.calls('one')) and time.monotonic()<deadline:
            time.sleep(.02)
        self.assertTrue(any(m.get('method')=='account/rateLimits/read' for m in self.calls('one')))
        self.submit('two',cwd=str(self.cwd2));self.started('two')
        gate.write_text('')
        self.assertEqual(self.wait('one')['error_kind'],'quota_headroom_insufficient')
        self.assertFalse(any(m.get('method')=='turn/start' for m in self.calls('one')))
        self.cli('cancel','--job','two');self.assertEqual(self.wait('two')['status'],'interrupted')

    def test_acknowledged_slots_leave_the_headroom_calculation(self):
        self.cli('register','--account','test','--codex-home',str(self.home),'--max-concurrent','3','--quota-margin-pct','20')
        third=self.worktree('feature-3')
        self.config(pct=10)
        for job,cwd in (('one',self.cwd),('two',self.cwd2),('three',third)):
            self.submit(job,cwd=str(cwd));self.assertEqual(self.wait(job)['status'],'completed')
        for job in ('one','two','three'):self.cli('ack','--job',job)
        # Three slot rows remain, but only the new job is occupied: 70 + 20*1 fits, 70 + 20*3 would not.
        self.config(pct=70);self.submit('four')
        self.assertEqual(self.wait('four')['status'],'completed')

    def test_server_error_response_on_start_is_failed(self):
        self.config(reject='turn/start',reject_code=-32003);self.submit();r=self.wait()
        self.assertEqual(r['status'],'failed')
        self.assertEqual(r['error_kind'],'server_rejected_start_-32003')
        self.cli('ack','--job','one')

    def test_disconnect_before_reply_is_unknown(self):
        self.config(disconnect_before='turn/start');self.submit();r=self.wait()
        self.assertEqual(r['status'],'unknown')
        self.cli('ack','--job','one',code=2)

    def test_error_response_after_turn_accepted_stays_unknown(self):
        self.config(wait=True,reject='turn/interrupt');self.submit();self.started()
        self.cli('cancel','--job','one');r=self.wait()
        self.assertEqual(r['status'],'unknown')
        self.assertEqual(r['error_kind'],'rpc_error_-32000')
        self.cli('ack','--job','one',code=2)

    def test_reap_releases_acknowledged_slots(self):
        self.submit();self.wait();self.cli('ack','--job','one')
        r=self.cli('reap','--account','test')
        self.assertEqual([(s['job'],s['reason']) for s in r['released']],[('one','acked')])
        self.assertEqual(r['kept'],[])

    def test_reap_keeps_unknown_slots(self):
        self.config(disconnect=True);self.submit();self.assertEqual(self.wait()['status'],'unknown')
        r=self.cli('reap','--older-than','0')
        self.assertEqual(r['released'],[])
        self.assertEqual([(s['job'],s['reason']) for s in r['kept']],[('one','unknown')])

    def test_reap_frees_stale_unacked_but_not_the_working_directory(self):
        self.submit();self.assertEqual(self.wait()['status'],'completed')
        self.assertEqual([s['reason'] for s in self.cli('reap')['kept']],['not_stale'])
        r=self.cli('reap','--older-than','0')
        self.assertEqual([(s['job'],s['reason']) for s in r['released']],[('one','stale_unacked')])
        self.assertEqual(self.submit('two',code=2)['error'],'cwd_locked')
        self.state=self.root/'other-state';self.state.mkdir(mode=0o700)
        self.cli('register','--account','test','--codex-home',str(self.home))
        self.assertEqual(self.cli('submit','--request',str(self.root/'one.json'),code=2)['error'],'global_cwd_locked')

    def test_reap_keeps_running_slots(self):
        self.config(wait=True);self.submit();self.wait(status='running')
        r=self.cli('reap','--older-than','0')
        self.assertEqual(r['released'],[])
        self.assertEqual([(s['job'],s['reason']) for s in r['kept']],[('one','active')])
        self.cli('cancel','--job','one');self.assertEqual(self.wait()['status'],'interrupted')

    def test_reap_rejects_unknown_account_and_negative_age(self):
        self.assertEqual(self.cli('reap','--account','absent',code=2)['error'],'account_not_registered')
        self.assertEqual(self.cli('reap','--older-than','-1',code=2)['error'],'invalid_older_than')

    def test_reaped_slot_is_reused_by_the_next_submission(self):
        self.submit();self.assertEqual(self.wait()['status'],'completed')
        self.assertEqual([s['slot'] for s in self.cli('reap','--older-than','0')['released']],[0])
        self.submit('two',cwd=str(self.cwd2));self.assertEqual(self.wait('two')['status'],'completed')
        db=self.ownership()
        slots=dict(db.execute('SELECT slot,job FROM account_slots').fetchall());db.close()
        self.assertEqual(slots,{0:'two'})

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

if __name__=='__main__':unittest.main()
