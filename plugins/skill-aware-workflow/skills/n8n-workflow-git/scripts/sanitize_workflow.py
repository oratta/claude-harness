#!/usr/bin/env python3
"""
n8n Workflow Sanitizer

Extracts credentials from n8n workflow JSON and replaces them with placeholders.
Credentials are saved to a .env file for secure storage.

Usage:
    python sanitize_workflow.py <workflow.json> [--env-file <path>]

Example:
    python sanitize_workflow.py auto-post-to-x-from-notion.json
    python sanitize_workflow.py workflow.json --env-file ../.env
"""

import json
import re
import sys
import argparse
from pathlib import Path
from typing import Any


def to_env_key(credential_type: str) -> str:
    """Convert credential type to environment variable key format.

    Example: notionApi -> NOTION_API, twitterOAuth2Api -> TWITTER_OAUTH2_API
    """
    # Insert underscore before uppercase letters, then uppercase all
    result = re.sub(r'([a-z])([A-Z])', r'\1_\2', credential_type)
    return result.upper()


def extract_credentials(workflow: dict) -> dict[str, dict[str, str]]:
    """Extract all credentials from workflow nodes.

    Returns dict mapping credential type to {id, name}.
    """
    credentials = {}

    nodes = workflow.get('nodes', [])
    for node in nodes:
        node_creds = node.get('credentials', {})
        for cred_type, cred_data in node_creds.items():
            if cred_type not in credentials:
                credentials[cred_type] = {
                    'id': cred_data.get('id', ''),
                    'name': cred_data.get('name', '')
                }

    return credentials


def sanitize_workflow(workflow: dict, credentials: dict[str, dict[str, str]]) -> dict:
    """Replace credential values with placeholders in workflow.

    Modifies workflow in place and returns it.
    """
    nodes = workflow.get('nodes', [])
    for node in nodes:
        node_creds = node.get('credentials', {})
        for cred_type in node_creds:
            env_key = to_env_key(cred_type)
            node_creds[cred_type] = {
                'id': f'${{{env_key}_ID}}',
                'name': f'${{{env_key}_NAME}}'
            }

    return workflow


def generate_env_content(credentials: dict[str, dict[str, str]], existing_env: str = '') -> str:
    """Generate .env file content with credentials.

    Preserves existing entries and adds/updates credential entries.
    """
    # Parse existing .env content
    existing_vars = {}
    for line in existing_env.splitlines():
        line = line.strip()
        if line and not line.startswith('#') and '=' in line:
            key, _, value = line.partition('=')
            existing_vars[key.strip()] = value.strip()

    # Add/update credential entries
    for cred_type, cred_data in credentials.items():
        env_key = to_env_key(cred_type)
        existing_vars[f'{env_key}_ID'] = cred_data['id']
        # Quote name if it contains spaces
        name = cred_data['name']
        if ' ' in name or '"' in name:
            name = f'"{name}"'
        existing_vars[f'{env_key}_NAME'] = name

    # Generate sorted output
    lines = ['# n8n Workflow Credentials', '# Auto-generated - DO NOT COMMIT', '']

    # Group by prefix
    prefixes = set()
    for key in existing_vars:
        if '_ID' in key or '_NAME' in key:
            prefix = key.rsplit('_', 1)[0]
            prefixes.add(prefix)

    for prefix in sorted(prefixes):
        id_key = f'{prefix}_ID'
        name_key = f'{prefix}_NAME'
        if id_key in existing_vars:
            lines.append(f'{id_key}={existing_vars[id_key]}')
        if name_key in existing_vars:
            lines.append(f'{name_key}={existing_vars[name_key]}')
        lines.append('')

    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(
        description='Sanitize n8n workflow by extracting credentials to .env file'
    )
    parser.add_argument('workflow_file', type=Path, help='Path to workflow JSON file')
    parser.add_argument('--env-file', type=Path, default=None,
                        help='Path to .env file (default: same directory as workflow)')
    parser.add_argument('--dry-run', action='store_true',
                        help='Print changes without modifying files')

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

    # Extract credentials
    credentials = extract_credentials(workflow)

    if not credentials:
        print('No credentials found in workflow.')
        sys.exit(0)

    print(f'Found {len(credentials)} credential type(s):')
    for cred_type, cred_data in credentials.items():
        env_key = to_env_key(cred_type)
        print(f'  - {cred_type} -> {env_key}_ID, {env_key}_NAME')

    # Read existing .env if present
    existing_env = ''
    if env_path.exists():
        with open(env_path, 'r', encoding='utf-8') as f:
            existing_env = f.read()

    # Generate new .env content
    env_content = generate_env_content(credentials, existing_env)

    # Sanitize workflow
    sanitized_workflow = sanitize_workflow(workflow, credentials)

    if args.dry_run:
        print('\n--- .env content ---')
        print(env_content)
        print('\n--- Sanitized workflow (credentials only) ---')
        for node in sanitized_workflow.get('nodes', []):
            if 'credentials' in node:
                print(f'{node["name"]}: {node["credentials"]}')
    else:
        # Write .env file
        with open(env_path, 'w', encoding='utf-8') as f:
            f.write(env_content)
        print(f'\nCredentials saved to: {env_path}')

        # Write sanitized workflow
        with open(args.workflow_file, 'w', encoding='utf-8') as f:
            json.dump(sanitized_workflow, f, indent=2, ensure_ascii=False)
        print(f'Workflow sanitized: {args.workflow_file}')

        print(f'\nRemember to add {env_path} to .gitignore!')


if __name__ == '__main__':
    main()
