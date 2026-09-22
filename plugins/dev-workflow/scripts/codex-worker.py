#!/usr/bin/env python3
"""Run one account-bound App Server turn in the foreground."""
import argparse
import base64
import hashlib
import json
import math
import os
from pathlib import Path
import queue
import re
import select
import shutil
import signal
import subprocess
import tempfile
import threading
import time

TERMINAL = {'completed', 'failed', 'interrupted'}
# The writers run with no OS sandbox because the Claude subagent each one mirrors runs with
# none either; a linked worktree's $GIT_DIR stays read-only under workspace-write, so commit
# and branch creation cannot work there. The readers keep readOnly, which is the one limit
# Claude also has (the decider holds Read/Grep/Glob and no shell).
ROLES = {'implement': 'danger-full-access', 'spec-write': 'danger-full-access',
         'review': 'read-only', 'spec-review': 'read-only',
         'impl-review': 'read-only', 'decider': 'read-only',
         'explore': 'read-only', 'summarize': 'read-only'}
# Reach matches the Claude subagent each role mirrors: the writers and the reviewers run
# with a shell and gh, while the decider only has Read/Grep/Glob and fetches nothing. The
# writers reach the network by having no sandbox, so this set decides readOnly roles only.
NETWORK_ROLES = {'implement', 'spec-write', 'review', 'spec-review', 'impl-review',
                 'explore', 'summarize'}
# The child otherwise inherits the parent, as a Claude subagent does. These are removed:
# the one value the worker decides itself (CODEX_HOME), values that would move Codex's
# authentication or billing to a different account, and values that would
# point the child's git at a checkout other than cwd. TMPDIR/TMPPREFIX are not here: every
# role gets the caller's temporary area, exactly as a Claude subagent does.
DROPPED_ENV = ('CODEX_HOME',
               'OPENAI_API_KEY', 'CODEX_API_KEY', 'OPENAI_BASE_URL', 'CODEX_AUTH_JSON',
               'OPENAI_ORGANIZATION', 'OPENAI_PROJECT',
               'GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR', 'GIT_INDEX_FILE')


class Rejected(Exception):
    pass


class ServerRejected(Rejected):
    # An error response is proof the request was refused; a disconnect proves nothing.
    def __init__(self, code):
        super().__init__('rpc_error_'+str(code))
        self.code = code


def require(value, reason):
    if not value:
        raise Rejected(reason)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def auth_info(home):
    raw = (Path(home) / 'auth.json').read_bytes()
    data = json.loads(raw)
    tokens = data.get('tokens') or {}
    token = tokens.get('id_token', '').split('.')
    require(len(token) == 3, 'chatgpt_profile_required')
    claims = json.loads(base64.urlsafe_b64decode(token[1] + '=' * (-len(token[1]) % 4)))
    email = claims.get('email')
    require(email and tokens.get('account_id'), 'identity_unknown')
    # Claims identify local profile; account/read verifies the server view before any turn.
    return {'auth_hash': digest(raw), 'identity': digest(email.strip().lower().encode()),
            'account_id_hash': digest(tokens['account_id'].encode())}


def git_env():
    # Fixed minimal allowlist for the worker's own git calls only. The caller's GIT_* must
    # never redirect the linked-worktree checks to another checkout, so these
    # calls do not use the inherited environment that the child job gets.
    allowed = {'PATH', 'HOME', 'USER', 'LOGNAME', 'SHELL', 'TMPDIR', 'LANG', 'LC_ALL', 'SYSTEMROOT'}
    return {k: v for k, v in os.environ.items() if k in allowed}


def child_env():
    # The child gets the parent's environment so the same role can finish the same work a
    # Claude subagent finishes; only DROPPED_ENV is withheld.
    return {k: v for k, v in os.environ.items() if k not in DROPPED_ENV}


def git_common_dir(cwd):
    # Absolute path of the shared Git directory; for a linked worktree this is elsewhere
    # than cwd, so the project-config check needs it to see the repository's own layer.
    return subprocess.check_output(['git', '-C', str(cwd), 'rev-parse',
                                    '--path-format=absolute', '--git-common-dir'],
                                   env=git_env(), text=True).strip()


