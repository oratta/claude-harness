#!/usr/bin/env python3
"""Compare the procedures actually loaded with freshly fetched main content."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import urlsplit, urlunsplit

SKILL = 'skills/develop/SKILL.md'
PREFIX = 'plugins/dev-workflow/'
MARK = 'develop-procedure-preview.json'


def run(*args, **kwargs):
    return subprocess.run(args, check=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, **kwargs).stdout


def git(repo, *args):
    return run('git', '-C', str(repo), *args)


def target(name):
    return name == SKILL or (name.endswith('.md') and name.startswith(
        ('skills/develop/references/', 'references/')))


def digest(files):
    raw = b'develop-procedure-v1\0'
    for name, content in sorted(files, key=lambda item: item[0].encode('utf-8')):
        raw += name.encode('utf-8') + b'\0' + hashlib.sha256(content).hexdigest().encode() + b'\n'
    return 'sha256:' + hashlib.sha256(raw).hexdigest()


def readable(path):
    # Also detect unreadable fixtures when run by a privileged account.
    if not path.stat().st_mode & 0o444:
        raise ValueError(f'読取不能: {path}')
    return path.read_bytes()


def fingerprint(root):
    root = Path(root)
    files = {SKILL: readable(root / SKILL)}
    for folder in ['skills/develop/references', 'references']:
        for path in (root / folder).rglob('*.md'):
            files[path.relative_to(root).as_posix()] = readable(path)
    return digest(files.items())


def tree_fingerprint(repo, oid):
    files = []
    names = git(repo, 'ls-tree', '-r', '--name-only', '-z', oid, '--', PREFIX).split(b'\0')
    for raw in names:
        name = raw.decode('utf-8')
        if name.startswith(PREFIX) and target(name[len(PREFIX):]):
            files.append((name[len(PREFIX):], git(repo, 'show', f'{oid}:{name}')))
    if not any(name == SKILL for name, _ in files):
        # A valid loaded tree always has SKILL; this historical tree cannot match.
        return None
    return digest(files)


def record_url(value):
    url = urlsplit(value)
    path = url.path.rstrip('/')
    if (url.scheme not in ('https', 'http') or not url.netloc
            or not re.fullmatch(r'/[^/]+/[^/]+/(issues|pull)/[1-9][0-9]*', path)):
        raise ValueError('記録先には完全な issue/PR URL が必要')
    return urlunsplit((url.scheme, url.netloc, path, '', ''))


def preview_tuple(args, loaded):
    worktree = Path(args.preview_worktree).resolve()
    actual = Path(git(worktree, 'rev-parse', '--show-toplevel').decode().strip()).resolve()
    if actual != worktree:
        raise ValueError('元 worktree root を指定してください')
    head = git(worktree, 'rev-parse', 'HEAD').decode().strip()
    if loaded != fingerprint(worktree / PREFIX) or loaded != tree_fingerprint(worktree, head):
        raise ValueError('3者の指紋不一致: 対象内容を先に commit してください')
    directory = Path(git(worktree, 'rev-parse', '--absolute-git-dir').decode().strip()).resolve()
    common = Path(git(worktree, 'rev-parse', '--git-common-dir').decode().strip())
    if directory == (worktree / common).resolve():
        raise ValueError('共有 git-common-dir には印を発行できません: linked worktree を指定してください')
    return directory / MARK, dict(schema_version=1, loaded_plugin_root=str(args.loaded_plugin_root),
                                 worktree_root=str(worktree), worktree_head=head,
                                 procedure_fingerprint=loaded, record_url=args.record)


def valid_preview(args, loaded):
    if not args.preview_worktree:
        return False
    try:
        path, expected = preview_tuple(args, loaded)
        actual = json.loads(readable(path))
        if actual != expected or type(actual.get('schema_version')) is not int:
            raise ValueError('印の tuple 不一致')
        return True
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(f'警告: マージ前の印を無視します: {exc}', file=sys.stderr)
        return False


def emit(status, **fields):
    print(json.dumps(dict(status=status, **fields), ensure_ascii=False))


def record_continue(args, reason, fetched=False):
    detail = ('読込元と origin/main の新旧を証明できない' if fetched
              else 'origin/main を取得できなかった')
    body = (f'手順書の版を確かめられなかった。{detail}ため、develop を続けます。\n'
            f'読込元: {args.loaded_plugin_root}\n'
            f'比較元: {args.comparison_repo or "未設定"}\n理由: {reason}')
    kind = 'issue' if '/issues/' in urlsplit(args.record).path else 'pr'
    recording = 'posted'
    try:
        run('gh', kind, 'comment', args.record, '--body-file', '-', input=body.encode('utf-8'))
    except (OSError, subprocess.CalledProcessError) as exc:
        recording = 'failed'
        print(f'投稿失敗: {exc}', file=sys.stderr)
    emit('continue', reason=reason, body=body, recording=recording)
    return 0


def check(args, loaded):
    # Validate an explicit preview even if main later proves identical/unavailable.
    preview = valid_preview(args, loaded)
    if not args.comparison_repo:
        return record_continue(args, 'comparison-repo-unavailable')
    try:
        git(args.comparison_repo, 'rev-parse', '--git-dir')
    except (OSError, subprocess.CalledProcessError):
        return record_continue(args, 'comparison-repo-unavailable')
    try:
        git(args.comparison_repo, 'fetch', '--no-tags', 'origin',
            '+refs/heads/main:refs/remotes/origin/main')
    except (OSError, subprocess.CalledProcessError):
        return record_continue(args, 'origin-main-fetch-failed')
    try:
        tip = git(args.comparison_repo, 'rev-parse', 'refs/remotes/origin/main').decode().strip()
        if loaded == tree_fingerprint(args.comparison_repo, tip):
            emit('same', procedure_fingerprint=loaded, main_tip=tip)
            return 0
        if preview:
            emit('preview', procedure_fingerprint=loaded, main_tip=tip)
            return 0
        history = git(args.comparison_repo, 'rev-list', '--first-parent', tip).decode().splitlines()
        for oid in history[1:]:
            if loaded == tree_fingerprint(args.comparison_repo, oid):
                emit('old', procedure_fingerprint=loaded, main_tip=tip, matched_commit=oid)
                return 1
        incomplete = git(args.comparison_repo, 'rev-parse', '--is-shallow-repository').strip() == b'true'
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(f'履歴の照合不能: {exc}', file=sys.stderr)
        incomplete = True
    return record_continue(args, 'history-incomplete' if incomplete
                           else 'fingerprint-not-in-main-history', fetched=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for command in ['check', 'mark-preview']:
        p = sub.add_parser(command)
        p.add_argument('--loaded-plugin-root', required=True)
        p.add_argument('--record', required=True)
        p.add_argument('--preview-worktree', required=command == 'mark-preview')
        if command == 'check':
            p.add_argument('--comparison-repo', default=os.environ.get('CLAUDE_HARNESS_DEV_DIR'))
    args = parser.parse_args()
    try:
        args.record = record_url(args.record)
        args.loaded_plugin_root = Path(args.loaded_plugin_root).resolve()
        loaded = fingerprint(args.loaded_plugin_root)
        if args.command == 'mark-preview':
            path, value = preview_tuple(args, loaded)
            path.write_text(json.dumps(value, ensure_ascii=False) + '\n', encoding='utf-8')
            emit('preview-marked', **value)
            return 0
        if args.comparison_repo:
            args.comparison_repo = Path(args.comparison_repo).resolve()
        return check(args, loaded)
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(f'検査入力不備: {exc}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
