#!/usr/bin/env python3
"""Account-bound, detached App Server worker. Initial supported origin: manual."""
import argparse
import base64
import hashlib
import json
import math
import os
from pathlib import Path
import queue
import re
import sqlite3
import subprocess
import sys
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
# authentication or billing to an account the ledger does not know, and values that would
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


def db_open(directory):
    path = Path(directory).expanduser().resolve()
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    require(path.stat().st_uid == os.getuid() and path.stat().st_mode & 0o077 == 0,
            'state_directory_must_be_private')
    db = sqlite3.connect(path / 'ledger.sqlite', timeout=10, isolation_level=None)
    os.chmod(path / 'ledger.sqlite', 0o600)
    db.row_factory = sqlite3.Row
    db.executescript('''
    CREATE TABLE IF NOT EXISTS accounts(name TEXT PRIMARY KEY, home TEXT UNIQUE, identity TEXT, auth_hash TEXT, account_id_hash TEXT);
    CREATE UNIQUE INDEX IF NOT EXISTS account_identity ON accounts(account_id_hash);
    CREATE TABLE IF NOT EXISTS jobs(id TEXT PRIMARY KEY, payload_hash TEXT, payload TEXT, account TEXT, cwd TEXT,
      status TEXT, acked INTEGER DEFAULT 0, created REAL, updated REAL, pid INTEGER,
      thread_id TEXT, turn_id TEXT, text TEXT, usage TEXT, error_kind TEXT, cancel INTEGER DEFAULT 0,
      execution TEXT);
    ''')
    columns = {row[1] for row in db.execute('PRAGMA table_info(accounts)')}
    if 'max_concurrent' not in columns:
        db.execute('ALTER TABLE accounts ADD COLUMN max_concurrent INTEGER DEFAULT 3')
    if 'quota_margin_pct' not in columns:
        db.execute('ALTER TABLE accounts ADD COLUMN quota_margin_pct REAL DEFAULT 5')
    job_columns = {row[1] for row in db.execute('PRAGMA table_info(jobs)')}
    if 'execution' not in job_columns:
        db.execute('ALTER TABLE jobs ADD COLUMN execution TEXT')
    return db


def public(row):
    return {key: row[key] for key in ('status', 'acked', 'created', 'updated', 'thread_id',
                                     'turn_id', 'text', 'error_kind')} | {'job_id': row['id'],
        'usage': json.loads(row['usage']) if row['usage'] else None,
        'execution': json.loads(row['execution']) if row['execution'] else None}


def update(db, job, **values):
    values['updated'] = time.time()
    db.execute('UPDATE jobs SET ' + ','.join(k+'=?' for k in values) + ' WHERE id=?',
               [*values.values(), job])


def get_job(db, job):
    row = db.execute('SELECT * FROM jobs WHERE id=?', (job,)).fetchone()
    require(row is not None, 'job_not_found')
    if row['status'] in ('queued', 'running') and time.time()-row['updated'] > 30:
        # A lost heartbeat is uncertainty, never a license to run another job.
        update(db, job, status='unknown', error_kind='worker_heartbeat_lost')
        row = db.execute('SELECT * FROM jobs WHERE id=?', (job,)).fetchone()
    return row


def git_env():
    # Fixed minimal allowlist for the worker's own git calls only. The caller's GIT_* must
    # never redirect the linked-worktree and ownership checks to another checkout, so these
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


def ownership_open():
    root = Path.home() / '.local/state/claude-harness-codex'
    root.mkdir(parents=True, mode=0o700, exist_ok=True)
    require(root.stat().st_uid == os.getuid() and root.stat().st_mode & 0o077 == 0, 'ownership_directory_not_private')
    conn = sqlite3.connect(root / 'ownership.sqlite', isolation_level=None, timeout=10)
    os.chmod(root / 'ownership.sqlite', 0o600)
    conn.execute('CREATE TABLE IF NOT EXISTS owners(key TEXT PRIMARY KEY, ledger TEXT, job TEXT)')
    conn.execute('CREATE TABLE IF NOT EXISTS account_slots(account_key TEXT, slot INTEGER, ledger TEXT, job TEXT,'
                 ' PRIMARY KEY(account_key, slot))')
    return conn


