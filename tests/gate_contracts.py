"""Text preservation only: concatenate gate .md and related develop procedures.

Catch missing strings, allowing relocation. An unreachable rule or a retained rule
next to its opposite passes: reachability/conditions need separate tests and review.
Closing all semantic holes is not a completion condition. This is not a size budget.
"""
import json
import sys
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
    return '\n'.join(p.read_text() for p in paths)


def preserved(text, blocks):
    return all(b['text'] in text for b in blocks)


def main(mode, root):
    data = json.loads((root / 'tests/fixtures/gate-contracts/blocks.json').read_text())
    if mode == 'contracts':
        text = corpus(root)
        missing = [f"{b['source']}:{b['line']}" for b in data['blocks'] if b['text'] not in text]
        assert not missing, missing
    elif mode == 'links':
        stages = root / 'plugins/dev-workflow/skills/pr-review-gate/stages'
        for name, targets in LINKS.items():
            text = (stages / (name + '.md')).read_text()
            for target in targets:
                assert target + '.md' in text, (name, target)
                assert (stages / (target + '.md')).is_file(), target
    elif mode == 'fixtures':
        blocks = [{'text': '停止条件: ここで止める'}]
        original = ['停止条件: ここで止める', '別の段']
        moved = ['', '別の段\n停止条件: ここで止める']
        assert preserved('\n'.join(original), blocks)
        assert preserved('\n'.join(moved), blocks)
        assert not preserved('別の段', blocks)
        # No link to the other stage, and an opposite instruction, intentionally pass.
        assert preserved('\n'.join(moved), blocks)
        assert preserved('\n'.join(moved) + '\n停止条件でも進める', blocks)


if __name__ == '__main__':
    main(sys.argv[1], Path(sys.argv[2]))
