#!/usr/bin/env python3
"""How much each account has left, and until when: the one place this is counted.

Specified in openspec/specs/dev-workflow-headroom. The counting is moved from flatmate's
scripts/account_allocation.py (evaluate_accounts / segment_surplus / counted_tickets); the Claude
reset grants are read like flatmate's dashboard (_saved_reset_grants / _claude_credits).

  headroom.py --json [--now EPOCH]                   print compute(now) as one JSON line
  headroom.py write [--refresh-codex] [--now EPOCH]  write ${CLAUDE_CONFIG_DIR:-~/.claude}/.headroom.json

Inputs: the Claude effective values (usage_view.build_view, on/off from usage_view.read_slots),
the reset grants in .usage-snapshot (accounts.<id>.reset_grants), and the Codex `current`
account's cache codex-usage/<hash>.json written by codex-develop.py. claude_rows and codex_row
give the same rows to codex-develop.py (its snapshot path, any Codex account it maps).
Settings come only from
HEADROOM_7D_CAP_PCT (default 90) and HEADROOM_NORMAL_RATE_PCT_PER_DAY (default none); a caller
cannot pass them. An invalid setting is an error (exit 2, nothing written), never the default.
"""
from datetime import datetime
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import sys
import tempfile
import time

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))
import usage_view  # noqa: E402

SCHEMA = 1
WEEK_SECONDS = 604800
WEEK_HOURS = 168
RATE_FLOOR_HOURS = 24
CAP_7D_DEFAULT = 90
FIVE_HOUR_LIMIT = 90        # best skips accounts at or above this five-hour use (not a setting)
FUTURE_TOLERANCE = 60       # a fetch up to this far in the future is clock drift, still ok
CODEX_WEEK_MINUTES = 10080
CODEX_FIVE_HOUR_MINUTES = 300
SPARE_KEYS = ('rocket', 'tickets', 'capacity_pct', 'left_pct', 'deadline_at', 'deadline_reason',
              'forecast', 'surplus_pct', 'margin')
VALUE_KEYS = ('observed_at', 'five_hour_pct', 'used_pct', 'elapsed_pct', 'weekly_reset_at') + SPARE_KEYS
_ISO = re.compile(r'(\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):\d{2}:\d{2})(?:\.(\d+))?(Z|[+-]\d{2}:\d{2})')
_codex = None


class ConfigError(Exception):
    """An invalid HEADROOM_* value (CLI exit 2)."""


def _setting(name, default):
    raw = os.environ.get(name)
    if raw is None or raw.strip() == '':
        return default
    try:
        value = float(raw)
    except ValueError:
        raise ConfigError(f'{name} must be a number') from None
    if not math.isfinite(value) or not 0 <= value <= 100:
        raise ConfigError(f'{name} must be between 0 and 100')
    return int(value) if value.is_integer() else value


def settings():
    return {'cap_7d_pct': _setting('HEADROOM_7D_CAP_PCT', CAP_7D_DEFAULT),
            'normal_rate_pct_per_day': _setting('HEADROOM_NORMAL_RATE_PCT_PER_DAY', None)}


def segment_surplus(to_cap, rate_per_h, hours):
    """What is left of to_cap after `hours` at the normal pace (never negative)."""
    return max(0.0, to_cap - rate_per_h * hours)


def counted_tickets(items, now, reset_at):
    """Tickets that expire after now and before reset_at, as sorted [(expires_at, count)]."""
    by_expiry = {}
    for expires_at, count in items:
        if expires_at is not None and now < expires_at < reset_at and count > 0:
            by_expiry[expires_at] = by_expiry.get(expires_at, 0) + count
    return sorted(by_expiry.items())


def _iso_epoch(value):
    match = _ISO.fullmatch(value) if isinstance(value, str) else None
    if not match:
        return None
    base, fraction, zone = match.groups()
    text = base + '.' + (fraction or '0').ljust(6, '0')[:6] + ('+00:00' if zone == 'Z' else zone)
    try:
        return math.floor(datetime.fromisoformat(text).timestamp())
    except (ValueError, OverflowError, OSError):
        return None


