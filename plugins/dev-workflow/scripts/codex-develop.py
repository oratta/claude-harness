#!/usr/bin/env python3
"""Manual develop transport. Claude remains the canonical workflow orchestrator."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import subprocess
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


def write(path, value):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=2))
    os.chmod(tmp, 0o600)
    tmp.replace(path)


def worker(state, *args):
    script = ROOT / 'scripts/codex-worker.py'
    result = subprocess.run([sys.executable, str(script), '--state-dir', state['worker_state'], *args],
                            text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or 'worker failed; no fallback')
    try:
        return json.loads(result.stdout)
    except ValueError as exc:
        raise RuntimeError('worker returned invalid JSON; retry same pending request, never fallback') from exc


def prompt(phase, instructions, state):
    role, source = PHASES[phase]
    docs = [('agents/decider.md' if phase == 'decider' else 'references/roles/' + ('gate-runner.md' if phase == 'review' else source)), 'references/decision-criteria.md']
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
        text += '\n\nCANONICAL SOURCE ' + name + '\n' + (ROOT / name).read_text()
    return text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-dir', required=True)
    sub = parser.add_subparsers(dest='command', required=True)
    init = sub.add_parser('init')
    for key in ('account', 'model', 'cwd', 'worker-state'):
        init.add_argument('--' + key, required=True)
    dispatch = sub.add_parser('dispatch')
    dispatch.add_argument('--phase', choices=PHASES, required=True)
    dispatch.add_argument('--input', required=True, help='UTF-8 phase instructions prepared by coordinator')
    for command in ('status', 'result', 'ack', 'cancel'):
        sub.add_parser(command)
    args = parser.parse_args()
    directory = Path(args.run_dir).expanduser().resolve()
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (directory / 'lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        path = directory / 'run.json'
        if args.command == 'init':
            if path.exists():
                raise RuntimeError('run exists; account/model cannot be changed')
            cwd = Path(args.cwd).expanduser().resolve()
            if not cwd.is_dir():
                raise RuntimeError('cwd must be prepared target worktree')
            check = subprocess.run(['git', '-C', str(cwd), 'rev-parse', '--show-toplevel'], capture_output=True, text=True)
            if check.returncode or Path(check.stdout.strip()).resolve() != cwd:
                raise RuntimeError('cwd must be the repository/worktree root')
            state = dict(account=args.account, model=args.model, cwd=str(cwd),
                         worker_state=str(Path(args.worker_state).expanduser().resolve()), pending=None, history=[])
            write(path, state)
            return {'status': 'initialized', 'run_dir': str(directory)}
        state = json.loads(path.read_text())
        if args.command == 'dispatch':
            instructions = Path(args.input).read_text()
            request = dict(origin='manual', account=state['account'], model=state['model'],
                           cwd=state['cwd'], role=PHASES[args.phase][0], prompt=prompt(args.phase, instructions, state))
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
            state['history'].append(dict(job_id=job, phase=state['phase'], result=result))
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
