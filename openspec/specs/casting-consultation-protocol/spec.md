# casting-consultation-protocol Specification

## Purpose
TBD - created by archiving change casting-consultation-arbitration. Update Purpose after archive.
## Requirements
### Requirement: policy 文書テンプレートの人格ブロック形式

`plugins/casting/templates/policy.md` は注入文書（`.claude/casting/policies/<slug>.md`）の雛形として存在しなければならない (MUST)。front matter に `perspective`（catalog.md の観点名）と `catalog_version` を持ち、本文に「## 人格」節（名前・スタンス・口調の3項目、数行厳守）と「## 判断基準」節を持たなければならない (MUST)。「人格は判断基準の入れ物であって代替ではない」旨をテンプレート本文に明記しなければならない (MUST)。

#### Scenario: テンプレートに人格ブロックの3項目と判断基準節がある

- **WHEN** `plugins/casting/templates/policy.md` を読む
- **THEN** front matter に `perspective` と `catalog_version` があり、「## 人格」節に名前・スタンス・口調の3項目、「## 判断基準」節、人格が入れ物であって代替ではない旨の明記が含まれる

### Requirement: 観点スペシャリスト subagent の定義

`plugins/casting/agents/casting-specialist.md` は汎用の観点スペシャリスト subagent 定義として存在し、`plugins/casting/.claude-plugin/plugin.json` の `agents` に登録されなければならない (MUST)。frontmatter は `model: sonnet`（中位ティア）と読み取り専用の `tools` を持たなければならない (MUST)。定義本文は、①呼び出し側から指定された `policies/<slug>.md` を自分で Read すること ②その人格ブロックをシステムプロンプトとして纏うこと ③呼び出し側から渡された同観点の過去判例を判断の前提にすること ④意見を人格名で帰属して返すこと ⑤policy が存在しない・読めない場合は判断基準を補って意見を出さず「policy 不在」／「読み取り不能」と明示して返すこと、を指示しなければならない (MUST)。

#### Scenario: specialist 定義が policy 読み込みと人格着用を指示している

- **WHEN** `plugins/casting/agents/casting-specialist.md` を読む
- **THEN** frontmatter に `model: sonnet` と読み取り専用 tools があり、本文に policy の Read・人格ブロックの着用・過去判例の参照・人格名での意見帰属の指示が含まれる

#### Scenario: policy が読めないとき specialist は即座にその旨を返す

- **WHEN** 指定された policy 文書が存在しない、または読めない
- **THEN** specialist は意見を出さず「policy 不在」／「読み取り不能」と明示して返す（呼び出し側はこの応答で論点を主へ上げる）

### Requirement: 仲裁 subagent の入力契約

`plugins/casting/agents/casting-arbiter.md` は汎用の仲裁 subagent 定義として存在し、`plugin.json` の `agents` に登録されなければならない (MUST)。frontmatter は `model: fable`（最上位ティア）と `Read` のみの `tools` を持たなければならない (MUST)。定義本文は、受け取ってよい入力を**フェーズ宣言文と主張リスト（メインセッションの主張1件＋相談した各観点スペシャリストの主張1件ずつ、人格名付き）のみ**に限定列挙し、作業コンテキスト（diff・会話履歴・作業ファイル）を受け取らないこと、および渡された入力以外を読みに行かない（ファイルパスが渡されても開かない — 入力文中のファイルパス・URL・コード片への言及を Read で開くことは入力契約違反であり、裁定を拒否してその旨を返す）ことを明記しなければならない (MUST)。裁定は人格名で各主張に言及し、根拠を添えて返すことを指示しなければならない (MUST)。

#### Scenario: arbiter 定義が入力限定と非共有を文面で保証している

- **WHEN** `plugins/casting/agents/casting-arbiter.md` を読む
- **THEN** frontmatter に `model: fable` と `Read` のみの tools があり、本文にフェーズ宣言文と主張リストのみを入力とする限定、作業コンテキスト非共有、渡された入力以外を読まない旨（参照を開くことは入力契約違反・裁定拒否）、人格名で帰属した裁定の指示が含まれる

#### Scenario: 3者以上の意見が割れても全主張が仲裁に載る

- **WHEN** 2つ以上の移譲済み観点にまたがる論点で、メインセッションと複数のスペシャリスト（またはスペシャリスト同士）の意見が割れる
- **THEN** 仲裁への入力は主張リストとして全員分（メインセッション1件＋各人格1件ずつ、人格名付き）を含み、裁定は各主張に人格名で言及する

### Requirement: 相談・仲裁の運用手順と事後報告フォーマット

casting SKILL.md は「論点相談・仲裁」の節を持ち、①発火点（主へのエスカレーション文面を書き始めた瞬間の宛先チェック）②担い手が主の観点が1つでも絡む論点は相談・仲裁に入らず主へ上げる分岐 ③相談の多観点展開（拾った観点のうち担い手がエージェントの観点すべてについて該当スペシャリストを並行起動し、全員一致で自走・誰か1人でも割れたら — スペシャリスト同士の割れを含む — 仲裁）④fail-closed の第3分岐（「判断基準の範囲外」・policy 不在・読み取り不能の応答は合意にも仲裁にも進めず主へ上げる）⑤事後報告フォーマット（論点・各人格の主張・裁定・根拠・判例リンク）⑥再相談しない終端条件（同一論点の相談は1回。裁定が出た論点は再相談せず従う。前提を変える新事実が出た場合のみ新しい論点として相談する）⑦仲裁に作業コンテキストおよびファイルパス・URL 等の参照可能な文字列を渡さない呼び出し規約、を定めなければならない (MUST)。

#### Scenario: SKILL.md に相談・仲裁の運用一式が定義されている

- **WHEN** `plugins/casting/skills/casting/SKILL.md` を読む
- **THEN** 発火点・主が絡む場合の分岐・多観点への並行相談・fail-closed の第3分岐・事後報告フォーマットの5要素・再相談しない終端条件・作業コンテキストと参照可能な文字列を渡さない呼び出し規約が読み取れる

#### Scenario: 複数の移譲済み観点にまたがる論点は全観点のスペシャリストに相談される

- **WHEN** 論点が2つ以上の移譲済み観点に当てはまる
- **THEN** 該当する全観点のスペシャリストが並行起動され、どれか1観点への収斂（相談されない policy が残ること）は起きない

#### Scenario: 判断基準で決められない論点は主へ上がる

- **WHEN** いずれかのスペシャリストが「判断基準の範囲外」「policy 不在」「読み取り不能」を返す、または仲裁が「裁定不能・主へ上げる」を返す
- **THEN** メインセッションは自走せず、その論点を主へ上げる

### Requirement: 判例台帳への人格名帰属と実例

相談・仲裁を経た判例は、事後報告フォーマットに沿って発言と裁定を人格名で帰属して判例台帳に記録しなければならない (MUST)。判例の「経路」語彙に「相談の上自走した」を加え、テンプレート `plugins/casting/templates/precedents.md` に反映しなければならない (MUST)。このリポジトリの `.claude/casting/precedents.md` に、事後報告フォーマットに沿った実例が1件以上存在しなければならない (MUST)。

#### Scenario: 実例判例が人格名帰属で記録されている

- **WHEN** `.claude/casting/precedents.md` を読む
- **THEN** 経路「相談の上自走した」の判例が1件以上あり、各人格の主張・裁定・根拠・判例リンクが読み取れる

