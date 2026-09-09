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

走査は 2 種類ある。ホワイトリスト（`offenders` ほか）はファイル単位で参照の有無を見る。
参照を書いたうえで規則を言い換えた面はそれでは素通りするので、正本が規定する①〜④それぞれの
再掲を文単位で拾う走査（`restatement-sentences`）を併せ持つ。

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

# 正本が規定する①〜④それぞれを「自分の言葉で述べた本文」の形。正本以外に現れてはならない。
# ホワイトリスト走査はファイル単位なので、同じファイルの別の段落に正本への参照があれば、そのファイル内の
# 再掲は素通りする（PR #253 で SKILL.md の失敗フローに残った「上限超なら再開しない」がこの形で漏れた）。
# ファイル単位という判定は spec が意図して選んだもの（箇所ごとに参照を書かせると再掲の圧力が戻る）なので、
# 再掲そのものは文単位のこの走査が受け持つ。①だけ・②だけを見ていると同じ欠陥が別の規則で再発するため、
# 正本が規定する 4 点すべてを覆う。
#
# 拾うのは規範の述語（「〜しない」「〜のは…だけ」）だけで、トピックの列挙（「送ってよい／送っては
# ならない SendMessage・手渡しを行ってよい条件・…」のような名詞句の並び）は拾わない。後者は規則の
# 答えではなく、正本を指すポインタ文が「何について正本なのか」を述べている形だからである。
# 各行は（規則名, 手渡しの文脈, 規範の述語）。文脈は、同じ言い回しを別の規則に使っている面
# （`仕様化判断:` / `仕様レビュー:` の 1 行目書式など）を巻き込まないための足切りで、
# 述語だけでは規則を特定できない③にだけ要る。
RESTATEMENT_SENTENCES = (
    # ①上限超過を検知したときに送ってよい／送ってはならない SendMessage（＝再開の禁止）
    ('①再開の禁止', None, re.compile(
        '(?=[^。]*(上限超|超過|exit 2|over_cap|上限を超))'
        '(?=[^。]*(再開しない|再開してはならない|再開してはいけない|再開せず|再開を禁|再開に進まない'
        '|SendMessage を送らない|SendMessage を送ってはならない|禁止の対象外))')),
    # ②手渡しを行ってよい条件
    ('②手渡しの許可条件', None, re.compile(
        '手渡[^。]*(を行ってよいのは|してよいのは|できるのは|を行ってよい条件は|の許可条件は)'
        '|(工程完了|停止確認)[^。]{0,40}(ときだけ|ときのみ|場合だけ|場合のみ|に限り|限る)[^。]{0,30}手渡'
        '|手渡[^。]{0,40}(工程完了|停止確認)[^。]{0,30}(ときだけ|ときのみ|場合だけ|場合のみ|に限り|限る)')),
    # ③return の 1 行目の宣言書式と、どちらを選ぶかの義務
    ('③宣言の書式と選び方', re.compile('工程完了|工程中断|手渡'), re.compile(
        '(1 行目|一行目)[^。]{0,60}(完全一致|に一致させ|にしなければ|としなければ|にすること|にせよ|に置くこと)'
        '|(工程完了|工程中断)[^。]{0,60}(宣言してはならない|宣言する義務|にする|にすること|を選ぶ|でなければ)')),
    # ④前任が動作中のまま交代させる手順と、その待ち方
    ('④停止指示と停止確認', None, re.compile(
        '停止確認[^。]{0,60}(受け取|待|してから|ブロック)'
        '|(停止を指示|停止指示)[^。]{0,60}(してから|受け取|前に[^。]{0,20}spawn)')),
)

# spec が固定している書式リテラル。引用は再掲に当たらないので③の述語判定の前に取り除く
# （文脈の判定は取り除く前の文に当てる。リテラルを引用しただけの面は述語を持たないので落ちない）。
LITERALS = ('工程完了: <工程名>', '工程中断: <理由>')
LITERAL_STRIPPED_RULES = ('③宣言の書式と選び方',)

# この検査を実装している 2 ファイルは、検出したい形をパターンとして書かざるを得ない。
# spec が「正本の断片を grep の引数として引用することは言い換えに当たらない」と定めているのと
# 同じ理由で、再掲の文単位走査からだけ外す（ホワイトリスト走査の対象からは外さない）。
DETECTOR_FILES = (
    'plugins/dev-workflow/tests/lib/handoff-scan.py',
    'plugins/dev-workflow/tests/handoff-declaration.bats',
)


def excluded(path, this_change):
    """spec が定める 3 種の除外。これ以外の除外を増やしてはならない。"""
    # ①歴史記録
    if path == 'plugins/dev-workflow/CHANGELOG.md':
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

    elif args.mode == 'restatement-sentences':
        source = args.source
        for path in paths:
            if path == source or path in DETECTOR_FILES:
                continue
            text = read(root, path)
            if text is None:
                continue
            for num, line in enumerate(text.splitlines(), 1):
                for sentence in re.split('。', re.sub('【[^】]*】', '', line)):
                    for rule, context, pattern in RESTATEMENT_SENTENCES:
                        if context is not None and not context.search(sentence):
                            continue
                        target = sentence
                        if rule in LITERAL_STRIPPED_RULES:
                            for literal in LITERALS:
                                target = target.replace(literal, '')
                        if pattern.search(target):
                            bad = 1
                            print(f'正本以外が{rule}を述べている: {path}:{num}: {sentence.strip()[:160]}')
        if bad:
            print(f'\n①〜④の本文は {source} にだけ置き、他の面は参照だけを書くこと。')

    else:
        print(f'unknown mode: {args.mode}', file=sys.stderr)
        return 2

    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
