#!/usr/bin/env python3
"""Foreground Claude role transport. Does not decide workflow quality or change accounts."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid

sys.dont_write_bytecode = True
from tier_caps import CAPPED_ROLES, TABLE_PATH, TIERS, exceeds, model_tier, read_table, refusal

PLUGIN = Path(__file__).resolve().parents[1]
ROLES = {
    'W': (('spec-write', 'implement'), 'worker', 'Read,Edit,Write,Bash,Grep,Glob,TaskStop'),
    'G': (('implement',), 'gate-runner', 'Read,Bash,Grep,Glob,TaskStop'),
    'reviewer': (('impl-review', 'review'), 'reviewer', 'Read,Bash,Grep,Glob,TaskStop'),
    'R1': (('spec-review',), None, 'Read,Bash,Grep,Glob,TaskStop'),
    'decider': (('decider',), 'decider', 'Read,Grep,Glob'),
}


class Refusal(Exception):
    pass


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise Refusal(message)


def identity(cli, plugin):
    """Bind the probe to executable bytes, CLI version, and all distributed plugin contents."""
    version = subprocess.run([cli, '--version'], capture_output=True, text=True, timeout=10, check=True)
    digest = hashlib.sha256()
    for path in sorted(plugin.rglob('*')):
        if path.is_file() and '__pycache__' not in path.parts:
            digest.update(str(path.relative_to(plugin)).encode())
            digest.update(path.read_bytes())
    return {'cli': str(Path(cli).resolve()), 'version': version.stdout.strip(),
            'cli_sha256': hashlib.sha256(Path(cli).read_bytes()).hexdigest(),
            'plugin_sha256': digest.hexdigest()}


def outside(path, cwd):
    path = path.resolve()
    if path == cwd or cwd in path.parents:
        raise Refusal('logs, records and verification must be outside cwd')
    # A worktree's common repository is also not a log destination.
    top = Path(subprocess.check_output(['git', '-C', str(cwd), 'rev-parse', '--show-toplevel'], text=True).strip()).resolve()
    if path == top or top in path.parents:
        raise Refusal('external path required')
    return path


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as handle:
            json.dump(value, handle, ensure_ascii=False)
            handle.write('\n')
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def register(path, record):
    """Readers see whole old or new JSONL; lock a stable sidecar across replacement."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(str(path)+'.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        previous = path.read_text() if path.exists() else ''
        for line in previous.splitlines():
            json.loads(line)
        fd, temporary = tempfile.mkstemp(dir=path.parent)
        try:
            with os.fdopen(fd, 'w') as handle:
                handle.write(previous.rstrip('\n') + ('\n' if previous else ''))
                handle.write(json.dumps(record, ensure_ascii=False)+'\n')
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)


def members(pgid):
    result = subprocess.run(['ps', '-axo', 'pid=,pgid=,stat='], capture_output=True, text=True, timeout=5, check=True)
    return [int(p[0]) for line in result.stdout.splitlines()
            if len(p := line.split()) >= 3 and p[1] == str(pgid) and not p[2].startswith('Z')]


def cleanup(process, owned):
    pgid = process.pid
    if not owned or pgid == os.getpgrp():
        return {'ok': False, 'reason': 'ownership_unconfirmed', 'pgid': pgid}
    try:
        for sig, grace in ((signal.SIGTERM, .5), (signal.SIGKILL, 2)):
            if not members(pgid):
                break
            try:
                os.killpg(pgid, sig)
            except ProcessLookupError:
                pass
            deadline = time.monotonic()+grace
            while members(pgid) and time.monotonic() < deadline:
                process.poll()
                time.sleep(.05)
        process.wait(timeout=2)
        remaining = members(pgid)
        return {'ok': not remaining, 'pgid': pgid, 'remaining': remaining}
    except (OSError, subprocess.SubprocessError) as error:
        return {'ok': False, 'pgid': pgid, 'reason': str(error)}


def probe_evidence(path, model, tools):
    observed_models, observed_tools = set(), set()
    for line in path.read_text().splitlines():
        row = json.loads(line)
        msg = row.get('message', {})
        if row.get('type') == 'assistant' and isinstance(msg, dict):
            if msg.get('model'):
                observed_models.add(msg['model'])
            for block in msg.get('content', []) if isinstance(msg.get('content'), list) else []:
                if isinstance(block, dict) and block.get('type') == 'tool_use':
                    observed_tools.add(block.get('name'))
    table = read_table(PLUGIN / TABLE_PATH)
    wanted = model_tier(table['executors']['claude'], model)
    return bool(observed_models and observed_tools and
                all(model_tier(table['executors']['claude'], m) == wanted for m in observed_models) and
                observed_tools <= set(tools.split(',')))


