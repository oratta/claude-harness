#!/usr/bin/env python3
"""Generate public instructions, explicitly distribute them, and measure UTF-8 bytes."""
import argparse
import json
import os
from pathlib import Path
import re
import sys
import tomllib

BEGIN = b'<!-- BEGIN claude-harness shared instructions -->\n'
END = b'<!-- END claude-harness shared instructions -->\n'
MINIMUM = 131072
ROOT = Path(__file__).resolve().parents[1]
ARTIFACT = Path('generated/codex/AGENTS.md')


def generate(root, overlays=()):
    parts = [BEGIN, '# Claude harness 共通指示\n\n'.encode()]
    for source, directory in [('rules', root/'rules'), *overlays]:
        for rule in sorted(directory.glob('*.md')):
            if rule.name != 'README.md' and rule.is_file():
                parts.extend([f'## {source}/{rule.name}\n\n'.encode(), rule.read_bytes(), b'\n\n'])
    parts.extend(['## harness 専用規約（供給元: oratta/claude-harness の AGENTS.md）\n\n'
                  'この節は harness 配布元リポジトリを変更するときだけ適用する。'
                  '相対参照の基準は供給元リポジトリ。一般 repo や flatmate には開発場所・PR 運用を広げない。'
                  'Claude 固有の hook や Agent が Codex で実行済みとは扱わない。\n\n'.encode(),
                  (root/'AGENTS.md').read_bytes(), b'\n\n', END])
    return b''.join(parts)


def overlays(claude):
    """Same allowlist/marker/order/collision contract as sync.sh; never scan memories."""
    allow = claude/'harness-overlays'
    if not allow.is_file():
        return []
    names = sorted(line.strip() for line in allow.read_text().splitlines()
                   if line.strip() and not line.strip().startswith('#'))
    seen, result = set(), []
    for name in names:
        if '/' in name or name.startswith('.'):
            continue
        directory = claude/'plugins/marketplaces'/name
        marker = directory/'.harness-overlay'
        if not directory.is_dir() or not marker.is_file():
            continue
        lines = marker.read_text().splitlines()
        label = lines[0] if lines else ''
        if not re.fullmatch('[a-z0-9][a-z0-9-]*', label) or label in seen:
            continue
        seen.add(label)
        dest = claude/'rules/claude-harness'/label
        if dest.is_symlink() or (dest.exists() and not dest.is_dir()):
            continue
        result.append((f'overlay/{name}/rules', directory/'rules'))
    return result


def managed(data):
    """Return the block bounds, preserving every byte outside them."""
    if BEGIN.rstrip() not in data and END.rstrip() not in data:
        return None
    if (data.count(BEGIN.rstrip()) != 1 or data.count(END.rstrip()) != 1
            or BEGIN not in data or END not in data):
        raise ValueError('shared instruction markers are missing or duplicated')
    start, end = data.index(BEGIN), data.index(END)+len(END)
    if start >= end-len(END):
        raise ValueError('shared instruction markers are reversed')
    return start, end


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate account-home JSON key')
        result[key] = value
    return result


def account_homes(pairs, filename):
    # Same account-home table contract as develop: no registry and no auth requirement.
    if pairs and filename:
        raise ValueError('account-home cannot be combined with account-home-file')
    mapping = json.loads(Path(filename).read_text(), object_pairs_hook=unique_object) if filename else {}
    if not isinstance(mapping, dict):
        raise ValueError('account-home-file must be a flat object')
    for pair in pairs:
        name, sep, value = pair.partition('=')
        if not sep or not name or name in mapping:
            raise ValueError('account-home must be NAME=PATH with a NAME given once')
        mapping[name] = value
    result = []
    for name, value in mapping.items():
        if not isinstance(name, str) or not name or not isinstance(value, str) or not value:
            raise ValueError('account-home entries must be non-empty strings')
        path = Path(value)
        if not path.is_absolute() or not path.is_dir():
            raise ValueError(f'account-home {name} must be an existing absolute directory')
        result.append(path.resolve())
    return result