def _claude_tickets(grants):
    """reset_grants -> [(expires_at or None, resets_left)] or None when the field is unreadable.

    Paused bundles and bundles with no resets left are not held. Any bundle that cannot be read
    makes the whole field unknown (counted as zero tickets, `tickets` null).
    """
    if not isinstance(grants, list):
        return None
    items = []
    for item in grants:
        if not isinstance(item, dict):
            return None
        count, paused, ends = item.get('resets_left'), item.get('paused'), item.get('ends_at')
        if type(count) is not int or count < 0 or not (paused is None or type(paused) is bool):
            return None
        expiry = None
        if ends is not None:
            expiry = _iso_epoch(ends)
            if expiry is None:
                return None
        if count and not paused:
            items.append((expiry, count))
    return items


def _codex_tickets(resets, now):
    """Cache resets -> (held count, [(expires_at or None, 1)]) or None when unreadable.

    available_count was true at the fetch; the credits that expired since then (an integer
    expires_at at or before now) are taken off it, never below zero.
    """
    if not isinstance(resets, dict):
        return None
    count, expires = resets.get('available_count'), resets.get('expires_at')
    if type(count) is not int or count < 0 or not isinstance(expires, list):
        return None
    items = [(value if type(value) is int else None, 1) for value in expires]
    expired = sum(1 for expiry, _ in items if expiry is not None and expiry <= now)
    return max(0, count - expired), items


def _held(count, items, now):
    known = [expiry for expiry, n in items if expiry is not None and expiry > now and n > 0]
    return {'count': count, 'earliest_expiry': min(known) if known else None}


def _blank(provider, account, label, status):
    row = {'provider': provider, 'account': account, 'label': label, 'status': status}
    row.update({key: None for key in VALUE_KEYS})
    return row


def _row(provider, account, label, *, observed, five, used, reset, now, cfg, ticket_count, items):
    """One counted row (status ok or stale) from the weekly effective values."""
    row = _blank(provider, account, label, 'ok')
    weekly_elapsed = 100 * (1 - (reset - now) / WEEK_SECONDS)
    row.update(observed_at=observed, five_hour_pct=five, used_pct=used, weekly_reset_at=reset,
               elapsed_pct=min(100.0, max(0.0, weekly_elapsed)))
    if observed is not None and observed > now + FUTURE_TOLERANCE:
        row['status'] = 'stale'
        return row
    cap = cfg['cap_7d_pct']
    hours_left = (reset - now) / 3600
    to_cap = (100 - used) - (100 - cap)
    if cfg['normal_rate_pct_per_day'] is not None:
        rate = cfg['normal_rate_pct_per_day'] / 24
    else:
        rate = used / max(WEEK_HOURS - hours_left, RATE_FLOOR_HOURS)
    counted = counted_tickets(items or [], now, reset)
    rocket_count = sum(n for _, n in counted)
    rocket = {'count': rocket_count, 'earliest_expiry': counted[0][0]} if counted else None
    if provider == 'claude':
        end = counted[0][0] if counted else reset
        surplus = segment_surplus(to_cap, rate, (end - now) / 3600) + rocket_count * cap
        capacity, left = 100 + 100 * rocket_count, (100 - used) + 100 * rocket_count
        deadline, reason = reset, 'weekly_reset'
    else:
        deadline = min(reset, counted[0][0]) if counted else reset
        reason = 'ticket_expiry' if deadline < reset else 'weekly_reset'
        surplus = segment_surplus(to_cap, rate, (deadline - now) / 3600)
        capacity, left = 100, 100 - used
        if reason == 'ticket_expiry':
            start = reset - WEEK_SECONDS
            # A deadline at or before the start of the week (reset more than a week away) has
            # not begun: 0, and no division by a zero or negative span.
            row['elapsed_pct'] = (0.0 if deadline <= start else
                                  min(100.0, max(0.0, 100 * (now - start) / (deadline - start))))
    spare = left - rate * (deadline - now) / 3600
    forecast = ({'kind': 'spare', 'pct': spare} if spare >= 0 else
                {'kind': 'exhaust', 'at': now + left / rate * 3600})
    row.update(rocket=rocket,
               tickets=None if items is None else _held(ticket_count, items, now),
               capacity_pct=capacity, left_pct=left, deadline_at=deadline, deadline_reason=reason,
               forecast=forecast, surplus_pct=surplus, margin=weekly_elapsed - used)
    return row