def slot_state(ledger, job):
    # The referenced ledger is the only evidence; a slot row alone never means the job ended.
    # Only 'acked' is free. A slot whose ledger cannot be read stays occupied, never reusable.
    if not ledger or not Path(ledger).is_file():
        return 'ledger_missing', None
    prior = None
    try:
        # Opening can fail too (unreadable file), so it belongs inside the guard.
        prior = sqlite3.connect('file:'+ledger+'?mode=ro', uri=True, timeout=10)
        row = prior.execute('SELECT status,acked,updated FROM jobs WHERE id=?', (job,)).fetchone()
    except sqlite3.DatabaseError:
        return 'ledger_missing', None
    finally:
        if prior:
            prior.close()
    if not row:
        return 'ledger_missing', None
    if row[0] not in TERMINAL:
        return ('unknown' if row[0] == 'unknown' else 'active'), row[2]
    return ('acked' if row[1] == 1 else 'unacked'), row[2]


def occupied_slots(account_id_hash):
    conn = ownership_open()
    try:
        rows = conn.execute('SELECT ledger,job FROM account_slots WHERE account_key=?',
                            ('account:'+account_id_hash,)).fetchall()
    finally:
        conn.close()
    return sum(1 for row in rows if slot_state(row[0], row[1])[0] != 'acked')


def reserve_global(directory, job, account, cwd):
    conn = ownership_open()
    try:
        conn.execute('BEGIN IMMEDIATE')
        account_key = 'account:'+account['account_id_hash']
        cwd_key = 'cwd:'+digest(cwd.encode())
        ledger = str(Path(directory).resolve()/'ledger.sqlite')
        legacy = conn.execute('SELECT ledger,job FROM owners WHERE key=?', (account_key,)).fetchone()
        if legacy:
            # Older versions held the account as a single owners row; carry it into slot 0.
            if not conn.execute('SELECT 1 FROM account_slots WHERE account_key=? AND slot=0', (account_key,)).fetchone():
                conn.execute('INSERT INTO account_slots VALUES(?,0,?,?)', (account_key, legacy[0], legacy[1]))
            conn.execute('DELETE FROM owners WHERE key=?', (account_key,))
        old = conn.execute('SELECT ledger,job FROM owners WHERE key=?', (cwd_key,)).fetchone()
        if old and tuple(old) != (ledger, job):
            require(Path(old[0]).is_file(), 'global_owner_unknown')
            prior = None
            try:
                prior = sqlite3.connect('file:'+old[0]+'?mode=ro', uri=True)
                row = prior.execute('SELECT status,acked FROM jobs WHERE id=?', (old[1],)).fetchone()
            except sqlite3.DatabaseError:
                raise Rejected('global_owner_unknown')
            finally:
                if prior:
                    prior.close()
            require(row and row[0] in TERMINAL and row[1] == 1, 'global_cwd_locked')
        conn.execute('INSERT INTO owners VALUES(?,?,?) ON CONFLICT(key) DO UPDATE SET ledger=excluded.ledger,job=excluded.job',
                     (cwd_key, ledger, job))
        taken = {row[0]: (row[1], row[2]) for row in
                 conn.execute('SELECT slot,ledger,job FROM account_slots WHERE account_key=?', (account_key,))}
        # The limit counts occupied slots, whatever their number: another state-dir registered with a
        # larger limit can hold slots at or above this limit's range, and those still spend the account.
        occupied = sum(1 for slot, ref in taken.items()
                       if ref != (ledger, job) and slot_state(*ref)[0] != 'acked')
        require(occupied < account['max_concurrent'], 'account_slots_exhausted')
        free = next((slot for slot in range(account['max_concurrent'])
                     if taken.get(slot) in (None, (ledger, job)) or slot_state(*taken[slot])[0] == 'acked'), None)
        require(free is not None, 'account_slots_exhausted')
        conn.execute('INSERT INTO account_slots VALUES(?,?,?,?) ON CONFLICT(account_key,slot) DO UPDATE SET ledger=excluded.ledger,job=excluded.job',
                     (account_key, free, ledger, job))
        conn.execute('COMMIT')
    finally:
        conn.close()


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


