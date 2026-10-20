## ADDED Requirements

### Requirement: dev-workflow の公開版の部品は Orca 経路を除いて決めた固有名を持たない

公開版に残る dev-workflow の部品は、固有記述の一覧で担い手なしだった Orca 経路以外の行の語を持たない。次の検索がそれぞれ 0 件でなければならない（MUST）。検索は大文字と小文字を区別し、付属の `changes/`・`CHANGELOG.md`・`tests/`・`evals/` は対象に含めない。

- `moko`: `plugins/dev-workflow/` の全ファイル
- `new-resident`: `plugins/dev-workflow/references/pr-body-format.md`・`plugins/dev-workflow/skills/issueify/SKILL.md`・`plugins/dev-workflow/skills/push-guard-setup/SKILL.md`
- `flatmate`: `plugins/dev-workflow/references/pr-body-format.md`・`plugins/dev-workflow/skills/issueify/SKILL.md`・`plugins/dev-workflow/skills/push-guard-setup/SKILL.md`・`plugins/dev-workflow/templates/escalation-tripwires.md`・`plugins/dev-workflow/scripts/pr-state.sh`・`plugins/dev-workflow/skills/memory-refresh/SKILL.md`・`plugins/dev-workflow/templates/auto-merge/docs/auto-merge.md`
- `CLAUDE_HARNESS_DEV_DIR`: `plugins/dev-workflow/references/ci-watch.md`・`plugins/dev-workflow/skills/memory-refresh/SKILL.md`

この検索の守備範囲は次のとおりで、範囲の外の誤りを見つけることは完了条件にしない（MUST NOT）。

- 拾う誤り: 直した語が上のファイルに戻ってくること
- 通してよい具体例: 検索語に無い別の固有名・出典としての flatmate の言及（載せない行の基準）・書き換えた文の良し悪し。人のレビューと固有記述の一覧が見る
- 見つかる穴をすべて塞ぐことは完了条件にしない

#### Scenario: 直した語が戻ると落ちる

- **WHEN** `plugins/dev-workflow/references/pr-body-format.md` に flatmate の `new-resident` が issue テンプレートを配ると書く
- **THEN** `tests/public-private-split.bats` が落ちる

#### Scenario: 検索語に無い固有名は検査を通る

- **WHEN** 対象のファイルに検索語に無い別の固有名がある
- **THEN** 検索のテストは通り、その誤りは人のレビューが見る

### Requirement: Orca 経路の行の担い手は #1177 とする

固有記述の一覧は、dev-workflow の公開版の部品のうち Orca 経路を書く行（Orca の語を含み、`epic-launch-orca.sh` 以外の公開版の部品にある行）の「直す issue」を、書き直しが済むまで「担い手なし」でなく `#1177` としなければならない（MUST）。#1177 は #1123 の change 3b の後に、これらの行を差し替え可能な起動部品の 1 つとしての「Orca を使う場合」の書き方に直す。

#### Scenario: Orca 経路の行に担い手が付く

- **WHEN** 一覧の Orca 経路の行を読む
- **THEN** 「直す issue」の欄が `#1177` で、「担い手なし」の行が dev-workflow に無い
