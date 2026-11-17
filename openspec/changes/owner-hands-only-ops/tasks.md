# Tasks

## 1. develop の文面

- [x] 1.1 `SKILL.md` の節「主に聞かずに決めること」の主の手でしかできない操作の例を、パスワード・MFA・CAPTCHA（エージェントの手では通せないもの）に替え、ログイン済みのブラウザで押せる操作（OAuth の認可ボタン・チャットの板の作成など）は入らないこと、そのうち主の名義で外へ公開・送信する・課金する・取り消せないものは規則が主の承認を求める操作として聞くことを書く。確かめ方: `plugins/dev-workflow/tests/develop-skill.bats` に、節の中に `パスワード・MFA・CAPTCHA` があり `MFA・OAuth・ログイン` が無いことに加え、`ログイン済みのブラウザ` を含む文が主の手でしかできない操作から外す書き方（「入らない」）であること、同じ節に、主の名義で外へ公開・送信する・課金する・取り消せない操作は規則が主の承認を求める操作として聞く書き分けがあることを、文単位で確かめるテストを足して通す（語の有無だけでは通さない）。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:65-67（節「主に聞かずに決めること」の最初の段落）、plugins/dev-workflow/tests/develop-skill.bats:980-1000（`主の手でしかできない操作` を探すテストの近く）
- [x] 1.2 `parent-pass-criteria.md` の条件「実機操作でない」の中身と、通らない例の「実機操作」の例を、パスワード・MFA・CAPTCHA に替え、ログイン済みのブラウザで押せる操作は入らないと書く（条件の数と名前は変えない）。確かめ方: `plugins/dev-workflow/tests/epic-dispatch.bats` の `| 実機操作でない |` を見るテストの近くに、その行と通らない例に `MFA・OAuth・ログイン` が無く `CAPTCHA` があり、`ログイン済みのブラウザ` を含む文が実機操作から外す書き方（「入らない」）であることを、行単位で確かめるテストを足して通す（語の有無だけでは通さない）。触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:23、plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:76、plugins/dev-workflow/tests/epic-dispatch.bats:4105-4125

## 2. readable.md

- [x] 2.1 `output-styles/readable.md` の節 3 の「主の手でしかできない操作」の例を、パスワード・MFA・CAPTCHA のようにエージェントの手では通せないもの・人が押すと決まっているマージに替え、ログイン済みのブラウザで押せる操作（OAuth の認可ボタンなど）は入らないと書く。製品名は書かない。`rules/communication-style.md` は例を持たないので変えないことを確かめる。確かめ方: `tests/owner-question-style.bats` に、節 3 の「主の手でしかできない操作」の項目にこの例があり `MFA・ログイン・` が無く、`ログイン済みのブラウザ` を含む文がその操作から外す書き方（「入らない」）であることを、項目の行単位で確かめるテストを足し、既存の固有名の検索のテストと合わせて通す。触る範囲: output-styles/readable.md:51、tests/owner-question-style.bats:55-70（`主の手でしかできない操作` を探すテストの近く）

## 3. 記録と通し

- [x] 3.1 `plugins/dev-workflow/changes/1654.md` を新しく作り、この change の分（何を替えたか・直さなかった箇所と理由・戻し方）を書く。確かめ方: ファイルがあり、見出しに `#1654` がある。触る範囲: plugins/dev-workflow/changes/1654.md（新規）
- [x] 3.2 `bats plugins/dev-workflow/tests/develop-skill.bats plugins/dev-workflow/tests/epic-dispatch.bats tests/owner-question-style.bats plugins/dev-workflow/tests/unclear-reply-rephrase.bats tests/injection-budget.bats` が通り、`grep -rnE 'MFA・OAuth・ログイン|MFA・ログイン・' plugins/dev-workflow/skills output-styles rules` が 0 件であることを確かめる

## Workflow follow-up

- マージ後に、本体が flatmate のメモリ `browser-ops-do-not-ask-owner` を消す（このリポジトリの外）
