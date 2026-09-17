#!/usr/bin/env python3
"""Manual develop transport. Claude remains the canonical workflow orchestrator."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import stat
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]
PHASES = {
    'spec': ('spec-write', 'worker.md'),
    'spec-review': ('spec-review', 'spec-reviewer.md'),
    'implement': ('implement', 'worker.md'),
    'finish': ('implement', 'worker.md'),
    'gate': ('implement', 'gate-runner.md'),
    'review': ('impl-review', 'spec-reviewer.md'),
    'decider': ('decider', 'spec-reviewer.md'),
}


def clean_env():
    return {k: v for k, v in os.environ.items() if not k.startswith('GIT_')}


def git(cwd, *args):
    return subprocess.check_output(['git', '-C', cwd, *args], text=True, env=clean_env()).strip()


def spec_digest(state):
    root = Path(state['cwd'])
    digest = hashlib.sha256()
    for slot, relative in enumerate(state['spec_paths']):
        digest.update(str(slot).encode() + b'\0')
        path = (root / relative).resolve()
        if not path.is_relative_to(root) or path == root:
            raise RuntimeError('spec path must be inside cwd and narrower than repository root')
        files = sorted(path.rglob('*')) if path.is_dir() else [path]
        for item in files:
            if item.is_symlink():
                raise RuntimeError('symlink spec artifact is unsupported')
            if item.is_file():
                name = str(item.relative_to(path)) if path.is_dir() else item.name
                digest.update(name.encode() + b'\0' + item.read_bytes())
            elif not item.exists():
                digest.update(str(item.relative_to(root)).encode() + b'\0missing')
    return digest.hexdigest()


def write(path, value):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=2))
    os.chmod(tmp, 0o600)
    tmp.replace(path)


def worker(state, *args):
    script = ROOT / 'scripts/codex-worker.py'
    result = subprocess.run([sys.executable, str(script), '--state-dir', state['worker_state'], *args],
                            text=True, capture_output=True, env=clean_env())
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or 'worker failed; no fallback')
    try:
        return json.loads(result.stdout)
    except ValueError as exc:
        raise RuntimeError('worker returned invalid JSON; retry same pending request, never fallback') from exc


def prompt(phase, instructions, state):
    role, source = PHASES[phase]
    docs = [('agents/decider.md' if phase == 'decider' else 'skills/develop/references/roles/' + ('gate-runner.md' if phase == 'review' else source)), 'skills/develop/references/decision-criteria.md']
    if phase in ('gate', 'review'):
        docs.append('skills/pr-review-gate/SKILL.md')
    text = f'''Codex delegated develop phase: {phase}. Role: {role}.
The Claude coordinator follows the canonical develop workflow; execute ONLY the requested phase.
Account is fixed by the worker. Work only in {state['cwd']}.
Do not spawn agents, invoke Claude, codex exec, or codex-companion. If an independent role is needed,
return needs-reviewer/needs-decider with the exact request; the coordinator dispatches a fresh thread.
Claude Agent/SendMessage/Skill/opsx operations in canonical references are provider-specific:
use repository CLI equivalents for openspec only where available; do not pretend a Claude hook ran.
If required verification/permissions/tools are unavailable return blocked with evidence.
Never merge or enable auto-merge. Do not claim quality success from transport completion.
Fresh context: do not apply Claude transcript counters or assume usage=0 means empty context.
References below retain quality criteria; Claude model names/escalation are not Codex model selection.
Return a concise result with phase, artifacts, test commands and exit codes, review verdict where
applicable, and blockers. Reviewer: read-only, review the coordinator's fixed HEAD/artifacts only.

REQUEST:
{instructions}
'''
    for name in docs:
        content = (ROOT / name).read_text()
        text += '\n\nCANONICAL SOURCE ' + name + ' sha256=' + hashlib.sha256(content.encode()).hexdigest() + '\n' + content
    return text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-dir', required=True)
    sub = parser.add_subparsers(dest='command', required=True)
    init = sub.add_parser('init')
    for key in ('account', 'model', 'cwd', 'worker-state'):
        init.add_argument('--' + key, required=True)
    init.add_argument('--spec-path', action='append', required=True, help='relative specification file/directory covered by review')
    init.add_argument('--required-check', action='append', default=[], help='JSON argv array; required before finish/gate')
    sub.add_parser('check')
    relocate = sub.add_parser('relocate-spec')
    relocate.add_argument('--from-path', required=True)
    relocate.add_argument('--to-path', required=True)
    dispatch = sub.add_parser('dispatch')
    dispatch.add_argument('--phase', choices=PHASES, required=True)
    dispatch.add_argument('--input', required=True, help='UTF-8 phase instructions prepared by coordinator')
    sub.add_parser('accept-review')
    for command in ('status', 'result', 'ack', 'cancel'):
        sub.add_parser(command)
    args = parser.parse_args()
    directory = Path(args.run_dir).expanduser().resolve()
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    info = directory.stat()
    if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077:
        raise RuntimeError('run-dir must be owned by current user with mode 0700')
    with (directory / 'lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        path = directory / 'run.json'
        if args.command == 'init':
            if path.exists():
                raise RuntimeError('run exists; account/model cannot be changed')
            cwd = Path(args.cwd).expanduser().resolve()
            if not cwd.is_dir():
                raise RuntimeError('cwd must be prepared target worktree')
            check = subprocess.run(['git', '-C', str(cwd), 'rev-parse', '--show-toplevel'], capture_output=True, text=True, env=clean_env())
            if check.returncode or Path(check.stdout.strip()).resolve() != cwd:
                raise RuntimeError('cwd must be the repository/worktree root')
            state = dict(account=args.account, model=args.model, cwd=str(cwd),
                         worker_state=str(Path(args.worker_state).expanduser().resolve()), pending=None, history=[], spec_paths=args.spec_path,
                         required_checks=[json.loads(v) for v in args.required_check])
            if not state['required_checks'] or any(not isinstance(v, list) or not v or any(not isinstance(a, str) for a in v) for v in state['required_checks']):
                raise RuntimeError('at least one --required-check JSON argv array is required')
            spec_digest(state)
            write(path, state)
            return {'status': 'initialized', 'run_dir': str(directory)}
        state = json.loads(path.read_text())
        if args.command == 'relocate-spec':
            if state['pending'] or git(state['cwd'], 'status', '--porcelain'):
                raise RuntimeError('finish job and commit archive before relocation')
            previous = state.get('approvals', {}).get('spec-review', {}).get('spec_digest')
            candidate = dict(state, spec_paths=[args.to_path if value == args.from_path else value for value in state['spec_paths']])
            if args.from_path not in state['spec_paths'] or not previous or spec_digest(candidate) != previous:
                raise RuntimeError('archive content differs from approved specification; re-review required')
            state['spec_paths'] = candidate['spec_paths']
            write(path, state)
            return {'status': 'relocated', 'spec_paths': state['spec_paths']}
        if args.command == 'check':
            if state['pending']:
                raise RuntimeError('collect and ack current job before checks')
            if git(state['cwd'], 'status', '--porcelain'):
                raise RuntimeError('commit artifacts before checks')
            head = git(state['cwd'], 'rev-parse', 'HEAD')
            evidence = []
            for command in state['required_checks']:
                result = subprocess.run(command, cwd=state['cwd'], capture_output=True, text=True, env=clean_env())
                evidence.append(dict(command=command, exit_code=result.returncode, stdout=result.stdout, stderr=result.stderr))
            unchanged = git(state['cwd'], 'rev-parse', 'HEAD') == head and not git(state['cwd'], 'status', '--porcelain')
            state['checks'] = dict(head=head, evidence=evidence, unchanged=unchanged)
            write(path, state)
            return {'status': 'passed' if unchanged and all(v['exit_code'] == 0 for v in evidence) else 'failed', 'checks': state['checks']}
        if args.command == 'accept-review':
            if not state['history'] or state['history'][-1]['phase'] not in ('spec-review', 'review'):
                raise RuntimeError('collect and ack an independent reviewer first')
            entry = state['history'][-1]
            head = git(state['cwd'], 'rev-parse', 'HEAD')
            marker = '仕様レビュー: APPROVE' if entry['phase'] == 'spec-review' else 'レビュー: APPROVE'
            if entry['result'].get('status') != 'completed' or marker not in entry['result'].get('text', '').splitlines() or head != entry['head'] or git(state['cwd'], 'status', '--porcelain') or spec_digest(state) != entry['spec_digest']:
                raise RuntimeError('review not approved or reviewed HEAD changed')
            state.setdefault('approvals', {})[entry['phase']] = dict(head=head, job_id=entry['job_id'], spec_digest=entry['spec_digest'])
            write(path, state)
            return {'status': 'recorded', 'review': entry['phase'], 'head': head}
        if args.command == 'dispatch':
            if args.phase in ('implement', 'finish', 'gate') and 'spec-review' not in state.get('approvals', {}):
                raise RuntimeError('independent specification approval required')
            if args.phase in ('implement', 'finish', 'gate') and state['approvals']['spec-review']['spec_digest'] != spec_digest(state):
                raise RuntimeError('specification changed; independent re-review required')
            head = git(state['cwd'], 'rev-parse', 'HEAD')
            if args.phase in ('finish', 'gate'):
                checks = state.get('checks', {})
                if git(state['cwd'], 'status', '--porcelain') or not checks.get('unchanged') or checks.get('head') != head or not checks.get('evidence') or any(v['exit_code'] != 0 for v in checks['evidence']):
                    raise RuntimeError('required checks must pass on current HEAD')
            if args.phase == 'spec-review' and any(not (Path(state['cwd']) / name).exists() for name in state['spec_paths']):
                raise RuntimeError('specification artifacts must exist before review')
            if args.phase in ('spec-review', 'review'):
                dirty = git(state['cwd'], 'status', '--porcelain')
                if dirty.strip():
                    raise RuntimeError('commit review artifacts before independent review')
            instructions = Path(args.input).read_text()
            request = dict(origin='manual', account=state['account'], model=state['model'],
                           cwd=state['cwd'], role=PHASES[args.phase][0], prompt=prompt(args.phase, 'Target HEAD: ' + head + '\nRequired checks: ' + json.dumps(state['required_checks']) + '\n' + instructions, state))
            if state['pending']:
                old = json.loads((directory / 'request.json').read_text())
                if any(old.get(k) != v for k, v in request.items()):
                    raise RuntimeError('pending request differs; collect result and ack before next phase')
                request = old
            else:
                request['request_id'] = 'develop-' + uuid.uuid4().hex
                write(directory / 'request.json', request)
                state['pending'] = request['request_id']
                state['phase'] = args.phase
                state['head'] = head
                state['spec_digest'] = spec_digest(state)
                if args.phase == 'spec':
                    state.pop('approvals', None)
                write(path, state)  # Persist BEFORE submit: uncertain response keeps same request ID.
            return worker(state, 'submit', '--request', str(directory / 'request.json'))
        if not state['pending']:
            raise RuntimeError('no pending job')
        job = state['pending']
        if args.command == 'ack':
            result = worker(state, 'result', '--job', job)
            if result.get('status') == 'unknown':
                raise RuntimeError('unknown job cannot be acknowledged or replaced')
            response = worker(state, 'ack', '--job', job)
            state['history'].append(dict(job_id=job, phase=state['phase'], head=state['head'], spec_digest=state['spec_digest'], result=result))
            state['pending'] = None
            write(path, state)
            return response
        return worker(state, args.command, '--job', job)


if __name__ == '__main__':
    try:
        print(json.dumps(main(), ensure_ascii=False))
    except (OSError, ValueError, RuntimeError, KeyError) as exc:
        print(json.dumps({'status': 'blocked', 'error': str(exc)}, ensure_ascii=False))
        sys.exit(2)
