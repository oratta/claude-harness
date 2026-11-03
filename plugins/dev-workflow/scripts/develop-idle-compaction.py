#!/usr/bin/env python3
"""Check or atomically set only worktree-local idleCompaction on disk."""

import argparse
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON key")
        result[key] = value
    return result


def reject_constant(_value):
    raise ValueError("invalid JSON constant")


def configure(worktree, apply):
    root = Path(worktree).absolute()
    target = root / ".claude" / "settings.local.json"
    temporary = None
    try:
        git = subprocess.run(
            ["git", "-C", str(root), "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=False,
        )
        if git.returncode or Path(git.stdout.strip()).resolve() != root.resolve():
            raise ValueError("expected a git worktree root")
        directory = target.parent
        if directory.is_symlink() or target.is_symlink():
            raise ValueError("symlinks are not supported")
        data = {}
        mode = 0o600
        if target.exists():
            info = target.stat()
            if not stat.S_ISREG(info.st_mode):
                raise ValueError("settings must be a regular file")
            if not info.st_mode & 0o444:
                raise ValueError("settings are not readable")
            mode = stat.S_IMODE(info.st_mode)
            data = json.loads(
                target.read_text(encoding="utf-8"),
                object_pairs_hook=unique_object, parse_constant=reject_constant,
            )
            if not isinstance(data, dict):
                raise ValueError("settings must be a JSON object")
        if data.get("idleCompaction") is False:
            print(f"{target}: disk idleCompaction is false")
            return 0
        if not apply:
            print(f"{target}: disk idleCompaction needs false")
            return 2
        data["idleCompaction"] = False
        # Serialize before creating anything; rejected inputs leave no new paths.
        content = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
        directory.mkdir(exist_ok=True)
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=directory,
            prefix=".idle-compaction-", delete=False,
        ) as stream:
            temporary = stream.name
            os.fchmod(stream.fileno(), mode)
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, target)
        temporary = None
        print(f"{target}: disk idleCompaction set to false")
        return 0
    except (OSError, ValueError) as error:
        # JSON diagnostics can contain configuration contents: never echo them.
        if isinstance(error, json.JSONDecodeError):
            reason = "invalid JSON"
        elif isinstance(error, UnicodeError):
            reason = "invalid UTF-8"
        elif isinstance(error, OSError):
            reason = error.strerror or "filesystem operation failed"
        else:
            reason = str(error)
        print(f"{target}: {reason}", file=sys.stderr)
        return 1
    finally:
        if temporary is not None:
            os.unlink(temporary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--check", action="store_true")
    action.add_argument("--apply", action="store_true")
    parser.add_argument("worktree")
    args = parser.parse_args()
    return configure(args.worktree, args.apply)


if __name__ == "__main__":
    sys.exit(main())
