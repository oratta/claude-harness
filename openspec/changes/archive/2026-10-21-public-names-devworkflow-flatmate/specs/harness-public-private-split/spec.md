## ADDED Requirements

### Requirement: dev-workflow の公開版の部品は Orca 経路を除いて決めた固有名を持たない

公開版に残る dev-workflow の部品は、固有記述の一覧で担い手なしだった Orca 経路以外の行の語を、許可リストに載った行を除いて持たない。次の検索の当たりは、許可リストの行を除いて 0 件でなければならない（MUST）。検索は大文字と小文字を区別する。

- `moko`: `plugins/dev-workflow/` の公開版のファイル
- `new-resident`: `plugins/dev-workflow/references/pr-body-format.md`・`plugins/dev-workflow/skills/issueify/SKILL.md`・`plugins/dev-workflow/skills/push-guard-setup/SKILL.md`
- `flatmate`: 上の 3 ファイルに加えて `plugins/dev-workflow/templates/escalation-tripwires.md`・`plugins/dev-workflow/scripts/pr-state.sh`・`plugins/dev-workflow/skills/memory-refresh/SKILL.md`・`plugins/dev-workflow/templates/auto-merge/docs/auto-merge.md`
- `CLAUDE_HARNESS_DEV_DIR`: `plugins/dev-workflow/references/ci-watch.md`・`plugins/dev-workflow/skills/memory-refresh/SKILL.md`
- 公開版のファイル: 仕分けの表で個人版に決まるファイル（`plugins/dev-workflow/docs/auto-merge-deployments.md`）と保留の行のファイルは対象に含めない。付属の `changes/`・`CHANGELOG.md`・`tests/`・`evals/` も含めない
- 許可リスト: 載せない行の基準のうち「出典や経緯としてだけ名前を挙げる行」に当たる行は、`tests/public-private-split.bats` の中の許可リストに「ファイルのパス・行に含まれる固定の文字列・当たる基準」の 3 つ組で 1 件ずつ載せたものだけを通す。許可リストに無い当たりは落ちる。許可リストの各件は、判定の表（tasks の実施欄）に同じ行がなければならない

この検索の守備範囲は次のとおりで、範囲の外の誤りを見つけることは完了条件にしない（MUST NOT）。

- 拾う誤り: 直した語が上のファイルに戻ってくること／許可リストに無い当たりが現れること
- 通してよい具体例: 検索語に無い別の固有名・許可リストの載せ方の良し悪し・書き換えた文の良し悪し。人のレビューと固有記述の一覧が見る
- 見つかる穴をすべて塞ぐことは完了条件にしない

#### Scenario: 直した語が戻ると落ちる

- **WHEN** `plugins/dev-workflow/references/pr-body-format.md` に flatmate の `new-resident` が issue テンプレートを配ると書く
- **THEN** `tests/public-private-split.bats` が落ちる

#### Scenario: 許可リストの出典の行は通る

- **WHEN** 検索対象のファイルに、出典としてだけ flatmate の名を挙げる行があり、許可リストに載っている
- **THEN** 検索のテストは通る。同じファイルの別の行に flatmate を書き足すと、許可リストに無いので落ちる

#### Scenario: 検索語に無い固有名は検査を通る

- **WHEN** 対象のファイルに検索語に無い別の固有名がある
- **THEN** 検索のテストは通り、その誤りは人のレビューが見る

### Requirement: Orca 経路の行の担い手は #1177 とする

固有記述の一覧は、dev-workflow の公開版の部品のうち Orca 経路を書く行（Orca の語を含み、`epic-launch-orca.sh` 以外の公開版の部品にある行）の「直す issue」を、書き直しが済むまで「担い手なし」でなく `#1177` としなければならない（MUST）。#1177 は #1123 の change 3b の後に、これらの行を差し替え可能な起動部品の 1 つとしての「Orca を使う場合」の書き方に直す。

#### Scenario: Orca 経路の行に担い手が付く

- **WHEN** 一覧の Orca 経路の行を読む
- **THEN** 「直す issue」の欄が `#1177` で、「担い手なし」の行が dev-workflow に無い
