## MODIFIED Requirements

### Requirement: G が passed を返したら本体が CI を見張る
`skills/develop/SKILL.md` の (4) は、G が `passed` を return したあと、本体が `plugins/dev-workflow/references/ci-watch.md` の手順で CI の見張りを始めることを書かなければならない（MUST）。G の `passed` の return に `issue で承認済み:` の行があれば、本体は見張りを始める前に、主へその行（宣言コメントの URL・当たった分類・引用した issue の文）を 1 回伝えなければならない（MUST。pr-review-gate 手順 5 の事後報告。auto-merge 配備リポではマージまで主との会話が起きないため、本体の手順に置かないと報告が起きない）。見張りの一手が `fix` のときは、本体が W に直させ（W の再開か手渡しかは `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」に従う）、W が push したら本体が passed を外したまま同じ状態ファイルで `wait` → `next` を続け（CI のやり直し・再度の直しもここで処理する）、`ready` になってから G を起こしてゲートを取り直させ、G が再び `passed` を返したら見張りの続き（reference の「`ready` を受けたあと」）に進むこと、合格するまでマージ待ち・マージ依頼に進まないことを書く（MUST）。見張りの中身は reference を参照し、SKILL.md に言い換えて再掲してはならない（MUST NOT）。

G の指示書 `skills/develop/references/roles/gate-runner.md` は、G が CI の見張りを始めずに `passed` を return することを書かなければならない（MUST）。unmanned モードは (4) を回さないので、この見張りの対象外とする。

#### Scenario: (4) の passed のあとに本体が見張る
- **WHEN** `skills/develop/SKILL.md` の (4) を読む
- **THEN** `passed` を受けた本体が `references/ci-watch.md` の手順で見張りを始めること、`fix` なら W に直させ、push のあと passed を外したまま `wait` → `next` を続けて `ready` になってから G にゲートを取り直させることが書かれている

#### Scenario: G は見張りを始めない
- **WHEN** `skills/develop/references/roles/gate-runner.md` を読む
- **THEN** G が CI の見張りを始めずに `passed` を return することが書かれている

#### Scenario: issue で承認済みの passed は見張りの前に主へ伝える
- **WHEN** `skills/develop/SKILL.md` の (4) の passed の行を読む
- **THEN** return に `issue で承認済み:` の行があれば、CI の見張りを始める前に主へその行（宣言 URL・分類・引用）を 1 回伝えることが書かれている