def observe_execution(db, job, **observations):
    row = db.execute('SELECT execution FROM jobs WHERE id=?', (job,)).fetchone()
    if not row or not row[0]:
        return
    execution = json.loads(row[0])
    for key, (value, source) in observations.items():
        if value is not None:
            execution['effective'][key] = value
            execution['evidence'][key] = source
    update(db, job, execution=json.dumps(execution, sort_keys=True))


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


def runtime_home(directory, job, source, cwd, common):
    # The Git project config layer can re-enable external tools; initial version refuses it.
    project = Path(cwd)
    roots = {project, Path(common).parent, *project.parents}
    # The normal user config is intentionally replaced by runtime config, not a project layer.
    roots.discard(Path.home())
    require(not any((root/'.codex/config.toml').exists() for root in roots), 'unsupported_project_config')
    runtime = Path(directory)/'runtimes'/job
    runtime.mkdir(parents=True, mode=0o700, exist_ok=False)
    (runtime/'auth.json').symlink_to(Path(source)/'auth.json')
    (runtime/'config.toml').write_text('cli_auth_credentials_store = "file"\n[features]\napps = false\n')
    os.chmod(runtime/'config.toml', 0o600)
    return runtime


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
        # Each concurrent slot will spend before the next window read, so reserve for all of them.
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
        threading.Thread(target=self.reader, daemon=True).start()

    def reader(self):
        try:
            for line in self.proc.stdout:
                self.events.put(json.loads(line))
        except Exception:
            pass
        self.events.put({'disconnected': True})

    def send(self, msg):
        self.proc.stdin.write(json.dumps(msg)+'\n')
        self.proc.stdin.flush()

    def receive(self, timeout):
        msg = self.events.get(timeout=timeout)
        if msg.get('disconnected'):
            raise Rejected('transport_disconnected')
        if 'method' in msg and 'id' in msg:
            self.unsupported = True
            self.send({'id': msg['id'], 'error': {'code': -32601, 'message': 'Unsupported worker request'}})
        return msg

    def request(self, method, params):
        self.tick()
        self.next_id += 1
        rid = self.next_id
        self.send({'id': rid, 'method': method, 'params': params})
        deadline = time.monotonic()+15
        while time.monotonic() < deadline:
            msg = self.receive(max(.001, deadline-time.monotonic()))
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


