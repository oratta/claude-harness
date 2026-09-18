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
from urllib.parse import quote, unquote_to_bytes


CONTINUATION_KEYS = ('executor', 'account', 'model', 'run-dir', 'worker-state', 'cwd')
CONTINUATION_PREFIX = '<!-- codex-develop-continuation:v1 '
CONTINUATION_RE = r'<!-- codex-develop-continuation:v1 ((?:[A-Za-z0-9._~-]+=(?:[A-Za-z0-9._~-]|%[0-9A-F]{2})+ ){5}[A-Za-z0-9._~-]+=(?:[A-Za-z0-9._~-]|%[0-9A-F]{2})+) -->'


class ContinuationError(ValueError):
    """A continuation record cannot be trusted for fail-closed resumption."""


def _continuation_encode(value):
    if not isinstance(value, str) or not value:
        raise ContinuationError('continuation values must be non-empty strings')
    return quote(value, safe='-._~')


def _continuation_decode(value):
    if not value or '%' in value and any(
            part != '%' and (len(part) < 2 or any(c not in '0123456789ABCDEF' for c in part[:2]))
            for part in value.split('%')[1:]):
        raise ContinuationError('invalid percent encoding')
    try:
        decoded = unquote_to_bytes(value).decode('utf-8')
    except (UnicodeDecodeError, ValueError) as exc:
        raise ContinuationError('invalid UTF-8 percent encoding') from exc
    if not decoded:
        raise ContinuationError('empty continuation value')
    return decoded


def format_continuation_record(values):
    """Return the one-line machine-readable record written by the coordinator."""
    if set(values) != set(CONTINUATION_KEYS):
        raise ContinuationError('continuation keys must be exactly the required six keys')
    if values.get('executor') != 'codex':
        raise ContinuationError('continuation executor must be codex')
    encoded = ' '.join(f'{key}={_continuation_encode(values[key])}' for key in CONTINUATION_KEYS)
    return f'{CONTINUATION_PREFIX}{encoded} -->'


def parse_continuation_record(line):
    """Parse one exact continuation line, rejecting unknown and duplicate keys."""
    import re
    if not isinstance(line, str) or '\n' in line or '\r' in line or not re.fullmatch(CONTINUATION_RE, line):
        raise ContinuationError('invalid continuation record')
    payload = line[len(CONTINUATION_PREFIX):-4]
    parts = payload.split(' ')
    if len(parts) != len(CONTINUATION_KEYS):
        raise ContinuationError('invalid continuation record')
    values = {}
    for part, key in zip(parts, CONTINUATION_KEYS):
        name, separator, encoded = part.partition('=')
        if separator != '=' or name != key or key in values:
            raise ContinuationError('invalid continuation keys')
        values[key] = _continuation_decode(encoded)
    if values['executor'] != 'codex':
        raise ContinuationError('continuation executor must be codex')
    return values


def select_continuation_record(comments):
    """Select the newest candidate from the already-selected GitHub record source."""
    candidates = []
    for comment in comments:
        body = comment.get('body', '') if isinstance(comment, dict) else ''
        for line in body.splitlines():
            if line.startswith(CONTINUATION_PREFIX):
                candidates.append((int(comment.get('id', 0)), line))
    if not candidates:
        raise ContinuationError('continuation record not found')
    _, line = max(candidates, key=lambda item: item[0])
    try:
        return parse_continuation_record(line)
    except ContinuationError as exc:
        raise ContinuationError(f'invalid latest continuation record: {exc}') from exc


