import base64
import json
import os
from pathlib import Path
import subprocess
import sqlite3
import sys
import tempfile
import time
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/codex-worker.py'
FAKE = r'''#!/usr/bin/env python3
import json,os,sys,time
from pathlib import Path
runtime=Path(os.environ['CODEX_HOME']); home=(runtime/'auth.json').resolve().parent; config=json.loads((home/'fixture.json').read_text())
for line in sys.stdin:
 m=json.loads(line); method=m.get('method'); rid=m.get('id')
 with (home/'calls.jsonl').open('a') as f:f.write(json.dumps(m)+'\n')
 if rid is None:continue
 if method=='account/read':r={'account':{'type':'chatgpt','email':config.get('email','worker@example.invalid')}}
 elif method=='account/rateLimits/read':r={'rateLimitsByLimitId':{'codex':{'primary':{'usedPercent':config.get('pct',1),'windowDurationMins':300,'resetsAt':int(time.time())+1000}}}}
 elif method=='thread/start':r={'thread':{'id':'thread'}}
 elif method=='turn/start':r={'turn':{'id':'turn'}}
 elif method=='thread/read':r={'thread':{'turns':[{'id':'turn','items':config.get('items',[{'type':'agentMessage','phase':'final_answer','text':'DONE'}])}]}}
 else:r={}
 print(json.dumps({'id':rid,'result':r}),flush=True)
 if method=='turn/start':
  if config.get('disconnect'):sys.exit(0)
  print(json.dumps({'method':'item/started','params':{'threadId':'thread','turnId':'turn'}}),flush=True)
  if config.get('wait'):continue
  print(json.dumps({'method':'turn/completed','params':{'threadId':'thread','turn':{'id':'turn','status':'completed','items':[]}}}),flush=True)
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
        repo = self.root/'repo';repo.mkdir()
        self.git(repo,'init','-q','-b','main')
        self.git(repo,'-c','user.name=Fixture','-c','user.email=f@invalid','commit','--allow-empty','-qm','initial')
        self.cwd = self.root/'work'
        self.git(repo,'worktree','add','-qb','feature',str(self.cwd))
        self.cli('register','--account','test','--codex-home',str(self.home))

    def git(self, cwd, *args):
        return subprocess.run(['git','-C',str(cwd),*args],check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)

    def tearDown(self):
        # All fixture jobs must be terminal before removal.
        self.tmp.cleanup()

    def cli(self,*args,code=0):
        p = subprocess.run([sys.executable,str(SCRIPT),'--state-dir',str(self.state),*args],
            env=self.env,text=True,capture_output=True,timeout=10)
        self.assertEqual(p.returncode,code,p.stderr+p.stdout)
        return json.loads(p.stdout)

    def config(self,**kwargs):
        (self.home/'fixture.json').write_text(json.dumps(kwargs))

    def submit(self,job='one',**fields):
        data={'request_id':job,'origin':'manual','account':'test','cwd':str(self.cwd),
              'model':'fixture-model','role':'implement','prompt':'fixture'}
        data.update(fields)
        path=self.root/(job+'.json');path.write_text(json.dumps(data))
        return self.cli('submit','--request',str(path))

    def wait(self,job='one',status=None):
        deadline=time.monotonic()+8
        while time.monotonic()<deadline:
            r=self.cli('status','--job',job)
            if (status and r['status']==status) or (not status and r['status'] not in ('queued','running')):return r
            time.sleep(.03)
        self.fail('worker did not settle: '+str(r))

    def calls(self):
        p=self.home/'calls.jsonl'
        return [json.loads(s) for s in p.read_text().splitlines()] if p.exists() else []

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
        self.assertEqual(turn['sandboxPolicy'],{'type':'readOnly','networkAccess':False})

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
        self.assertEqual(r['error'],'cwd_or_account_locked')

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
        self.assertEqual(r['error'],'global_account_or_cwd_locked')

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
        subprocess.run([sys.executable,str(SCRIPT),'--state-dir',str(self.state),'_worker','--job','one'],
                       env=self.env,check=True,timeout=10)
        self.assertEqual(self.cli('status','--job','one')['status'],'running')
        self.cli('cancel','--job','one');self.assertEqual(self.wait()['status'],'interrupted')

    def test_concurrent_duplicate_starts_one_turn(self):
        data={'request_id':'one','origin':'manual','account':'test','cwd':str(self.cwd),
              'model':'fixture-model','role':'implement','prompt':'fixture'}
        path=self.root/'one.json';path.write_text(json.dumps(data))
        cmd=[sys.executable,str(SCRIPT),'--state-dir',str(self.state),'submit','--request',str(path)]
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

if __name__=='__main__':unittest.main()
