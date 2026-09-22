#!/usr/bin/env python3
"""Build one foreground Codex request or route a Claude role to the coordinator."""
import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import select
import subprocess
import sys
import time
import unicodedata
import uuid

ROOT = Path(__file__).resolve().parents[1]
CANONICAL_ROLES = ('spec-write', 'spec-review', 'implement', 'impl-review', 'review',
                   'decider', 'explore', 'summarize')
PHASES = {
    'spec': ('spec-write', 'worker.md'),
    'spec-review': ('spec-review', 'spec-reviewer.md'),
    'implement': ('implement', 'worker.md'),
    'finish': ('implement', 'worker.md'),
    'gate': ('implement', 'gate-runner.md'),
    'review': ('impl-review', 'spec-reviewer.md'),
    'decider': ('decider', 'spec-reviewer.md'),
    'explore': ('explore', 'worker.md'),
    'summarize': ('summarize', 'worker.md'),
}
# The writers run with no OS sandbox and inherit the parent environment, exactly like the
# Claude subagent each one mirrors, so they finish their own GitHub work. Every other role
# is readOnly and cannot write anywhere, so the coordinator posts its verdict for it.
WRITER_ROLES = frozenset({'implement', 'spec-write'})
WRITER_TRANSPORT = '''This worker has network access and the parent environment: perform GitHub reads and writes,
comments, push, PR creation and commit yourself here, and do not return needs-coordinator for
them. The coordinator performs only operations already recorded as ones it could not align.'''
READER_TRANSPORT = '''This worker is read-only: never write to GitHub, push, or commit. Return the review verdict and
its evidence; the coordinator posts it on your behalf, then starts a fresh phase with it.'''
FRESH_SECONDS = 300
WEEK_SECONDS = 604800


def _service_name(securestorage):
    if not securestorage:
        return 'Claude Code-credentials'
    value = unicodedata.normalize('NFC', securestorage).encode()
    return 'Claude Code-credentials-' + hashlib.sha256(value).hexdigest()[:8]


def usage_margin(snapshot, now, *, codex=False):
    """Return the unrounded weekly margin, or None for missing/unsafe input."""
    if not isinstance(snapshot, dict) or type(snapshot.get('fetched_at')) is not int:
        return None
    age = now - snapshot['fetched_at']
    if age < 0 or age > FRESH_SECONDS:
        return None
    if codex:
        windows = snapshot.get('windows')
        if not isinstance(windows, list):
            return None
        weekly = [item for item in windows if isinstance(item, dict) and
                  item.get('minutes') == 10080]
        if not weekly:
            return None
        value = weekly[0]
        used, reset = value.get('used_percent'), value.get('reset_at')
    else:
        used, reset = snapshot.get('weekly_all_pct'), snapshot.get('weekly_resets_epoch')
    if (type(used) not in (int, float) or not math.isfinite(used) or not 0 <= used <= 100 or
            type(reset) is not int or not now < reset <= now + WEEK_SECONDS):
        return None
    elapsed = 100 * (1 - (reset - now) / WEEK_SECONDS)
    return elapsed - used


def claude_usage_evidence(snapshot, now):
    accounts = snapshot.get('accounts') if isinstance(snapshot, dict) else None
    accounts = accounts if isinstance(accounts, dict) else {}
    active = None
    wanted = _service_name(os.environ.get('CLAUDE_SECURESTORAGE_CONFIG_DIR', ''))
    for name, entry in accounts.items():
        if isinstance(entry, dict) and _service_name(entry.get('securestorage')) == wanted:
            active = name
            break
    if active is None and isinstance(snapshot, dict) and snapshot.get('active') in accounts:
        active = snapshot['active']
    if active is None and accounts:
        active = next(iter(accounts))
    entry = accounts.get(active) if active is not None else None
    margin = usage_margin(entry, now) if entry is not None else None
    return {'account': active, 'margin': margin,
            'fetched_at': entry.get('fetched_at') if isinstance(entry, dict) else None}


