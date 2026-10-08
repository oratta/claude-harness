## MODIFIED Requirements

### Requirement: 仲裁 subagent の入力契約

`plugins/casting/agents/casting-arbiter.md` は汎用の仲裁 subagent 定義として存在し、`plugin.json` の `agents` に登録されなければならない (MUST)。frontmatter は `model: fable`（最上位ティア）と `Read` のみの `tools`、および `omitClaudeMd: true`（CLAUDE.md を読み込まない）を持たなければならない (MUST)。定義本文は、受け取ってよい入力を**フェーズ宣言文と主張リスト（メインセッションの主張1件＋相談した各観点スペシャリストの主張1件ずつ、人格名付き）のみ**に限定列挙し、作業コンテキスト（diff・会話履歴・作業ファイル）を受け取らないこと、および渡された入力以外を読みに行かない（ファイルパスが渡されても開かない — 入力文中のファイルパス・URL・コード片への言及を Read で開くことは入力契約違反であり、裁定を拒否してその旨を返す）ことを明記しなければならない (MUST)。裁定は人格名で各主張に言及し、根拠を添えて返すことを指示しなければならない (MUST)。

#### Scenario: arbiter 定義が入力限定と非共有を文面で保証している

- **WHEN** `plugins/casting/agents/casting-arbiter.md` を読む
- **THEN** frontmatter に `model: fable` と `Read` のみの tools があり、本文にフェーズ宣言文と主張リストのみを入力とする限定、作業コンテキスト非共有、渡された入力以外を読まない旨（参照を開くことは入力契約違反・裁定拒否）、人格名で帰属した裁定の指示が含まれる

#### Scenario: arbiter は CLAUDE.md を読み込まない

- **WHEN** `grep -c '^omitClaudeMd: true' plugins/casting/agents/casting-arbiter.md` を実行する
- **THEN** 出力は `1` である

#### Scenario: 3者以上の意見が割れても全主張が仲裁に載る

- **WHEN** 2つ以上の移譲済み観点にまたがる論点で、メインセッションと複数のスペシャリスト（またはスペシャリスト同士）の意見が割れる
- **THEN** 仲裁への入力は主張リストとして全員分（メインセッション1件＋各人格1件ずつ、人格名付き）を含み、裁定は各主張に人格名で言及する
