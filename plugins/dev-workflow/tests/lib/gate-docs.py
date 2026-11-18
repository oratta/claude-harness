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
    processed = set()
    details = {name: body(name) for name in names}
    # Reference-only table rows delegate to a detail's concrete row. Replace
    # at that table position, and insert the rest of the detail once as usual.
    for name in names:
        for row in details[name].splitlines(True):
            if row.startswith('| '):
                key = row.split('|', 2)[1]
                for entry in text.splitlines(True):
                    if entry.startswith('|' + key + '|') and f'`stages/{name}.md`' in entry:
                        text = text.replace(entry, row)
                        details[name] = details[name].replace(row, '')

    def insert(content):
        lines = []
        for line in content.splitlines(True):
            selected = [n for n in names if (stages / (n + '.md')).resolve() not in processed
                        and f'`stages/{n}.md`' in line
                        and ('を読む。' in line or '専用 3 コマンド' in line)]
            # A table's reference row stands in for the actual row in the detail.
            if not (selected and line.startswith('|')):
                lines.append(line)
            for name in selected:
                path = (stages / (name + '.md')).resolve()
                processed.add(path)
                lines.append('\n' + insert(details[name]) + '\n')
        return ''.join(lines)

    text = insert(text)
    # Some details are cross references rather than explicit Read instructions.
    for name in names:
        path = (stages / (name + '.md')).resolve()
        if path not in processed:
            processed.add(path)
            index = text.index('## 出口') if '## 出口' in text else len(text)
            text = text[:index] + insert(details[name]) + '\n' + text[index:]
    return text


dest = temp / 'gate-docs'
dest.mkdir(exist_ok=True)
for key, (path, names) in groups.items():
    text = expand((gate / path).read_text(), names)
    (dest / (key + '.md')).write_text(text)
text = (plugin / 'skills/develop/references/roles/gate-runner.md').read_text()
detail = body('gate-triage')
summary = detail.split('## 段ごとの起動と入力\n', 1)[1]
text = text.replace('照合と振り分けの G がレビュアーの要約・補足結果を受け取ったときは `stages/gate-triage.md` を読む。', summary)
index = text.index('## return の書式')
text = text[:index] + expand(detail.split('## 段ごとの起動と入力')[0], ['gate-triage-partitions']) + '\n' + text[index:]
(dest / 'GATE.md').write_text(text)

# Wording-presence input covers every gate file, including newly moved details.
paths = sorted(gate.rglob('*.md')) + [plugin / 'skills/develop/references/roles/gate-runner.md']
(dest / 'ALL.md').write_text('\n'.join(p.read_text() for p in paths))
