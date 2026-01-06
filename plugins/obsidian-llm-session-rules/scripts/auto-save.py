#!/usr/bin/env python3
"""
Auto-save session transcript to LLM/ directory as Markdown.
Triggered by Stop hook after each Claude response.
"""

import json
import sys
import os
from datetime import datetime
from pathlib import Path

def parse_transcript(transcript_path: str) -> list:
    """Parse JSONL transcript file and extract conversation."""
    messages = []
    expanded_path = os.path.expanduser(transcript_path)

    if not os.path.exists(expanded_path):
        return messages

    with open(expanded_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                entry_type = entry.get('type')

                # Extract user input (type: 'user' in transcript)
                # Skip tool results (entries with 'toolUseResult' key)
                if entry_type == 'user' and 'toolUseResult' not in entry:
                    content = entry.get('message', {}).get('content', '')
                    if isinstance(content, str) and content.strip():
                        # Direct user input as string
                        messages.append({'role': 'user', 'content': content.strip()})
                    elif isinstance(content, list):
                        # Handle content blocks (but skip tool_result blocks)
                        text_parts = []
                        for block in content:
                            if isinstance(block, dict):
                                # Only extract text blocks, skip tool_result
                                if block.get('type') == 'text':
                                    text_parts.append(block.get('text', ''))
                            elif isinstance(block, str):
                                text_parts.append(block)
                        if text_parts:
                            content = '\n'.join(text_parts)
                            if content.strip():
                                messages.append({'role': 'user', 'content': content.strip()})

                # Extract Claude's response
                elif entry_type == 'assistant':
                    content = entry.get('message', {}).get('content', '')
                    if isinstance(content, list):
                        text_parts = []
                        for block in content:
                            if isinstance(block, dict) and block.get('type') == 'text':
                                text_parts.append(block.get('text', ''))
                        content = '\n'.join(text_parts)
                    if content and content.strip():
                        messages.append({'role': 'assistant', 'content': content.strip()})
            except json.JSONDecodeError:
                continue

    return messages

def generate_markdown(messages: list, session_id: str, cwd: str) -> str:
    """Convert messages to Markdown format."""
    now = datetime.now()
    
    md_content = f"""# Session Log

- Session ID: {session_id}
- Date: {now.strftime('%Y-%m-%d %H:%M')}
- Directory: {cwd}

---

"""
    
    for msg in messages:
        role = "**User**" if msg['role'] == 'user' else "**Claude**"
        content = msg['content']
        md_content += f"## {role}\n\n{content}\n\n---\n\n"
    
    return md_content

def main():
    # Read hook input from stdin
    try:
        hook_input = json.loads(sys.stdin.read())
    except json.JSONDecodeError:
        sys.exit(0)
    
    transcript_path = hook_input.get('transcript_path', '')
    session_id = hook_input.get('session_id', 'unknown')
    cwd = hook_input.get('cwd', os.getcwd())
    
    if not transcript_path:
        sys.exit(0)
    
    # Parse transcript
    messages = parse_transcript(transcript_path)
    
    if not messages:
        sys.exit(0)
    
    # Determine save directory (LLM/ in current working directory)
    llm_dir = Path(cwd) / 'LLM'
    llm_dir.mkdir(exist_ok=True)
    
    # Generate filename with date and session ID
    now = datetime.now()
    filename = f"{now.strftime('%Y-%m-%d')}_{session_id[:8]}.md"
    filepath = llm_dir / filename
    
    # Generate and save Markdown
    md_content = generate_markdown(messages, session_id, cwd)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(md_content)
    
    # Output nothing to avoid interfering with Claude
    sys.exit(0)

if __name__ == '__main__':
    main()
