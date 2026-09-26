## ADDED Requirements

### Requirement: G が passed を返したら本体が CI を見張る
`skills/develop/SKILL.md` の (4) は、G が `passed` を return したあと、本体が `plugins/dev-workflow/references/ci-watch.md` の手順で CI の見張りを始めることを書かなければならない（MUST）。見張りの一手が `fix` のときは、本体が W に直させ（W の再開か手渡しかは `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」に従う）、G を起こしてゲートを取り直させ、G が再び `passed` を返したら見張りを始め直すことを書く（MUST）。見張りの中身は reference を参照し、SKILL.md に言い換えて再掲してはならない（MUST NOT）。

G の指示書 `skills/develop/references/roles/gate-runner.md` は、G が CI の見張りを始めずに `passed` を return することを書かなければならない（MUST）。unmanned モードは (4) を回さないので、この見張りの対象外とする。

#### Scenario: (4) の passed のあとに本体が見張る
- **WHEN** `skills/develop/SKILL.md` の (4) を読む
- **THEN** `passed` を受けた本体が `references/ci-watch.md` の手順で見張りを始めること、`fix` なら W に直させて G を取り直すことが書かれている

#### Scenario: G は見張りを始めない
- **WHEN** `skills/develop/references/roles/gate-runner.md` を読む
- **THEN** G が CI の見張りを始めずに `passed` を return することが書かれている