def validate_request(payload):
    require(set(payload) <= {'request_id', 'origin', 'account', 'cwd', 'model', 'role', 'prompt', 'effort'}, 'unknown_request_field')
    for field in ('request_id', 'account', 'cwd', 'model', 'role', 'prompt'):
        require(isinstance(payload.get(field), str) and bool(payload[field].strip()), 'missing_'+field)
    require(re.fullmatch(r'[A-Za-z0-9_-]{1,100}', payload['request_id']), 'invalid_request_id')
    require(payload.get('origin') == 'manual', 'unsupported_origin')
    require(payload['role'] in ROLES, 'unsupported_role')
    if 'effort' in payload:
        require(isinstance(payload['effort'], str) and bool(payload['effort'].strip()), 'invalid_effort')
    cwd = Path(payload['cwd']).expanduser().resolve()
    require(cwd.is_dir() and cwd.stat().st_uid == os.getuid(), 'cwd_not_owned')
    def git(*args):
        return subprocess.check_output(['git', '-C', str(cwd), *args], stderr=subprocess.DEVNULL, text=True, env=git_env()).strip()
    require(Path(git('rev-parse', '--show-toplevel')).resolve() == cwd, 'cwd_must_be_repo_root')
    branch = git('branch', '--show-current')
    require(branch and branch not in ('main', 'master'), 'feature_branch_required')
    # A real linked worktree prevents accidental operation on the main checkout.
    require((cwd / '.git').is_file(), 'linked_worktree_required')
    payload['cwd'] = str(cwd)
    return payload


def execution_metadata(payload):
    requested = {'executor': 'codex', 'account': payload['account'], 'model': payload['model'],
                 'effort': payload.get('effort')}
    return {'version': 1, 'role': payload['role'], 'requested': requested,
            'effective': {'executor': None, 'account': None, 'model': None, 'effort': None},
            'evidence': {key: 'unavailable' for key in requested}}


def apply_observations(execution, observations):
    for key, (value, source) in observations.items():
        if value is not None:
            execution['effective'][key] = value
            execution['evidence'][key] = source
    return execution


def advertised_model(rpc, model, effort):
    matches, cursor = [], None
    try:
        while True:
            params = {'includeHidden': True}
            if cursor is not None:
                params['cursor'] = cursor
            result = rpc.request('model/list', params)
            data = result.get('data')
            require(isinstance(data, list), 'model_list_invalid')
            for item in data:
                require(isinstance(item, dict) and isinstance(item.get('model'), str), 'model_list_invalid')
                efforts = item.get('supportedReasoningEfforts')
                require(isinstance(efforts, list) and all(isinstance(value, dict) and
                        isinstance(value.get('reasoningEffort'), str) for value in efforts), 'model_list_invalid')
                if item['model'] == model:
                    matches.append(item)
            cursor = result.get('nextCursor')
            require(cursor is None or isinstance(cursor, str) and cursor, 'model_list_invalid')
            if cursor is None:
                break
    except ServerRejected:
        raise Rejected('model_list_unavailable')
    except Rejected as exc:
        if str(exc) in ('transport_disconnected', 'rpc_timeout'):
            raise Rejected('model_list_unavailable')
        raise
    except (queue.Empty, TimeoutError, BrokenPipeError):
        raise Rejected('model_list_unavailable')
    require(matches, 'model_not_available')
    require(len(matches) == 1, 'model_not_unique')
    if effort is not None:
        supported = {value['reasoningEffort'] for value in matches[0]['supportedReasoningEfforts']}
        require(effort in supported, 'unsupported_model_effort')
    return matches[0]


def reject_project_config(cwd, common):
    # The Git project config layer can re-enable external tools; initial version refuses it.
    project = Path(cwd)
    roots = {project, Path(common).parent, *project.parents}
    # The normal user config is intentionally replaced by runtime config, not a project layer.
    roots.discard(Path.home())
    require(not any((root/'.codex/config.toml').exists() for root in roots), 'unsupported_project_config')


def install_runtime(runtime, source):
    (runtime/'auth.json').symlink_to(Path(source)/'auth.json')
    (runtime/'config.toml').write_text('cli_auth_credentials_store = "file"\n[features]\napps = false\n')
    os.chmod(runtime/'config.toml', 0o600)
    return runtime


