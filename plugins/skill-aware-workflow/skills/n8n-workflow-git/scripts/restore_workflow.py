#!/usr/bin/env python3
"""
n8n Workflow Credential Restorer

Replaces credential placeholders in workflow JSON with actual values from .env file.
Used to reconstruct a complete workflow for import into n8n.

Usage:
    python restore_workflow.py <workflow.json> [--env-file <path>] [--output <path>]

Example:
    python restore_workflow.py auto-post-to-x-from-notion.json
    python restore_workflow.py workflow.json --output workflow-restored.json
"""

import json
import re
import sys
import argparse
from pathlib import Path
from typing import Any


def load_env_file(env_path: Path) -> dict[str, str]:
    """Load environment variables from .env file."""
    env_vars = {}

    if not env_path.exists():
        return env_vars

    with open(env_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if '=' not in line:
                continue

            key, _, value = line.partition('=')
            key = key.strip()
            value = value.strip()

            # Remove quotes if present
            if value.startswith('"') and value.endswith('"'):
                value = value[1:-1]
            elif value.startswith("'") and value.endswith("'"):
                value = value[1:-1]

            env_vars[key] = value

    return env_vars


def restore_credentials(workflow: dict, env_vars: dict[str, str]) -> tuple[dict, list[str]]:
    """Replace credential placeholders with actual values.

    Returns (restored_workflow, list_of_missing_vars).
    """
    missing_vars = []
    placeholder_pattern = re.compile(r'\$\{([^}]+)\}')

    nodes = workflow.get('nodes', [])
    for node in nodes:
        node_creds = node.get('credentials', {})
        for cred_type, cred_data in node_creds.items():
            for field in ['id', 'name']:
                if field not in cred_data:
                    continue

                value = cred_data[field]
                match = placeholder_pattern.match(str(value))
                if match:
                    var_name = match.group(1)
                    if var_name in env_vars:
                        cred_data[field] = env_vars[var_name]
                    else:
                        missing_vars.append(var_name)

    return workflow, missing_vars


def main():
    parser = argparse.ArgumentParser(
        description='Restore n8n workflow credentials from .env file'
    )
    parser.add_argument('workflow_file', type=Path, help='Path to workflow JSON file')
    parser.add_argument('--env-file', type=Path, default=None,
                        help='Path to .env file (default: same directory as workflow)')
    parser.add_argument('--output', '-o', type=Path, default=None,
                        help='Output file path (default: print to stdout)')
    parser.add_argument('--in-place', '-i', action='store_true',
                        help='Modify workflow file in place (use with caution)')

    args = parser.parse_args()

    # Determine .env file path
    if args.env_file:
        env_path = args.env_file
    else:
        env_path = args.workflow_file.parent / '.env'

    # Read workflow
    if not args.workflow_file.exists():
        print(f'Error: Workflow file not found: {args.workflow_file}', file=sys.stderr)
        sys.exit(1)

    with open(args.workflow_file, 'r', encoding='utf-8') as f:
        workflow = json.load(f)

    # Load .env file
    if not env_path.exists():
        print(f'Warning: .env file not found: {env_path}', file=sys.stderr)
        env_vars = {}
    else:
        env_vars = load_env_file(env_path)
        print(f'Loaded {len(env_vars)} variables from {env_path}', file=sys.stderr)

    # Restore credentials
    restored_workflow, missing_vars = restore_credentials(workflow, env_vars)

    if missing_vars:
        print(f'Warning: Missing environment variables:', file=sys.stderr)
        for var in sorted(set(missing_vars)):
            print(f'  - {var}', file=sys.stderr)

    # Output
    output_json = json.dumps(restored_workflow, indent=2, ensure_ascii=False)

    if args.in_place:
        with open(args.workflow_file, 'w', encoding='utf-8') as f:
            f.write(output_json)
        print(f'Workflow restored in place: {args.workflow_file}', file=sys.stderr)
    elif args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(output_json)
        print(f'Restored workflow saved to: {args.output}', file=sys.stderr)
    else:
        print(output_json)


if __name__ == '__main__':
    main()
