#!/usr/bin/env python3
"""Opt-in live checks for #1857. All repositories and evidence stay outside the checkout."""
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

PLUGIN = Path(__file__).resolve().parents[1]
LAUNCH = PLUGIN / 'scripts/claude-role-launch.py'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true', help='actually invoke the installed Claude CLI')
    parser.add_argument('--model', default='sonnet')
    parser.add_argument('--mode', choices=('agent', 'explicit'), default='agent')
    parser.add_argument('--assignment', choices=('W','G','reviewer','R1','decider'), default='W')
    parser.add_argument('--role', default='implement')
    parser.add_argument('--record', type=int, default=1857)
    parser.add_argument('--case', choices=('capability','normal','git-deny','resume-cap','lifecycle'), default='capability')
    parser.add_argument('--verification', type=Path, help='external proof from a successful capability run')
    parser.add_argument('--timeout', type=float, default=120)
    a = parser.parse_args()
    if not a.execute:
        parser.error('--execute is required; see references/claude-role-launch.md')
    if a.case != 'capability' and a.verification is None:
        parser.error('run capability first, then supply its --verification path')
    root = Path(tempfile.mkdtemp(prefix='claude-role-live-')).resolve()
    if PLUGIN in root.parents or root == PLUGIN:
        raise RuntimeError('TMPDIR must be outside the plugin checkout')
    print('evidence_dir: '+str(root), file=sys.stderr)
    repo = root/'repo'
    subprocess.run(['git','init','-q',str(repo)], check=True)
    (repo/'f.txt').write_text('committed\n')
    subprocess.run(['git','-C',str(repo),'add','f.txt'], check=True)
    subprocess.run(['git','-C',str(repo),'-c','user.name=fixture','-c','user.email=fixture@example.invalid',
                    'commit','-qm','fixture'], check=True)
    (repo/'f.txt').write_text('uncommitted-preserve\n')
    proof = a.verification.resolve() if a.verification else root/'verification.json'
    prompt = root/'instructions.txt'
    prompt.write_text('段: implement\nRead f.txt once. Do not edit it. Return first line 工程完了: 実装＋verify\n')
    if a.case == 'git-deny':
        prompt.write_text('段: implement\nUse Bash to attempt exactly `git reset --hard HEAD` once in this temporary repo. '
                          'If a hook denies it, do not retry or ask for a permit. Return the denial verbatim. '
                          'Do not change any files by other means. Return first line 工程中断: git deny.\n')
    argv = [sys.executable,str(LAUNCH),'--assignment',a.assignment,'--role',a.role,'--model',a.model,
            '--cwd',str(repo),'--instructions',str(prompt),'--max-turns','2' if a.case=='capability' else '8',
            '--record',str(a.record),'--session-records',str(root/'sessions.jsonl'),
            '--plugin-dir',str(PLUGIN),'--verification',str(proof),'--timeout',str(a.timeout),'--mode',a.mode]
    if a.case == 'capability':
        argv.append('--verify')

    def snapshot():
        return {'head':subprocess.check_output(['git','-C',str(repo),'rev-parse','HEAD'],text=True).strip(),
                'status':subprocess.check_output(['git','-C',str(repo),'status','--porcelain'],text=True),
                'content':(repo/'f.txt').read_text()}

    before = snapshot()
    results = []
    control = subprocess.Popen(['sleep','600']) if a.case == 'lifecycle' else None
    try:
        for route in (('normal','max-turns','cli-kill','INT','TERM') if a.case=='lifecycle' else (a.case,)):
            invocation = list(argv)
            if a.case == 'lifecycle':
                prompt.write_text('段: implement\nUse Bash to start `sleep 300 >/dev/null 2>&1 &` once. '
                                  'Then return first line 工程完了: 実装＋verify.\n')
            if route in ('max-turns','cli-kill','INT','TERM'):
                prompt.write_text('段: implement\nUse Bash to start `sleep 300 >/dev/null 2>&1 &` once. '
                                  'Then repeatedly Read f.txt one call per turn, 100 times. Never finish early.\n')
            if route == 'max-turns':
                invocation[invocation.index('--max-turns')+1]='2'
            out_path, err_path = root/(route+'.json'), root/(route+'.stderr')
            with out_path.open('w') as out, err_path.open('w') as err:
                child = subprocess.Popen(invocation,stdout=out,stderr=err)
                if route in ('cli-kill','INT','TERM'):
                    # Find only a child of this launcher, never a name-wide process.
                    deadline = time.monotonic()+min(a.timeout,30)
                    pid = None
                    while child.poll() is None and time.monotonic()<deadline:
                        listing=subprocess.run(['ps','-axo','pid=,ppid=,command='],capture_output=True,text=True,check=True)
                        for line in listing.stdout.splitlines():
                            fields=line.split(None,2)
                            if len(fields)==3 and fields[1]==str(child.pid) and '--max-turns' in fields[2]:
                                pid=int(fields[0]); break
                        if pid:
                            break
                        time.sleep(.1)
                    if pid is None:
                        child.wait(timeout=a.timeout+10)
                        raise RuntimeError('live CLI child not observed; inspect '+str(err_path))
                    time.sleep(3)  # give the requested background child time to start
                    os.kill(pid if route=='cli-kill' else child.pid,
                            signal.SIGKILL if route=='cli-kill' else signal.SIGINT if route=='INT' else signal.SIGTERM)
                child.wait(timeout=a.timeout+15)
            data=json.loads(out_path.read_text())
            item={'route':route,'command':invocation,'exit_code':child.returncode,'result':data}
            if control:
                item['outside_control_alive']=control.poll() is None
            results.append(item)
            if a.case=='resume-cap' and child.returncode==0:
                log=Path(data['transcript_path']); original=log.read_bytes()
                (root/'original-transcript.jsonl').write_bytes(original)
                try:
                    log.write_text(json.dumps({'type':'assistant','message':{'model':a.model,
                        'usage':{'input_tokens':999999,'output_tokens':1}}})+'\n')
                    resumed=subprocess.run(invocation+['--resume',data['session_id'],'--transcript',str(log)],
                                           capture_output=True,text=True,timeout=45)
                    (root/'resume-cap.json').write_text(resumed.stdout)
                    (root/'resume-cap.stderr').write_text(resumed.stderr)
                    results.append({'route':'resume-cap','exit_code':resumed.returncode,'result':json.loads(resumed.stdout)})
                finally:
                    log.write_bytes(original)
    finally:
        if control:
            control.terminate(); control.wait(timeout=5)
    after=snapshot()
    summary={'evidence_dir':str(root),'plugin_dir':str(PLUGIN),'verification':str(proof),
             'before':before,'after':after,'unchanged':before==after,'results':results,
             'review_required':'Inspect role/tool/model evidence, actual tool attempts and hook denial in transcripts. '
                               'Transport completion alone is not quality success.'}
    (root/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(summary,ensure_ascii=False,indent=2))
    # Probe failure and unexpected transport outcomes stay nonzero. No quality verdict is produced.
    expected = {'capability':0,'normal':0,'git-deny':2,'resume-cap':2}
    if a.case=='lifecycle':
        return 0 if all(r['exit_code']==(0 if r['route']=='normal' else 2) and
                        r['result'].get('cleanup',{}).get('ok') and r['outside_control_alive'] for r in results) else 1
    return 0 if results[-1]['exit_code']==expected[a.case] and before==after else 1


if __name__ == '__main__':
    sys.exit(main())
