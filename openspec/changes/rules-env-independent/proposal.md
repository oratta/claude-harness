## Why

flatmate は客の Mac に Harness の規則の一部を版固定で配る方針にした（genetta-inc/flatmate の第3版エピック #1615）。配る候補の規則のうち 3 本に、オーナーの環境のパスや客の Mac に無い仕組みへの参照が残っていて、flatmate の出荷検査（`oratta-claude-harness` などの語を禁じる）で止まる。このままでは Harness の原本のまま配れず、写すたびに手で書き換えることになる（issue #1098、エピック #1127 の子）。

## What Changes

配る候補の 6 ファイル（`rules/communication-style.md` `rules/link-when-requesting-review.md` `rules/dev-server.md` `rules/browser-infra-env-capture.md` `rules/destructive-git-guard.md` `output-styles/readable.md`）から、オーナーの環境に固有の記述を外す。規則の中身（守らせる原則）は変えない。

- `rules/communication-style.md`: 正本の場所を、marketplace の clone の絶対パスでなく Output Style `readable` の名前で書く。clone のパスは `rules/README.md` の同じ規則の行（オーナーの環境で読む場所）に残す
- `rules/browser-infra-env-capture.md`: 昇格先を 1Password・GitHub Actions secrets と名指しせず「秘密情報の保管庫」と書く。`capability-registry:capability-registry` スキルは「入っていれば、昇格の手順の正本」と条件つきにする。無い環境の手順（置く保管庫と登録する人をその場で決めて移す）を本文に書く
- `rules/destructive-git-guard.md`: 経緯の置き場の絵（`~/.claude/rules-archive/`）を外す。「hook との分担」の節を「dev-workflow の hook が入っていれば」の条件つきにし、hook が無い環境ではこのルールだけが止めることを明記する。節の中の事実（何を止めるか・止まらないもの・子と無人のセッションの扱い）は変えない
- `rules/link-when-requesting-review.md` `rules/dev-server.md` `output-styles/readable.md`: 現状で固有の記述が無いので変えない（検索で 0 件を確かめる）
- `rules/README.md`: 上の 3 本の行を、外した参照の行き先（オーナーの環境でだけ読む場所）が読める形に直す
- `docs/public-private-split.md`: 固有記述の一覧のうち、直した 3 行を外す
- 変更の記録 `plugins/dev-workflow/changes/1098.md` と `plugins/capability-registry/changes/1098.md` に、外した参照の行き先を 1 行ずつ書く

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `destructive-git-hook`: 「ルール本文と hook の分担」を、hook の分担の書き方が「hook が入っていれば」の条件つきで、hook が無い環境でも指示として読めることを求める形に変える。変更前の「既存の文を外さず」の対象から、経緯の置き場の絵を外す
- `harness-public-private-split`: 配る候補の 6 ファイルが環境固有の記述を持たず、プラグインを前提にする記述が条件つきであることを求める要件を足す

## Impact

- `rules/communication-style.md` `rules/browser-infra-env-capture.md` `rules/destructive-git-guard.md` `rules/README.md` `docs/public-private-split.md`
- `plugins/dev-workflow/tests/git-destructive-guard.bats`（「hook との分担」の節を読むテスト）と `tests/public-private-split.bats`（6 ファイルの検索のテスト）
- 常時注入の固定分のバイト数（`tests/injection-budget.txt`）。増減は小さい見込み。予算の値を動かす場合は PR 本文に理由を書く
- `rules/` は auto-merge の聖域パス。PR は人がマージする
- `scripts/sync.sh` は変えない。symlink を張る対象はファイル名（`rules/*.md` と `output-styles/*.md`）で、改名も新規も削除もしないので、`~/.claude/rules/` の symlink は壊れない
