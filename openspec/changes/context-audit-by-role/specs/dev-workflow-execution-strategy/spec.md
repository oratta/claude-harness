## ADDED Requirements

### Requirement: `--by-role` による担当別集計の出力

`subagent-context-audit.sh` は `--by-role` フラグを受け付けなければならない（MUST）。`--by-role` を付けない既定の呼び出しは、この要件の追加前と完全に同じ出力（既存キーの形・値）にならなければならない（MUST。走査コストも変えない）。

`--by-role` を付けた場合、出力 JSON のトップレベルに `by_role` キーを追加しなければならない（SHALL）。`by_role` は担当名（`W` / `R1` / `G` / `Reviewer` / `decider` / `unknown`）をキーとするオブジェクトで、各値は `count` / `first_median` / `docs_median` / `last_median` / `over_cap_pct` を持たなければならない（SHALL）。担当 `W` の値だけは追加で `reread_pct` を持たなければならない（SHALL）。

`by_role` の各担当の `count` の合計は、全体の `count` と一致しなければならない（MUST。分類できない件も `unknown` に含めて母集団から落とさないため）。

#### Scenario: 既定呼び出しは出力が変わらない

- **WHEN** `--by-role` を付けずに `subagent-context-audit.sh` を実行する
- **THEN** 出力 JSON に `by_role` キーは含まれず、既存キー（`count` / `first_median` / `first_max` / `last_median` / `last_max` / `over_cap_pct` / `cap` / `days` / `sources` / `generated_at`）の値はこの要件の追加前と同じになる

#### Scenario: `--by-role` で担当別の内訳が出る

- **WHEN** 対象期間内に `W` / `R1` / `G` の名前付きサブエージェントのトランスクリプトが混在する状態で `--by-role` を付けて実行する
- **THEN** 出力 JSON に `by_role` キーが追加され、`W` / `R1` / `G` それぞれに `count` / `first_median` / `docs_median` / `last_median` / `over_cap_pct` が入る
- **AND** `by_role.W` にだけ `reread_pct` が入る

#### Scenario: 担当別の合計が全体件数と一致する

- **GIVEN** `--by-role` 指定の実行で `W` / `R1` / `G` / `Reviewer` / `decider` / `unknown` のいずれかに分類された件が混在する
- **WHEN** 各担当の `count` を合計する
- **THEN** その合計は全体の `count` と一致する

### Requirement: 担当分類の優先順位

`--by-role` の担当分類は、対象トランスクリプトの隣にある `agent-<id>.meta.json` を次の優先順位で判定しなければならない（SHALL）。

1. `agentType` が `dev-workflow:decider` と一致する場合、`description` の内容に関わらず常に `decider` に分類する
2. 1 に当たらない場合、`description` の先頭コロン区切りトークン（例: `W: #552 ...` の `W`）が `W` / `R1` / `G` / `Reviewer` のいずれかに完全一致すればそれに分類する
3. 1 にも 2 にも当たらない（`description` が無い・コロンが無い・未知のトークン・`meta.json` が無い/読めない）場合は `unknown` に分類する

分類できない件（`unknown`）も `by_role` の合計・母集団の `count` から落としてはならない（MUST NOT）。

#### Scenario: `agentType` が `description` の見た目より優先される

- **WHEN** `agent-<id>.meta.json` の `agentType` が `dev-workflow:decider` で、同じファイルの `description` が `R1: 仕様レビュー` のように別役割の体裁を取っている
- **THEN** その件は `decider` に分類される

#### Scenario: `description` の先頭トークンで分類される

- **WHEN** `agentType` が `dev-workflow:decider` ではなく、`description` が `G: #552 のマージ前検査` のように先頭コロン区切りトークンが `G` と完全一致する
- **THEN** その件は `G` に分類される

#### Scenario: どちらにも当たらない件は unknown に寄せられる

- **WHEN** `meta.json` が無い、または `description` の先頭トークンが `W` / `R1` / `G` / `Reviewer` のいずれとも一致しない
- **THEN** その件は `unknown` に分類され、全体の `count` には含まれたまま `by_role` の合計にも数えられる

### Requirement: `docs_median`（指示書の読み込み量の中央値）

