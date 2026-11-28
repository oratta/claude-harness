#!/usr/bin/env python3
"""Codex PreToolUse adapter; inspect pending commands, never execute them.

Dependency overrides must be absolute script paths. Defaults describe the source
repository layout, not an installed/trusted Codex deployment (see #1863).
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

PLUGIN = Path(__file__).resolve().parents[2]
DEPENDENCIES = {
    'git': ('DEV_WORKFLOW_CODEX_GIT_GUARD', PLUGIN / 'scripts/git-destructive-guard.sh'),
    'secret': ('DEV_WORKFLOW_CODEX_SECRET_GUARD',
               PLUGIN.parent / 'capability-registry/scripts/secret-guard.sh'),
    'ask': ('DEV_WORKFLOW_CODEX_ASK_GUARD', PLUGIN / 'scripts/unattended-ask-guard.sh'),
}
# Only this synchronous hook name was measured on codex-cli 0.163.0.
QUESTION_TOOLS = frozenset({'request_user_input'})


def unchecked(kind, reason):
    # Never log the payload, command, dependency stdout, or possible secret values.
    print(f'[codex-pretool-guard] {kind}: 未検査 ({reason})', file=sys.stderr)


def inspect(kind, data):
    variable, default = DEPENDENCIES[kind]
    path = Path(os.environ.get(variable, str(default)))
    if not path.is_absolute() or not path.is_file():
        unchecked(kind, 'dependency must be an existing absolute script path')
        return None
    if kind == 'secret' and not path.with_suffix('.py').is_file():
        unchecked(kind, 'secret-guard.py sibling missing')
        return None
    if not shutil.which('bash') or not shutil.which('python3'):
        unchecked(kind, 'bash/python3 unavailable')
        return None
    env = os.environ.copy()
    if kind == 'git':
        env['DEV_WORKFLOW_GIT_GUARD_NO_ASK'] = '1'
        env.pop('DEV_WORKFLOW_GIT_GUARD_FORCE', None)
    try:
        result = subprocess.run(['bash', str(path)], input=json.dumps(data),
                                capture_output=True, text=True, env=env, timeout=10)
        if result.returncode or result.stderr:
            unchecked(kind, 'dependency failed or reported diagnostics')
        if result.returncode:
            return None
        if not result.stdout.strip():
            return None
        out = json.loads(result.stdout)
        if not isinstance(out, dict) or not isinstance(out.get('hookSpecificOutput'), dict):
            raise ValueError('unexpected dependency output type')
        decision = out['hookSpecificOutput']
        if (decision.get('permissionDecision') != 'deny'
                or not isinstance(decision.get('permissionDecisionReason'), str)
                or not decision['permissionDecisionReason'].strip()):
            raise ValueError('unexpected dependency contract')
        return decision['permissionDecisionReason']
    except (OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError):
        unchecked(kind, 'dependency execution/output invalid')
        return None


def main():
    try:
        data = json.load(sys.stdin)
    except (ValueError, OSError):
        return
    if not isinstance(data, dict) or data.get('hook_event_name') != 'PreToolUse':
        return
    tool, inp = data.get('tool_name'), data.get('tool_input')
    if not isinstance(tool, str) or not isinstance(inp, dict):
        return
    reasons = []
    if tool == 'Bash' and isinstance(inp.get('command'), str):
        normalized = {'tool_name': 'Bash', 'tool_input': {'command': inp['command']}}
        for kind in ('git', 'secret'):
            reason = inspect(kind, normalized)
            if reason:
                reasons.append(f'{kind} の既存判定が対象操作を検出した。')
    elif tool in QUESTION_TOOLS:
        reason = inspect('ask', {})
        if reason:
            reasons.append(reason.replace('AskUserQuestion', '主への質問ツール'))
    if reasons:
        reason = ' '.join(reasons) + (
            ' 言い換えて再実行せず作業を止める。必要なら主に承認を求め、主が自分で実行する。'
            '子は本体への return に書いて返す。')
        print(json.dumps({'hookSpecificOutput': {
            'hookEventName': 'PreToolUse', 'permissionDecision': 'deny',
            'permissionDecisionReason': reason}}, ensure_ascii=False))


if __name__ == '__main__':
    main()
