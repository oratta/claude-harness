## ADDED Requirements

### Requirement: G の needs-decider を受けた本体の動き

`plugins/dev-workflow/skills/develop/SKILL.md` の (4) は、G の return の分岐に `needs-decider`（pr-review-gate の仕分け表の順 6。同じ型の再発）の行を持たなければならない（MUST）。その行は次を規定する（MUST）: 本体は `subagent_type: dev-workflow:decider` を、残量モードの規定どおりのモデルで spawn する。入力は、G の return に載った同じ型の指摘と前の周の指摘の原文（PR コメントの本文を貼る）、対象ファイルのパス、G の仕分け欄とする。依頼は、マージ可否を問うときと同じ `agents/decider.md` の既存の「可否と根拠」の出力契約で出し（決める役が 3 点の契約で返す取り違えを防ぐため、行にその旨を書く）、問いを「この PR の中で、同じ型を全部列挙してから直すべきか（可）、切り出すべきか（否）」の 1 つにする。本体は返ってきた可否を方式（可＝全部列挙してから直す、否＝切り出す）に読み替え、根拠とともに SendMessage で G に渡して G を再開する。本体は裁定を記録先に投稿しない（記録は G が PR コメントに行う）。これは「`dev-workflow:decider` で起こした役割の return は本体が代理投稿する」一般則の例外であり、SKILL.md は一般則の記述にもこの例外を一言書かなければならない（MUST）。`agents/decider.md` の出力契約は変えない（MUST NOT）。

#### Scenario: (4) に needs-decider の行がある

- **WHEN** develop の SKILL.md (4) の G の return の分岐を読む
- **THEN** `needs-decider` の行があり、`dev-workflow:decider` をマージ可否と同じ「可否と根拠」の契約で起こすこと、入力（同じ型の指摘と前の周の指摘・対象ファイル・仕分け欄）、可否を方式に読み替えること、裁定を SendMessage で G に返すこと、本体は裁定を代理投稿しないことが書かれており、代理投稿の一般則の記述にこの例外が書かれている

#### Scenario: decider の出力契約を変えない

- **WHEN** この change の前後で `plugins/dev-workflow/agents/decider.md` を比べる
- **THEN** 差分が無い