def worker(directory, job):
    db = db_open(directory)
    rpc = None
    # Two different facts, and the job's terminal state depends on which one holds:
    # turn_submitted means the request went out, so the model may already be running and
    # a failure afterwards is uncertainty (unknown); turn_accepted means the server
    # answered with a turn id, so an error before it proves no turn ever started (failed).
    turn_submitted = False
    turn_accepted = False
    execution_confirmed = False
    runtime = None
    claimed = False
    try:
        db.execute('BEGIN IMMEDIATE')
        row = get_job(db, job)
        require(row['status'] == 'queued', 'job_not_queued')
        update(db, job, status='running', pid=os.getpid())
        claimed = True
        db.execute('COMMIT')
        payload = json.loads(row['payload'])
        account = db.execute('SELECT * FROM accounts WHERE name=?', (row['account'],)).fetchone()
        actual = auth_info(account['home'])
        require(all(actual[k] == account[k] for k in actual), 'auth_profile_changed')
        # Repeat filesystem/branch checks immediately before execution.
        validate_request(payload)
        common = git_common_dir(row['cwd'])
        runtime = runtime_home(directory, job, account['home'], row['cwd'], common)
        runtime_identity_matches(runtime, account)
        sandbox = ROLES[payload['role']]
        rpc = Rpc(str(runtime), row['cwd'])
        def heartbeat():
            current = db.execute('SELECT status FROM jobs WHERE id=?', (job,)).fetchone()
            require(current and current['status'] == 'running', 'ledger_no_longer_running')
            update(db, job)
        rpc.tick = heartbeat
        rpc.request('initialize', {'clientInfo': {'name': 'harness-worker', 'version': '1'}})
        rpc.send({'method': 'initialized', 'params': {}})
        observed = rpc.request('account/read', {'refreshToken': False}).get('account') or {}
        require(observed.get('type') == 'chatgpt' and observed.get('email') and
                digest(observed['email'].strip().lower().encode()) == account['identity'], 'server_identity_mismatch')
        observe_execution(db, job, executor=('codex', 'transport:codex-app-server'),
                          account=(payload['account'], 'account/read:account.email'))
        runtime_identity_matches(runtime, account)
        advertised_model(rpc, payload['model'], payload.get('effort'))
        limits = rpc.request('account/rateLimits/read', {})
        # Count after the reply: a slot reserved while the read was in flight must enter this judgment.
        # Legacy jobs predate account_slots, so never count fewer than this job itself.
        inflight = max(occupied_slots(account['account_id_hash']), 1)
        quota_available(limits, account['quota_margin_pct'], inflight)
        thread_result = rpc.request('thread/start', {'cwd': row['cwd'], 'model': payload['model'],
            'sandbox': sandbox, 'approvalPolicy': 'never', 'modelProvider': 'openai'})['thread']
        thread = thread_result['id']
        update(db, job, thread_id=thread)
        observe_execution(db, job,
                          model=(thread_result.get('model'), 'thread/start:result.thread.model'),
                          effort=(thread_result.get('effort'), 'thread/start:result.thread.effort'))
        if db.execute('SELECT cancel FROM jobs WHERE id=?', (job,)).fetchone()[0]:
            update(db, job, status='interrupted', error_kind='cancelled_before_turn')
            return
        network = payload['role'] in NETWORK_ROLES
        # dangerFullAccess carries no fields: there is nothing to limit once the sandbox is
        # gone, so writableRoots and the /tmp exclusions do not appear for the writers.
        policy = ({'type': 'readOnly', 'networkAccess': network} if sandbox == 'read-only'
                  else {'type': 'dangerFullAccess'})
        turn_submitted = True
        turn_params = {'threadId': thread, 'model': payload['model'],
            'sandboxPolicy': policy, 'approvalPolicy': 'never',
            'input': [{'type': 'text', 'text': payload['prompt']}]}
        if 'effort' in payload:
            turn_params['effort'] = payload['effort']
        turn_result = rpc.request('turn/start', turn_params)['turn']
        turn = turn_result['id']
        turn_accepted = True
        update(db, job, turn_id=turn)
        observe_execution(db, job,
                          model=(turn_result.get('model'), 'turn/start:result.turn.model'),
                          effort=(turn_result.get('effort'), 'turn/start:result.turn.effort'))
        cancel_sent = False
        cancel_at = None
        activity = False
        while True:
            current = db.execute('SELECT status,cancel FROM jobs WHERE id=?', (job,)).fetchone()
            require(current['status'] == 'running', 'ledger_no_longer_running')
            update(db, job)
            try:
                runtime_identity_matches(runtime, account)
                changed = False
            except Exception:
                changed = True
            cancel = current['cancel'] or rpc.unsupported or changed
            if cancel and activity and not cancel_sent:
                rpc.request('turn/interrupt', {'threadId': thread, 'turnId': turn})
                cancel_sent = True
                cancel_at = time.monotonic()
            if cancel and cancel_at is None:
                cancel_at = time.monotonic()
            if cancel_at and time.monotonic()-cancel_at > 20:
                raise Rejected('interrupt_unconfirmed')
            try:
                msg = rpc.buffer.pop(0) if rpc.buffer else rpc.receive(.25)
            except queue.Empty:
                continue
            params = msg.get('params', {})
            if params.get('threadId') != thread:
                continue
            if params.get('turnId') == turn:
                activity = True
                if msg.get('method') == 'thread/tokenUsage/updated':
                    update(db, job, usage=json.dumps(params.get('tokenUsage')))
            if msg.get('method') == 'turn/completed' and params.get('turn', {}).get('id') == turn:
                status = params['turn']['status']
                require(status in TERMINAL, 'unsupported_terminal')
                execution_confirmed = True
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
                        update(db, job, status='failed', text='', error_kind=str(error))
                        return
                update(db, job, status=status, text=text,
                       error_kind='auth_profile_changed' if changed else 'unsupported_server_request' if rpc.unsupported else None)
                return
    except Exception as error:
        if db.in_transaction:
            db.execute('ROLLBACK')
        # Exception text is deliberately not persisted (it may contain credentials).
        kind = str(error) if isinstance(error, Rejected) else type(error).__name__
        if claimed:
            if isinstance(error, ServerRejected) and not turn_accepted:
                # The server answered the start request, so no turn is running; record the code.
                update(db, job, status='failed', error_kind='server_rejected_start_'+str(error.code))
            else:
                # A confirmed terminal turn is not uncertainty, whatever failed afterwards.
                update(db, job, status='unknown' if turn_submitted and not execution_confirmed else 'failed',
                       error_kind=kind)
    finally:
        try:
            if rpc:
                rpc.close()
        finally:
            if runtime:
                # The runtime's link to the authentication profile never outlives the job.
                (runtime/'auth.json').unlink(missing_ok=True)
            db.close()


