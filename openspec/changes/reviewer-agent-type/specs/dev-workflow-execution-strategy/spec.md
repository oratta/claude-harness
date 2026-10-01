## MODIFIED Requirements

### Requirement: 担当分類の優先順位

`--by-role` の担当分類は、対象トランスクリプトの隣にある `agent-<id>.meta.json` を次の優先順位で判定しなければならない（SHALL）。

1. `agentType` が `dev-workflow:decider` と一致する場合、`description` の内容に関わらず常に `decider` に分類する
2. 1 に当たらず、`agentType` が `dev-workflow:reviewer` と一致する場合、`description` の内容に関わらず常に `Reviewer` に分類する
3. 1 にも 2 にも当たらない場合、`description` の先頭コロン区切りトークン（例: `W: #552 ...` の `W`）が `W` / `R1` / `G` / `Reviewer` のいずれかに完全一致すればそれに分類する
4. 1〜3 のどれにも当たらない（`description` が無い・コロンが無い・未知のトークン・`meta.json` が無い/読めない）場合は `unknown` に分類する

分類できない件（`unknown`）も `by_role` の合計・母集団の `count` から落としてはならない（MUST NOT）。

この分類は `agent-<id>.meta.json` の `agentType` / `description` という自由記述を解釈する要件であり、次の 4 点を守備範囲とする。①入力の出どころ: `description` は develop 本体が `plugins/dev-workflow/skills/develop/SKILL.md` の紐付け規約（役割を問わず記録先番号を `#N` の形で入れる。例: `W: impl for #288`、`G: gate for PR #400 (#288)`）に沿って書く。`agentType` は Agent 呼び出しの `subagent_type` がそのまま入る。②拾いたい誤り: develop の担当を別の担当に数えること、分類できない件が母集団の合計から落ちること。③通ることを許す入力の具体例: develop 以外の経路で起こした `G: ...` のような `description` も先頭トークン一致で `G` に数えてよい。`w:`（小文字）や `Reviewer1:` のような接頭辞の変形は `unknown` に落ちてよい（規約外の書式まで拾い切ることを目的にしない）。`general-purpose` で起こした古いレビュアーは `description` の先頭トークンだけで判定し、`Reviewer:` で始まらなければ `unknown` に落ちてよい。④新しい書き方が見つかるたびに規則を足して塞ぎ切ることを完了条件にしない。

`Reviewer` は「G のレビュアー」に割り当てる担当名である。`dev-workflow:reviewer` で起こしたレビュアーは `agentType` で `Reviewer` に数えられる。`general-purpose` で起こしたレビュアー（新種別より前の記録と、事前分類で `dev-workflow:decider` に替えた件を除く）は `description` の先頭トークンに頼るので、`unknown` に落ちうる（想定内の挙動とする）。

#### Scenario: `agentType` が `description` の見た目より優先される

- **WHEN** `agent-<id>.meta.json` の `agentType` が `dev-workflow:decider` で、同じファイルの `description` が `R1: 仕様レビュー` のように別役割の体裁を取っている
- **THEN** その件は `decider` に分類される

#### Scenario: レビュアーの種別は description に頼らず Reviewer に数えられる

- **WHEN** `agent-<id>.meta.json` の `agentType` が `dev-workflow:reviewer` で、`description` が `code review for PR #12` のように `Reviewer:` で始まっていない
- **THEN** その件は `Reviewer` に分類される

#### Scenario: `description` の先頭トークンで分類される

- **WHEN** `agentType` が `dev-workflow:decider` でも `dev-workflow:reviewer` でもなく、`description` が `G: #552 のマージ前検査` のように先頭コロン区切りトークンが `G` と完全一致する
- **THEN** その件は `G` に分類される

#### Scenario: どちらにも当たらない件は unknown に寄せられる

- **WHEN** `meta.json` が無い、または `agentType` が `dev-workflow:decider` でも `dev-workflow:reviewer` でもなく、`description` の先頭トークンが `W` / `R1` / `G` / `Reviewer` のいずれとも一致しない
- **THEN** その件は `unknown` に分類され、全体の `count` には含まれたまま `by_role` の合計にも数えられる
