#!/usr/bin/env python3
"""Deterministic, offline epic packing. All limits are supplied by the caller."""
import argparse
from decimal import Decimal, ROUND_CEILING, ROUND_FLOOR
import json
from pathlib import Path
import re
import sys

DEFAULT_CONFIG = Path(__file__).resolve().parents[1] / 'references/epic-granularity-coefficients.json'


class Invalid(ValueError):
    pass


def require(condition, field, message):
    if not condition:
        raise Invalid(f'{field}: {message}')


def obj(value, field):
    require(isinstance(value, dict), field, 'expected object')
    return value


def field(value, key, prefix):
    obj(value, prefix)
    require(key in value, f'{prefix}.{key}', 'required')
    return value[key]


def string(value, name):
    require(isinstance(value, str) and bool(value.strip()), name, 'expected nonempty string')
    return value


def integer(value, name, positive=False):
    require(type(value) is int and value >= int(positive), name, 'expected integer in range')
    return value


def strings(value, name, nonempty=False):
    require(isinstance(value, list) and (value or not nonempty), name, 'expected string array')
    return sorted(set(string(v, name) for v in value))


def acyclic(edges):
    visiting, done = set(), set()

    def visit(n):
        if n in visiting:
            raise Invalid(f'depends_on: cycle involving {", ".join(map(str, sorted(visiting)))}')
        if n in done:
            return
        visiting.add(n)
        for dep in sorted(edges[n]):
            visit(dep)
        visiting.remove(n)
        done.add(n)
    for n in sorted(edges):
        visit(n)


def validate(data, config):
    require(type(field(data, 'schema_version', 'input')) is int and data['schema_version'] == 1,
            'schema_version', 'expected 1')
    for section, keys in [('limits', ['context_cap', 'record_cap']),
                          ('context', ['startup_tokens', 'reserve_tokens'])]:
        target = field(data, section, 'input')
        for key in keys:
            integer(field(target, key, section), f'{section}.{key}', section == 'limits')
            string(field(target, key + '_source', section), f'{section}.{key}_source')
    slots = field(data, 'worker_slots', 'input')
    integer(field(slots, 'max_parallel', 'worker_slots'), 'worker_slots.max_parallel', True)
    integer(field(slots, 'occupied', 'worker_slots'), 'worker_slots.occupied')
    require(slots['occupied'] <= slots['max_parallel'], 'worker_slots', 'occupied > max_parallel')
    string(field(slots, 'source', 'worker_slots'), 'worker_slots.source')
    items = field(data, 'items', 'input')
    require(isinstance(items, list) and bool(items), 'items', 'expected nonempty array')
    normalized, reads = {}, {}
    for i in items:
        name = string(field(i, 'id', 'items'), 'items.id')
        require(name not in normalized, 'items.id', f'duplicate {name}')
        prefix = f'items[{name}]'
        repo = string(field(i, 'repo', prefix), prefix + '.repo')
        require(re.fullmatch(r'[A-Za-z0-9_-][A-Za-z0-9_.-]*/[A-Za-z0-9_-][A-Za-z0-9_.-]*', repo),
                prefix + '.repo', 'expected owner/repo')
        n = dict(i)
        n['capabilities'] = strings(field(i, 'capabilities', prefix), prefix + '.capabilities', True)
        n['depends_on'] = strings(field(i, 'depends_on', prefix), prefix + '.depends_on')
        for key in ['sanctuary', 'approval_wait']:
            require(type(field(i, key, prefix)) is bool, prefix + '.' + key, 'expected bool')
        for key in ['estimated_changed_lines', 'context_extra_tokens']:
            integer(field(i, key, prefix), prefix + '.' + key)
        string(field(i, 'estimate_source', prefix), prefix + '.estimate_source')
        n['source_issues'] = strings(i.get('source_issues', []), prefix + '.source_issues')
        for url in n['source_issues']:
            require(re.fullmatch(r'https://github\.com/[^/]+/[^/]+/issues/[1-9][0-9]*', url),
                    prefix + '.source_issues', 'expected issue URL')
        files = field(i, 'files', prefix)
        require(isinstance(files, list), prefix + '.files', 'expected array')
        n['files'] = []
        for f in files:
            path = string(field(f, 'path', prefix + '.files'), prefix + '.files.path')
            require(not path.startswith('/') and '\\' not in path and
                    all(p not in ('', '.', '..') for p in path.split('/')),
                    prefix + '.files.path', 'expected normalized repo-relative path')
            access = field(f, 'access', prefix + '.files')
            require(access in ('read', 'edit'), prefix + '.files.access', 'expected read/edit')
            integer(field(f, 'tokens', prefix + '.files'), prefix + '.files.tokens')
            string(field(f, 'source', prefix + '.files'), prefix + '.files.source')
            for key in ['read_id', 'read_scope']:
                string(field(f, key, prefix + '.files'), prefix + '.files.' + key)
            key = (repo, path, f['read_id'])
            output = (f['read_scope'], f['tokens'])
            require(key not in reads or reads[key] == output,
                    prefix + '.files', f'conflicting read {key}: read_scope/tokens must agree')
            reads[key] = output
            n['files'].append(dict(path=path, access=access, tokens=f['tokens'], source=f['source'],
                                   read_id=f['read_id'], read_scope=f['read_scope']))
        n['files'].sort(key=lambda f: (f['path'], f['read_id'], f['read_scope'], f['access'], f['tokens'], f['source']))
        normalized[name] = n
    for name, i in normalized.items():
        for dep in i['depends_on']:
            require(dep in normalized and dep != name, f'items[{name}].depends_on', f'invalid dependency {dep}')
    acyclic({name: i['depends_on'] for name, i in normalized.items()})
    for key in ['version', 'source', 'guard_basis', 'planning_basis', 'uncertainty']:
        string(field(config, key, 'config'), 'config.' + key)
    require(config['source'].startswith('https://'), 'config.source', 'expected source URL')
    numbers = {}
    for key in ['total_intercept', 'total_per_token', 'record_intercept', 'record_per_line',
                'guard_multiplier', 'planning_fraction']:
        value = field(config, key, 'config')
        require(type(value) in (int, float), 'config.' + key, 'expected finite positive number')
        number = Decimal(str(value))
        require(number.is_finite() and number > 0, 'config.' + key, 'expected finite positive number')
        numbers[key] = number
    require(numbers['planning_fraction'] < 1, 'config.planning_fraction', 'expected 0 < fraction < 1')
    return normalized, numbers


