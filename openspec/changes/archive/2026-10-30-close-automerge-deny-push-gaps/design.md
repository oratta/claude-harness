# Design

## Context

See proposal.md. 固定 HEAD は `219ccc5a60ccbccb4faa3fa736b4748c67027c08`、既存 deny は 7 件。既存 capability の該当要件とそのシナリオを MODIFIED で更新する。以下は仕様段の候補検証であり、テンプレート自体は未編集。

## Goals / Non-Goals

対象は、文字列として直接書かれた通常の `git push` の単純コマンドと、issue に指定された危険オプション・宛先。Git の構文全体を新しい parser / hook で解析する変更や、シェル構文による迂回の全面封鎖は含めない。前置形の既存 7 件と既存設定へのマージの互換性を維持する。

## Decisions

### 引数の終端と後続引数を分ける境界設計

2026-10-30 に確認した公式資料:

- [Permission の wildcard patterns](https://code.claude.com/docs/en/permissions#wildcard-patterns): `*` は空白を含む任意文字列。唯一の wildcard が末尾の ` *` なら素のコマンドも一致する。`:*` は末尾だけで認識する旧表現で ` *` と同義。
- [Bash の照合と限界](https://code.claude.com/docs/en/permissions#bash): コマンド全体の文字列照合を基本とし、複合コマンド・wrapper は別途処理される。`git -C . push ...` や引用されたサブコマンドは通常の `git push` と同じ扱いにはならない。
- [CLI reference](https://code.claude.com/docs/en/cli-reference): 公開のコマンド一覧に任意の Bash 入力をオフラインで permission 判定する専用コマンドは見つからない。実マッチャーの公開 API が存在しないとまでは断定しない。

上記からの設計上の帰結: `git push *:main` は末尾の宛先、`git push *:main *` は後続引数のある宛先を覆う。後者は wildcard が複数あるので、終端の `main` にも一致すると仮定しない。`git push *:main:*` だけに置き換えてもこの問題は解消しない。危険オプションも同じく末尾形と空白区切りの形を対にする。

既存 7 件は削除・置換しない。追加候補は次の 18 件（合計 25 件）。fully qualified の宛先も main/master 宛て refspec の別表記として覆う。

```json
[
  "Bash(git push * --force)",
  "Bash(git push * --force *)",
  "Bash(git push * -f)",
  "Bash(git push * -f *)",
  "Bash(git push * --force-with-lease)",
  "Bash(git push * --force-with-lease *)",
  "Bash(git push --force-with-lease=*)",
  "Bash(git push * --force-with-lease=*)",
  "Bash(git push * --no-verify)",
  "Bash(git push * --no-verify *)",
  "Bash(git push *:main)",
  "Bash(git push *:main *)",
  "Bash(git push *:master)",
  "Bash(git push *:master *)",
  "Bash(git push *:refs/heads/main)",
  "Bash(git push *:refs/heads/main *)",
  "Bash(git push *:refs/heads/master)",
  "Bash(git push *:refs/heads/master *)"
]
```

棄却した候補と、公式仕様から導いた一致/不一致:

| 候補 | 一致する例 | 問題・採否 |
|---|---|---|
| `Bash(git push * --force*)` | `origin feature --force` / `--force-with-lease` / `--force-if-includes`（いずれも先頭は `git push `） | 別オプションまで一致。token の終端で絞る |
| `Bash(git push * -f*)` | `git push origin -feature` | リモート名等の部分一致を増やす。単独 `-f` に絞る |
| `Bash(git push * --force-with-lease*)` | 値付き lease、`--force-with-lease-extra` | `=` か空白か終端を明示 |
| `Bash(git push * --no-verify*)` | `git push origin feature --no-verify-extra` | 空白か終端を明示 |
| `Bash(git push *:main*)` / `*:master*` | `git push origin feature:main-fix` / `HEAD:master-fix` | 別ブランチを拒否するため棄却 |
| `Bash(git push *:main *)` のみ | `git push origin HEAD:main --porcelain` | `git push origin HEAD:main` に不一致。末尾一致形も追加 |
| `Bash(git push origin main:*)`（既存） | `git push origin main` / `git push origin main --porcelain` | `main-fix`・`HEAD:main` に不一致。既存の保護として保持 |

### 検証は公式仕様の再現として記録する

triage の受け入れ条件 2 にある「permission 判定を再現する手段」を使う。`claude` の起動とモデル呼び出しは行わない。実マッチャーをオフラインで直接呼び出す公開手段は今回の調査では確認できず、実装時も見つからなければ「公式仕様に基づく照合の再現、実マッチャー未実測」と明記する。実測済みという受け入れ判定をこの段で宣言しない。

Bats の既存 deny 節に Python 標準ライブラリによる照合とケース表を同居させる（新しい補助ファイルは増やさない）。実際の settings.json の配列を入力に、前置/中置/後置・末尾/後続引数・複数 refspec・似たブランチ名を検証する。ルール文字列の存在検査だけでは合格にしない。通常 push の非一致は、他ルールによる allow の保証とは区別する。

再現モデルの対象は、引用や展開を含まず、空白で区切った単純コマンド。全体一致で `*` だけを任意文字列にする（正規表現の他のメタ文字は escape）。末尾 `:*` を ` *` に正規化し、wildcard がその 1 個だけなら末尾空白以降の無い形も許す。Python `fnmatch` をそのまま使うと `?` や `[]` を別の wildcard として扱うため採用しない。公式例によるモデル自体の対照テストも必要。

仕様段で再実行できる候補検証（worktree ルートで実行。ファイル書き込みも push の実行もない）:

```python
import json, pathlib, re
root = pathlib.Path('.')
doc = (root / 'openspec/changes/close-automerge-deny-push-gaps/design.md').read_text()
added = json.loads(re.search(r'```json\n(.*?)\n```', doc, re.S)[1])
old = json.loads((root / 'plugins/dev-workflow/templates/auto-merge/.claude/settings.json').read_text())['permissions']['deny']
assert len(old) == 7 and len(set(old + added)) == 25

def matches(rule, command):
    assert rule.startswith('Bash(') and rule.endswith(')')
    pattern = rule[5:-1]
    if pattern.endswith(':*'):
        pattern = pattern[:-2] + ' *'
    if pattern.endswith(' *') and pattern.count('*') == 1 and command == pattern[:-2]:
        return True
    return re.fullmatch('.*'.join(re.escape(p) for p in pattern.split('*')), command) is not None

# モデルの対照。ここで失敗したら候補の可否を論じる前にモデルを直す。
controls = [
    ('Bash(ls *)', 'ls', True), ('Bash(ls *)', 'ls -la', True),
    ('Bash(ls *)', 'lsof', False), ('Bash(ls*)', 'lsof', True),
    ('Bash(ls:*)', 'ls', True), ('Bash(ls:*)', 'lsof', False),
    ('Bash(git * main)', 'git push origin main', True),
    ('Bash(* --help *)', 'npm --help', False),
    ('Bash(* --help *)', 'npm --help x', True),
    ('Bash(git:* push)', 'git push', False),
]
for rule, command, expected in controls:
    assert matches(rule, command) == expected, (rule, command)

# (コマンド, 既存7件の期待, 追加後の期待) を境界ごとに固定。
cases = []
for option in ('--force', '-f', '--force-with-lease', '--no-verify'):
    cases.extend([
        (f'git push {option} origin feature', True, True),
        (f'git push origin feature {option}', False, True),
        (f'git push origin {option} feature', False, True),
        (f'git push origin feature {option} --porcelain', False, True),
    ])
for destination in ('main', 'master', 'refs/heads/main', 'refs/heads/master'):
    for suffix in ('', ' --porcelain', ' other:feature/bar'):
        cases.append((f'git push origin HEAD:{destination}{suffix}', False, True))
    cases.append((f'git push origin HEAD:{destination}-fix', False, False))
cases.extend([
    ('git push --force-with-lease=refs/heads/feature:abc123 origin feature', False, True),
    ('git push origin feature --force-with-lease=refs/heads/feature:abc123', False, True),
    ('git push origin feature:main other:feature/bar', False, True),
    ('git push -u origin HEAD:master', False, True),
    ('git push origin feature/foo', False, False),
    ('git push -u origin feature/foo', False, False),
    ('git push origin HEAD:feature/foo', False, False),
    ('git push origin feature:main-fix', False, False),
    ('git push origin main-fix', False, False),
    ('git push origin master-fix', False, False),
    ('git push origin feature --force-if-includes', False, False),
    ('git push origin -feature', False, False),
    ('git push origin feature --force-with-lease-extra', False, False),
    ('git push origin feature --no-verify-extra', False, False),
    ('git push origin main', True, True),
    ('git push origin master', True, True),
    ('git push origin main --porcelain', True, True),
    ('gh pr merge 123', True, True),
])
for command, before, after in cases:
    assert any(matches(r, command) for r in old) == before, ('before', command)
    assert any(matches(r, command) for r in old + added) == after, ('after', command)
print(f'PASS: {len(controls)} model controls, {len(cases)} commands before/after; 7 + 18 = 25 rules')
```

## Risks / Trade-offs

- [文字列照合と Git の引数解析は異なる] → 引用符・タブ・変数・値を取るオプションの中の文字列・URL・複合 shell・wrapper・global Git オプションはモデルの対象外と明記する。例えばオプション値が `x:main` なら refspec と区別せず一致しうる。既存ルールを含め、完全な Git 操作の防壁とは主張しない。
- [モデルと製品実装の差] → 公式例の対照、参照 URL、確認日、モデルの対象範囲を変更記録に残す。実マッチャー未実測を隠さず R1 と実装後レビューへ渡す。
- [広い glob の短縮は過剰一致を戻す] → `main-fix` / `master-fix` と通常 feature push を同じ回帰テストで固定する。短いオプションの結合形・省略形や `+` refspec の全面対応は今回増やさない。

## Migration Plan

実装・レビュー後に README の既存 jq 和集合手順で展開先へ追加する。既存 deny / allow / env を保持するテストを継続する。件数は 25 件に更新し、配布用ガイドには複数 wildcard の末尾境界の理由を記す。問題が見つかった場合は変更を通常のレビュー経路で修正し、既存 7 件の保護を維持する。版上げはしない。

## Spec-phase validation

2026-10-30: 上の Python ブロックを `python3 -` で抽出実行し exit 0。`PASS: 10 model controls, 50 commands before/after; 7 + 18 = 25 rules`。`openspec validate close-automerge-deny-push-gaps --type change --strict` は exit 0、status は planning artifacts 4/4 complete。製品の実マッチャー・変更後の実装・Bats 回帰検証はこの段では実行していない。
