#!/usr/bin/env python3
"""Nonblocking Codex quota cache. Never persist credentials or raw RPC responses."""
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import sys
import tempfile
import time

TTL = 180
RETRY = 60
TIMEOUT = 15


def identity():
    home = Path(os.environ.get('CODEX_HOME', str(Path.home() / '.codex'))).expanduser()
    try:
        auth = (home / 'auth.json').read_bytes()
        doc = json.loads(auth)
        if not isinstance(doc, dict) or not doc.get('tokens'):
            return None  # API-key authentication has no ChatGPT quota.
        return hashlib.sha256(str(home.resolve()).encode() + b'\0' + auth).hexdigest()
    except (OSError, ValueError):
        return None


def windows(result):
    """Select the normal Codex bucket, never accidentally display Spark limits."""
    buckets = result.get('rateLimitsByLimitId')
    bucket = buckets.get('codex') if isinstance(buckets, dict) else result.get('rateLimits')
    if not isinstance(bucket, dict) or bucket.get('limitId') not in (None, 'codex'):
        return []
    out = []
    for name in ('primary', 'secondary'):
        w = bucket.get(name)
        if not isinstance(w, dict):
            continue
        pct, mins, reset = (w.get(k) for k in ('usedPercent', 'windowDurationMins', 'resetsAt'))
        if (type(pct) not in (int, float) or not math.isfinite(pct) or not 0 <= pct <= 100
                or type(mins) is not int or not 0 < mins <= 525600
                or type(reset) is not int or not 0 < reset < 100000000000):
            continue
        out.append({'pct': int(pct + 0.5), 'minutes': mins, 'reset': reset})
    return out


def read_json(path):
    try:
        d = json.loads(path.read_text())
        if not isinstance(d, dict):
            return {}
        retry = d.get('next_attempt', 0)
        if type(retry) is not int or not 0 <= retry <= int(time.time()) + TTL + 5:
            return {}  # Corrupt/future retry dates must not disable recovery forever.
        if not isinstance(d.get('windows', []), list):
            return {}
        return d
    except (OSError, ValueError):
        return {}


def atomic(path, doc):
    fd, tmp = tempfile.mkstemp(prefix=path.name + '.', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(doc, stream)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def fetch(binary):
    proc = subprocess.Popen([binary, 'app-server'], stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    sel = selectors.DefaultSelector()
    sel.register(proc.stdout, selectors.EVENT_READ)
    deadline, buffer = time.monotonic() + TIMEOUT, b''
    def send(doc):
        proc.stdin.write((json.dumps(doc) + '\n').encode())
        proc.stdin.flush()
    try:
        send({'id': 1, 'method': 'initialize', 'params': {
            'clientInfo': {'name': 'claude-statusline', 'version': '1.0.0'}}})
        while time.monotonic() < deadline:
            if not sel.select(max(0, deadline - time.monotonic())):
                break
            chunk = os.read(proc.stdout.fileno(), 65536)
            if not chunk:
                break
            buffer += chunk
            if len(buffer) > 1048576:
                raise ValueError('oversize RPC')
            while b'\n' in buffer:
                line, buffer = buffer.split(b'\n', 1)
                msg = json.loads(line)
                if msg.get('id') == 1:
                    if 'error' in msg:
                        raise ValueError('initialize failed')
                    send({'method': 'initialized'})
                    send({'id': 2, 'method': 'account/rateLimits/read'})
                elif msg.get('id') == 2:
                    if 'error' in msg:
                        raise ValueError('quota unavailable')
                    return windows(msg['result'])
        raise TimeoutError('quota timeout')
    finally:
        sel.close()
        proc.terminate()
        try:
            proc.wait(timeout=1)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
        proc.stdin.close()
        proc.stdout.close()


def refresh(cache, binary, key):
    # flock is released by the OS on crashes: no stale PID/lock-directory races.
    with open(str(cache) + '.lock', 'a') as lock:
        os.chmod(lock.name, 0o600)
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        previous = read_json(cache)
        now = int(time.time())
        if previous.get('identity') == key and now < previous.get('next_attempt', 0):
            return
        doc = {'identity': key, 'next_attempt': now + RETRY, 'windows': []}
        if previous.get('identity') == key:
            doc.update({k: previous[k] for k in ('fetched_at', 'windows') if k in previous})
        # Reserve retry interval before RPC, including crashes/timeouts.
        atomic(cache, doc)
        try:
            data = fetch(binary)
            if identity() != key:
                return
            doc = {'identity': key, 'next_attempt': now + TTL,
                   'fetched_at': int(time.time()), 'windows': data}
        except (OSError, ValueError, KeyError, TypeError, TimeoutError):
            pass
        atomic(cache, doc)


def main():
    key = identity()
    binary = shutil.which(os.environ.get('STATUSLINE_CODEX_BIN', 'codex'))
    if not key or not binary:
        return
    folder = Path(os.environ.get('CLAUDE_CONFIG_DIR', str(Path.home() / '.claude')))
    folder.mkdir(parents=True, exist_ok=True)
    cache = folder / '.statusline-codex'
    if '--refresh' in sys.argv:
        refresh(cache, binary, key)
        return
    doc = read_json(cache)
    now = int(time.time())
    if doc.get('identity') != key:
        doc = {}
    if now >= doc.get('next_attempt', 0):
        subprocess.Popen([sys.executable, str(Path(__file__).resolve()), '--refresh'],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True, close_fds=True)
    # Revalidate cached fields too; hand-edited/corrupt cache must never reach Bash arithmetic.
    valid = windows({'rateLimits': {name: {'usedPercent': w.get('pct'),
                    'windowDurationMins': w.get('minutes'), 'resetsAt': w.get('reset')}
                    for name, w in zip(('primary', 'secondary'), doc.get('windows', []))
                    if isinstance(w, dict)}})
    fetched = doc.get('fetched_at')
    if type(fetched) is not int or fetched < 0:
        valid = []
    if not valid:
        print('pending')
    else:
        for w in valid:
            print('{}\t{}\t{}\t{}'.format(w['pct'], w['minutes'], w['reset'], fetched))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, TypeError):
        pass  # Statusline must remain usable when quota retrieval is unavailable.