def select_configuration(claude_margin, codex_margin):
    claude_ok, codex_ok = (claude_margin is not None and claude_margin >= 0,
                           codex_margin is not None and codex_margin >= 0)
    if claude_ok and codex_ok:
        return 'claude-write-codex-review', 'both-providers-have-headroom'
    if not claude_ok and codex_ok:
        return 'codex-standard', 'only-codex-has-headroom'
    if claude_ok:
        return 'claude-default', 'only-claude-has-headroom'
    return 'claude-default', 'no-provider-has-headroom'


def _auth_identity(home):
    raw = json.loads((Path(home) / 'auth.json').read_text())
    tokens = raw.get('tokens') or {}
    parts = tokens.get('id_token', '').split('.')
    if len(parts) != 3 or not tokens.get('account_id'):
        raise RuntimeError('Codex identity is unavailable')
    claims = json.loads(base64.urlsafe_b64decode(parts[1] + '=' * (-len(parts[1]) % 4)))
    email = claims.get('email')
    if not isinstance(email, str) or not email:
        raise RuntimeError('Codex identity is unavailable')
    return {'email_hash': hashlib.sha256(email.strip().lower().encode()).hexdigest(),
            'account_id_hash': hashlib.sha256(tokens['account_id'].encode()).hexdigest()}


def _rpc_requests(home, requests, timeout=15):
    env = clean_env() | {'CODEX_HOME': home}
    proc = subprocess.Popen(['codex', 'app-server', '-c', 'model_provider="openai"'],
        env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        bufsize=0)
    results = []
    buffered = b''
    try:
        for number, (method, params) in enumerate(requests, 1):
            proc.stdin.write((json.dumps(
                {'id': number, 'method': method, 'params': params}) + '\n').encode())
            proc.stdin.flush()
            deadline = time.monotonic() + timeout
            while True:
                while b'\n' not in buffered:
                    wait = deadline - time.monotonic()
                    if wait <= 0 or not select.select([proc.stdout], [], [], max(0, wait))[0]:
                        raise RuntimeError('Codex quota RPC timed out')
                    chunk = os.read(proc.stdout.fileno(), 65536)
                    if not chunk:
                        raise RuntimeError('Codex quota RPC disconnected')
                    buffered += chunk
                line, buffered = buffered.split(b'\n', 1)
                if not line:
                    continue
                message = json.loads(line)
                if message.get('id') != number or 'method' in message:
                    continue
                if message.get('error'):
                    raise RuntimeError('Codex quota RPC was rejected')
                results.append(message.get('result') or {})
                if method == 'initialize':
                    proc.stdin.write((json.dumps(
                        {'method': 'initialized', 'params': {}}) + '\n').encode())
                    proc.stdin.flush()
                break
        return results
    finally:
        try:
            proc.stdin.close()
        except (BrokenPipeError, OSError):
            pass
        try:
            proc.terminate(); proc.wait(timeout=2)
        except (OSError, subprocess.TimeoutExpired):
            proc.kill(); proc.wait()


def _quota_windows(result):
    buckets = result.get('rateLimitsByLimitId')
    if isinstance(buckets, dict):
        values = [buckets.get('codex')]
    else:
        legacy = result.get('rateLimits')
        values = [legacy] if (isinstance(legacy, dict) and
                              legacy.get('limitId') in (None, 'codex')) else []
    windows = []
    for bucket in values:
        if not isinstance(bucket, dict):
            continue
        for name in ('primary', 'secondary'):
            value = bucket.get(name)
            if not isinstance(value, dict):
                continue
            windows.append({'minutes': value.get('windowDurationMins'),
                            'used_percent': value.get('usedPercent'),
                            'reset_at': value.get('resetsAt')})
    return windows