`--by-role` は担当ごとに `docs_median` を算出しなければならない（SHALL）。算出対象は、`Read` ツール呼び出し（`file_path` が harness の指示書格納パス `plugins/cache/oratta-claude-harness/` 配下の `.md` に一致するもの）または `Skill` ツール呼び出しを含む assistant ターンから、対応する `tool_result` を経て次に `usage` を持つ assistant レコードまでの 1 区間（1 ホップ）とする（SHALL）。各ホップの `docs_median` への計上値は、次ホップの `usage` と現在の `usage` の差分とする（SHALL）。1 ホップに複数の `tool_use` が混在する場合は、ホップ全体を docs 側の計上に丸める（SHALL。指示書以外の呼び出しコストと厳密に分離しない近似）。

`docs_median` の算出はトランスクリプトの全文を前方から走査する必要があり、`--by-role` を指定したときにのみ行う（SHALL。既定呼び出しの走査コストは変えない）。

#### Scenario: 指示書 Read を含むホップが docs_median に計上される

- **WHEN** ある担当のトランスクリプトに、`file_path` が `plugins/cache/oratta-claude-harness/` 配下の `.md` に一致する `Read` の `tool_use` を含む assistant ターンがあり、対応する `tool_result` の次に `usage` 付き assistant レコードが続く
- **THEN** その区間の `usage` 差分が、その担当の `docs_median` の算出対象に含まれる

#### Scenario: Skill 呼び出しも docs_median に計上される

- **WHEN** ある担当のトランスクリプトに `Skill` ツール呼び出しを含む assistant ターンがある
- **THEN** そのホップの `usage` 差分も同じ担当の `docs_median` の算出対象に含まれる

### Requirement: `reread_pct`（作業担当 W の読み直し割合）

`--by-role` は担当 `W` についてのみ `reread_pct` を算出しなければならない（SHALL）。算出手順は次のとおり。

1. 各 `W` の `description` に含まれる `#N`（記録先の issue/PR 番号）で、同じ記録先を担当した `W` を `timestamp` の開始順にグループ化する（SHALL）
2. 各グループの 2 番目以降の `W` について、そのグループ内で自分より前に開始した全 `W` が読んだ `Read` の `file_path`（ファイル名一致）の和集合に対し、自分が読み直した `file_path` の割合を求める（SHALL）
3. 各グループの最初の `W`（先行が存在しない個体）は、この中央値の母数から除く（MUST。分母が定義できないため）
4. `description` から `#N` が取れない `W` は `reread_pct` の対象から除く（MUST。グルーピングできない個体を母数に含めない）
5. 2 で求めた割合を担当 `W` 内で中央値に集約し `reread_pct` とする（SHALL）

#### Scenario: 同一記録先の後続 W の読み直し割合が算出される

- **GIVEN** `#552` を記録先とする `W` が 2 体（先行・後続の順で開始）存在し、先行が `fileA.md` と `fileB.md` を読み、後続が `fileA.md` を読み直した
- **WHEN** `--by-role` を実行する
- **THEN** 後続の `W` の読み直し割合（このケースでは 1/2）が `reread_pct` の算出対象に含まれる

#### Scenario: グループ最初の W は母数から除かれる

- **GIVEN** `#552` を記録先とする `W` が 1 体だけ存在する（先行なし）
- **WHEN** `--by-role` を実行する
- **THEN** その `W` は `reread_pct` の中央値の母数に含まれない

#### Scenario: 記録先番号が取れない W は対象から除かれる

- **WHEN** ある `W` の `description` に `#N` の形式の記録先番号が含まれない
- **THEN** その `W` は `reread_pct` の算出対象から除かれる

### Requirement: `usage-audit.md` への `--by-role` の追記

`plugins/dev-workflow/docs/usage-audit.md` は `--by-role` の使い方を追記しなければならない（SHALL）。追記内容は次を含む（SHALL）: ① `--by-role` の実行コマンド例 ② `by_role` 配下の出力キー（`count` / `first_median` / `docs_median` / `last_median` / `over_cap_pct` / `W` のみの `reread_pct`）の意味 ③ 担当分類の優先順位（`agentType` → `description` 先頭トークン → `unknown`) ④ `reread_pct` の母数の注意（グループ最初の個体・記録先番号が取れない個体を除く）。

#### Scenario: `--by-role` の読み方が文書からたどれる

- **WHEN** 担当別の傾向を確認したい人が `plugins/dev-workflow/docs/usage-audit.md` を読む
- **THEN** `--by-role` の実行コマンド・出力キーの意味・分類規則・`reread_pct` の母数の注意が揃っており、他のファイルを見ずに担当別監査を 1 回回せる
