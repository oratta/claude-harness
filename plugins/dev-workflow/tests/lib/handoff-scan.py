#!/usr/bin/env python3
"""手渡し規則のホワイトリスト走査。

spec: dev-workflow-execution-strategy「サブエージェントのコンテキスト上限と手渡し」

トリガー語に掛かった面が、正本
（plugins/dev-workflow/skills/develop/references/decision-criteria.md
「コンテキスト上限（サブエージェントの手渡し）」）への参照を持つことを検査する。
禁じたい言い回しを列挙するブラックリストは採らない（1 つの言い回しに限定した正規表現で
2 度、面を手で列挙した一覧で 1 度、取り残しを見逃した）。

トリガーは語彙に依存することを前提に、取りこぼしより誤検出に倒す（再現率優先）。
誤検出は当該の面に正本への参照を 1 行足せば解消できるので、副作用が無い。

grep を使わないのは、マルチバイトの否定文字クラスが locale 次第で壊れ、偽陰性になるため。
"""
import argparse
import os
import re
import subprocess
import sys

# 語彙 A: 手渡しに固有の語。リポジトリの追跡ファイル全体に適用する。
VOCAB_A = re.compile('手渡|工程完了|工程中断|subagent-context|DEV_WORKFLOW_CONTEXT_CAP|コンテキスト上限')
# 語彙 B: 他の文脈でも使う一般語。dev-workflow プラグイン配下と dev-workflow の live spec にだけ適用する。
VOCAB_B = re.compile('引き継|交代|後任|乗り換え|新しい W|新しい G|新規 spawn|再 spawn')
VOCAB_B_SCOPE = ('plugins/dev-workflow/',)
VOCAB_B_SCOPE_RE = re.compile(r'^openspec/specs/dev-workflow-[^/]+/spec\.md$')

# 正本への参照とみなす文字列（spec が 2 つのリテラルに固定している）
REFERENCES = ('decision-criteria.md', 'コンテキスト上限（サブエージェントの手渡し）')

# 手渡しの許可条件を絶対文で述べる形。正本以外に現れてはならない。
PERMISSION_SENTENCE = re.compile('手渡.*行ってよいのは|手渡.*してよいのは')

# この検査を実装している 2 ファイルは、検出したい形をパターンとして書かざるを得ない。
# spec が「正本の断片を grep の引数として引用することは言い換えに当たらない」と定めているのと
# 同じ理由で、許可条件の文単位走査からだけ外す（ホワイトリスト走査の対象からは外さない）。
DETECTOR_FILES = (
    'plugins/dev-workflow/tests/lib/handoff-scan.py',
    'plugins/dev-workflow/tests/handoff-declaration.bats',
)


def excluded(path, this_change):
    """spec が定める 3 種の除外。これ以外の除外を増やしてはならない。"""
    # ①歴史記録
    if path == 'plugins/dev-workflow/CHANGELOG.md' or path.endswith('/CHANGELOG.md'):
        return True
    if path.startswith('_longruns/'):
        return True
    if path.startswith('openspec/changes/archive/') and not path.startswith(this_change):
        return True
    # ②change の proposal.md / tasks.md
    if re.match(r'^openspec/changes/.*/(proposal|tasks)\.md$', path):
        return True
    # ③配布メタデータ
    if path == 'plugins/dev-workflow/.claude-plugin/plugin.json':
        return True
    return False


def in_vocab_b_scope(path):
    return path.startswith(VOCAB_B_SCOPE) or bool(VOCAB_B_SCOPE_RE.match(path))


def read(root, path):
    try:
        with open(os.path.join(root, path), encoding='utf-8') as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError):
        return None


def tracked(root):
    out = subprocess.run(['git', '-C', root, 'ls-files'],
                         capture_output=True, text=True, check=True).stdout
    return [p for p in out.splitlines() if p and os.path.isfile(os.path.join(root, p))]


def has_reference(text):
    return any(r in text for r in REFERENCES)


def hits(pattern, text):
    return [(i, line.strip()[:160])
            for i, line in enumerate(text.splitlines(), 1) if pattern.search(line)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', required=True)
    ap.add_argument('--this-change', required=True)
    ap.add_argument('--mode', required=True)
    ap.add_argument('--source', default='')
    ap.add_argument('exemptions', nargs='*')
    args = ap.parse_args()

    exempt = {}
    for entry in args.exemptions:
        path, _, reason = entry.partition('\t')
        exempt[path.strip()] = reason.strip()

    root, this_change = args.root, args.this_change
    paths = [p for p in tracked(root) if not excluded(p, this_change)]

    if args.mode == 'list-inspected':
        print('\n'.join(paths))
        return 0

    if args.mode == 'list-excluded':
        print('\n'.join(p for p in tracked(root) if excluded(p, this_change)))
        return 0

    # 面ごとにどの語彙で発火したかを求める
    fired_a, fired_b = {}, {}
    for path in paths:
        text = read(root, path)
        if text is None:
            continue
        a = hits(VOCAB_A, text)
        if a:
            fired_a[path] = (text, a)
            continue  # 語彙 A で拾った面は語彙 B の判定に回さない
        if in_vocab_b_scope(path):
            b = hits(VOCAB_B, text)
            if b:
                fired_b[path] = (text, b)

    bad = 0

    if args.mode == 'offenders':
        for path, (text, lines) in sorted(fired_a.items()):
            if has_reference(text):
                continue
            bad = 1
            print(f'[語彙A] 正本への参照が無い: {path}')
            for num, line in lines[:5]:
                print(f'    {path}:{num}: {line}')
        for path, (text, lines) in sorted(fired_b.items()):
            if has_reference(text) or path in exempt:
                continue
            bad = 1
            print(f'[語彙B] 正本への参照も除外表の登録も無い: {path}')
            for num, line in lines[:5]:
                print(f'    {path}:{num}: {line}')
        if bad:
            print('\n参照 1 行（decision-criteria.md か「コンテキスト上限（サブエージェントの手渡し）」）'
                  'を足すか、語彙 B の面なら理由付きで除外表に載せること。')

    elif args.mode == 'stale':
        for path, reason in sorted(exempt.items()):
            if path in fired_b:
                continue
            bad = 1
            if path in fired_a:
                print(f'語彙 A で発火する面が除外表にある（除外できない）: {path}')
            elif path not in paths:
                print(f'除外表の面が検査対象に存在しない: {path}')
            else:
                print(f'除外表の面がトリガー語を含まなくなった（stale。行を消すこと）: {path} — {reason}')

    elif args.mode == 'vocab-a-exempt':
        for path in sorted(exempt):
            if path in fired_a:
                bad = 1
                print(f'語彙 A（手渡し固有語）で発火する面は除外表に載せられない: {path}')

    elif args.mode == 'permission-sentences':
        source = args.source
        for path in paths:
            if path == source or path in DETECTOR_FILES:
                continue
            text = read(root, path)
            if text is None:
                continue
            for num, line in enumerate(text.splitlines(), 1):
                for sentence in re.split('。', re.sub('【[^】]*】', '', line)):
                    if PERMISSION_SENTENCE.search(sentence):
                        bad = 1
                        print(f'正本以外が手渡しの許可条件を述べている: {path}:{num}: {sentence.strip()[:160]}')
        if bad:
            print(f'\n許可条件の本文は {source} にだけ置き、他の面は参照だけを書くこと。')

    else:
        print(f'unknown mode: {args.mode}', file=sys.stderr)
        return 2

    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