def probe_codex_account(home):
    identity = _auth_identity(home)
    initialized, observed, limits = _rpc_requests(home, [
        ('initialize', {'clientInfo': {'name': 'develop-quota', 'version': '1'}}),
        ('account/read', {'refreshToken': False}),
        ('account/rateLimits/read', {}),
    ])
    del initialized
    account = observed.get('account') or {}
    email = account.get('email')
    if (account.get('type') != 'chatgpt' or not isinstance(email, str) or
            hashlib.sha256(email.strip().lower().encode()).hexdigest() != identity['email_hash']):
        raise RuntimeError('Codex server identity mismatch')
    windows = _quota_windows(limits)
    if not windows:
        raise RuntimeError('Codex weekly quota is unavailable')
    return {'identity': identity, 'windows': windows}


def _cache_path(config_dir, home):
    digest = hashlib.sha256(str(Path(home).resolve()).encode()).hexdigest()
    return Path(config_dir) / 'codex-usage' / (digest + '.json')


def _update_codex_cache(name, home, config_dir, now):
    path = _cache_path(config_dir, home)
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(path.parent, 0o700)
    lock_path = path.with_suffix('.lock')
    lock_path.touch(mode=0o600, exist_ok=True); os.chmod(lock_path, 0o600)
    with lock_path.open('r+') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        previous = None
        try:
            previous = json.loads(path.read_text())
        except (OSError, ValueError):
            pass
        if not isinstance(previous, dict):
            previous = None
        if previous is not None:
            try:
                if previous.get('identity') != _auth_identity(home):
                    previous = None
            except (OSError, ValueError, RuntimeError, KeyError):
                previous = None
        try:
            result = probe_codex_account(home)
            value = {'version': 1, 'identity': result['identity'],
                     'fetched_at': now, 'windows': result['windows']}
            write(path, value)
        except Exception:
            value = previous
        return name, value


def read_codex_usages(mapping, config_dir, now):
    def update(name, home):
        try:
            return _update_codex_cache(name, home, config_dir, now)
        except Exception:
            return name, None

    with ThreadPoolExecutor(max_workers=max(1, len(mapping))) as pool:
        futures = [pool.submit(update, name, home)
                   for name, home in mapping.items()]
        values = dict(future.result() for future in futures)
    return {name: values.get(name) for name in mapping}


def _run_usage_probe(snapshot_path):
    env = clean_env() | {'USAGE_SNAPSHOT': str(snapshot_path)}
    try:
        subprocess.run([str(ROOT / 'scripts/usage-probe.sh')], env=env,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       timeout=20, check=False)
    except (OSError, subprocess.TimeoutExpired):
        pass


def automatic_selection(mapping, now=None):
    config_dir = Path(os.environ.get('CLAUDE_CONFIG_DIR', Path.home() / '.claude'))
    snapshot_path = Path(os.environ.get('USAGE_SNAPSHOT', config_dir / '.usage-snapshot'))
    _run_usage_probe(snapshot_path)
    now = int(time.time()) if now is None else now
    try:
        snapshot = json.loads(snapshot_path.read_text())
    except (OSError, ValueError):
        snapshot = {}
    claude = claude_usage_evidence(snapshot, now)
    usages = read_codex_usages(mapping, str(config_dir), now) if mapping else {}
    candidates = []
    for order, (name, value) in enumerate(usages.items()):
        margin = usage_margin(value, now, codex=True)
        if margin is not None:
            candidates.append((margin, -order, name, value))
    best = max(candidates) if candidates else None
    codex = {'account': best[2] if best else None, 'margin': best[0] if best else None,
             'fetched_at': best[3].get('fetched_at') if best else None}
    selected, reason = select_configuration(claude['margin'], codex['margin'])
    return selected, {'selection_mode': 'automatic', 'configuration': selected,
        'reason': reason,
        'claude': {'account': claude['account'], 'margin': claude['margin'],
                   'fetched_at': claude['fetched_at']},
        'codex': {'account': codex['account'], 'margin': codex['margin'],
                  'fetched_at': codex['fetched_at']}}


