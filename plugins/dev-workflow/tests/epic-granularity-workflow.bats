#!/usr/bin/env bats
setup() {
  PLUGIN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REF="$PLUGIN/skills/develop/references"
}

@test "Step C: CLI then record then representative children; counts are not split gates" {
  run python3 - "$REF/spec-decision.md" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text().split('## Step C:', 1)[1].split('## 判定に使わない', 1)[0]
assert s.index('epic-granularity.py') < s.index('入力・出力') < s.index('代表子')
assert 'epic-granularity.md' in s
assert '1〜5個程度' not in s and '独立した capability ごとに change 候補' not in s
assert '強制分割' in s and '逸脱' in s
PY
  [ "$status" -eq 0 ]
}

@test "entry points share the planner contract and preserve dispatch identity" {
  grep -q 'epic-granularity.md' "$REF/epic.md"
  grep -q 'epic-granularity.md' "$REF/roles/worker/spec.md"
  grep -q '精算' "$REF/epic.md"
  grep -q '精算' "$REF/epic-loop.md"
  grep -q 'route/launch/wait/adopt' "$REF/epic-granularity.md"
}

@test "size tripwire recalculates quantities and stops on overflow or unknown, never counts alone" {
  run python3 - "$PLUGIN" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
for file in ['templates/escalation-tripwires.md', 'skills/develop/references/roles/worker/common.md']:
    text = (p/file).read_text()
    assert 'epic-granularity.md' in text
    assert '容量超過' in text and '不明' in text and '再計算' in text
    assert '編集対象ファイルが5個を超えた' not in text
    assert '編集対象ファイルが 5 個を超えた' not in text
text = (p/'skills/develop/references/epic-granularity.md').read_text()
assert '6 ファイル' in text and '2 回' in text and '上限を広げない' in text
PY
  [ "$status" -eq 0 ]
}

@test "aggregation procedure forbids nested originals, active sessions and unsafe reattachment" {
  run python3 - "$REF/epic-granularity.md" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
for required in ['全項目が単一 group', '他 group が参照しない', '多対多', '直接の子',
                 'nested', '外部依存', '未マージ PR', '付替え', '確認するまで起動しない',
                 'completed', 'not_planned', 'idempotent', '実機確認']:
    assert required in s, required
PY
  [ "$status" -eq 0 ]
}

@test "procedure fixtures: A/B to C and A to C/D launch only representatives and count once" {
  run python3 - "$REF/epic-granularity.md" <<'PY'
import json
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
examples = json.loads(s.split('<!-- procedure-fixtures -->\n```json\n',1)[1].split('```',1)[0])
for case in examples:
    reps = set(case['mapping'])
    originals = {o for sources in case['mapping'].values() for o in sources}
    assert set(case['direct_children']) == reps
    assert set(case['launch']) == reps
    assert not reps & originals
    assert case['nested_originals'] == []
    assert case['launch_if_active'] == [] and case['launch_if_reattach_failed'] == []
    counted, done = set(), set()
    for step in case['events']:
        done.update(step['done'])
        counted.update(step['done'])
        assert counted <= reps
        for source in originals:
            covering = {r for r, sources in case['mapping'].items() if source in sources}
            assert (source in step['eligible_to_settle']) == (covering <= done)
        assert step['progress'] == len(counted)
    assert len(counted) == len(reps)
    assert case['closes'] == {r: [r] for r in reps}
assert examples[0]['mapping'] == {'C': ['A', 'B']}
assert examples[1]['mapping'] == {'C': ['A'], 'D': ['A']}
assert examples[1]['events'][0]['eligible_to_settle'] == []
assert examples[1]['events'][-1]['progress'] == 2
PY
  [ "$status" -eq 0 ]
}

@test "planner unit acceptance tests run in the Bats CI discovery path" {
  run env PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s "$PLUGIN/tests" -p test_epic_granularity.py
  [ "$status" -eq 0 ]
}

@test "planned reads, incremental scopes and unplaced redesign have explicit instructions" {
  run python3 - "$REF/epic-granularity.md" <<'PYTEST'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
for term in ['read_id', 'read_scope', '(repo, path, read_id)', '矛盾',
             '部分的に重なる', '再取得', '0.77', '0.65', '出力文字数',
             '二重計上', '予定読取範囲', '必要情報を保存', '名目上',
             '切詰め', '未完了', '検証済み予測精度']:
    assert term in s, term
assert '最大全文' not in s and '追加のファイル全文' not in s
PYTEST
  [ "$status" -eq 0 ]
}