def run():
    p = Parser(description=__doc__)
    p.add_argument('--担当', '--assignment', dest='assignment', required=True, choices=ROLES)
    p.add_argument('--role', required=True)
    p.add_argument('--model', required=True)
    p.add_argument('--cwd', type=Path, required=True)
    p.add_argument('--instructions', type=Path, required=True)
    p.add_argument('--max-turns', type=int, required=True)
    p.add_argument('--record', type=int, action='append', required=True)
    p.add_argument('--session-records', type=Path, required=True)
    p.add_argument('--plugin-dir', type=Path, default=PLUGIN)
    p.add_argument('--verification', type=Path, required=True)
    p.add_argument('--verify', action='store_true', help='bounded live probe; writes a capability result')
    p.add_argument('--mode', choices=('agent', 'explicit'), default='agent')
    p.add_argument('--resume')
    p.add_argument('--transcript', type=Path)
    p.add_argument('--timeout', type=float, default=1800)
    a = p.parse_args()
    roles, agent, tools = ROLES[a.assignment]
    if a.role not in roles or a.max_turns <= 0 or a.timeout <= 0 or any(n <= 0 for n in a.record):
        raise Refusal('invalid role, turns, timeout or record')
    table = read_table(PLUGIN / TABLE_PATH)
    if table is None:
        raise Refusal('model table unavailable')
    tier = model_tier(table['executors']['claude'], a.model)
    if tier is None:
        raise Refusal(f'unknown model: role={a.role}, requested_model={a.model}')
    if a.role in CAPPED_ROLES:
        cap = table['role_caps'].get(a.role)
        if cap not in TIERS or exceeds(tier, cap):
            raise Refusal(refusal(a.role, tier, cap, a.model))
    if tier == TIERS[-1] and a.assignment != 'decider':
        raise Refusal(f'forbidden model: role={a.role}, requested_model={a.model}, allowed=decider only')
    cwd = a.cwd.resolve(strict=True)
    plugin = a.plugin_dir.resolve(strict=True)
    records = outside(a.session_records, cwd)
    verification = outside(a.verification, cwd)
    cli = shutil.which('claude')
    if not cli:
        raise Refusal('claude not found')
    stamp = identity(cli, plugin)
    mode = 'explicit' if agent is None else a.mode
    binding = dict(identity=stamp, role=a.role, assignment=a.assignment, model=a.model, mode=mode)
    if not a.verify:
        try:
            proof = json.loads(verification.read_text())
            if not proof.get('approved') or any(proof.get(k) != v for k, v in binding.items()):
                raise ValueError('identity or capability mismatch')
        except (OSError, ValueError) as error:
            raise Refusal('verification required: '+str(error)) from error
    if bool(a.resume) != bool(a.transcript) or (a.verify and a.resume):
        raise Refusal('resume requires its exact transcript; probe must be fresh')
    sid = str(uuid.UUID(a.resume)) if a.resume else str(uuid.uuid4())
    config = Path(os.environ.get('CLAUDE_CONFIG_DIR', str(Path.home()/'.claude'))).resolve()
    expected = config/'projects'/re.sub(r'[^a-zA-Z0-9]', '-', str(cwd))/(sid+'.jsonl')
    transcript = outside(expected, cwd)
    if a.transcript and a.transcript.resolve() != transcript:
        raise Refusal('transcript does not belong to requested session/cwd/config')
    result = dict(session_id=sid, transcript_path=str(transcript), role=a.role, model=a.model,
                  requested_model=a.model, applied_models=[],
                  cli_exit_code=None, role_return='', cleanup={'ok': True}, phase_declaration=None)
    if a.resume:
        context = subprocess.run([str(PLUGIN/'scripts/subagent-context.sh'), '--file', str(transcript)],
                                 cwd=cwd, capture_output=True, text=True, timeout=30)
        result['context'] = {'exit_code': context.returncode, 'output': context.stdout}
        if context.returncode:
            reason = 'context_cap' if context.returncode == 2 else 'context_unavailable'
            result.update(termination_reason=reason, phase_declaration='工程中断: '+reason)
            return 2, result
    body = a.instructions.read_text()
    body += '\n孫を起こさない。不足した独立役は本体へ要求する。\n'
    if mode == 'explicit':
        source = plugin/'agents'/((agent or 'worker')+'.md') if agent else plugin/'skills/develop/references/roles/spec-reviewer.md'
        definition = source.read_text()
        body = (definition.split('---', 2)[-1] if definition.startswith('---') else definition) + '\n' + body
    if a.verify:
        body = ('CLI capability probe. Follow your role restrictions. Use Read to read the instructions file '
                + str(a.instructions.resolve()) + ' repeatedly, one tool call per turn, at least '
                + str(a.max_turns+3) + ' times. Do not finish early. Never spawn agents.\n' + body)
    rid = subprocess.check_output(['git','-C',str(cwd),'rev-parse','--path-format=absolute','--git-common-dir'], text=True).strip()
    register(records, dict(schema_version=1, provider='claude', kind='role', records=a.record,
                           repo_common_dir=os.path.realpath(rid), cwd=str(cwd), session_id=sid,
                           log_path=str(transcript), role=a.role, model=a.model))
    argv = [cli, '-p', '--model', a.model, '--max-turns', str(a.max_turns), '--output-format', 'json',
            '--plugin-dir', str(plugin)]
    if mode == 'agent':
        argv += ['--agent', 'dev-workflow:'+agent]
    else:
        argv += ['--tools', tools]
    argv += ['--disallowedTools', 'Agent', '--resume' if a.resume else '--session-id', sid]
    env = dict(os.environ, DEVELOP_ROLE=a.role)
    interrupted = []
    def on_signal(number, frame):
        interrupted.append(number)
    previous = {s: signal.signal(s, on_signal) for s in (signal.SIGINT, signal.SIGTERM)}
    process = None
    owned = False
    reason = 'cli_error'
    try:
        # File-backed capture prevents a background descendant's inherited pipe from blocking communicate.
        with tempfile.TemporaryFile() as out, tempfile.TemporaryFile() as err, tempfile.TemporaryFile() as inp:
            inp.write(body.encode()); inp.seek(0)
            process = subprocess.Popen(argv, cwd=cwd, env=env, start_new_session=True,
                                       stdin=inp, stdout=out, stderr=err)
            owned = os.getpgid(process.pid) == process.pid and os.getsid(process.pid) == process.pid
            result['ownership'] = {'pid': process.pid, 'pgid': process.pid, 'confirmed': owned}
            deadline = time.monotonic()+a.timeout
            while process.poll() is None and not interrupted and time.monotonic() < deadline:
                time.sleep(.05)
            reason = 'signal' if interrupted else ('timeout' if process.poll() is None else 'cli_error')
            result['cleanup'] = cleanup(process, owned)
            result['cli_exit_code'] = process.returncode
            out.seek(0); err.seek(0)
            result['stderr'] = err.read().decode(errors='replace')
            try:
                response = json.loads(out.read())
                if not isinstance(response, dict) or response.get('session_id') != sid:
                    raise ValueError('invalid CLI result/session')
                result['role_return'] = response.get('result') or ''
                if reason not in ('signal', 'timeout'):
                    reason = ('max_turns' if response.get('subtype') == 'error_max_turns' else
                              'cli_error' if response.get('is_error') or process.returncode else 'normal')
            except (ValueError, TypeError):
                response = {}
            if transcript.is_file():
                observed = set()
                for line in transcript.read_text().splitlines():
                    try:
                        entry = json.loads(line)
                        message = entry.get('message', {}) if isinstance(entry, dict) else {}
                        model = message.get('model') if isinstance(message, dict) else None
                        if entry.get('type') == 'assistant' and isinstance(model, str):
                            observed.add(model)
                    except (ValueError, AttributeError):
                        continue
                result['applied_models'] = sorted(observed)
            if a.verify:
                approved = (reason == 'max_turns' and result['cleanup']['ok'] and transcript.is_file()
                            and probe_evidence(transcript, a.model, tools))
                write_json(verification, dict(binding, approved=approved, session_id=sid,
                                             transcript_path=str(transcript), reason=reason))
                result['verification_approved'] = approved
                result['termination_reason'] = reason
                result['phase_declaration'] = '工程中断: 検証のみ'
                return (0 if approved else 2), result
    finally:
        if process is not None and process.poll() is None:
            result['cleanup'] = cleanup(process, owned)
        for sig, handler in previous.items():
            signal.signal(sig, handler)
    declaration = result['role_return'].splitlines()[0] if result['role_return'] else ''
    if reason == 'normal' and a.assignment in ('W', 'G') and not re.fullmatch(r'工程完了: .+', declaration):
        reason = 'role_interrupted' if declaration.startswith('工程中断: ') else 'missing_declaration'
    if declaration.startswith('工程中断: '):
        reason = 'role_interrupted'
    if not result['cleanup']['ok']:
        reason = 'cleanup_failed'
    if not transcript.is_file():
        result['transcript_unresolved'] = 'requested session transcript unavailable'
    result['termination_reason'] = reason
    result['phase_declaration'] = declaration if reason == 'normal' and a.assignment in ('W','G') else '工程中断: '+reason
    # Independent verdicts remain in role_return; transport never creates APPROVE or a workflow declaration.
    if reason == 'normal' and a.assignment not in ('W','G'):
        result['phase_declaration'] = None
    return (0 if reason == 'normal' else 2), result


if __name__ == '__main__':
    try:
        code, output = run()
    except (Refusal, OSError, ValueError, subprocess.SubprocessError) as error:
        code, output = 1, {'termination_reason': str(error), 'phase_declaration': '工程中断: 起動不可'}
    print(json.dumps(output, ensure_ascii=False))
    sys.exit(code)