def bind_codex_account(config, account, accounts):
    if account is None:
        return config
    roles = {}
    for role, entry in config['roles'].items():
        roles[role] = dict(entry, account=account) if entry['executor'] == 'codex' else dict(entry)
        validate_role_entry(role, roles[role], accounts, source='automatic profile role')
    bound = {'version': 1, 'profile': config['profile'], 'roles': roles}
    if bound['roles']['review'] != bound['roles']['impl-review']:
        raise RuntimeError('profile review must equal impl-review')
    return bound


def claude_default(role):
    model = ('haiku' if role in {'explore', 'summarize'} else
             'fable' if role == 'decider' else
             'opus' if role in {'spec-review', 'impl-review', 'review'} else 'sonnet')
    effort = 'low' if model == 'haiku' else 'high' if model in {'opus', 'fable'} else 'medium'
    return {'role': role, 'executor': 'claude', 'account': 'current',
            'model': model, 'effort': effort}


def _unique_object(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError(f'duplicate JSON key: {key}')
        value[key] = item
    return value


def execution_config_hash(config):
    encoded = json.dumps(config, ensure_ascii=False, sort_keys=True,
                         separators=(',', ':')).encode()
    return hashlib.sha256(encoded).hexdigest()


def account_homes(pairs, path):
    # The two ways of giving the table are alternatives, like profile versus account/model:
    # when both are present nothing is merged and neither wins, the call is refused.
    if pairs and path:
        raise RuntimeError('account-home cannot be combined with account-home-file')
    mapping = {}
    if path:
        try:
            document = json.loads(Path(path).expanduser().resolve().read_text(), object_pairs_hook=_unique_object)
        except (OSError, ValueError) as exc:
            raise RuntimeError('account-home-file is unavailable or invalid') from exc
        if not isinstance(document, dict):
            raise RuntimeError('account-home-file must be a flat object of name to CODEX_HOME')
        mapping = document
    for item in pairs:
        name, separator, value = item.partition('=')
        if not separator or not name or name in mapping:
            raise RuntimeError('account-home must be NAME=PATH with a NAME given once')
        mapping[name] = value
    clean = {}
    for name, value in mapping.items():
        if not isinstance(name, str) or not name or not isinstance(value, str) or not value:
            raise RuntimeError('account-home entries must be non-empty strings')
        home = Path(value)
        if not home.is_absolute() or not home.is_dir():
            raise RuntimeError(f'account-home {name} must be an existing absolute directory')
        clean[name] = str(home.resolve())
    return clean


def default_automatic_account_home():
    value = os.environ.get('CODEX_HOME')
    candidate = Path(value).expanduser() if value is not None else Path.home() / '.codex'
    if not candidate.is_absolute() or not candidate.is_dir():
        return {}
    return {'current': str(candidate.resolve())}


def validate_role_entry(role, entry, accounts=None, *, source='profile role'):
    if not isinstance(entry, dict) or set(entry) != {'executor', 'account', 'model', 'effort'}:
        raise RuntimeError(f'{source} {role} has invalid fields')
    if any(not isinstance(entry[key], str) or not entry[key] for key in entry):
        raise RuntimeError(f'{source} {role} has an empty or non-string value')
    executor = entry['executor']
    if executor not in {'claude', 'codex'}:
        raise RuntimeError(f'{source} {role} executor must be claude or codex')
    if executor == 'codex':
        if accounts is not None and entry['account'] not in accounts:
            raise RuntimeError(f'{source} {role} account is not registered')
    else:
        if entry['account'] != 'current':
            raise RuntimeError(
                f'{source} {role}: different Claude account execution is not supported yet')
        if entry['model'] not in {'haiku', 'sonnet', 'opus', 'fable'}:
            raise RuntimeError(
                f'{source} {role} Claude model must be one of haiku, sonnet, opus, fable')
        if entry['model'] == 'fable' and role != 'decider':
            raise RuntimeError(f'{source} {role}: fable is only supported for decider')
    return dict(entry)


def load_profile(name, profile_file, accounts):
    source = Path(profile_file).expanduser().resolve() if profile_file else ROOT / 'references/codex-role-profiles.json'
    try:
        document = json.loads(source.read_text(), object_pairs_hook=_unique_object)
    except (OSError, ValueError) as exc:
        raise RuntimeError('profile file is unavailable or invalid') from exc
    if (not isinstance(document, dict) or set(document) != {'version', 'profiles'} or
            type(document['version']) is not int or document['version'] != 1):
        raise RuntimeError('profile document must have exactly version=1 and profiles')
    profiles = document['profiles']
    if not isinstance(profiles, dict) or name not in profiles:
        raise RuntimeError('profile is not defined')
    selected = profiles[name]
    if not isinstance(selected, dict) or set(selected) != {'roles'} or not isinstance(selected['roles'], dict):
        raise RuntimeError('profile must contain exactly roles')
    roles = selected['roles']
    if set(roles) != set(CANONICAL_ROLES):
        raise RuntimeError('profile roles are incomplete or unknown')
    clean = {}
    for role in CANONICAL_ROLES:
        clean[role] = validate_role_entry(role, roles[role], accounts)
    if clean['review'] != clean['impl-review']:
        raise RuntimeError('profile review must equal impl-review')
    return {'version': 1, 'profile': name, 'roles': clean}


def validate_execution_config(state):
    config = state.get('execution_config')
    if config is None:
        return
    if (not isinstance(config, dict) or set(config) != {'version', 'profile', 'roles'} or
            type(config.get('version')) is not int or config.get('version') != 1 or
            set(config.get('roles', {})) != set(CANONICAL_ROLES)):
        raise RuntimeError('execution config mismatch')
    for role, entry in config['roles'].items():
        try:
            validate_role_entry(role, entry, source='execution config role')
        except RuntimeError as exc:
            raise RuntimeError(f'execution config role {role} mismatch: {exc}') from exc
    if config['roles']['review'] != config['roles']['impl-review']:
        raise RuntimeError('execution config review must equal impl-review')
    if state.get('execution_config_hash') != execution_config_hash(config):
        raise RuntimeError('execution config hash mismatch')


def resolve_execution(state, role):
    validate_execution_config(state)
    if 'execution_config' not in state:
        return {'role': role, 'executor': 'codex', 'account': state['account'],
                'model': state['model']}
    return {'role': role} | dict(state['execution_config']['roles'][role])


def clean_env():
    return {k: v for k, v in os.environ.items() if not k.startswith('GIT_')}


def git(cwd, *args):
    return subprocess.check_output(['git', '-C', cwd, *args], text=True, env=clean_env()).strip()


def write(path, value):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=2))
    os.chmod(tmp, 0o600)
    tmp.replace(path)


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
{WRITER_TRANSPORT if role in WRITER_ROLES else READER_TRANSPORT}
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


