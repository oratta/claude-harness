import base64
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sqlite3
import sys
import tempfile
import time
import unittest
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/codex-worker.py'
spec = importlib.util.spec_from_file_location('codex_worker', SCRIPT)
worker_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker_module)
FAKE = r'''#!/usr/bin/env python3
import json,os,sys,time,subprocess,stat
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
 'env':{k:os.environ.get(k) for k in watched}}
if tmp:
 info.update(mode=stat.S_IMODE(Path(tmp).stat().st_mode),uid=Path(tmp).stat().st_uid,
  git=subprocess.run(['git','-C',tmp,'rev-parse','--absolute-git-dir'],capture_output=True).returncode,
  child=subprocess.check_output([sys.executable,'-c','import os;print(os.environ.get("TMPDIR", ""))'],text=True).strip())
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
 elif method=='thread/start':r={'thread':{'id':'thread'}}
 elif method=='turn/start':r={'turn':{'id':'turn'}}
 elif method=='thread/read':r={'thread':{'turns':[{'id':'turn','items':config.get('items',[{'type':'agentMessage','phase':'final_answer','text':'DONE'}])}]}}
 else:r={}
 print(json.dumps({'id':rid,'result':r}),flush=True)
 if method=='turn/start':
  if config.get('tmp_symlink'):
   (Path(tmp)/'link').symlink_to(home, target_is_directory=True)
  if config.get('replace_tmp'):
   Path(tmp).rmdir();Path(tmp).symlink_to(home, target_is_directory=True)
  if config.get('disconnect'):sys.exit(0)
  print(json.dumps({'method':'item/started','params':{'threadId':'thread','turnId':'turn'}}),flush=True)
  if config.get('wait'):continue
  print(json.dumps({'method':'turn/completed','params':{'threadId':'thread','turn':{'id':'turn','status':config.get('status','completed'),'items':[]}}}),flush=True)
 if method=='turn/interrupt':
  print(json.dumps({'method':'turn/completed','params':{'threadId':'thread','turn':{'id':'turn','status':'interrupted','items':[]}}}),flush=True)
'''

