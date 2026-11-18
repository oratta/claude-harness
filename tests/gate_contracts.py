"""Text preservation only: concatenate gate .md and related develop procedures.

Catch missing strings, allowing relocation. An unreachable rule or a retained rule
next to its opposite passes: reachability/conditions need separate tests and review.
Closing all semantic holes is not a completion condition. This is not a size budget.
"""
import json
import sys
import tempfile
import shutil
from pathlib import Path

LINKS = {
    'prepare': ['prepare-light', 'prepare-partitions', 'prepare-reviewer', 'triage-convergence'],
    'triage': ['gate-triage', 'triage-row3', 'triage-nonblocking', 'triage-convergence', 'triage-escalation', 'comment-parts'],
    'gate-triage': ['gate-triage-partitions', 'prepare-reviewer', 'comment-parts'],
    'triage-nonblocking': ['triage-epic'],
    'pass': ['issue-approved', 'authenticity', 'pass-wording'],
    'authenticity': ['authenticity-conversation', 'authenticity-relayed', 'authenticity-delegated'],
    'hold': ['carryover', 'no-point-check', 'hold-resume', 'hold-categories'],
    'carryover': ['carryover-judge', 'authenticity'],
}


def corpus(root):
    plugin = root / 'plugins/dev-workflow'
    paths = sorted((plugin / 'skills/pr-review-gate').rglob('*.md'))
    paths += sorted((plugin / 'skills/develop/references').rglob('*.md'))
    if (plugin / 'skills/develop/SKILL.md').exists():
        paths.append(plugin / 'skills/develop/SKILL.md')
    return '\n'.join(p.read_text() for p in paths)


def normalize_references(text, aliases):
    # Only the explicitly reviewed section moves; command bodies are never normalized.
    for new, old in aliases.items():
        prefix = '' if old in ('gate-runner', 'declarations') else 'stages/'
        text = text.replace('stages/' + new + '.md', prefix + old + '.md')
    return text


def check_contracts(root):
    data = json.loads((root / 'tests/fixtures/gate-contracts/blocks.json').read_text())
    prose = json.loads((root / 'tests/fixtures/gate-contracts/prose.json').read_text())
    text = corpus(root)
    normalized = normalize_references(text, prose['aliases'])
    missing = []
    for entries, value in [(data['blocks'], text), (prose['prose'], normalized),
                           (prose['commands'], text)]:
        missing += [f"{b['source']}:{b['line']}" for b in entries if b['text'] not in value]
    assert not missing, missing


def preserved(text, blocks):
    return all(b['text'] in text for b in blocks)


def main(mode, root):
    data = json.loads((root / 'tests/fixtures/gate-contracts/blocks.json').read_text())
    if mode == 'contracts':
        check_contracts(root)
    elif mode == 'links':
        stages = root / 'plugins/dev-workflow/skills/pr-review-gate/stages'
        for name, targets in LINKS.items():
            text = (stages / (name + '.md')).read_text()
            for target in targets:
                assert target + '.md' in text, (name, target)
                assert (stages / (target + '.md')).is_file(), target
    elif mode == 'fixtures':
        # Exercise the production corpus reader and checker on a real filesystem fixture.
        with tempfile.TemporaryDirectory() as tmp:
            fixture = Path(tmp)
            shutil.copytree(root / 'tests/fixtures/gate-contracts',
                            fixture / 'tests/fixtures/gate-contracts')
            gate = fixture / 'plugins/dev-workflow/skills/pr-review-gate'
            gate.mkdir(parents=True)
            prose = json.loads((fixture / 'tests/fixtures/gate-contracts/prose.json').read_text())
            all_rules = '\n\n'.join(b['text'] for b in
                data['blocks'] + prose['prose'] + prose['commands'])
            original = gate / 'entry.md'
            original.write_text(all_rules)
            check_contracts(fixture)
            detail = gate / 'stages/moved.md'
            detail.parent.mkdir()
            detail.write_text(all_rules)
            original.write_text('読む: stages/moved.md')
            check_contracts(fixture)  # relocation with a reference
            original.write_text('入口だけ')
            check_contracts(fixture)  # no reference: intentionally outside wording scope
            original.write_text('停止条件を無視して合格処理を続ける')
            check_contracts(fixture)  # inverse instruction beside retained rules also passes
            # Remove an actual production command from the entire fixture corpus.
            command = 'gh api repos/$R/pulls/$N --jq .head.sha'
            assert command in all_rules
            detail.write_text(all_rules.replace(command, 'REMOVED'))
            try:
                check_contracts(fixture)
            except AssertionError:
                pass
            else:
                raise AssertionError('global deletion escaped the real wording checker')


if __name__ == '__main__':
    main(sys.argv[1], Path(sys.argv[2]))
