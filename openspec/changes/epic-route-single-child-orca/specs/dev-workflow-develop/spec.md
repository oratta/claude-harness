## ADDED Requirements

### Requirement: 着手できる子が 1 件でも Orca 経路で回す
`plugins/dev-workflow/scripts/epic-dispatch.sh` の `route` は、エピックの子のセッションでなく（`nested` でなく）、子の番号が 1 件以上あり、`orca` コマンドが PATH にあり、かつ `orca worktree current --json` が exit 0 で終わる（今いるディレクトリが Orca 管理のワークツリー）ときは、子の件数が 1 件でも 2 件以上でも stdout に `orca` の 1 行を出さなければならない（MUST）。子が 0 件のときは `subagent`、`orca` が PATH に無いときと Orca 管理外のときは `subagent` を出す。`nested` の判定が先に行われること、`orca worktree current` を 1 回の `route` で 1 回だけ呼ぶこと、子の番号が数字でなければ exit 1 で終わることは変えない。develop の SKILL.md「エピックの扱い」の「経路の決め方」は、件数の条件を書いてはならない（MUST NOT）。

経路は `/develop <エピック番号>` の最初の開始時に 1 回決めて途中で変えず、再開時は `回し方:` で始まる最新のコメントから引き継ぎ、すでに `回し方: サブエージェント` と記録したエピックを途中で Orca 経路に切り替える規則は置かない（SHALL。進行中のサブエージェント方式の子と Orca の子ワークツリーの子が混在する状態を扱う規則が無く、Orca 経路の手順の規定は別の変更が扱うため）。この要件は、要件「エピックの条件・作り方・回し方・完了条件を規定する」の `route` が `orca` を返す条件の規定、要件「epic-dispatch.sh はエピックの子の経路判定・起動・待ち受けを LLM なしで行う」の `route` の判定の規定、要件「エピックの子への注意書きと…引き継ぐ」の `route` の段落のうち、子の件数の条件に関わる部分に優先する。

この要件の守備範囲で入力として扱うのは、本体が依存グラフから求めた子の番号の並びと、`orca` の有無・`orca worktree current` の終了コードである。次は通してよく、この要件では止めない: 存在しない・重複した・blocked されている子の番号は `route` では検証しない（既存の規定どおり）／この変更より前に `回し方: サブエージェント` と記録した進行中のエピックは、そのエピックが終わるまでサブエージェント方式のまま進む。

#### Scenario: Orca 管理のワークツリーで子が 1 件なら orca を返す
- **WHEN** `orca` が PATH にあり Orca 管理のワークツリーにいる環境で `epic-dispatch.sh route 11` を実行する
- **THEN** stdout は `orca` の 1 行で exit 0

#### Scenario: 子が 2 件でも今までどおり orca を返す
- **WHEN** `orca` が PATH にあり Orca 管理のワークツリーにいる環境で `epic-dispatch.sh route 11 12` を実行する
- **THEN** stdout は `orca` の 1 行で exit 0

#### Scenario: 子が 1 件でも orca が無い・Orca 管理外ならサブエージェント方式になる
- **WHEN** `orca` が PATH に無い環境と、`orca` が PATH にあり `orca worktree current` が exit 1 を返す環境のそれぞれで `epic-dispatch.sh route 11` を実行する
- **THEN** どちらも stdout は `subagent` の 1 行で exit 0

#### Scenario: 子が 0 件なら Orca 管理下でも subagent を返す
- **WHEN** `orca` が PATH にあり Orca 管理のワークツリーにいる環境で `epic-dispatch.sh route` を子なしで実行する
- **THEN** stdout は `subagent` の 1 行で exit 0

#### Scenario: nested の判定は子が 1 件でも先に行われる
- **WHEN** `EPIC_DISPATCH_PARENT_EPIC=420` の環境で `orca` が PATH にあり Orca 管理のワークツリーにいるとき、`epic-dispatch.sh route 11` を実行する
- **THEN** stdout は `nested` の 1 行で exit 0、`orca` は呼ばれない

#### Scenario: SKILL.md の経路の決め方に件数の条件が書かれていない
- **WHEN** `skills/develop/SKILL.md` の「エピックの扱い」の「経路の決め方」を読む
- **THEN** `orca` になる条件が「`orca` が PATH にあり、本体が Orca 管理のワークツリーにいる」だけで書かれ、blocked されていない子の件数の条件（「2 件以上」）が無く、経路は最初の開始時に 1 回だけ決めて途中で変えないこと、再開時は `回し方:` のコメントから引き継ぐことは残っている