class JobTmpTest(unittest.TestCase):
    def test_cleanup_removes_owned_tree_but_preserves_symlink_target(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            target = root/'target'; target.mkdir()
            (target/'keep').write_text('keep')
            path = root/'owned'; path.mkdir(mode=0o700)
            owned = worker_module.JobTmp(path)
            (path/'link').symlink_to(target, target_is_directory=True)
            (path/'nested').mkdir(); (path/'nested/file').write_text('temporary')
            owned.cleanup()
            self.assertFalse(path.exists())
            self.assertEqual((target/'keep').read_text(), 'keep')

    def test_cleanup_refuses_replaced_root(self):
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            path = root/'owned'; path.mkdir(mode=0o700)
            owned = worker_module.JobTmp(path)
            moved = root/'moved'; path.rename(moved)
            path.symlink_to(moved, target_is_directory=True)
            with self.assertRaises(worker_module.Rejected):
                owned.cleanup()
            self.assertTrue(moved.is_dir())
            self.assertTrue(path.is_symlink())

    def test_cleanup_refuses_root_replaced_by_a_plain_directory(self):
        # A swap to a normal directory looks valid to rmtree's own checks; only the
        # identity recorded at creation distinguishes it from the tree we own.
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            path = root/'owned'; path.mkdir(mode=0o700)
            owned = worker_module.JobTmp(path)
            moved = root/'moved'; path.rename(moved)
            path.mkdir(mode=0o700); (path/'someone-elses').write_text('keep')
            with self.assertRaisesRegex(worker_module.Rejected, 'job_tmp_identity_changed'):
                owned.cleanup()
            self.assertEqual((path/'someone-elses').read_text(), 'keep')
            self.assertTrue(moved.is_dir())

    def test_cleanup_deletes_through_the_opened_fd_when_the_name_is_swapped(self):
        # Swap the name after the identity check but before the walk. The deletion must
        # follow the fd opened on our own inode, and the removal of the name must refuse.
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            path = root/'owned'; path.mkdir(mode=0o700)
            (path/'ours').write_text('ours')
            owned = worker_module.JobTmp(path)
            intruder = root/'intruder'; intruder.mkdir(mode=0o700)
            (intruder/'theirs').write_text('theirs')
            # Hook os.stat, which both a name-based and an fd-based cleanup call, so this
            # stays a regression guard rather than a test of the current call sequence.
            real_stat, swapped = os.stat, []
            def swap_then_stat(*args, **kwargs):
                if not swapped:
                    swapped.append(True)
                    path.rename(root/'ours-moved'); intruder.rename(path)
                return real_stat(*args, **kwargs)
            with mock.patch.object(worker_module.os, 'stat', side_effect=swap_then_stat):
                with self.assertRaisesRegex(worker_module.Rejected, 'job_tmp_identity_changed'):
                    owned.cleanup()
            self.assertEqual((path/'theirs').read_text(), 'theirs')
            self.assertFalse((root/'ours-moved'/'ours').exists())

    def test_cleanup_error_is_not_silenced(self):
        with tempfile.TemporaryDirectory() as root:
            (Path(root)/'nested').mkdir()
            owned = worker_module.JobTmp(Path(root))
            with mock.patch.object(worker_module.shutil, 'rmtree', side_effect=PermissionError):
                with self.assertRaises(PermissionError):
                    owned.cleanup()

    def test_creation_refuses_git_parent(self):
        with tempfile.TemporaryDirectory() as root:
            subprocess.run(['git','init','-q',root], check=True)
            with mock.patch.dict(os.environ, TMPDIR=root):
                with self.assertRaisesRegex(worker_module.Rejected, 'job_tmp_in_git'):
                    worker_module.JobTmp.create(Path(root)/'work')
            self.assertEqual(list(Path(root).glob('codex-worker-*')), [])


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
        p = subprocess.run([sys.executable,str(SCRIPT),'--state-dir',str(self.state),*args],
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

    def test_job_tmp_is_private_external_and_not_reused(self):
        paths = []
        for job, role in [('one','implement'), ('two','spec-write')]:
            self.submit(job, role=role)
            self.assertEqual(self.wait(job)['status'], 'completed')
            info = self.tmp_info()
            path = Path(info['path'])
            self.assertEqual(str(path.resolve()), str(path))
            self.assertNotEqual(str(path), os.environ.get('TMPDIR'))
            self.assertEqual(info['mode'], 0o700)
            self.assertEqual(info['uid'], os.getuid())
            self.assertNotEqual(info['git'], 0)
            self.assertEqual(info['child'], str(path))
            # zsh here-documents follow TMPPREFIX, not TMPDIR; it must stay inside the job area.
            self.assertEqual(info['prefix'], str(path/'zsh'))
            self.assertFalse(path.is_relative_to(self.cwd))
            self.wait_cleanup(job)
            self.assertFalse(path.exists())
            paths.append(path)
            self.cli('ack','--job',job)
        self.assertNotEqual(*paths)

    def test_all_role_policies_remain_restricted(self):
        for role in ('implement','spec-write','review','spec-review','impl-review','decider'):
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
                # The job's own temporary area survives the sandbox removal: the child
                # still gets it through TMPDIR/TMPPREFIX and the worker still owns it.
                self.assertIsNotNone(self.tmp_info()['path'])
            else:
                self.assertEqual(thread['sandbox'], 'read-only')
                # The reviewers mirror general subagents that read GitHub with gh; the
                # decider mirrors an agent with no shell, so it gets no reach at all.
                self.assertEqual(turn['sandboxPolicy'], {
                    'type':'readOnly', 'networkAccess':role!='decider'})
                self.assertNotIn('writableRoots', turn['sandboxPolicy'])
                self.assertIsNone(self.tmp_info()['path'])
                self.assertIsNone(self.tmp_info()['prefix'])
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
        # TMPDIR/TMPPREFIX are the worker's own values, never the caller's.
        self.assertEqual(seen['TMPDIR'], self.tmp_info()['path'])
        self.assertEqual(seen['TMPPREFIX'], str(Path(self.tmp_info()['path'])/'zsh'))

    def test_read_only_child_gets_neither_tmpdir_nor_tmpprefix(self):
        # Regression for the inherit-by-default change: a caller's temp settings must not
        # ride along into a read-only job, which owns no private area to redirect them to.
        self.env['TMPDIR'] = str(self.root)
        self.env['TMPPREFIX'] = str(self.root/'caller-zsh')
        self.submit(role='review')
        self.assertEqual(self.wait()['status'], 'completed')
        seen = self.tmp_info()['env']
        self.assertIsNone(seen['TMPDIR'])
        self.assertIsNone(seen['TMPPREFIX'])

    def test_tmp_cleanup_for_confirmed_outcomes_and_symlink_contents(self):
        cases = [('success', {}, 'completed'), ('failure', {'status':'failed'}, 'failed'),
                 ('cancel', {'wait':True}, 'interrupted'),
                 ('before', {'pct':100}, 'failed'),
                 ('badfinal', {'items':[{'type':'agentMessage','text':'ambiguous'}]}, 'failed')]
        for job, config, expected in cases:
            self.config(tmp_symlink=True, **config)
            self.submit(job)
            if job == 'cancel':
                self.wait(job, status='running')
                self.cli('cancel','--job',job)
            self.assertEqual(self.wait(job)['status'], expected)
            path = Path(self.tmp_info()['path'])
            self.wait_cleanup(job)
            self.assertFalse(path.exists())
            self.assertTrue(path.parent.is_dir())
            self.assertTrue(self.cwd.is_dir())
            self.assertTrue((self.home/'auth.json').is_file())
            self.cli('ack','--job',job)

    def test_unknown_retains_tmp_and_ownership(self):
        self.config(disconnect=True)
        self.submit()
        self.assertEqual(self.wait()['status'], 'unknown')
        path = Path(self.tmp_info()['path'])
        self.wait_cleanup()
        self.assertTrue(path.is_dir())
        self.assertNotEqual(str(path), os.environ.get('TMPDIR'))
        self.cli('ack','--job','one',code=2)
        # Only the fake server has exited; this is fixture residue, not a real unknown job.
        if path.name.startswith('codex-worker-'):
            path.rmdir()

    def test_replaced_tmp_reports_cleanup_failure_without_following_symlink(self):
        self.config(replace_tmp=True)
        self.submit()
        self.wait()
        result = self.wait_cleanup()
        self.assertIn('job_tmp_cleanup_failed', result['error_kind'] or '')
        path = Path(self.tmp_info()['path'])
        self.assertTrue(path.is_symlink())
        self.assertTrue((self.home/'auth.json').is_file())
        path.unlink()

    def test_invalid_tmp_parent_rejects_without_fallback(self):
        for name, parent in [('missing',self.root/'absent'), ('file',self.home/'auth.json'),
                             ('cwd',self.cwd), ('git',self.root/'repo/.git')]:
            self.env['TMPDIR'] = str(parent)
            self.submit(name)
            self.assertEqual(self.wait(name)['status'], 'failed')
            self.assertFalse(self.calls())
            self.cli('ack','--job',name)

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

if __name__=='__main__':unittest.main()
