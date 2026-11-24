"""Offline acceptance tests for the planner's JSON contract."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/epic-granularity.py'
CONFIG = ROOT / 'references/epic-granularity-coefficients.json'


def item(name='A', **kwargs):
    value = dict(id=name, repo='owner/repo', capabilities=['feature'], depends_on=[],
                 sanctuary=False, approval_wait=False,
                 files=[dict(path=f'{name}.py', access='edit', tokens=1000, read_id='planned', read_scope='rev:1-20', source='fixture')],
                 estimated_changed_lines=50, context_extra_tokens=100, estimate_source='fixture')
    value.update(kwargs)
    return value


def payload(*items):
    return dict(schema_version=1,
                limits=dict(context_cap=150000, record_cap=30000000,
                            context_cap_source='existing effective cap', record_cap_source='existing cap'),
                context=dict(startup_tokens=40000, reserve_tokens=10000,
                             startup_tokens_source='fixture estimate', reserve_tokens_source='fixture estimate'),
                worker_slots=dict(max_parallel=2, occupied=1, source='fixed snapshot'),
                items=list(items or [item()]))


class PlannerTests(unittest.TestCase):
    def run_cli(self, data, config=None):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'input.json'
            path.write_text(json.dumps(data))
            cmd = [sys.executable, str(SCRIPT), '--input', str(path)]
            if config is not None:
                cfg = Path(tmp) / 'config.json'
                cfg.write_text(json.dumps(config))
                cmd += ['--config', str(cfg)]
            proc = subprocess.run(cmd, capture_output=True, text=True)
        result = json.loads(proc.stdout) if proc.stdout else {}
        return proc.returncode, result, proc.stderr

    def plan(self, data, config=None, code=0):
        actual, result, err = self.run_cli(data, config)
        self.assertEqual(actual, code, err)
        return result

    def test_formula_and_deduplication(self):
        a, b = item(), item('B')
        b['files'] = copy.deepcopy(a['files'])
        result = self.plan(payload(a, b))
        g, = result['groups']
        for key, value in dict(F=1000, L=100, T=9949900, E=10065000, S=16104000, C=51200).items():
            self.assertEqual(g[key], value, key)
        b['files'][0].update(tokens=2000, read_id='other', read_scope='rev:10-40')
        self.assertEqual(self.plan(payload(a, b))['groups'][0]['F'], 3000)
        b['repo'] = 'other/repo'
        self.assertEqual(sum(g['F'] for g in self.plan(payload(a, b))['groups']), 3000)
        self.assertIn('Codex', json.dumps(result, ensure_ascii=False))
        self.assertIn('uncertainty', result)
        self.assertTrue(result['coefficient_source'].startswith('https://'))

    def test_missing_invalid_fields(self):
        base = payload()
        cases = []
        for group, key in [('limits', 'context_cap'), ('limits', 'record_cap_source'),
                           ('context', 'startup_tokens'), ('context', 'reserve_tokens_source'),
                           ('worker_slots', 'source')]:
            d = copy.deepcopy(base)
            del d[group][key]
            cases.append((d, key))
        for key in item():
            d = copy.deepcopy(base)
            del d['items'][0][key]
            cases.append((d, key))
        for key, value in [('repo', '/repo'), ('capabilities', []), ('sanctuary', 1),
                           ('estimated_changed_lines', -1), ('context_extra_tokens', True)]:
            d = copy.deepcopy(base)
            d['items'][0][key] = value
            cases.append((d, key))
        for key, value in [('tokens', True), ('tokens', float('inf')), ('tokens', -1),
                           ('path', '/abs'), ('path', '../x'), ('path', 'a/../b'),
                           ('path', './a'), ('access', 'write'), ('source', '')]:
            d = copy.deepcopy(base)
            d['items'][0]['files'][0][key] = value
            cases.append((d, key))
        for slots in [dict(max_parallel=1, occupied=2, source='x'),
                      dict(max_parallel=True, occupied=0, source='x'),
                      dict(max_parallel=0, occupied=0, source='x')]:
            d = copy.deepcopy(base)
            d['worker_slots'] = slots
            cases.append((d, 'worker_slots'))
        for d, field in cases:
            with self.subTest(field=field, data=d):
                code, _, err = self.run_cli(d)
                self.assertEqual(code, 1)
                self.assertIn(field, err)

    def test_read_contract_and_conflicts(self):
        for key in ['read_id', 'read_scope']:
            for value in [None, '', ' ', False]:
                data = payload()
                if value is None:
                    del data['items'][0]['files'][0][key]
                else:
                    data['items'][0]['files'][0][key] = value
                with self.subTest(key=key, value=value):
                    code, _, err = self.run_cli(data)
                    self.assertEqual(code, 1)
                    self.assertIn(key, err)
        for key, value in [('tokens', 1001), ('read_scope', 'rev:2-30')]:
            a, b = item(), item('B', sanctuary=True)
            b['files'] = copy.deepcopy(a['files'])
            b['files'][0][key] = value
            code, _, err = self.run_cli(payload(a, b))
            self.assertEqual(code, 1)
            self.assertIn('A.py', err)
            self.assertIn('planned', err)

    def test_distinct_overlapping_and_repeated_outputs(self):
        a = item()
        for scope in ['rev:10-30', 'rev:1-20']:
            b = item('B', files=[dict(a['files'][0], read_id='again',
                                      read_scope=scope, tokens=2000)])
            self.assertEqual(self.plan(payload(a, b))['groups'][0]['F'], 3000)
        a['files'].append(dict(a['files'][0], access='read', source='other citation'))
        self.assertEqual(self.plan(payload(a))['groups'][0]['F'], 1000)

    def test_large_whole_file_partial_read(self):
        a = item(context_extra_tokens=0)
        a['files'][0].update(read_scope='fixed-rev:100-120',
                             source='whole file 200000 tokens; planned excerpt 1000 tokens')
        self.assertEqual(self.plan(payload(a))['groups'][0]['C'], 51000)

    def test_required_output_itself_exceeds_capacity(self):
        a = item(context_extra_tokens=0)
        a['files'][0]['tokens'] = 120001
        r = self.plan(payload(a), code=2)
        u, = r['unplaced']
        self.assertEqual(u['context_overflow'], 50001)
        self.assertEqual(u['reads'][0]['path'], 'A.py')
        self.assertEqual(u['reads'][0]['read_id'], 'planned')
        self.assertEqual(u['reads'][0]['tokens'], 120001)
        self.assertIn('preserv', u['reason'])

    def test_dependency_errors(self):
        for items, term in [([item(), item()], 'duplicate'),
                            ([item(depends_on=['missing'])], 'missing'),
                            ([item(depends_on=['A'])], 'A'),
                            ([item(depends_on=['B']), item('B', depends_on=['A'])], 'A')]:
            code, _, err = self.run_cli(payload(*items))
            self.assertEqual(code, 1)
            self.assertIn(term, err)

    def test_order_invariance(self):
        a, b, c = item(), item('B', depends_on=['A']), item('C', depends_on=['A', 'B'])
        a['files'] += [dict(a['files'][0], read_id='second', read_scope='rev:15-40', tokens=2000)]
        a['files'] += [dict(path='z.py', access='read', tokens=30, read_id='extra', read_scope='rev:1-3', source='x')]
        data = payload(a, b, c)
        expected = self.plan(data)
        data['items'].reverse()
        for i in data['items']:
            i['files'].reverse()
            i['depends_on'].reverse()
            i['capabilities'].reverse()
        self.assertEqual(expected, self.plan(data))

    def test_context_boundary_and_unplaced(self):
        a = item(context_extra_tokens=69000)
        self.assertEqual(self.plan(payload(a))['groups'][0]['C'], 120000)
        a['context_extra_tokens'] += 1
        result = self.plan(payload(a, item('B')), code=2)
        self.assertEqual(result['unplaced'][0]['item_id'], 'A')
        self.assertEqual(result['unplaced'][0]['context_overflow'], 1)
        self.assertEqual(result['groups'][0]['item_ids'], ['B'])
        # Explicit C example from the specification.
        a['files'][0]['tokens'] = 30000
        a['context_extra_tokens'] = 15000
        self.assertEqual(self.plan(payload(a))['groups'][0]['C'], 95000)

    def test_record_boundary_config_and_validation(self):
        cfg = json.loads(CONFIG.read_text())
        cfg['record_intercept'] = 15000000
        cfg['record_per_line'] = 1
        d = payload(item(estimated_changed_lines=0))
        self.assertEqual(self.plan(d, cfg)['groups'][0]['S'], 24000000)
        cfg['guard_multiplier'] = 1
        cfg['record_intercept'] = 24000001
        self.assertEqual(self.plan(d, cfg, code=2)['unplaced'][0]['record_overflow'], 1)
        for key, value in [('source', ''), ('planning_fraction', 0), ('planning_fraction', 1),
                           ('total_per_token', -1), ('guard_multiplier', float('nan'))]:
            bad = json.loads(CONFIG.read_text())
            bad[key] = value
            code, _, err = self.run_cli(d, bad)
            self.assertEqual(code, 1)
            self.assertIn(key, err)
        d['limits']['record_cap'] = 60000000
        self.assertEqual(self.plan(d)['limits']['record_planning_cap'], 48000000)

    def test_boundaries_and_six_files(self):
        data = payload(item(), item('B', repo='other/repo'), item('C', sanctuary=True),
                       item('D', approval_wait=True), item('E', approval_wait=True))
        self.assertEqual(len(self.plan(data)['groups']), 5)
        data = payload(*(item(str(i), capabilities=[str(i)]) for i in range(6)))
        self.assertEqual(len(self.plan(data)['groups']), 1)

    def test_relation_priority_and_cycle_contraction(self):
        data = payload(item(context_extra_tokens=25000),
                       item('B', depends_on=['A'], context_extra_tokens=25000),
                       item('C', capabilities=['other'], context_extra_tokens=25000))
        result = self.plan(data)
        self.assertIn(['A', 'B'], [g['item_ids'] for g in result['groups']])
        self.assertIn('direct_dependency', json.dumps(result))
        # A+C fit; A+B and B+C don't. Contraction would create a cycle.
        data = payload(item(context_extra_tokens=20000),
                       item('B', depends_on=['A'], context_extra_tokens=48001),
                       item('C', depends_on=['B'], context_extra_tokens=20000))
        groups = self.plan(data)['groups']
        self.assertEqual([g['item_ids'] for g in groups], [['A'], ['B'], ['C']])
        self.assertEqual([g['depends_on'] for g in groups], [[], ['G001'], ['G002']])

    def test_cycle_fixture_boundary_allows_exact_capacity(self):
        data = payload(item(context_extra_tokens=20000),
                       item('B', depends_on=['A'], context_extra_tokens=48000),
                       item('C', depends_on=['B'], context_extra_tokens=20000))
        groups = self.plan(data)['groups']
        self.assertEqual([g['item_ids'] for g in groups], [['A', 'B'], ['C']])
        self.assertEqual(groups[0]['context_margin'], 0)
        self.assertEqual([g['depends_on'] for g in groups], [[], ['G001']])

    def test_slots_parallel_and_conflicts(self):
        data = payload(item(capabilities=['a']), item('B', capabilities=['b']))
        for occupied in [2, 1]:
            data['worker_slots']['occupied'] = occupied
            r = self.plan(data)
            self.assertEqual(len(r['groups']), 1)
            self.assertFalse(r['worker_slots']['launch_authorized'])
        data['worker_slots']['occupied'] = 0
        r = self.plan(data)
        self.assertEqual(len(r['groups']), 2)
        self.assertLess(r['parallel_comparison']['selected_makespan'],
                        r['parallel_comparison']['merged_makespan'])
        data['items'][1]['depends_on'] = ['A']
        self.assertEqual(len(self.plan(data)['groups']), 1)
        data['items'][1]['depends_on'] = []
        data['items'][1]['files'] = copy.deepcopy(data['items'][0]['files'])
        self.assertEqual(len(self.plan(data)['groups']), 1)
        # No benefit for two empty independent units: the fixed T is paid twice.
        data = payload(item(files=[], capabilities=['a']), item('B', files=[], capabilities=['b']))
        data['worker_slots']['occupied'] = 0
        self.assertEqual(len(self.plan(data)['groups']), 1)

    def test_reference_example(self):
        doc = (ROOT / 'skills/develop/references/epic-granularity.md').read_text()
        example = json.loads(doc.split('```json\n', 1)[1].split('```', 1)[0])
        g, = self.plan(example)['groups']
        self.assertEqual((g['F'], g['L'], g['T'], g['E'], g['S'], g['C']),
                         (1000, 100, 9949900, 10065000, 16104000, 51000))

    def test_historical_sources_are_complete_and_recountable(self):
        directory = ROOT / 'tests/fixtures/epic-granularity'
        sources = json.loads((directory / 'sources.json').read_text())
        outputs = json.loads((directory / 'outputs.json').read_text())
        for epic, count in [('1701', 3), ('1732', 21)]:
            data = json.loads((directory / f'epic-{epic}.json').read_text())
            self.assertEqual(len(sources['epics'][epic]['children']), count)
            self.assertEqual({url.rsplit('/', 1)[-1] for i in data['items']
                              for url in i['source_issues']},
                             set(map(str, sources['epics'][epic]['children'])))
            self.assertEqual(data['worker_slots']['max_parallel'], 2)
            self.assertEqual(data['worker_slots']['occupied'], 1)
            for i in data['items']:
                changes = 0
                for f in i['files']:
                    evidence = sources['outputs'][f['read_id']]
                    output = outputs[f['read_id']]
                    self.assertTrue(output)
                    self.assertEqual(len(output), evidence['characters'])
                    self.assertEqual(f['tokens'], (len(output) * 65 + 99) // 100)
                    self.assertEqual(f['read_scope'], evidence['scope'])
                    if f['access'] == 'edit':
                        changes += evidence['additions'] + evidence['deletions']
                self.assertEqual(i['estimated_changed_lines'], changes)
        for pr in sources['prs'].values():
            pr_outputs = [o for o in sources['outputs'].values() if o.get('pr') == pr['number']]
            self.assertEqual({o['path'] for o in pr_outputs}, {f['filename'] for f in pr['files']})
            for f in pr['files']:
                pieces = [o for o in pr_outputs if o['path'] == f['filename']]
                self.assertEqual(sum(o['additions'] for o in pieces), f['additions'])
                self.assertEqual(sum(o['deletions'] for o in pieces), f['deletions'])
                for rid, o in sources['outputs'].items():
                    if o in pieces:
                        lines = outputs[rid].splitlines()
                        self.assertTrue(lines[0].startswith('diff --git '))
                        self.assertEqual(sum(line.startswith('+') and not line.startswith('+++')
                                             for line in lines), o['additions'])
                        self.assertEqual(sum(line.startswith('-') and not line.startswith('---')
                                             for line in lines), o['deletions'])

    def test_historical_fixtures(self):
        for epic in [1701, 1732]:
            with self.subTest(epic=epic):
                directory = ROOT / 'tests/fixtures/epic-granularity'
                data = json.loads((directory / f'epic-{epic}.json').read_text())
                r = self.plan(data)
                self.assertEqual(r, json.loads((directory / f'epic-{epic}.expected.json').read_text()))
                ids = [i for g in r['groups'] for i in g['item_ids']]
                self.assertCountEqual(ids, [i['id'] for i in data['items']])
                self.assertEqual(len(ids), len(set(ids)))
                lookup = {i['id']: i for i in data['items']}
                edges = {g['id']: g['depends_on'] for g in r['groups']}
                owner = {i: g['id'] for g in r['groups'] for i in g['item_ids']}
                for i in data['items']:
                    for dep in i['depends_on']:
                        if owner[i['id']] != owner[dep]:
                            self.assertIn(owner[dep], edges[owner[i['id']]])
                seen = set()
                def visit(n, path):
                    self.assertNotIn(n, path)
                    for dep in edges[n]:
                        visit(dep, path | {n})
                    seen.add(n)
                for g in r['groups']:
                    visit(g['id'], set())
                    members = [lookup[i] for i in g['item_ids']]
                    self.assertEqual(len({i['repo'] for i in members}), 1)
                    self.assertEqual(len({i['sanctuary'] for i in members}), 1)
                    if any(i['approval_wait'] for i in members):
                        self.assertEqual(len(members), 1)
                    self.assertGreaterEqual(g['context_margin'], 0)
                    self.assertGreaterEqual(g['record_margin'], 0)


if __name__ == '__main__':
    unittest.main()