def foreground_runtime(job, source, cwd, common):
    # The one runtime CODEX_HOME goes into the
    # caller's temporary area (TMPDIR when set, the platform default otherwise). What the
    # App Server and its children receive as TMPDIR/TMPPREFIX is untouched.
    reject_project_config(cwd, common)
    base = Path(tempfile.mkdtemp(prefix='codex-run-'))
    os.chmod(base, 0o700)
    runtime = base/job
    runtime.mkdir(mode=0o700)
    return install_runtime(runtime, source)


def discard_runtime(runtime):
    # The runtime's link to the authentication profile never outlives the job.
    (runtime/'auth.json').unlink(missing_ok=True)


def ancestors(pid):
    # The direct parent is a shell wrapper whenever the caller starts this in the background,
    # so the whole chain identifies the caller: if any link disappears the rest is reparented
    # and the chain no longer matches. A recycled PID cannot fake the entire chain.
    chain = []
    while pid > 1 and len(chain) < 64:
        chain.append(pid)
        try:
            pid = int(subprocess.check_output(['ps', '-o', 'ppid=', '-p', str(pid)],
                                              text=True, stderr=subprocess.DEVNULL).strip())
        except (subprocess.CalledProcessError, ValueError, OSError):
            chain.append(-1)
            break
    return chain


def runtime_identity_matches(runtime, account):
    path = runtime/'auth.json'
    require(path.is_symlink() and path.resolve() == (Path(account['home'])/'auth.json').resolve(), 'runtime_auth_link_changed')
    actual = auth_info(account['home'])
    require(all(actual[k] == account[k] for k in actual), 'auth_profile_changed')


def quota_available(result, margin, inflight):
    # Bucket selection follows statusline-codex.py; unlike display, reject malformed windows.
    buckets = result.get('rateLimitsByLimitId')
    bucket = buckets.get('codex') if isinstance(buckets, dict) else result.get('rateLimits')
    require(isinstance(bucket, dict) and bucket.get('limitId') in (None, 'codex'), 'quota_unknown')
    found = False
    for name in ('primary', 'secondary'):
        window = bucket.get(name)
        if window is None:
            continue
        require(isinstance(window, dict), 'quota_unknown')
        pct, mins, reset = (window.get(k) for k in ('usedPercent', 'windowDurationMins', 'resetsAt'))
        require(type(pct) in (int, float) and math.isfinite(pct) and 0 <= pct <= 100 and
                type(mins) is int and mins > 0 and type(reset) is int and reset > time.time(), 'quota_unknown')
        require(pct < 100, 'quota_exhausted')
        # Reserve margin for every request counted in inflight.
        require(pct + margin*inflight <= 100, 'quota_headroom_insufficient')
        found = True
    require(found, 'quota_unknown')


