"""#1685: document presence, mandatory entries, startup skeleton and byte budgets.

Input is the plugin tree (or a disposable copy), never archives/docs. Equal-size
paragraph swaps are intentionally outside the contract (epic #1682).
"""
import re
import sys
from pathlib import Path


def procedures(root):
    base = root / 'skills/develop'
    return '\n'.join(p.read_text() for p in [base / 'SKILL.md', *sorted((base / 'references').rglob('*.md'))])


def check(root, mode, budget=None):
    skill = (root / 'skills/develop/SKILL.md').read_text()
    if mode == 'content':
        body = procedures(root)
        for term in ['git-guard-permit.sh', 'agent_id', '15 分以内', '終了コード 3',
                     '1 回だけ報告を求める', 'pr-token-budget.sh', 'pr-token-measure.sh']:
            assert term in body, term
    elif mode == 'structure':
        end = '<!-- startup-core-end -->'
        assert end in skill, 'startup skeleton end'
        prefix = skill[:skill.index(end) + len(end)]
        assert len(prefix.encode()) <= 5000, 'startup skeleton exceeds 5000 byte/token'
        for term in ['| 作業者 |', '| 仕様レビュアー |', '| ゲート実行者 |', '| 画面確認役 |',
                     '本体は Edit でコードを書かない', '本体はレビューを代行しない',
                     '軽い通し方', '記録先', 'R1', '実装＋verify', 'archive', 'Draft PR',
                     '仕様宣言', 'G', 'コンパクト', 'Read']:
            assert term in prefix, term
        for ref, trigger in [('pr-token-budget.md', 'spawn・再開・Codex 委譲'),
                             ('worker-recovery.md', '通常 return')]:
            assert re.search(rf'[^\n]*{re.escape(trigger)}[^\n]*必ず[^\n]*{ref}[^\n]*Read', skill), ref
        assert '空 return' in skill
        assert 'Status → 読むファイル' in skill
        for status in ['次の段へ', 'passed', 'needs-reviewer', '重複で降りた',
                       'review-incomplete', 'failed', '保留', 'needs-fix-check',
                       'needs-carryover-judge', 'needs-no-point-check', 'needs-decider']:
            row = re.search(rf'^\| {status} \| `([^`]+)#([^`]+)`', skill, re.M)
            assert row, status
            dest = root / 'skills/develop' / row[1]
            assert dest.is_file(), str(dest)
            assert f'## {row[2]}' in dest.read_text(), row[2]
        command = (root / 'commands/develop.md').read_text()
        adapter = (root / 'references/codex-develop.md').read_text()
        for body in [skill, command]:
            assert 'references/codex-develop.md' in body
            assert 'Read' in body
            for term in ['2方式の併用は拒否し', '--failure first|executor|judgment',
                         'margin / fetched_at', '返った `tier` が thread']:
                assert term not in body, 'duplicated resolver: ' + term
        for term in ['--failure first|executor|judgment', 'margin / fetched_at',
                     '返った `tier` が thread', 'requested_model', 'executed_tier', 'tier_cap']:
            assert adapter.count(term) >= 1, term
        assert adapter.count('同じ Claude role を再開する前にも毎回') == 1
        assert 'git-guard-permit.sh' not in skill
        assert 'scripts/codex-records.sh' not in skill
        assert 'needs-reviewer →' not in skill
    elif mode == 'budget':
        rows = Path(budget).read_text().splitlines()
        expected = {f'skills/develop/references/{s}.md' for s in
                    ['pr-token-budget', 'gate-result', 'worker-recovery']}
        assert len(rows) == 3
        assert {r.split(' ')[0] for r in rows} == expected
        for row in rows:
            assert re.fullmatch(r'[^ ]+ [1-9][0-9]*', row), row
            name, cap = row.split(' ')
            actual = len((root / name).read_bytes())
            assert actual <= int(cap), f'over budget: {name}'
            assert int(cap) * 10 <= actual * 11, f'slack budget: {name}'
    else:
        raise ValueError(mode)


if __name__ == '__main__':
    check(Path(sys.argv[1]), *sys.argv[2:])
