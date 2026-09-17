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
ROLES = {'implement': 'workspace-write', 'spec-write': 'workspace-write',
         'review': 'read-only', 'spec-review': 'read-only',
         'impl-review': 'read-only', 'decider': 'read-only'}


class Rejected(Exception):
    pass


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
      thread_id TEXT, turn_id TEXT, text TEXT, usage TEXT, error_kind TEXT, cancel INTEGER DEFAULT 0);
    ''')
    return db


def public(row):
    return {key: row[key] for key in ('status', 'acked', 'created', 'updated', 'thread_id',
                                     'turn_id', 'text', 'error_kind')} | {'job_id': row['id'],
        'usage': json.loads(row['usage']) if row['usage'] else None}


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


def validate_request(payload):
    require(set(payload) <= {'request_id', 'origin', 'account', 'cwd', 'model', 'role', 'prompt'}, 'unknown_request_field')
    for field in ('request_id', 'account', 'cwd', 'model', 'role', 'prompt'):
        require(isinstance(payload.get(field), str) and bool(payload[field].strip()), 'missing_'+field)
    require(re.fullmatch(r'[A-Za-z0-9_-]{1,100}', payload['request_id']), 'invalid_request_id')
    require(payload.get('origin') == 'manual', 'unsupported_origin')
    require(payload['role'] in ROLES, 'unsupported_role')
    cwd = Path(payload['cwd']).expanduser().resolve()
    require(cwd.is_dir() and cwd.stat().st_uid == os.getuid(), 'cwd_not_owned')
    def git(*args):
        return subprocess.check_output(['git', '-C', str(cwd), *args], stderr=subprocess.DEVNULL, text=True).strip()
    require(Path(git('rev-parse', '--show-toplevel')).resolve() == cwd, 'cwd_must_be_repo_root')
    branch = git('branch', '--show-current')
    require(branch and branch not in ('main', 'master'), 'feature_branch_required')
    # A real linked worktree prevents accidental operation on the main checkout.
    require((cwd / '.git').is_file(), 'linked_worktree_required')
    payload['cwd'] = str(cwd)
    return payload


def quota_available(result):
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
        found = True
    require(found, 'quota_unknown')


class Rpc:
    def __init__(self, home, cwd):
        env = dict(os.environ)
        for name in list(env):
            if name in ('OPENAI_API_KEY', 'OPENAI_BASE_URL', 'CODEX_COMPANION_APP_SERVER_ENDPOINT'):
                env.pop(name)
        env['CODEX_HOME'] = home
        self.proc = subprocess.Popen(['codex', 'app-server', '-c', 'model_provider="openai"'], cwd=cwd, env=env,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        self.events = queue.Queue()
        self.buffer = []
        self.next_id = 0
        self.unsupported = False
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
        self.next_id += 1
        rid = self.next_id
        self.send({'id': rid, 'method': method, 'params': params})
        deadline = time.monotonic()+15
        while time.monotonic() < deadline:
            msg = self.receive(max(.001, deadline-time.monotonic()))
            if msg.get('id') == rid and 'method' not in msg:
                if msg.get('error'):
                    raise Rejected('rpc_error_'+str(msg['error'].get('code')))
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


def worker(directory, job):
    db = db_open(directory)
    rpc = None
    try:
        db.execute('BEGIN IMMEDIATE')
        row = get_job(db, job)
        require(row['status'] == 'queued', 'job_not_queued')
        update(db, job, status='running', pid=os.getpid())
        db.execute('COMMIT')
        payload = json.loads(row['payload'])
        account = db.execute('SELECT * FROM accounts WHERE name=?', (row['account'],)).fetchone()
        actual = auth_info(account['home'])
        require(all(actual[k] == account[k] for k in actual), 'auth_profile_changed')
        # Repeat filesystem/branch checks immediately before execution.
        validate_request(payload)
        rpc = Rpc(account['home'], row['cwd'])
        rpc.request('initialize', {'clientInfo': {'name': 'harness-worker', 'version': '1'}})
        rpc.send({'method': 'initialized', 'params': {}})
        observed = rpc.request('account/read', {'refreshToken': False}).get('account') or {}
        require(observed.get('type') == 'chatgpt' and observed.get('email') and
                digest(observed['email'].strip().lower().encode()) == account['identity'], 'server_identity_mismatch')
        require(auth_info(account['home'])['auth_hash'] == account['auth_hash'], 'auth_profile_changed')
        quota_available(rpc.request('account/rateLimits/read', {}))
        sandbox = ROLES[payload['role']]
        thread = rpc.request('thread/start', {'cwd': row['cwd'], 'model': payload['model'],
            'sandbox': sandbox, 'approvalPolicy': 'never', 'modelProvider': 'openai'})['thread']['id']
        update(db, job, thread_id=thread)
        if db.execute('SELECT cancel FROM jobs WHERE id=?', (job,)).fetchone()[0]:
            update(db, job, status='interrupted', error_kind='cancelled_before_turn')
            return
        turn = rpc.request('turn/start', {'threadId': thread, 'model': payload['model'],
            'input': [{'type': 'text', 'text': payload['prompt']}]})['turn']['id']
        update(db, job, turn_id=turn)
        cancel_sent = False
        cancel_at = None
        activity = False
        while True:
            current = db.execute('SELECT status,cancel FROM jobs WHERE id=?', (job,)).fetchone()
            require(current['status'] == 'running', 'ledger_no_longer_running')
            update(db, job)
            changed = auth_info(account['home'])['auth_hash'] != account['auth_hash']
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
                items = params['turn'].get('items', [])
                if status == 'completed' and not any(i.get('type') == 'agentMessage' for i in items):
                    stored = rpc.request('thread/read', {'threadId': thread, 'includeTurns': True})
                    items = [i for t in stored['thread']['turns'] if t['id'] == turn for i in t.get('items', [])]
                text = '\n'.join(i.get('text', '') for i in items if i.get('type') == 'agentMessage')
                require(status != 'completed' or text.strip(), 'result_missing')
                update(db, job, status=status, text=text,
                       error_kind='auth_profile_changed' if changed else 'unsupported_server_request' if rpc.unsupported else None)
                return
    except Exception as error:
        if db.in_transaction:
            db.execute('ROLLBACK')
        # Exception text is deliberately not persisted (it may contain credentials).
        kind = str(error) if isinstance(error, Rejected) else type(error).__name__
        update(db, job, status='unknown', error_kind=kind)
    finally:
        if rpc:
            rpc.close()
        db.close()


def command(args):
    db = db_open(args.state_dir)
    try:
        if args.command == 'register':
            require(re.fullmatch(r'[A-Za-z0-9_-]{1,100}', args.account), 'invalid_account_name')
            home = str(Path(args.codex_home).expanduser().resolve())
            require(Path(home).stat().st_uid == os.getuid(), 'profile_not_owned')
            info = auth_info(home)
            db.execute('BEGIN IMMEDIATE')
            require(not db.execute('SELECT 1 FROM jobs WHERE account=? AND acked=0', (args.account,)).fetchone(), 'account_has_unacknowledged_jobs')
            db.execute('INSERT INTO accounts VALUES(?,?,?,?,?) ON CONFLICT(name) DO UPDATE SET home=excluded.home, identity=excluded.identity,auth_hash=excluded.auth_hash,account_id_hash=excluded.account_id_hash',
                       (args.account, home, info['identity'], info['auth_hash'], info['account_id_hash']))
            db.execute('COMMIT')
            return {'account': args.account, 'registered': True}
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
            require(not db.execute('SELECT 1 FROM jobs WHERE acked=0 AND (cwd=? OR account=?)',
                (payload['cwd'], payload['account'])).fetchone(), 'cwd_or_account_locked')
            now = time.time()
            db.execute('INSERT INTO jobs(id,payload_hash,payload,account,cwd,status,created,updated) VALUES(?,?,?,?,?,?,?,?)',
                (job, digest(encoded.encode()), encoded, payload['account'], payload['cwd'], 'queued', now, now))
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
    submit = subs.add_parser('submit')
    submit.add_argument('--request', required=True)
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