def validate_continuation(record, run_dir):
    """Validate record values against the fixed private run before reuse."""
    directory = Path(run_dir).expanduser().resolve()
    try:
        info = directory.stat()
        if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077:
            raise ContinuationError('run-dir ownership or permissions mismatch')
        state = json.loads((directory / 'run.json').read_text())
    except (OSError, ValueError, KeyError) as exc:
        raise ContinuationError('run-dir is unavailable or invalid') from exc
    expected = {
        'run-dir': str(directory),
        'account': state.get('account'),
        'model': state.get('model'),
        'worker-state': state.get('worker_state'),
        'cwd': state.get('cwd'),
    }
    if record.get('executor') != 'codex':
        raise ContinuationError('continuation executor mismatch: expected codex')
    for key, value in expected.items():
        if record.get(key) != value:
            raise ContinuationError(f'continuation {key} mismatch')
    return record

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
The Claude coordinator follows the canonical develop workflow; execute ONLY the requested assignment.
Phase labels select role instructions, not an alternate workflow or mandatory sequence.
The spec label includes the canonical decision whether specification is needed: it does not require
creating a specification. Follow the same decision criteria and return contract as a Claude worker.
The coordinator alone applies workflow prerequisites, reviews, checks and transitions.
Account is fixed by the worker. Work only in {state['cwd']}.
Do not spawn agents, invoke Claude, codex exec, or codex-companion. If an independent role is needed,
return needs-reviewer/needs-decider with the exact request; the coordinator dispatches a fresh thread.
Claude Agent/SendMessage/Skill/opsx operations in canonical references are provider-specific:
use repository CLI equivalents for openspec only where available; do not pretend a Claude hook ran.
If required verification/permissions/tools are unavailable return blocked with evidence.
The worker has no network access. For GitHub reads/writes, push, PR creation, or unavailable
commit operations, return needs-coordinator with precise operations/data; do not execute them.
The coordinator performs authorized transport/recording, then starts a fresh phase with evidence.
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
    parser.add_argument('--run-dir', help='init defaults to a new private runs/<UUID>; later commands require it')
    sub = parser.add_subparsers(dest='command', required=True)
    init = sub.add_parser('init')
    for key in ('account', 'model', 'cwd'):
        init.add_argument('--' + key, required=True)
    init.add_argument('--worker-state', default=str(Path.home() / '.local/state/claude-harness-codex/jobs'))
    dispatch = sub.add_parser('dispatch')
    dispatch.add_argument('--phase', choices=PHASES, required=True)
    dispatch.add_argument('--input', required=True, help='UTF-8 phase instructions prepared by coordinator')
    for command in ('status', 'result', 'ack', 'cancel', 'retry'):
        sub.add_parser(command)
    args = parser.parse_args()
    if not args.run_dir and args.command != 'init':
        raise RuntimeError('--run-dir from init output is required to resume')
    directory = Path(args.run_dir).expanduser().resolve() if args.run_dir else (Path.home() / '.local/state/claude-harness-codex/runs' / uuid.uuid4().hex).resolve()
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
                         worker_state=str(Path(args.worker_state).expanduser().resolve()), pending=None, history=[])
            write(path, state)
            return {'status': 'initialized', 'run_dir': str(directory)}
        state = json.loads(path.read_text())
        if args.command == 'retry':
            # Replay the durable envelope exactly, including prompts from older versions.
            # submit is idempotent: never allocate a replacement job on uncertain delivery.
            if not state['pending']:
                raise RuntimeError('no pending job')
            request_path = directory / 'request.json'
            request = json.loads(request_path.read_text())
            if request.get('request_id') != state['pending'] or any(request.get(k) != state[k] for k in ('account', 'model', 'cwd')):
                raise RuntimeError('saved request identity differs from pending run')
            return worker(state, 'submit', '--request', str(request_path))
        if args.command == 'dispatch':
            head = git(state['cwd'], 'rev-parse', 'HEAD')
            instructions = Path(args.input).read_text()
            request = dict(origin='manual', account=state['account'], model=state['model'],
                           cwd=state['cwd'], role=PHASES[args.phase][0], prompt=prompt(args.phase, 'Dispatch HEAD: ' + head + '\n' + instructions, state))
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
            state['history'].append(dict(job_id=job, phase=state['phase'], head=state['head'], result=result))
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