def build_request(args):
    # Role settings are resolved for each request, and CODEX_HOME comes from the caller's
    # explicit account table. The profile form and account/model form are mutually exclusive.
    legacy = bool(args.account or args.model)
    profile = bool(args.profile or args.profile_file)
    if legacy and profile or args.profile_file and not args.profile:
        raise RuntimeError('profile cannot be combined with account/model; profile-file requires profile')
    if legacy and not (args.account and args.model):
        raise RuntimeError('legacy request requires both account and model')
    mapping = account_homes(args.account_home, args.account_home_file)
    if not legacy and not profile and not args.account_home and not args.account_home_file:
        mapping = default_automatic_account_home()
    cwd = Path(args.cwd).expanduser().resolve()
    if not cwd.is_dir():
        raise RuntimeError('cwd must be prepared target worktree')
    check = subprocess.run(['git', '-C', str(cwd), 'rev-parse', '--show-toplevel'], capture_output=True, text=True, env=clean_env())
    if check.returncode or Path(check.stdout.strip()).resolve() != cwd:
        raise RuntimeError('cwd must be the repository/worktree root')
    selection = None
    if args.profile:
        config = load_profile(args.profile, args.profile_file, set(mapping))
        state = {'cwd': str(cwd), 'execution_config': config,
                 'execution_config_hash': execution_config_hash(config)}
        selection = {'selection_mode': 'explicit', 'configuration': args.profile,
                     'reason': 'explicit-profile'}
    elif legacy:
        # load_profile refuses an account the table does not map; the legacy pair names one
        # account directly, so the same refusal has to be made here.
        if args.account not in mapping:
            raise RuntimeError('account is not in the account-home table')
        state = {'cwd': str(cwd), 'account': args.account, 'model': args.model}
        selection = {'selection_mode': 'explicit', 'configuration': 'legacy',
                     'reason': 'explicit-account-model'}
    else:
        selected, selection = automatic_selection(mapping)
        if selected == 'claude-default':
            state = {'cwd': str(cwd), 'automatic_claude_default': True}
        else:
            config = load_profile(selected, None, None)
            config = bind_codex_account(config, selection['codex']['account'], set(mapping))
            state = {'cwd': str(cwd), 'execution_config': config,
                     'execution_config_hash': execution_config_hash(config)}
    role = PHASES[args.phase][0]
    execution = (claude_default(role) if state.get('automatic_claude_default') else
                 resolve_execution(state, role))
    head = git(str(cwd), 'rev-parse', 'HEAD')
    if execution['executor'] == 'claude':
        result = {'status': 'agent-required', 'phase': args.phase, 'role': role,
                'executor': execution['executor'], 'account': execution['account'],
                'model': execution['model'], 'effort': execution.get('effort'),
                'head': head, 'selection': selection}
        if 'execution_config' in state:
            result.update(execution_config=state['execution_config'],
                          execution_config_hash=state['execution_config_hash'])
        return result
    request = dict(request_id='develop-' + uuid.uuid4().hex, origin='manual',
                   account=execution['account'], model=execution['model'], cwd=str(cwd), role=role,
                   codex_home=mapping[execution['account']],
                   prompt=prompt(args.phase, 'Dispatch HEAD: ' + head + '\n' + Path(args.input).read_text(), state))
    if 'effort' in execution:
        request['effort'] = execution['effort']
    if args.quota_margin_pct is not None:
        request['quota_margin_pct'] = args.quota_margin_pct
    out = Path(args.out).expanduser().resolve()
    write(out, request)
    result = {'status': 'request-written', 'request': str(out), 'request_id': request['request_id'],
            'phase': args.phase, 'role': role, 'executor': execution['executor'],
            'account': execution['account'],
            'codex_home': request['codex_home'], 'model': execution['model'],
            'effort': execution.get('effort'), 'head': head, 'selection': selection}
    if 'execution_config' in state:
        result.update(execution_config=state['execution_config'],
                      execution_config_hash=state['execution_config_hash'])
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    request = sub.add_parser('request')
    request.add_argument('--phase', choices=PHASES, required=True)
    request.add_argument('--input', required=True,
                         help='UTF-8 phase instructions prepared by coordinator')
    request.add_argument('--cwd', required=True)
    request.add_argument('--account')
    request.add_argument('--model')
    request.add_argument('--profile')
    request.add_argument('--profile-file')
    request.add_argument('--account-home', action='append', default=[], metavar='NAME=PATH',
                         help='account name to CODEX_HOME; repeatable, not combinable with --account-home-file')
    request.add_argument('--account-home-file',
                         help='flat JSON object of account name to CODEX_HOME')
    request.add_argument('--quota-margin-pct', type=float)
    request.add_argument('--out', required=True,
                         help='where to write the request file for codex-worker.py run')
    return build_request(parser.parse_args())


if __name__ == '__main__':
    try:
        print(json.dumps(main(), ensure_ascii=False))
    except (OSError, ValueError, RuntimeError, KeyError) as exc:
        print(json.dumps({'status': 'blocked', 'error': str(exc)}, ensure_ascii=False))
        sys.exit(2)