def command(args):
    db = db_open(args.state_dir)
    try:
        if args.command == 'register':
            require(re.fullmatch(r'[A-Za-z0-9_-]{1,100}', args.account), 'invalid_account_name')
            require(args.max_concurrent >= 1, 'invalid_max_concurrent')
            require(math.isfinite(args.quota_margin_pct) and 0 <= args.quota_margin_pct <= 100, 'invalid_quota_margin_pct')
            home = str(Path(args.codex_home).expanduser().resolve())
            require(Path(home).stat().st_uid == os.getuid(), 'profile_not_owned')
            info = auth_info(home)
            db.execute('BEGIN IMMEDIATE')
            require(not db.execute('SELECT 1 FROM jobs WHERE account=? AND acked=0', (args.account,)).fetchone(), 'account_has_unacknowledged_jobs')
            # Omitted options restore the defaults: the limit is whatever the latest registration says.
            db.execute('INSERT INTO accounts(name,home,identity,auth_hash,account_id_hash,max_concurrent,quota_margin_pct)'
                       ' VALUES(?,?,?,?,?,?,?) ON CONFLICT(name) DO UPDATE SET home=excluded.home, identity=excluded.identity,'
                       'auth_hash=excluded.auth_hash,account_id_hash=excluded.account_id_hash,'
                       'max_concurrent=excluded.max_concurrent,quota_margin_pct=excluded.quota_margin_pct',
                       (args.account, home, info['identity'], info['auth_hash'], info['account_id_hash'],
                        args.max_concurrent, args.quota_margin_pct))
            db.execute('COMMIT')
            return {'account': args.account, 'registered': True, 'max_concurrent': args.max_concurrent,
                    'quota_margin_pct': args.quota_margin_pct}
        if args.command == 'reap':
            require(args.older_than >= 0, 'invalid_older_than')
            rows = db.execute('SELECT name,account_id_hash FROM accounts' + (' WHERE name=?' if args.account else ''),
                              (args.account,) if args.account else ()).fetchall()
            require(rows or not args.account, 'account_not_registered')
            released, kept = [], []
            conn = ownership_open()
            try:
                conn.execute('BEGIN IMMEDIATE')
                for account in rows:
                    key = 'account:'+account['account_id_hash']
                    slots = conn.execute('SELECT slot,ledger,job FROM account_slots WHERE account_key=? ORDER BY slot',
                                         (key,)).fetchall()
                    for slot, ledger, job in slots:
                        state, updated = slot_state(ledger, job)
                        entry = {'account': account['name'], 'slot': slot, 'job': job}
                        stale = state == 'unacked' and time.time()-updated > args.older_than
                        if state == 'acked' or stale:
                            conn.execute('DELETE FROM account_slots WHERE account_key=? AND slot=?', (key, slot))
                            released.append(entry | {'reason': 'stale_unacked' if stale else 'acked'})
                        else:
                            # unknown and ledger_missing are unobserved endings; never free them.
                            kept.append(entry | {'reason': 'not_stale' if state == 'unacked' else state})
                conn.execute('COMMIT')
            finally:
                conn.close()
            return {'released': released, 'kept': kept}
        if args.command == 'submit':
            payload = validate_request(json.loads(Path(args.request).read_text()))
            encoded = json.dumps(payload, sort_keys=True)
            job = payload['request_id']
            db.execute('BEGIN IMMEDIATE')
            old = db.execute('SELECT * FROM jobs WHERE id=?', (job,)).fetchone()
            if old:
                require(old['payload_hash'] == digest(encoded.encode()), 'request_id_conflict')
                db.execute('COMMIT')
                return public(get_job(db, job))
            account = db.execute('SELECT * FROM accounts WHERE name=?', (payload['account'],)).fetchone()
            require(account is not None, 'account_not_registered')
            # Account concurrency is decided by the shared slots; here only the working directory.
            require(not db.execute('SELECT 1 FROM jobs WHERE acked=0 AND cwd=?',
                (payload['cwd'],)).fetchone(), 'cwd_locked')
            reserve_global(args.state_dir, job, account, payload['cwd'])
            now = time.time()
            db.execute('INSERT INTO jobs(id,payload_hash,payload,account,cwd,status,created,updated,execution) VALUES(?,?,?,?,?,?,?,?,?)',
                (job, digest(encoded.encode()), encoded, payload['account'], payload['cwd'], 'queued', now, now,
                 json.dumps(execution_metadata(payload), sort_keys=True)))
            db.execute('COMMIT')
            try:
                subprocess.Popen([sys.executable, str(Path(__file__).resolve()), '--state-dir', args.state_dir,
                    '_worker', '--job', job], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL, start_new_session=True, close_fds=True)
            except Exception:
                update(db, job, status='unknown', error_kind='worker_spawn_failed')
            return public(get_job(db, job))
        if args.command == 'send':
            raise Rejected('unsupported_send_context_metrics_not_verified_use_fresh_job_after_ack')
        db.execute('BEGIN IMMEDIATE')
        row = get_job(db, args.job)
        if args.command == 'cancel':
            require(not row['acked'], 'already_acknowledged')
            require(row['status'] in ('queued', 'running'), 'not_cancellable_or_unknown')
            update(db, args.job, cancel=1)
        elif args.command == 'ack':
            require(row['status'] in TERMINAL, 'cannot_ack_unconfirmed_execution')
            update(db, args.job, acked=1)
        result = public(get_job(db, args.job))
        db.execute('COMMIT')
        return result
    finally:
        db.close()


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--state-dir', required=True)
    subs = parser.add_subparsers(dest='command', required=True)
    register = subs.add_parser('register')
    register.add_argument('--account', required=True)
    register.add_argument('--codex-home', required=True)
    register.add_argument('--max-concurrent', type=int, default=3)
    register.add_argument('--quota-margin-pct', type=float, default=5)
    submit = subs.add_parser('submit')
    submit.add_argument('--request', required=True)
    reap = subs.add_parser('reap')
    reap.add_argument('--older-than', type=float, default=86400)
    reap.add_argument('--account')
    for name in ('status', 'result', 'cancel', 'ack', 'send', '_worker'):
        sub = subs.add_parser(name)
        sub.add_argument('--job', required=True)
        if name == 'send':
            sub.add_argument('--request', required=True)
    args = parser.parse_args()
    args.state_dir = str(Path(args.state_dir).expanduser().resolve())
    if args.command == '_worker':
        worker(args.state_dir, args.job)
        return
    try:
        print(json.dumps(command(args)))
    except Exception as error:
        print(json.dumps({'error': str(error) if isinstance(error, Rejected) else type(error).__name__}))
        raise SystemExit(2)


if __name__ == '__main__':
    main()