def claude_rows(now, snapshot_path=None):
    """The Claude rows in declared order (the ones compute uses).

    snapshot_path, when given, is read for both the effective values (build_view) and the reset
    grants; otherwise the default of compute (usage_view.default_paths). The settings are read
    here, never passed in.
    """
    return _claude_rows(now, snapshot_path, settings())


def _claude_rows(now, snapshot_path, cfg):
    paths = usage_view.default_paths()
    if snapshot_path is None:
        snapshot_path = paths['snapshot_path']
        view = usage_view.build_view(now=now)
    else:
        view = usage_view.build_view(snapshot_path=snapshot_path, now=now)
    snapshot = usage_view.read_snapshot(snapshot_path)
    entries = snapshot.get('accounts') if isinstance(snapshot.get('accounts'), dict) else {}
    rows = []
    for slot_id, _secure, enabled in usage_view.read_slots(paths['accounts_file']):
        entry = entries.get(slot_id) if isinstance(entries.get(slot_id), dict) else {}
        label = entry.get('label') if isinstance(entry.get('label'), str) and entry.get('label') else slot_id
        if not enabled:
            rows.append(_blank('claude', slot_id, label, 'off'))
            continue
        slot = view['accounts'].get(slot_id) or {}
        used, reset = slot.get('weekly_all_pct'), slot.get('weekly_resets_epoch')
        if not (usage_view.finite_number(used) and 0 <= used <= 100 and usage_view.finite_number(reset)):
            rows.append(_blank('claude', slot_id, label, 'missing'))
            continue
        items = _claude_tickets(entry.get('reset_grants'))
        count = None if items is None else sum(
            n for expiry, n in items if expiry is None or expiry > now)
        rows.append(_row('claude', slot_id, label, observed=slot.get('observed_at'),
                         five=slot.get('five_hour_pct'), used=used, reset=reset, now=now, cfg=cfg,
                         ticket_count=count, items=items))
    return rows