class Rpc:
    def __init__(self, home, cwd):
        env = child_env()
        env['CODEX_HOME'] = home
        self.proc = subprocess.Popen(['codex', 'app-server', '-c', 'model_provider="openai"'], cwd=cwd, env=env,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        self.events = queue.Queue()
        self.buffer = []
        self.next_id = 0
        self.unsupported = False
        self.tick = lambda: None
        # Hooks the foreground path installs: budget() caps one request at the remaining
        # interrupt deadline, aborted() ends a wait as soon as a stop is requested, and
        # poll_wait makes the wait wake often enough to see it.
        self.timeout = 15
        self.budget = lambda: None
        self.aborted = lambda: False
        self.poll_wait = None
        # Writes go out by hand so they can be given up on: a peer that stops reading fills the
        # pipe, and a blocking write would hold the process past every deadline below.
        os.set_blocking(self.proc.stdin.fileno(), False)
        threading.Thread(target=self.reader, daemon=True).start()

    def reader(self):
        try:
            for line in self.proc.stdout:
                self.events.put(json.loads(line))
        except Exception:
            pass
        self.events.put({'disconnected': True})

    def deadline(self):
        # The same budget the replies wait on: under the foreground grace period it is what is
        # left of it, and otherwise the plain per-request timeout.
        limit = self.budget()
        return time.monotonic()+(self.timeout if limit is None else max(0.0, min(self.timeout, limit)))

    def send(self, msg):
        data = (json.dumps(msg)+'\n').encode()
        fd = self.proc.stdin.fileno()
        deadline = self.deadline()
        while data:
            if self.aborted():
                raise Rejected('stop_requested')
            wait = deadline-time.monotonic()
            if wait <= 0:
                raise Rejected('rpc_timeout')
            if not select.select((), (fd,), (), min(wait, self.poll_wait) if self.poll_wait else wait)[1]:
                continue
            try:
                written = os.write(fd, data)
            except BlockingIOError:
                continue
            except OSError:
                raise Rejected('transport_disconnected')
            data = data[written:]

    def receive(self, timeout):
        msg = self.events.get(timeout=timeout)
        if msg.get('disconnected'):
            raise Rejected('transport_disconnected')
        if 'method' in msg and 'id' in msg:
            self.unsupported = True
            self.send({'id': msg['id'], 'error': {'code': -32601, 'message': 'Unsupported worker request'}})
        return msg

    def request(self, method, params, tick=True):
        # tick=False is for the interrupt itself: a stop is already requested by then, so the
        # entry check that refuses new requests must not refuse the one that stops the turn.
        if tick:
            self.tick()
        self.next_id += 1
        rid = self.next_id
        self.send({'id': rid, 'method': method, 'params': params})
        deadline = self.deadline()
        while time.monotonic() < deadline:
            wait = max(.001, deadline-time.monotonic())
            try:
                msg = self.receive(min(wait, self.poll_wait) if self.poll_wait else wait)
            except queue.Empty:
                if self.aborted():
                    raise Rejected('stop_requested')
                continue
            if msg.get('id') == rid and 'method' not in msg:
                if msg.get('error'):
                    raise ServerRejected(msg['error'].get('code'))
                return msg.get('result', {})
            self.buffer.append(msg)
        raise Rejected('rpc_timeout')

    def close(self):
        try:
            self.proc.stdin.close()
        except BrokenPipeError:
            pass
        try:
            self.proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait(timeout=3)
        self.proc.stdout.close()


def final_answer(items):
    messages = [item for item in items if item.get('type') == 'agentMessage']
    require(not any(item.get('phase') not in ('commentary', 'final_answer') for item in messages), 'result_phase_unknown')
    finals = [item for item in messages if item.get('phase') == 'final_answer']
    require(len(finals) == 1, 'result_final_not_unique')
    text = finals[0].get('text', '')
    require(isinstance(text, str) and text.strip(), 'result_missing')
    return text


class TurnState:
    # accepted means the server answered turn/start; a ServerRejected before it is reported
    # as server_rejected_start_<code>.
    def __init__(self):
        self.accepted = False
        self.thread_id = None
        self.turn_id = None
        self.usage = None


def run_turn(rpc, recorder, payload, account, runtime, cwd, state):
    # One app-server turn, from handshake to terminal status. Returns
    # (status, text, error_kind); text is None when it must not be set.
    sandbox = ROLES[payload['role']]
    rpc.tick = recorder.tick
    rpc.request('initialize', {'clientInfo': {'name': 'harness-worker', 'version': '1'}})
    rpc.send({'method': 'initialized', 'params': {}})
    observed = rpc.request('account/read', {'refreshToken': False}).get('account') or {}
    require(observed.get('type') == 'chatgpt' and observed.get('email') and
            digest(observed['email'].strip().lower().encode()) == account['identity'], 'server_identity_mismatch')
    recorder.observe(executor=('codex', 'transport:codex-app-server'),
                     account=(recorder.account_effective(payload, observed), 'account/read:account.email'))
    runtime_identity_matches(runtime, account)
    advertised_model(rpc, payload['model'], payload.get('effort'))
    limits = rpc.request('account/rateLimits/read', {})
    # inflight is read after the reply.
    inflight = recorder.inflight(account)
    quota_available(limits, account['quota_margin_pct'], inflight)
    thread_result = rpc.request('thread/start', {'cwd': cwd, 'model': payload['model'],
        'sandbox': sandbox, 'approvalPolicy': 'never', 'modelProvider': 'openai'})['thread']
    thread = thread_result['id']
    state.thread_id = thread
    recorder.record_thread(thread)
    recorder.observe(model=(thread_result.get('model'), 'thread/start:result.thread.model'),
                     effort=(thread_result.get('effort'), 'thread/start:result.thread.effort'))
    if recorder.poll():
        return ('interrupted', None, 'cancelled_before_turn')
    network = payload['role'] in NETWORK_ROLES
    # dangerFullAccess carries no fields: there is nothing to limit once the sandbox is
    # gone, so writableRoots and the /tmp exclusions do not appear for the writers.
    policy = ({'type': 'readOnly', 'networkAccess': network} if sandbox == 'read-only'
              else {'type': 'dangerFullAccess'})
    turn_params = {'threadId': thread, 'model': payload['model'],
        'sandboxPolicy': policy, 'approvalPolicy': 'never',
        'input': [{'type': 'text', 'text': payload['prompt']}]}
    if 'effort' in payload:
        turn_params['effort'] = payload['effort']
    turn_result = rpc.request('turn/start', turn_params)['turn']
    turn = turn_result['id']
    state.accepted = True
    state.turn_id = turn
    recorder.record_turn(turn)
    recorder.observe(model=(turn_result.get('model'), 'turn/start:result.turn.model'),
                     effort=(turn_result.get('effort'), 'turn/start:result.turn.effort'))
    cancel_sent = False
    cancel_at = None
    while True:
        cancel = recorder.poll()
        try:
            runtime_identity_matches(runtime, account)
            changed = False
        except Exception:
            changed = True
        cancel = cancel or rpc.unsupported or changed
        if cancel and cancel_at is None:
            # One deadline covering the interrupt and the completion after it, started where the
            # cancel is first seen, so an interrupt that never answers cannot extend the wait.
            cancel_at = time.monotonic()
            recorder.begin_grace(cancel_at)
        if cancel and not cancel_sent:
            try:
                rpc.request('turn/interrupt', {'threadId': thread, 'turnId': turn}, tick=False)
            except Rejected:
                # Under one deadline a failed interrupt still ends as interrupt_unconfirmed.
                pass
            cancel_sent = True
            if cancel_at is None:
                cancel_at = time.monotonic()
        if cancel and cancel_at is None:
            cancel_at = time.monotonic()
        if cancel_at is not None and time.monotonic()-cancel_at > recorder.grace:
            raise Rejected('interrupt_unconfirmed')
        try:
            msg = rpc.buffer.pop(0) if rpc.buffer else rpc.receive(.25)
        except queue.Empty:
            continue
        params = msg.get('params', {})
        if params.get('threadId') != thread:
            continue
        if params.get('turnId') == turn:
            if msg.get('method') == 'thread/tokenUsage/updated':
                state.usage = params.get('tokenUsage')
                recorder.record_usage(state.usage)
        if msg.get('method') == 'turn/completed' and params.get('turn', {}).get('id') == turn:
            status = params['turn']['status']
            require(status in TERMINAL, 'unsupported_terminal')
            items = params['turn'].get('items', [])
            if status == 'completed' and not any(i.get('type') == 'agentMessage' and i.get('phase') == 'final_answer' for i in items):
                stored = rpc.request('thread/read', {'threadId': thread, 'includeTurns': True})
                items = [i for t in stored['thread']['turns'] if t['id'] == turn for i in t.get('items', [])]
            text = ''
            if status == 'completed':
                try:
                    text = final_answer(items)
                except Rejected as error:
                    # Execution is terminal, but ambiguous output cannot authorize a quality gate.
                    return ('failed', '', str(error))
            return (status, text, 'auth_profile_changed' if changed else
                    'unsupported_server_request' if rpc.unsupported else None)


class ForegroundRecorder:
    # Nothing is persisted; one stop flag and one deadline cover interruption.
    grace = 10

    def __init__(self, execution, stop):
        self.execution = execution
        self.stop = stop
        self.deadline = None

    def tick(self):
        require(not self.stop.is_set(), 'stop_requested')

    def poll(self):
        return self.stop.is_set()

    def record_thread(self, thread):
        pass

    def record_turn(self, turn):
        pass

    def record_usage(self, usage):
        pass

    def observe(self, **observations):
        apply_observations(self.execution, observations)

    def inflight(self, account):
        # This foreground process represents the only in-flight request it can observe.
        return 1

    def account_effective(self, payload, observed):
        # The running account, not the requested label: a caller whose name-to-CODEX_HOME
        # mapping is wrong can only notice by comparing the two afterwards.
        return observed['email'].strip()

    def begin_grace(self, now):
        self.deadline = now + self.grace

    def budget(self):
        return None if self.deadline is None else max(0.0, self.deadline-time.monotonic())

    def aborted(self):
        # Once the grace period has started the interrupt is already out and its completion
        # is what the wait is for, so only a stop seen before that ends a wait early.
        return self.deadline is None and self.stop.is_set()


def watch_caller(stop, chain, interval=1):
    while not stop.wait(interval):
        if ancestors(os.getppid()) != chain:
            stop.set()
            return


def run(request_path):
    execution = None
    state = TurnState()
    status = text = error_kind = None
    rpc = runtime = None
    try:
        payload = json.loads(Path(request_path).read_text())
        require(isinstance(payload, dict), 'invalid_request')
        source = payload.pop('codex_home', None)
        margin = payload.pop('quota_margin_pct', 5)
        require(isinstance(source, str) and source.strip(), 'missing_codex_home')
        require(type(margin) in (int, float) and math.isfinite(margin) and 0 <= margin <= 100,
                'invalid_quota_margin_pct')
        payload.setdefault('request_id', 'run-'+digest(os.urandom(16))[:16])
        # validate_request insists on a label, but the label is only what the result records:
        # when the caller named no account the requested side stays empty in the result.
        label = payload.get('account')
        payload['account'] = label or payload['request_id']
        validate_request(payload)
        execution = execution_metadata(payload)
        execution['requested']['account'] = label or None
        home = Path(source).expanduser().resolve()
        require((home/'auth.json').is_file(), 'codex_home_not_found')
        # Identity comes from the CODEX_HOME the request named, so the match is self-contained:
        # no persistent registry decides which account this is.
        account = dict(auth_info(str(home)), home=str(home), quota_margin_pct=margin)
        stop = threading.Event()
        # The handler only raises the flag; every request to the App Server is sent from the
        # main flow, which checks it at the entry.
        for number in (signal.SIGTERM, signal.SIGINT):
            signal.signal(number, lambda *_: stop.set())
        threading.Thread(target=watch_caller, args=(stop, ancestors(os.getppid())),
                         daemon=True).start()
        recorder = ForegroundRecorder(execution, stop)
        common = git_common_dir(payload['cwd'])
        runtime = foreground_runtime(payload['request_id'], str(home), payload['cwd'], common)
        runtime_identity_matches(runtime, account)
        rpc = Rpc(str(runtime), payload['cwd'])
        rpc.budget = recorder.budget
        rpc.aborted = recorder.aborted
        rpc.poll_wait = .25
        status, text, error_kind = run_turn(rpc, recorder, payload, account, runtime,
                                            payload['cwd'], state)
    except Exception as error:
        # Exception text is deliberately not printed (it may contain credentials).
        status = text = None
        if isinstance(error, ServerRejected) and not state.accepted:
            # The server answered the start request, so no turn is running; keep the code.
            error_kind = 'server_rejected_start_'+str(error.code)
        else:
            error_kind = str(error) if isinstance(error, Rejected) else type(error).__name__
    finally:
        try:
            if rpc:
                rpc.close()
        finally:
            if runtime:
                discard_runtime(runtime)
                shutil.rmtree(runtime.parent, ignore_errors=True)
    print(json.dumps({'text': text or None, 'status': status, 'usage': state.usage,
                      'execution': execution, 'thread_id': state.thread_id,
                      'turn_id': state.turn_id, 'error_kind': error_kind}))
    raise SystemExit(0 if status == 'completed' and error_kind is None else 2)


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    run_parser = sub.add_parser('run')
    run_parser.add_argument('--request', required=True)
    args = parser.parse_args()
    run(args.request)


if __name__ == '__main__':
    main()
