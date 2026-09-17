#!/usr/bin/env python3
"""Bounded read-only App Server experiment; never an execution worker."""
import argparse
import hashlib
import json
import os
import queue
import subprocess
import threading
import time


def fingerprint(account):
    if not account or account.get('type') != 'chatgpt' or not account.get('email'):
        return None
    return hashlib.sha256(('chatgpt:' + account['email'].strip().lower()).encode()).hexdigest()


def interrupt_pass(status, requested):
    return requested and status == 'interrupted'


class Client:
    def __init__(self, command, cwd):
        self.proc = subprocess.Popen(command, cwd=cwd, stdin=subprocess.PIPE,
                                     stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        self.events = queue.Queue()
        self.buffer = []
        self.next_id = 0
        self.server_request = False
        threading.Thread(target=self._read, daemon=True).start()

    def _read(self):
        try:
            for line in self.proc.stdout:
                self.events.put(json.loads(line))
        except Exception:
            pass
        finally:
            self.events.put({'disconnected': True})

    def send(self, msg):
        self.proc.stdin.write(json.dumps(msg) + '\n')
        self.proc.stdin.flush()

    def receive(self, deadline):
        try:
            msg = self.events.get(timeout=max(0, deadline-time.monotonic()))
        except queue.Empty:
            raise TimeoutError('attention_required') from None
        if msg.get('disconnected'):
            raise ConnectionError('unknown')
        if 'method' in msg and 'id' in msg:
            self.server_request = True
            self.send({'id': msg['id'], 'error': {'code': -32601, 'message': 'Unsupported PoC request'}})
        return msg

    def request(self, method, params, timeout=15):
        self.next_id += 1
        rid = self.next_id
        self.send({'id': rid, 'method': method, 'params': params})
        deadline = time.monotonic()+timeout
        while True:
            msg = self.receive(deadline)
            if msg.get('id') == rid and 'method' not in msg:
                if 'error' in msg:
                    # Error strings can contain credentials or prompt fragments.
                    raise RuntimeError('rpc_error:' + str(msg['error'].get('code')))
                return msg.get('result', {})
            self.buffer.append(msg)

    def close(self):
        # Only our newly spawned server is terminated, never a shared broker.
        self.proc.stdin.close()
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


def run(args, command=None):
    client = Client(command or ['codex', 'app-server'], args.cwd)
    result = {'transport': 'direct-stdio', 'mode': args.mode, 'status': 'unknown',
              'interruption_pass': False, 'progress_events': 0, 'usage_observed': False}
    try:
        client.request('initialize', {'clientInfo': {'name': 'harness-705-poc', 'version': '1'}})
        client.send({'method': 'initialized', 'params': {}})
        account = client.request('account/read', {'refreshToken': False}).get('account')
        observed = fingerprint(account)
        result['account_fingerprint'] = observed
        if args.mode == 'preflight':
            result['status'] = 'identity_observed' if observed else 'identity_unknown'
            return result
        if not observed or not args.expected_account or observed != args.expected_account:
            result['status'] = 'identity_mismatch'
            return result
        if not args.model:
            raise ValueError('explicit_model_required')
        thread = client.request('thread/start', {'cwd': os.path.abspath(args.cwd), 'model': args.model,
                                                'sandbox': 'read-only', 'approvalPolicy': 'never'})['thread']['id']
        prompt = ('Return the word READY only, without tools.' if args.mode == 'complete' else
                  'Without using tools, write a long numbered explanation of the integers 1 through 500. Do not finish early.')
        turn = client.request('turn/start', {'threadId': thread, 'input': [{'type': 'text', 'text': prompt}],
                                            'model': args.model})['turn']['id']
        result.update(thread_id=thread, turn_id=turn, accepted=True)
        requested = args.mode == 'interrupt'
        if requested:
            # Wait for actual activity on this turn; acceptance alone can precede activation.
            start_deadline = time.monotonic()+15
            seen = []
            while True:
                msg = client.buffer.pop(0) if client.buffer else client.receive(start_deadline)
                seen.append(msg)
                params = msg.get('params', {})
                if params.get('threadId') == thread and params.get('turnId') == turn:
                    break
                if msg.get('method') == 'turn/completed' and params.get('turn', {}).get('id') == turn:
                    break
            client.buffer = seen + client.buffer
            client.request('turn/interrupt', {'threadId': thread, 'turnId': turn})
        deadline = time.monotonic()+args.timeout
        while True:
            msg = client.buffer.pop(0) if client.buffer else client.receive(deadline)
            params = msg.get('params', {})
            if params.get('threadId') != thread:
                continue
            method = msg.get('method')
            if method == 'turn/completed' and params.get('turn', {}).get('id') == turn:
                result['status'] = params['turn']['status']
                result['interruption_pass'] = interrupt_pass(result['status'], requested)
                result['final_items'] = len(params['turn'].get('items', []))
                items = params['turn'].get('items', [])
                if not any(i.get('type') == 'agentMessage' for i in items) and args.mode == 'complete':
                    stored = client.request('thread/read', {'threadId': thread, 'includeTurns': True})
                    items = [i for t in stored['thread']['turns'] if t['id'] == turn for i in t.get('items', [])]
                result['result_text'] = '\n'.join(item.get('text', '') for item in items if item.get('type') == 'agentMessage')
                result['result_verified'] = args.mode == 'complete' and result['result_text'].strip() == 'READY'
                return result
            if params.get('turnId') == turn:
                result['progress_events'] += 1
                if method == 'thread/tokenUsage/updated':
                    result['usage_observed'] = True
            if client.server_request:
                client.request('turn/interrupt', {'threadId': thread, 'turnId': turn})
                client.server_request = False
                result['unsupported_request'] = True
    except (TimeoutError, ConnectionError, RuntimeError, ValueError, KeyError, BrokenPipeError) as error:
        result['status'] = 'attention_required' if isinstance(error, TimeoutError) else 'unknown'
        result['error_kind'] = type(error).__name__
        if isinstance(error, RuntimeError) and str(error).startswith('rpc_error:'):
            result['rpc_error_code'] = str(error).split(':')[1]
        return result
    finally:
        client.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=['preflight', 'complete', 'interrupt'], default='preflight')
    parser.add_argument('--cwd', required=True)
    parser.add_argument('--model')
    parser.add_argument('--expected-account', help='SHA256 fingerprint independently approved for this PoC')
    parser.add_argument('--timeout', type=float, default=45)
    options = parser.parse_args()
    if not 0 < options.timeout <= 60:
        parser.error('timeout must be within (0, 60] seconds')
    report = run(options)
    print(json.dumps(report))
    success = (report['status'] == 'identity_observed' if options.mode == 'preflight' else
               report['status'] == 'completed' and report.get('result_verified', False) if options.mode == 'complete' else
               report['interruption_pass'])
    raise SystemExit(0 if success else 1)
