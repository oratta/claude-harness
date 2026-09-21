#!/usr/bin/env python3
"""Manual develop transport. Claude remains the canonical workflow orchestrator."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import stat
import sys
import uuid
from urllib.parse import quote, unquote_to_bytes


CONTINUATION_V1_KEYS = ('executor', 'account', 'model', 'run-dir', 'worker-state', 'cwd')
CONTINUATION_V2_KEYS = ('executor', 'profile', 'config-version', 'config-hash',
                        'run-dir', 'worker-state', 'cwd')
CONTINUATION_PATH_KEYS = frozenset(('run-dir', 'worker-state', 'cwd'))
CONTINUATION_MARKER = '<!-- codex-develop-continuation:'
CONTINUATION_PREFIXES = {
    'v1': '<!-- codex-develop-continuation:v1 ',
    'v2': '<!-- codex-develop-continuation:v2 ',
}
CONTINUATION_VALUE_RE = r'(?:[A-Za-z0-9._~-]|%[0-9A-F]{2})+'


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
    if set(values) == set(CONTINUATION_V1_KEYS):
        version, keys = 'v1', CONTINUATION_V1_KEYS
    elif set(values) == set(CONTINUATION_V2_KEYS):
        version, keys = 'v2', CONTINUATION_V2_KEYS
    else:
        raise ContinuationError('continuation keys must match exactly one supported version')
    if values.get('executor') != 'codex':
        raise ContinuationError('continuation executor must be codex')
    encoded = ' '.join(f'{key}={_continuation_encode(values[key])}' for key in keys)
    return f'{CONTINUATION_PREFIXES[version]}{encoded} -->'


def parse_continuation_record(line):
    """Parse one exact continuation line, rejecting unknown and duplicate keys."""
    import re
    if not isinstance(line, str) or '\n' in line or '\r' in line:
        raise ContinuationError('invalid continuation record')
    version = next((item for item, prefix in CONTINUATION_PREFIXES.items()
                    if line.startswith(prefix)), None)
    if version is None or not line.endswith(' -->'):
        raise ContinuationError('invalid continuation record')
    keys = CONTINUATION_V1_KEYS if version == 'v1' else CONTINUATION_V2_KEYS
    prefix = CONTINUATION_PREFIXES[version]
    payload = line[len(prefix):-4]
    parts = payload.split(' ')
    if len(parts) != len(keys):
        raise ContinuationError('invalid continuation record')
    values = {}
    for part, key in zip(parts, keys):
        name, separator, encoded = part.partition('=')
        if (separator != '=' or name != key or key in values or
                not re.fullmatch(CONTINUATION_VALUE_RE, encoded)):
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
            # Detect candidates independently of strict version/spacing syntax.
            if line.lstrip().startswith(CONTINUATION_MARKER):
                candidates.append((int(comment.get('id', 0)), line))
    if not candidates:
        raise ContinuationError('continuation record not found')
    latest_id = max(comment_id for comment_id, _ in candidates)
    latest = [line for comment_id, line in candidates if comment_id == latest_id]
    if len(latest) != 1:
        raise ContinuationError('multiple latest continuation records')
    try:
        return parse_continuation_record(latest[0])
    except ContinuationError as exc:
        raise ContinuationError(f'invalid latest continuation record: {exc}') from exc


def restore_continuation(*, issue_comments=None, draft_pr_comments=None):
    """Restore coordinator-fetched comments; None means no issue, [] an empty issue.

    Only the selected source is inspected, including when its record is missing
    or invalid. GitHub access and subsequent dispatch remain coordinator-owned.
    """
    comments = issue_comments if issue_comments is not None else draft_pr_comments
    record = select_continuation_record(comments if comments is not None else [])
    return validate_continuation(record, record['run-dir'])


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
    is_v2 = set(record) == set(CONTINUATION_V2_KEYS)
    is_profile = 'execution_config' in state
    if is_v2 != is_profile:
        raise ContinuationError('continuation and run format mismatch')
    expected = {'run-dir': str(directory), 'worker-state': state.get('worker_state'),
                'cwd': state.get('cwd')}
    if is_v2:
        config = state.get('execution_config')
        if not isinstance(config, dict):
            raise ContinuationError('continuation and run format mismatch')
        computed_hash = execution_config_hash(config)
        if state.get('execution_config_hash') != computed_hash:
            raise ContinuationError('continuation config-hash mismatch')
        expected.update(profile=config.get('profile'),
                        **{'config-version': str(config.get('version')),
                           'config-hash': computed_hash})
    else:
        expected.update(account=state.get('account'), model=state.get('model'))
    if record.get('executor') != 'codex':
        raise ContinuationError('continuation executor mismatch: expected codex')
    for key, value in expected.items():
        actual = record.get(key)
        if key in CONTINUATION_PATH_KEYS:
            if not all(isinstance(path, str) and path for path in (actual, value)):
                raise ContinuationError(f'continuation {key} mismatch')
            try:
                actual = str(Path(actual).expanduser().resolve())
                value = str(Path(value).expanduser().resolve())
            except (OSError, RuntimeError, ValueError) as exc:
                raise ContinuationError(f'continuation {key} is invalid') from exc
        if actual != value:
            raise ContinuationError(f'continuation {key} mismatch')
    return record

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


def _unique_object(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError(f'duplicate JSON key: {key}')
        value[key] = item
    return value


def registered_accounts(worker_state):
    ledger = Path(worker_state).expanduser().resolve() / 'ledger.sqlite'
    if not ledger.is_file():
        return set()
    try:
        connection = sqlite3.connect(f'file:{ledger}?mode=ro', uri=True)
        try:
            return {row[0] for row in connection.execute('SELECT name FROM accounts')}
        finally:
            connection.close()
    except sqlite3.Error as exc:
        raise RuntimeError('worker account registry is unavailable') from exc


def execution_config_hash(config):
    encoded = json.dumps(config, ensure_ascii=False, sort_keys=True,
                         separators=(',', ':')).encode()
    return hashlib.sha256(encoded).hexdigest()


def payload_hash(request):
    return hashlib.sha256(json.dumps(request, sort_keys=True).encode()).hexdigest()


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
        entry = roles[role]
        if not isinstance(entry, dict) or set(entry) != {'executor', 'account', 'model', 'effort'}:
            raise RuntimeError(f'profile role {role} has invalid fields')
        if any(not isinstance(entry[key], str) or not entry[key] for key in entry):
            raise RuntimeError(f'profile role {role} has an empty or non-string value')
        if entry['executor'] != 'codex':
            raise RuntimeError(f'profile role {role} executor must be codex')
        if entry['account'] not in accounts:
            raise RuntimeError(f'profile role {role} account is not registered')
        clean[role] = dict(entry)
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
        if (not isinstance(entry, dict) or set(entry) != {'executor', 'account', 'model', 'effort'} or
                entry.get('executor') != 'codex' or
                any(not isinstance(value, str) or not value for value in entry.values())):
            raise RuntimeError(f'execution config role {role} mismatch')
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


def validate_profile_pending(state, request):
    validate_execution_config(state)
    expected = resolve_execution(state, request.get('role'))
    pending = state.get('pending_execution')
    if pending != expected:
        raise RuntimeError('pending execution mismatch')
    for key in ('account', 'model'):
        if request.get(key) != expected[key]:
            raise RuntimeError('saved request identity differs from pending execution')
    if request.get('effort') != expected.get('effort'):
        raise RuntimeError('saved request effort differs from pending execution')
    if request.get('cwd') != state.get('cwd') or request.get('request_id') != state.get('pending'):
        raise RuntimeError('saved request identity differs from pending run')
    if state.get('pending_payload_hash') != payload_hash(request):
        raise RuntimeError('pending payload hash mismatch')


def validate_legacy_pending(state, request):
    if (request.get('request_id') != state.get('pending') or
            any(request.get(key) != state.get(key) for key in ('account', 'model', 'cwd'))):
        raise RuntimeError('saved request identity differs from pending run')


def clean_env():
    return {k: v for k, v in os.environ.items() if not k.startswith('GIT_')}


def git(cwd, *args):
    return subprocess.check_output(['git', '-C', cwd, *args], text=True, env=clean_env()).strip()


def write(path, value):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=2))
    os.chmod(tmp, 0o600)
    tmp.replace(path)


def worker(state, command, *args):
    # The ledger path is what --state-dir belongs to, and it now sits behind the subcommand.
    script = ROOT / 'scripts/codex-worker.py'
    result = subprocess.run([sys.executable, str(script), command, '--state-dir', state['worker_state'], *args],
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
    # The foreground route has no run and no ledger: the role settings are resolved per call
    # and written into the request file, and CODEX_HOME comes from the caller's own table.
    # Both ways of naming the execution are accepted, exactly as init accepts them, and the
    # refusals are the same: never both, never half of the legacy pair, never neither.
    legacy = bool(args.account or args.model)
    profile = bool(args.profile or args.profile_file)
    if legacy and profile or args.profile_file and not args.profile:
        raise RuntimeError('profile cannot be combined with account/model; profile-file requires profile')
    if legacy and not (args.account and args.model):
        raise RuntimeError('legacy request requires both account and model')
    if not legacy and not args.profile:
        raise RuntimeError('request requires account/model or profile')
    mapping = account_homes(args.account_home, args.account_home_file)
    cwd = Path(args.cwd).expanduser().resolve()
    if not cwd.is_dir():
        raise RuntimeError('cwd must be prepared target worktree')
    check = subprocess.run(['git', '-C', str(cwd), 'rev-parse', '--show-toplevel'], capture_output=True, text=True, env=clean_env())
    if check.returncode or Path(check.stdout.strip()).resolve() != cwd:
        raise RuntimeError('cwd must be the repository/worktree root')
    if args.profile:
        config = load_profile(args.profile, args.profile_file, set(mapping))
        state = {'cwd': str(cwd), 'execution_config': config,
                 'execution_config_hash': execution_config_hash(config)}
    else:
        # load_profile refuses an account the table does not map; the legacy pair names one
        # account directly, so the same refusal has to be made here.
        if args.account not in mapping:
            raise RuntimeError('account is not in the account-home table')
        state = {'cwd': str(cwd), 'account': args.account, 'model': args.model}
    role = PHASES[args.phase][0]
    execution = resolve_execution(state, role)
    head = git(str(cwd), 'rev-parse', 'HEAD')
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
    return {'status': 'request-written', 'request': str(out), 'request_id': request['request_id'],
            'phase': args.phase, 'role': role, 'account': execution['account'],
            'codex_home': request['codex_home'], 'model': execution['model'],
            'effort': execution.get('effort'), 'head': head}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-dir', help='init defaults to a new private runs/<UUID>; later commands require it')
    sub = parser.add_subparsers(dest='command', required=True)
    init = sub.add_parser('init')
    for key in ('account', 'model', 'profile', 'profile-file'):
        init.add_argument('--' + key)
    init.add_argument('--cwd', required=True)
    init.add_argument('--worker-state', default=str(Path.home() / '.local/state/claude-harness-codex/jobs'))
    dispatch = sub.add_parser('dispatch')
    dispatch.add_argument('--phase', choices=PHASES, required=True)
    dispatch.add_argument('--input', required=True, help='UTF-8 phase instructions prepared by coordinator')
    foreground = sub.add_parser('request')
    foreground.add_argument('--phase', choices=PHASES, required=True)
    foreground.add_argument('--input', required=True, help='UTF-8 phase instructions prepared by coordinator')
    foreground.add_argument('--cwd', required=True)
    foreground.add_argument('--account')
    foreground.add_argument('--model')
    foreground.add_argument('--profile')
    foreground.add_argument('--profile-file')
    foreground.add_argument('--account-home', action='append', default=[], metavar='NAME=PATH',
                         help='account name to CODEX_HOME; repeatable, not combinable with --account-home-file')
    foreground.add_argument('--account-home-file', help='flat JSON object of account name to CODEX_HOME')
    foreground.add_argument('--quota-margin-pct', type=float)
    foreground.add_argument('--out', required=True, help='where to write the request file for codex-worker.py run')
    for command in ('status', 'result', 'ack', 'cancel', 'retry'):
        sub.add_parser(command)
    args = parser.parse_args()
    # The foreground route owns neither a run-dir nor a lock, so it returns before both.
    if args.command == 'request':
        return build_request(args)
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
            legacy = bool(args.account or args.model)
            profile = bool(args.profile or args.profile_file)
            if legacy and profile or args.profile_file and not args.profile:
                raise RuntimeError('profile cannot be combined with account/model; profile-file requires profile')
            if legacy and not (args.account and args.model):
                raise RuntimeError('legacy init requires both account and model')
            if not legacy and not args.profile:
                raise RuntimeError('init requires account/model or profile')
            cwd = Path(args.cwd).expanduser().resolve()
            if not cwd.is_dir():
                raise RuntimeError('cwd must be prepared target worktree')
            check = subprocess.run(['git', '-C', str(cwd), 'rev-parse', '--show-toplevel'], capture_output=True, text=True, env=clean_env())
            if check.returncode or Path(check.stdout.strip()).resolve() != cwd:
                raise RuntimeError('cwd must be the repository/worktree root')
            worker_state = str(Path(args.worker_state).expanduser().resolve())
            state = dict(cwd=str(cwd), worker_state=worker_state, pending=None, history=[])
            if args.profile:
                config = load_profile(args.profile, args.profile_file, registered_accounts(worker_state))
                state.update(execution_config=config, execution_config_hash=execution_config_hash(config))
                if args.profile_file:
                    state['profile_file'] = str(Path(args.profile_file).expanduser().resolve())
            else:
                state.update(account=args.account, model=args.model)
            write(path, state)
            return {'status': 'initialized', 'run_dir': str(directory)}
        state = json.loads(path.read_text())
        validate_execution_config(state)
        if args.command == 'retry':
            # Replay the durable envelope exactly, including prompts from older versions.
            # submit is idempotent: never allocate a replacement job on uncertain delivery.
            if not state['pending']:
                raise RuntimeError('no pending job')
            request_path = directory / 'request.json'
            request = json.loads(request_path.read_text())
            if 'execution_config' in state:
                validate_profile_pending(state, request)
            else:
                validate_legacy_pending(state, request)
            return worker(state, 'submit', '--request', str(request_path))
        if args.command == 'dispatch':
            head = git(state['cwd'], 'rev-parse', 'HEAD')
            instructions = Path(args.input).read_text()
            role = PHASES[args.phase][0]
            execution = resolve_execution(state, role)
            request = dict(origin='manual', account=execution['account'], model=execution['model'],
                           cwd=state['cwd'], role=role, prompt=prompt(args.phase, 'Dispatch HEAD: ' + head + '\n' + instructions, state))
            if 'effort' in execution:
                request['effort'] = execution['effort']
            if state['pending']:
                old = json.loads((directory / 'request.json').read_text())
                if any(old.get(k) != v for k, v in request.items()):
                    raise RuntimeError('pending request differs; collect result and ack before next phase')
                request = old
                if 'execution_config' in state:
                    validate_profile_pending(state, request)
                else:
                    validate_legacy_pending(state, request)
            else:
                request['request_id'] = 'develop-' + uuid.uuid4().hex
                write(directory / 'request.json', request)
                state['pending'] = request['request_id']
                state['phase'] = args.phase
                state['head'] = head
                if 'execution_config' in state:
                    state['pending_execution'] = execution
                    state['pending_payload_hash'] = payload_hash(request)
                write(path, state)  # Persist BEFORE submit: uncertain response keeps same request ID.
            return worker(state, 'submit', '--request', str(directory / 'request.json'))
        if not state['pending']:
            raise RuntimeError('no pending job')
        job = state['pending']
        if args.command == 'ack':
            result = worker(state, 'result', '--job', job)
            if result.get('status') == 'unknown':
                raise RuntimeError('unknown job cannot be acknowledged or replaced')
            history = dict(job_id=job, phase=state['phase'], head=state['head'], result=result)
            if 'execution_config' in state:
                request = json.loads((directory / 'request.json').read_text())
                validate_profile_pending(state, request)
                observed = result.get('execution')
                if (not isinstance(observed, dict) or observed.get('role') != state['pending_execution']['role'] or
                        observed.get('requested') != {key: state['pending_execution'].get(key)
                                                       for key in ('executor', 'account', 'model', 'effort')}):
                    raise RuntimeError('result execution identity mismatch')
                if result.get('job_id') not in (None, job):
                    raise RuntimeError('result job identity mismatch')
                history.update(execution=observed, thread_id=result.get('thread_id'),
                               turn_id=result.get('turn_id'))
            response = worker(state, 'ack', '--job', job)
            state['pending'] = None
            state.pop('pending_execution', None)
            state.pop('pending_payload_hash', None)
            state['history'].append(history)
            write(path, state)
            return response
        return worker(state, args.command, '--job', job)


if __name__ == '__main__':
    try:
        print(json.dumps(main(), ensure_ascii=False))
    except (OSError, ValueError, RuntimeError, KeyError) as exc:
        print(json.dumps({'status': 'blocked', 'error': str(exc)}, ensure_ascii=False))
        sys.exit(2)
