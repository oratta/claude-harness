#!/usr/bin/env python3
"""Prepare known hooks in an explicit temporary CODEX_HOME, never a user profile."""
import argparse
import json
import os
from pathlib import Path
import shlex
import shutil
import tempfile

MINIMAL_CONFIG = 'cli_auth_credentials_store = "file"\n[features]\napps = false\n'
# CLI/exec accept the flag; app-server needs the per-thread boolean override.
CLI_TRUST_ARGS = ['--dangerously-bypass-hook-trust']
THREAD_CONFIG = {'bypass_hook_trust': True}


def guard_environment():
    plugin = Path(__file__).resolve().parents[1]
    return {
        'DEV_WORKFLOW_CODEX_GUARD_DIR': str(plugin/'hooks/codex'),
        'DEV_WORKFLOW_CODEX_GIT_GUARD': str(plugin/'scripts/git-destructive-guard.sh'),
        'DEV_WORKFLOW_CODEX_SECRET_GUARD': str(plugin.parent/'capability-registry/scripts/secret-guard.sh'),
        'DEV_WORKFLOW_CODEX_ASK_GUARD': str(plugin/'scripts/unattended-ask-guard.sh'),
    }


def prepare(target):
    """Validate before writing; preserve only the worker's minimal auth/config pair.

    Absolute source paths intentionally expire when this checkout moves. Call again
    in a fresh target after updates. A successful prepare is not evidence of a live deny.
    """
    target = Path(target)
    if (not target.is_absolute() or target.is_symlink() or not target.is_dir()
            or not target.resolve().is_relative_to(Path(tempfile.gettempdir()).resolve())):
        raise ValueError('hook_runtime_target_not_temporary_directory')
    allowed = {'auth.json', 'config.toml'}
    if any(p.name not in allowed for p in target.iterdir()):
        raise ValueError('hook_runtime_target_has_existing_settings')
    config = target/'config.toml'
    if config.is_symlink() or (config.exists() and config.read_text() != MINIMAL_CONFIG):
        raise ValueError('hook_runtime_target_has_existing_config')
    env = guard_environment()
    guard = Path(env['DEV_WORKFLOW_CODEX_GUARD_DIR'])
    dependencies = [guard/'hooks.json', guard/'pretool-guard.py',
                    *(Path(env.get(k, '')) for k in ('DEV_WORKFLOW_CODEX_GIT_GUARD',
                      'DEV_WORKFLOW_CODEX_SECRET_GUARD', 'DEV_WORKFLOW_CODEX_ASK_GUARD')),
                    Path(env.get('DEV_WORKFLOW_CODEX_SECRET_GUARD', '')).with_suffix('.py'),
                    Path(env.get('DEV_WORKFLOW_CODEX_GIT_GUARD', '')).with_name('git-guard-scratchpad.py')]
    for path in dependencies:
        if not path.is_absolute() or not path.is_file() or not os.access(path, os.R_OK):
            raise ValueError('hook_runtime_dependency_missing')
    binaries = {}
    for name in ('bash', 'python3'):
        found = shutil.which(name)
        if not found:
            raise ValueError('hook_runtime_executable_missing_'+name)
        binaries[name] = Path(found).resolve()
    definition = json.loads((guard/'hooks.json').read_text())
    groups = definition.get('hooks', {}).get('PreToolUse', [])
    if (set(definition) != {'hooks'} or set(definition['hooks']) != {'PreToolUse'}
            or len(groups) != 1 or set(groups[0]) != {'hooks'}
            or len(groups[0]['hooks']) != 1
            or groups[0]['hooks'][0].get('type') != 'command'):
        raise ValueError('hook_runtime_definition_unexpected')
    # Keep bash/python3 lookup inside the existing adapter and shell guards pinned too.
    # System utilities (cat/dirname) remain available; caller PATH is not consulted here.
    binary_dir = target/'.hook-bin'
    command_env = dict(env, PATH=str(binary_dir)+':/usr/bin:/bin')
    command = 'export ' + ' '.join(k+'='+shlex.quote(v) for k,v in command_env.items())
    command += '; exec ' + shlex.quote(str(binaries['python3'])) + ' -I ' + shlex.quote(str(guard/'pretool-guard.py'))
    groups[0]['hooks'][0]['command'] = command
    try:
        binary_dir.mkdir(mode=0o700)
        for name, path in binaries.items():
            (binary_dir/name).symlink_to(path)
        with (target/'hooks.json').open('x') as stream:
            json.dump(definition, stream, indent=2)
        os.chmod(target/'hooks.json', 0o600)
    except Exception:
        (target/'hooks.json').unlink(missing_ok=True)
        shutil.rmtree(binary_dir, ignore_errors=True)
        raise
    return env


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', required=True, type=Path)
    args = parser.parse_args()
    try:
        env = prepare(args.target)
    except (OSError, ValueError):
        parser.exit(2, 'hook_runtime_preparation_failed: target/source/dependencies must be checked\n')
    print(json.dumps({'environment': env, 'trust_args': CLI_TRUST_ARGS,
                      'thread_config': THREAD_CONFIG}))


if __name__ == '__main__':
    main()
