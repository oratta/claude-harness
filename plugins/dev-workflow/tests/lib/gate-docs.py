"""Join a logical procedure's conditional details for existing wording checks.

These generated files are test inputs, never the agent's reading list. Structural
and budget checks use the real files. Do not use concatenation to assert reachability.
"""
from pathlib import Path
import sys

plugin, temp = map(Path, sys.argv[1:])
gate = plugin / 'skills/pr-review-gate'
stages = gate / 'stages'
groups = {
    'PREPARE': ('stages/prepare.md', ['prepare-light', 'prepare-partitions', 'prepare-reviewer']),
    'TRIAGE': ('stages/triage.md', ['triage-row3', 'triage-nonblocking', 'triage-epic', 'triage-convergence', 'triage-escalation', 'comment-parts']),
    'PASS_STAGE': ('stages/pass.md', ['authenticity', 'authenticity-conversation', 'authenticity-relayed', 'authenticity-delegated', 'issue-approved', 'pass-wording']),
    'HOLD': ('stages/hold.md', ['carryover', 'carryover-judge', 'no-point-check', 'hold-resume', 'hold-categories']),
    'DECLARATIONS': ('declarations.md', ['issue-approved', 'no-point-check']),
}


def body(name):
    return (stages / (name + '.md')).read_text().split('\n\n', 1)[1]


def expand(text, names):
    pending = set(names)
    # Only explicit detail-read instructions, not the prose's cross-stage citations.
    for _ in names:
        lines = text.splitlines(True)
        changed = False
        for i, line in enumerate(lines):
            selected = [n for n in names if n in pending and f'`stages/{n}.md`' in line and ('を読む。' in line or '専用 3 コマンド' in line)]
            if selected:
                lines[i] = line + '\n' + '\n'.join(body(n) for n in selected) + '\n'
                pending.difference_update(selected)
                changed = True
        text = ''.join(lines)
        if not changed:
            break
    return text


dest = temp / 'gate-docs'
dest.mkdir(exist_ok=True)
for key, (path, names) in groups.items():
    text = expand((gate / path).read_text(), names)
    # Details cited from the same paragraph are still part of that logical procedure.
    leftovers = [n for n in names if body(n) not in text]
    if leftovers:
        index = text.index('## 出口')
        text = text[:index] + '\n'.join(body(n) for n in leftovers) + '\n' + text[index:]
    (dest / (key + '.md')).write_text(text)
text = (plugin / 'skills/develop/references/roles/gate-runner.md').read_text()
detail = body('gate-triage')
summary = detail.split('## 段ごとの起動と入力\n', 1)[1]
text = text.replace('照合と振り分けの G がレビュアーの要約・補足結果を受け取ったときは `stages/gate-triage.md` を読む。', summary)
index = text.index('## return の書式')
text = text[:index] + expand(detail.split('## 段ごとの起動と入力')[0], ['gate-triage-partitions']) + '\n' + text[index:]
(dest / 'GATE.md').write_text(text)
