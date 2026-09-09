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
再掲を文単位で拾う走査（`restatement-sentences`）を併せ持つ。この走査の除外表（面のパス・断片・理由）は
`restatement-stale` が stale を検査する。

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
# 再掲は素通りする（PR #253 で SKILL.md の失敗フローに残った「上限超なら再開しない」がこの形で漏れた。handoff-scan: fixture）。
# ファイル単位という判定は spec が意図して選んだもの（箇所ごとに参照を書かせると再掲の圧力が戻る）なので、
# 再掲そのものは文単位のこの走査が受け持つ。①だけ・②だけを見ていると同じ欠陥が別の規則で再発するため、
# 正本が規定する 4 点すべてを覆う。
#
# 【この走査が保証しないこと】これは spec が列挙した言い回しに対する検査であって、任意の言い換えを
# 検出するものではない（自由な言い換えの網羅的検出は正規表現では原理的に不可能で、追いかけると
# 別の言い回しに抜けられる周回を繰り返す）。本文が 1 箇所にあることの本当の保証は、ホワイトリスト
# 走査（手渡しに触れる面は正本への参照を持たなければならない）とレビューが担う。この走査はその補助の網。
#
# 語彙は spec（dev-workflow-execution-strategy「サブエージェントのコンテキスト上限と手渡し」）が
# 列挙する。実装が勝手に語彙を決めない。各規則は「話題語（その規則が何について述べているか）」と
# 「規範の述語（禁止・限定・義務・手順）」の組み合わせで、同じ文にすべて現れたときに拾う。
# 取りこぼしより誤検出に倒す（再現率優先）。誤検出は、その文を正本への参照に書き換えれば解消する
# （本文をそこに置かない設計なので書き換えは常に可能）。
#
# 拾うのは規範の述語（「〜しない」「〜のは…だけ」）だけで、トピックの列挙（「送ってよい／送っては
# ならない SendMessage・手渡しを行ってよい条件・…」のような名詞句の並び）は拾わない。後者は規則の
# 答えではなく、正本を指すポインタ文が「何について正本なのか」を述べている形だからである。

# 語彙は 3 種類の部品でできている（spec が列挙する）。
#   話題語   … その文が①〜④のどれについて述べているか
#   規範の述語 … 禁止・限定・義務・手順。日本語の規範文は述語で終わるので、①②③は
#                **述語が文末（残り 15 文字以内）に来ること**を求める。名詞句を並べただけの
#                話題の列挙（「送ってよい／送ってはならない SendMessage、手渡しを行ってよい条件、…」）は
#                述語で終わらないので、これで規則の再掲と区別できる。
#
# 1 文は「行を `。` で区切ったもの」で、判定の前に `【…】` の注記を取り除く（③の述語の判定にだけ、
# 書式リテラルを取り除いた文を使う）。この前処理も語彙と同じく spec 側の決定で、実装が勝手に決めない。
#
# 同じ文が正本への参照を含んでいても外さない。参照を文末に添えたうえで規則を再掲する形が最も自然な
# 書き方で（この設計の動機になった PR #253 修正前の SKILL.md がその形だった）、外すと穴が一番当たり
# やすい所に開く。MAY で認めたガード 1 行は正本を読む義務だけを述べる文なので、話題語と規範の述語が
# 同じ文に揃わず、この走査には掛からない。手渡しと無関係な文が語彙に掛かった場合は参照への書き換えが
# できないので、テスト側の除外表（面のパス・断片・理由）で文単位に外す。

# 否定・禁止（①）
_NEG = '(ない|禁止|禁じ|不可|するな|せず|やめ|控え|避け)'
# 限定（②）「〜のは…だけ」の形
_ONLY = ('(ときだけ|ときのみ|場合だけ|場合のみ|に限る|に限り|だけとする|だけである|だけ|のみ'
         '|てよい|してよい|できるのは|よいのは)')
# 義務（③）書式をこうしろ、の形
_MUST = ('(完全一致|に一致|にする|にすること|にせよ|にしなければ|としなければ|でなければ'
         '|を選ぶ|どちらか|宣言する|宣言してはならない|宣言義務)')