def capacity_config(data):
    """Edit numeric value spans only, preserving comments, tables and unrelated settings."""
    text = data.decode('utf-8')
    parsed = tomllib.loads(text)
    # Reject alternative TOML spellings we cannot edit without rewriting other settings.
    def values(table):
        for key, value in table.items():
            if key == 'project_doc_max_bytes':
                if type(value) is not int or value < MINIMUM:
                    yield value
            if isinstance(value, dict):
                yield from values(value)
    def replace(match):
        value = tomllib.loads('value = '+match['value'])['value']
        if type(value) is not int:
            raise ValueError('project_doc_max_bytes must be an integer')
        return match['prefix'] + str(max(value, MINIMUM))
    text = re.sub(r'(?m)^(?P<prefix>[ \t]*(?:project_doc_max_bytes|"project_doc_max_bytes"|\'project_doc_max_bytes\')[ \t]*=[ \t]*)(?P<value>[^#\r\n]+)',
                  replace, text)
    if 'project_doc_max_bytes' not in parsed:
        text = f'project_doc_max_bytes = {MINIMUM}\n'+text
    updated = tomllib.loads(text)
    def unrelated(table):
        if isinstance(table, dict):
            return {key: unrelated(value) for key, value in table.items()
                    if key != 'project_doc_max_bytes'}
        if isinstance(table, list):
            return [unrelated(value) for value in table]
        return table
    if unrelated(parsed) != unrelated(updated):
        raise ValueError('unsupported TOML layout: refusing to alter unrelated settings')
    if list(values(updated)):
        raise ValueError('project_doc_max_bytes below minimum or unsupported spelling; update it explicitly')
    return text.encode()


def plan(home, block):
    for name in ('AGENTS.md','config.toml','AGENTS.override.md'):
        if (home/name).is_symlink():
            raise ValueError(f'{home/name}: unmanaged symlink')
    override = home/'AGENTS.override.md'
    if override.exists() and override.stat().st_size:
        raise ValueError(f'{override}: non-empty override takes precedence')
    agents = home/'AGENTS.md'
    old = agents.read_bytes() if agents.exists() else b''
    bounds = managed(old)
    outside = old if bounds is None else old[:bounds[0]]+old[bounds[1]:]
    config = home/'config.toml'
    return (home, block+outside, capacity_config(config.read_bytes() if config.exists() else b''))


def sync(args, dry_run=False):
    targets = [Path.home()/'.codex']
    if os.environ.get('CODEX_HOME'):
        targets.append(Path(os.environ['CODEX_HOME']).expanduser())
    targets.extend(account_homes(args.account_home, args.account_home_file))
    targets = list(dict.fromkeys(p.resolve() for p in targets))
    claude = Path(os.environ.get('CLAUDE_CONFIG_DIR', str(Path.home()/'.claude')))
    block = generate(ROOT, overlays(claude))
    plans = []
    for home in targets:
        try:
            plans.append(plan(home, block))
        except (ValueError, OSError) as error:
            raise ValueError(f'{home}: {error}') from error
    if not dry_run:
        for home, agents, config in plans:
            home.mkdir(parents=True, exist_ok=True)
            (home/'AGENTS.md').write_bytes(agents)
            (home/'config.toml').write_bytes(config)
            print(f'[codex-sync] {home}')