def _codex_module():
    """codex-develop.py, loaded on first use (it imports headroom for its margins)."""
    global _codex
    if _codex is None:
        spec = importlib.util.spec_from_file_location('codex_develop_for_headroom',
                                                      SCRIPTS / 'codex-develop.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        _codex = module
    return _codex


def _codex_home():
    """The automatic default of codex-develop.py (`current`: CODEX_HOME, else ~/.codex), or None."""
    return _codex_module().default_automatic_account_home().get('current')


def _codex_enabled():
    return usage_view.read_codex_enabled(usage_view.default_paths()['accounts_file'])


def _codex_window(windows, minutes):
    for item in windows:
        if isinstance(item, dict) and item.get('minutes') == minutes:
            return item
    return None


def codex_row(account, cache, now):
    """One Codex row named `account` from a loaded cache (None or any shape is accepted).

    The caller has already matched the auth identity and checked that Codex is on; any account
    name is accepted. A cache whose weekly window cannot be read gives a `missing` row.
    """
    return _codex_row(account, cache, now, settings())


def _codex_row(account, cache, now, cfg):
    missing = _blank('codex', account, account, 'missing')
    if not isinstance(cache, dict):
        return missing
    fetched, windows = cache.get('fetched_at'), cache.get('windows')
    if type(fetched) is not int or not isinstance(windows, list):
        return missing
    weekly = _codex_window(windows, CODEX_WEEK_MINUTES)
    used = weekly.get('used_percent') if weekly else None
    reset = weekly.get('reset_at') if weekly else None
    if not (usage_view.finite_number(used) and 0 <= used <= 100 and type(reset) is int):
        return missing
    # Past the reset the window is 0% and the reset moves on by whole weeks; the age of the
    # fetch is not checked.
    if now >= reset:
        used = 0
        reset += ((now - reset) // WEEK_SECONDS + 1) * WEEK_SECONDS
    five = None
    window = _codex_window(windows, CODEX_FIVE_HOUR_MINUTES)
    if window and usage_view.finite_number(window.get('used_percent')):
        five_reset = window.get('reset_at')
        five = 0 if usage_view.finite_number(five_reset) and now >= five_reset else window['used_percent']
    tickets = _codex_tickets(cache.get('resets'), now)
    count, items = tickets if tickets is not None else (None, None)
    return _row('codex', account, account, observed=fetched, five=five, used=used,
                reset=reset, now=now, cfg=cfg, ticket_count=count, items=items)


def _codex_rows(now, cfg):
    """compute's Codex rows: only `current`, read from its cache file after the identity check."""
    missing = [_blank('codex', 'current', 'current', 'missing')]
    try:
        home = _codex_home()
    except Exception:
        # A Codex home that cannot be resolved (e.g. no permission on its parent) must not stop
        # compute: `cld` reads it on every launch.
        return missing
    if home is None:
        return []
    if not _codex_enabled():
        return [_blank('codex', 'current', 'current', 'off')]
    codex = _codex_module()
    try:
        cache = json.loads(codex._cache_path(usage_view.config_dir(), home).read_text())
        if not isinstance(cache, dict) or cache.get('identity') != codex._auth_identity(home):
            return missing
    except Exception:
        return missing
    return [_codex_row('current', cache, now, cfg)]


def _best(rows):
    best = None
    for row in rows:
        if row['status'] != 'ok' or not usage_view.finite_number(row['surplus_pct']):
            continue
        if row['five_hour_pct'] is not None and row['five_hour_pct'] >= FIVE_HOUR_LIMIT:
            continue
        if best is None or row['surplus_pct'] > best['surplus_pct']:
            best = row
    return {'provider': best['provider'], 'account': best['account']} if best else None


def compute(now):
    cfg = settings()
    rows = _claude_rows(now, None, cfg) + _codex_rows(now, cfg)
    return {'schema': SCHEMA, 'computed_at': now, 'settings': cfg, 'best': _best(rows),
            'best_by_provider': {provider: _best([r for r in rows if r['provider'] == provider])
                                 for provider in ('claude', 'codex')},
            'accounts': rows}


def refresh_codex(now):
    """Re-read the Codex usage (current only) before writing; nothing when off or no home."""
    home = _codex_home()
    if home is None or not _codex_enabled():
        return
    _codex_module().read_codex_usages({'current': home}, usage_view.config_dir(), now)


def write(result):
    directory = Path(usage_view.config_dir())
    directory.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix='.headroom.', suffix='.tmp', dir=directory)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as handle:
            json.dump(result, handle, ensure_ascii=False, separators=(',', ':'))
            handle.write('\n')
        os.replace(tmp, directory / '.headroom.json')
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


USAGE = 'usage: headroom.py --json [--now EPOCH] | headroom.py write [--refresh-codex] [--now EPOCH]\n'


def main(argv):
    args = list(argv)
    now = None
    if '--now' in args:
        index = args.index('--now')
        try:
            now = int(args[index + 1])
        except (IndexError, ValueError):
            sys.stderr.write(USAGE)
            return 2
        del args[index:index + 2]
    if args == ['--json']:
        mode, refresh = 'json', False
    elif args and args[0] == 'write' and args[1:] in ([], ['--refresh-codex']):
        mode, refresh = 'write', args[1:] == ['--refresh-codex']
    else:
        sys.stderr.write(USAGE)
        return 2
    now = int(time.time()) if now is None else now
    try:
        settings()
    except ConfigError as exc:
        sys.stderr.write(f'headroom: {exc}\n')
        return 2
    if refresh:
        try:
            refresh_codex(now)
        except Exception:
            pass  # a failed fetch keeps the previous cache; count from it
    try:
        result = compute(now)
    except ConfigError as exc:
        sys.stderr.write(f'headroom: {exc}\n')
        return 2
    if mode == 'json':
        print(json.dumps(result, ensure_ascii=False, separators=(',', ':')))
    else:
        write(result)
    return 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