# 手渡しの行為語（②）
_ACT = '(手渡|後任|交代|spawn|新しい ?(W|G|エージェント|担当|実行役|ゲート役|サブエージェント))'
# 手渡しの許可条件になる状態語（②）
_COND = '(前任|工程完了|工程の終わり|完了宣言|停止確認|直近の return)'
# 文末（述語のうしろに「（MUST）」等が付くのを許す）
_TAIL = '[^。]{0,15}$'

# 各行は（規則名, 手渡しの文脈, 話題語, 規範の述語）。文脈は、同じ言い回しを別の規則に使っている面
# （`仕様化判断:` / `仕様レビュー:` / `仕様宣言` の 1 行目書式など）を巻き込まないための足切りで、
# 述語だけでは規則を特定できない③にだけ要る。
#
# 話題語と述語を別々のパターンに分けているのは、③だけ述語の判定に書式リテラルを取り除いた文を
# 使うためである（spec: 「③の述語の判定にだけ、書式リテラルを取り除いた文を使う。話題語と足切りの
# 判定は取り除く前の文に当てる」）。1 本の正規表現にまとめると、除去が話題語の判定にも掛かり、
# 話題語（`工程完了` / `工程中断`）がリテラルの中にしか無い文 — つまり書式を正しく引用した、実際に
# 面へ書かれるであろう形 — が③から抜ける。述語の位置が話題語からの相対で決まる①だけは、
# 話題語と述語を 1 本に持つ（①は除去の対象外なので、分けても分けなくても同じ文に当たる）。
RESTATEMENT_SENTENCES = (
    # ①上限超過を検知したときの SendMessage の可否
    #   話題語: 上限超過の状況 ＋ 継続の指示 / 述語: 否定・禁止（継続の指示の直後、かつ文末）  handoff-scan: fixture
    ('①再開の禁止', None, re.compile(
        '^(?=[^。]*(上限[^。]{0,6}超|超過|exit 2|over_cap|CONTEXT_CAP|キャップ[^。]{0,6}超))'
        '(?=[^。]*(再開|続き|続行|継続|作業を続|SendMessage)[^。]{0,15}' + _NEG + _TAIL + ')'), None),
    # ②手渡しを行ってよい条件
    #   話題語: 手渡しの行為 ＋ 許可条件になる状態 / 述語: 限定（文末）
    ('②手渡しの許可条件', None, re.compile(
        '^(?=[^。]*' + _ACT + ')(?=[^。]*' + _COND + ')(?=[^。]*' + _ONLY + _TAIL + ')'), None),
    # ③return の 1 行目の宣言に関する規定
    #   話題語: 宣言の置き場所 / 述語: 義務（文末）
    ('③宣言の書式と選び方', re.compile('工程|手渡|return|後任|交代|前任'),
     re.compile('^(?=[^。]*(1 行目|一行目|先頭行|先頭の 1 行|冒頭の 1 行|冒頭行|工程完了|工程中断))'),
     re.compile('^(?=[^。]*' + _MUST + _TAIL + ')')),
    # ④前任が動作中のまま交代させる手順と、その待ち方
    #   話題語: 停止 ＋ その確認 ＋ 手渡しの文脈 / 述語: 手順（〜を受け取ってから／〜する前に）  handoff-scan: fixture
    ('④停止指示と停止確認', None, re.compile(
        '^(?=[^。]*(停止|止ま|止める|止めて|中止))'
        '(?=[^。]*(確認|返事|報告|応答))'
        '(?=[^。]*(受け取|してから|る前に|待ってから|得てから))'
        '(?=[^。]*(前任|手渡|交代|後任|spawn|新しい))'), None),
)

# spec が固定している書式リテラル。引用は再掲に当たらないので③の述語判定の前に取り除く
# （文脈の判定は取り除く前の文に当てる。リテラルを引用しただけの面は述語を持たないので落ちない）。
LITERALS = ('工程完了: <工程名>', '工程中断: <理由>')