def dummy(entry):
    tail = b'\nEND-FIXTURE:'+entry['path'].encode()+b'\n'
    remaining = entry['bytes']-len(tail)
    if remaining < 0:
        raise ValueError('fixture smaller than marker')
    return 'あ'.encode()*(remaining//3)+b'x'*(remaining%3)+tail


def discover(root, cwd, fallback=()):
    """Choose the first nonempty instruction at each directory, root to cwd."""
    relative = cwd.relative_to(root)
    directories = [root]
    for part in relative.parts:
        directories.append(directories[-1]/part)
    result = []
    for directory in directories:
        for name in ('AGENTS.override.md','AGENTS.md',*fallback):
            path = directory/name
            if path.is_file() and path.stat().st_size:
                result.append(path)
                break
    return result


def capacity(args):
    if args.fixture:
        manifest = json.loads((ROOT/'tests/fixtures/codex-shared-instructions/manifest.json').read_text())
        # Match the real generator's source headings/separators for private rules.
        data = (ROOT/ARTIFACT).read_bytes()
        if data != generate(ROOT):
            raise ValueError('stale public artifact; run generate')
        personal = b''
        for entry in manifest['inputs']:
            if entry['source'] == 'personal-rules':
                personal += (f"## overlay/claude-harness-oratta/{entry['path']}\n\n".encode()
                             + dummy(entry) + b'\n\n')
            else:
                data += dummy(entry)
        insertion = data.index('## harness 専用規約'.encode())
        data = data[:insertion]+personal+data[insertion:]
        limit = args.limit if args.limit is not None else MINIMUM
        label = 'fixed fixture (not local evidence)'
        files = []
    else:
        if args.cwd is None or args.home is None:
            raise ValueError('local check requires --cwd and --home')
        cwd, home = Path(args.cwd).resolve(), Path(args.home).resolve()
        if not cwd.is_dir() or not (home/'AGENTS.md').is_file():
            raise ValueError('local instructions unavailable (実物不在)')
        config = tomllib.loads((home/'config.toml').read_text()) if (home/'config.toml').exists() else {}
        if args.profile:
            config = dict(config, **config.get('profiles', {}).get(args.profile, {}))
        limit = args.limit if args.limit is not None else config.get('project_doc_max_bytes',32768)
        fallback = config.get('project_doc_fallback_filenames', [])
        if any(Path(n).name != n for n in fallback):
            raise ValueError('fallback filenames must be simple filenames')
        root = cwd
        while not (root/'.git').exists() and root.parent != root:
            root = root.parent
        if not (root/'.git').exists():
            root = cwd
        files = discover(root,cwd,fallback)
        if not files:
            raise ValueError('local repository/personality instructions unavailable (実物不在)')
        home_files = discover(home,home)
        data = b''.join(p.read_bytes() for p in [*home_files,*files])
        label = 'local files (not session reading evidence)'
    size = len(data)
    print(json.dumps({'kind':label,'bytes':size,'limit':limit,'files':[str(p) for p in files]},ensure_ascii=False))
    if size > limit:
        raise ValueError(f'UTF-8 instruction capacity exceeded: {size} > {limit}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ('generate','check'):
        command = sub.add_parser(name)
        command.add_argument('--output',type=Path,default=ROOT/ARTIFACT)
    for name in ('sync','validate-sync'):
        command = sub.add_parser(name)
        command.add_argument('--codex',action='store_true')
        command.add_argument('--no-pull',action='store_true')
        command.add_argument('--account-home',action='append',default=[])
        command.add_argument('--account-home-file')
    command = sub.add_parser('capacity')
    command.add_argument('--fixture',action='store_true')
    command.add_argument('--cwd')
    command.add_argument('--home')
    command.add_argument('--profile')
    command.add_argument('--limit',type=int)
    args = parser.parse_args()
    try:
        if args.command in ('generate','check'):
            data = generate(ROOT)
            if args.command == 'check':
                if not args.output.exists() or args.output.read_bytes() != data:
                    raise ValueError('stale public artifact; run generate')
            else:
                args.output.parent.mkdir(parents=True,exist_ok=True)
                args.output.write_bytes(data)
        elif args.command == 'capacity':
            capacity(args)
        else:
            sync(args, dry_run=args.command == 'validate-sync')
    except (OSError, ValueError) as error:
        print(f'[codex-instructions] {error}',file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
