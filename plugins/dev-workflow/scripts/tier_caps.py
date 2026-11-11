"""The cap of a role's tier, shared by codex-develop.py and agent-model-guard.sh (#615).

Both enforcement layers turn a model name back into a tier and word the refusal here, so the
same table cannot give two answers. Standard library only, and Python 3.9 syntax: the guard
runs under macOS's /usr/bin/python3.
"""
import json

TIERS = ('最安', '中位', '上位', '最上位')
# The writer roles are the only capped ones (model-tier-resolution「格の語と対応表を 1 か所に置く」).
CAPPED_ROLES = ('spec-write', 'implement')
TABLE_PATH = 'references/model-tier-map.json'


def model_tier(models, model):
    """The lowest tier whose model name equals the model or one of its '-' pieces, else None.

    The lowest one: a model listed under two tiers runs at the lower one too, so judging it
    there never stops a model that is allowed below the cap.
    """
    if not isinstance(model, str):
        return None
    name = model.strip().lower()
    if not name:
        return None
    pieces = {name} | set(name.split('-'))
    for tier in TIERS:
        listed = models.get(tier)
        if isinstance(listed, str) and listed.strip().lower() in pieces:
            return tier
    return None


def exceeds(tier, cap):
    return tier is not None and cap in TIERS and TIERS.index(tier) > TIERS.index(cap)


def refusal(role, tier, cap, note=None):
    where = f'（{note}）' if note else ''
    return (f'役 {role}{where}に格 {tier} は付けられない。この役の上限は {cap}'
            f'（plugins/dev-workflow/{TABLE_PATH} の role_caps）。')


def read_table(path):
    """The table as the guard reads it, or None when it is unreadable (the guard fails open)."""
    try:
        with open(path, encoding='utf-8') as handle:
            table = json.load(handle)
        claude = table['executors']['claude']
        caps = table['role_caps']
        if not isinstance(claude, dict) or not isinstance(caps, dict):
            return None
        return table
    except Exception:
        return None