# この検査を実装している 2 ファイルは、検出したい形をパターンの断片として、また負のコントロールの
# サンプル文として書かざるを得ない。spec が「正本の断片を grep の引数として引用することは言い換えに
# 当たらない」と定めているのと同じ理由で外すが、外すのは **印を持つ行だけ**（行単位）とする。
# ファイル全体を外すと、この 2 ファイルに規則を書き足しても検出されない穴になる（PR #253 のゲート指摘）。
DETECTOR_FILES = (
    'plugins/dev-workflow/tests/lib/handoff-scan.py',
    'plugins/dev-workflow/tests/handoff-declaration.bats',
)
# 上の 2 ファイルの行を再掲の走査から外す印。この文字列を含む行だけが外れる。
FIXTURE_MARK = 'handoff-scan: fixture'


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


def parse_restatement_exemptions(entries):
    """再掲の走査の除外表。1 行は〈面のパス〉TAB〈その文に現れる断片〉TAB〈理由〉。

    手渡しと無関係な文が語彙に掛かったときの唯一の逃げ道（spec が定める。面単位では外せない）。
    """
    parsed = []
    for entry in entries:
        path, _, rest = entry.partition('\t')
        fragment, _, reason = rest.partition('\t')
        parsed.append((path.strip(), fragment.strip(), reason.strip()))
    return parsed


def restatement_hits(root, paths, source):
    """正本以外の面が①〜④を述べている文を（面, 行番号, 文, 規則名）で返す。"""
    for path in paths:
        if path == source:
            continue
        text = read(root, path)
        if text is None:
            continue
        detector = path in DETECTOR_FILES
        for num, line in enumerate(text.splitlines(), 1):
            if detector and FIXTURE_MARK in line:
                continue
            for sentence in re.split('。', re.sub('【[^】]*】', '', line)):
                stripped = sentence
                for literal in LITERALS:
                    stripped = stripped.replace(literal, '')
                for rule, context, topic, predicate in RESTATEMENT_SENTENCES:
                    # 足切りと話題語は「書式リテラルを取り除く前の文」に当てる
                    if context is not None and not context.search(sentence):
                        continue
                    if not topic.search(sentence):
                        continue
                    # 述語を別に持つ規則（③）だけ、リテラルを取り除いた文で述語を見る
                    if predicate is not None and not predicate.search(stripped):
                        continue
                    yield path, num, sentence, rule


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

    elif args.mode == 'list-referrers':
        # トリガー語で発火して正本への参照を持つ面（＝参照 1 行で合格した面）。
        # 参照のパスが実在するかは呼び出し側が見る（spec: 参照だけになった面はポインタが
        # 壊れるとその面で機構が失効する）。
        for path in sorted(set(fired_a) | set(fired_b)):
            text = read(root, path)
            if text is not None and has_reference(text):
                print(path)
        return 0

    elif args.mode == 'vocab-a-exempt':
        for path in sorted(exempt):
            if path in fired_a:
                bad = 1
                print(f'語彙 A（手渡し固有語）で発火する面は除外表に載せられない: {path}')

    elif args.mode == 'restatement-sentences':
        source = args.source
        exemptions = parse_restatement_exemptions(args.exemptions)
        for path, num, sentence, rule in restatement_hits(root, paths, source):
            if any(p == path and frag and frag in sentence for p, frag, _ in exemptions):
                continue
            bad = 1
            print(f'正本以外が{rule}を述べている: {path}:{num}: {sentence.strip()[:160]}')
        if bad:
            print(f'\n①〜④の本文は {source} にだけ置き、他の面は参照だけを書くこと。'
                  '\n手渡しと無関係な文が掛かったのなら、面のパス・断片・理由を除外表に載せること。')

    elif args.mode == 'restatement-stale':
        exemptions = parse_restatement_exemptions(args.exemptions)
        hit_list = list(restatement_hits(root, paths, args.source))
        for path, fragment, reason in exemptions:
            if any(p == path and fragment and fragment in sentence
                   for p, _, sentence, _ in hit_list):
                continue
            bad = 1
            print('除外表の断片が走査に掛からなくなった（行を消すこと）: '
                  f'{path} — {fragment} — {reason}')

    else:
        print(f'unknown mode: {args.mode}', file=sys.stderr)
        return 2

    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