def ceil(value):
    return int(value.to_integral_value(rounding=ROUND_CEILING))


class Planner:
    def __init__(self, data, config):
        self.items, self.n = validate(data, config)
        self.data, self.config = data, config
        self.c_cap = int((self.n['planning_fraction'] * data['limits']['context_cap']).to_integral_value(rounding=ROUND_FLOOR))
        self.s_cap = int((self.n['planning_fraction'] * data['limits']['record_cap']).to_integral_value(rounding=ROUND_FLOOR))
        self.history = []
        self.reachable = {}
        def ancestors(n):
            if n not in self.reachable:
                self.reachable[n] = set(self.items[n]['depends_on'])
                for d in self.items[n]['depends_on']:
                    self.reachable[n].update(ancestors(d))
            return self.reachable[n]
        for n in self.items:
            ancestors(n)

    def reads(self, group):
        files = {}
        for name in group:
            i = self.items[name]
            for f in i['files']:
                key = (i['repo'], f['path'], f['read_id'])
                files[key] = dict(repo=i['repo'], path=f['path'], read_id=f['read_id'],
                                  read_scope=f['read_scope'], tokens=f['tokens'])
        return [files[key] for key in sorted(files)]

    def estimate(self, group):
        f = sum(r['tokens'] for r in self.reads(group))
        l = sum(self.items[i]['estimated_changed_lines'] for i in group)
        t = ceil(self.n['total_intercept'] + self.n['total_per_token'] * f)
        e = ceil(self.n['record_intercept'] + self.n['record_per_line'] * l)
        s = ceil(self.n['guard_multiplier'] * e)
        c = self.data['context']['startup_tokens'] + self.data['context']['reserve_tokens'] + f + sum(
            self.items[i]['context_extra_tokens'] for i in group)
        return dict(F=f, L=l, T=t, E=e, S=s, C=c,
                    context_margin=self.c_cap-c, record_margin=self.s_cap-s)

    def fits(self, group):
        e = self.estimate(group)
        return e['context_margin'] >= 0 and e['record_margin'] >= 0

    def compatible(self, a, b):
        members = [self.items[i] for i in a | b]
        return (not any(i['approval_wait'] for i in members) and
                len({i['repo'] for i in members}) == 1 and
                len({i['sanctuary'] for i in members}) == 1)

    def edges(self, groups):
        owners = {i: n for n, g in enumerate(groups) for i in g}
        return {n: {owners[d] for i in g for d in self.items[i]['depends_on']
                    if d in owners and owners[d] != n} for n, g in enumerate(groups)}

    def valid_dag(self, groups):
        try:
            acyclic(self.edges(groups))
            return True
        except Invalid:
            return False

    def relation(self, a, b):
        deps = lambda g: {d for i in g for d in self.items[i]['depends_on']}
        caps = lambda g: {c for i in g for c in self.items[i]['capabilities']}
        direct = sum(d in b for i in a for d in self.items[i]['depends_on']) + sum(
            d in a for i in b for d in self.items[i]['depends_on'])
        return direct, len(caps(a) & caps(b)), len(deps(a) & deps(b))

    @staticmethod
    def ordered(groups):
        return sorted(groups, key=lambda g: tuple(sorted(g)))

    def merge(self, groups, related):
        while True:
            candidates = []
            for x, a in enumerate(groups):
                for y in range(x + 1, len(groups)):
                    b = groups[y]
                    rel = self.relation(a, b)
                    if bool(any(rel)) != related or not self.compatible(a, b) or not self.fits(a | b):
                        continue
                    new = self.ordered([g for k, g in enumerate(groups) if k not in (x, y)] + [a | b])
                    if not self.valid_dag(new):
                        continue
                    score = tuple(-v for v in rel) + (self.estimate(a | b)['T'], tuple(sorted(a | b)))
                    candidates.append((score, new, a, b, rel))
            if not candidates:
                return groups
            _, groups, a, b, rel = min(candidates, key=lambda c: c[0])
            reason = next((label for value, label in zip(rel, ['direct_dependency', 'shared_capability', 'shared_prerequisite']) if value), 'capacity_packing')
            self.history.append(dict(item_ids=sorted(a | b), reason=reason))

    def independent(self, a, b):
        if any(self.reachable[i] & b for i in a) or any(self.reachable[i] & a for i in b):
            return False
        def edits(g):
            return {(self.items[i]['repo'], f['path']) for i in g for f in self.items[i]['files'] if f['access'] == 'edit'}
        return not edits(a) & edits(b)

    def makespan(self, groups, slots):
        edges = self.edges(groups)
        durations = {n: self.estimate(g)['T'] for n, g in enumerate(groups)}
        pending, running, done, now = set(edges), {}, set(), 0
        while pending or running:
            ready = sorted((n for n in pending if edges[n] <= done),
                           key=lambda n: (-durations[n], tuple(sorted(groups[n]))))
            for n in ready[:slots-len(running)]:
                pending.remove(n)
                running[n] = now + durations[n]
            if not running:
                raise Invalid('groups: invalid scheduling DAG')
            now = min(running.values())
            finished = {n for n, end in running.items() if end == now}
            done.update(finished)
            running = {n: end for n, end in running.items() if n not in finished}
        return now

    def plan(self):
        unplaced, groups = [], []
        for name in sorted(self.items):
            if self.fits({name}):
                groups.append({name})
            else:
                e = self.estimate({name})
                unplaced.append(dict(item_id=name, **e, context_overflow=max(0, -e['context_margin']),
                                     record_overflow=max(0, -e['record_margin']),
                                     reads=self.reads({name}),
                                     reason='redesign work, read scopes and dependencies preserving required information; resubmit without raising limits or truncating tokens'))
        groups = self.merge(groups, True)
        atoms = list(groups)
        groups = self.merge(groups, False)
        slots = self.data['worker_slots']['max_parallel'] - self.data['worker_slots']['occupied']
        merged_span = self.makespan(groups, max(1, slots))
        merged_count = len(groups)
        merged_total = sum(self.estimate(g)['T'] for g in groups)
        if slots >= 2:
            while True:
                current = self.makespan(groups, slots)
                candidates = []
                for g in groups:
                    for atom in atoms:
                        if not atom < g or not self.independent(atom, g - atom):
                            continue
                        new = self.ordered([h for h in groups if h != g] + [atom, g - atom])
                        if not self.valid_dag(new):
                            continue
                        span = self.makespan(new, slots)
                        if span < current:
                            candidates.append(((span, len(new), tuple(tuple(sorted(h)) for h in new)), new))
                if not candidates:
                    break
                _, groups = min(candidates, key=lambda c: c[0])
        groups = self.ordered(groups)
        owner = {i: f'G{n+1:03d}' for n, g in enumerate(groups) for i in g}
        output = []
        for n, g in enumerate(groups):
            items = [self.items[i] for i in sorted(g)]
            dependencies = {d for i in items for d in i['depends_on'] if d not in g}
            output.append(dict(id=f'G{n+1:03d}', item_ids=sorted(g), repo=items[0]['repo'],
                               sanctuary=items[0]['sanctuary'], approval_wait=items[0]['approval_wait'],
                               source_issues=sorted({url for i in items for url in i['source_issues']}),
                               depends_on=sorted({owner[d] for d in dependencies if d in owner}),
                               unplaced_dependencies=sorted(d for d in dependencies if d not in owner),
                               **self.estimate(g)))
        return dict(schema_version=1, status='unplaced' if unplaced else 'planned', groups=output,
                    unplaced=unplaced, coefficient_version=self.config['version'],
                    coefficient_source=self.config['source'], coefficients=self.config,
                    limits=dict(self.data['limits'], context_planning_cap=self.c_cap, record_planning_cap=self.s_cap),
                    context=self.data['context'],
                    worker_slots=dict(self.data['worker_slots'], available=slots, launch_authorized=False,
                                      note='snapshot only; recheck epic-worker-slots.md before launch'),
                    parallel_comparison=dict(merged_makespan=merged_span,
                                             selected_makespan=self.makespan(groups, max(1, slots)),
                                             merged_total_T=merged_total,
                                             selected_total_T=sum(self.estimate(g)['T'] for g in groups),
                                             reason='parallel_improvement' if len(groups) > merged_count else 'merged_or_capacity',
                                             evaluated=slots >= 2),
                    merge_reasons=self.history,
                    boundaries=['different_repo', 'sanctuary_mismatch', 'approval_wait_singleton'],
                    measurement_targets=dict(T='本体＋Claudeサブエージェント', E_S='本体を除くClaudeサブエージェント＋Codex', C='W保持文脈'),
                    uncertainty=self.config['uncertainty'],
                    warnings=['Proxy makespan is not elapsed time or an optimality guarantee.',
                              'Declared quantities and source authority are not verified.'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', required=True, type=Path)
    parser.add_argument('--config', type=Path, default=DEFAULT_CONFIG)
    args = parser.parse_args()
    try:
        data = json.loads(args.input.read_text(encoding='utf-8'))
        config = json.loads(args.config.read_text(encoding='utf-8'))
        planner = Planner(data, config)
        result = planner.plan()
    except (OSError, ValueError, TypeError, OverflowError, RecursionError) as exc:
        print(f'epic-granularity: {exc}', file=sys.stderr)
        print(json.dumps(dict(schema_version=1, status='invalid', error=str(exc)), ensure_ascii=False))
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True, allow_nan=False))
    return 2 if result['unplaced'] else 0


if __name__ == '__main__':
    sys.exit(main())
