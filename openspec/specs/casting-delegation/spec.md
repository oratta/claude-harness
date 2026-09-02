# casting-delegation Specification

## Purpose
委任＝「許可ツール × 任された観点」の定義正本、委任宣言（2 表）の書式と置き場、`/casting:policy-interview` による観点の判断基準の対話生成、返信前チェック手順③でのツール側確認を規定する（oratta/claude-harness#207）。

## Requirements
### Requirement: 委任の定義正本

casting プラグインは委任の定義正本 `plugins/casting/catalog/delegation.md` を持たなければならない (MUST)。定義は「委任＝許可されたツール集合 × 判断を任された観点集合」の 2 プリミティブで書き、ツール側の正本は Claude Code の permission 設定、観点側の正本は配役表の 3 層解決であると明記しなければならない (MUST)。ロール（プリセット）はこの 2 集合の組み合わせに付けた名前と位置づけ、ロールの一覧表を正本として持ってはならない (MUST NOT)。「論点＝別の観点を入れると結論が変わるもの。LLM 側が情報を持つものは論点ではなく自分で決める」を定義に含めなければならない (MUST)。

#### Scenario: 定義正本に 2 プリミティブと正本の所在が書かれている

- **WHEN** `plugins/casting/catalog/delegation.md` を読む
- **THEN** 「許可ツール」「任された観点」「permission」「配役表」「組み合わせ」「論点」の語が含まれ、2 プリミティブ・それぞれの正本・ロールが組み合わせ名であること・論点の定義が読み取れる

### Requirement: 委任宣言の書式と置き場

委任宣言は `## 委任` 見出しの下に「許可ツール」表（`| ツール/パターン | 許可 | 出どころ |`）と「任された観点」表（`| 観点 | 担い手 | 根拠 |`）の 2 表を並べる書式でなければならない (MUST)。置き場は repo ファイル `<repo>/.claude/casting/delegation.md`（git 追跡）と起動プロンプト中のセッション宣言の 2 つとし、どちらも同じ書式を使わなければならない (MUST)。宣言ファイルは両正本の要約であり、正本と食い違った場合は正本が勝つと定義文に明記しなければならない (MUST)。宣言ファイルは `casting-check.sh` の 5 列検査の対象に含めてはならない (MUST NOT)。セッション宣言の `## 委任` 配下の観点表（3 列）は要約であって第 3 層の上書きではなく、観点の上書きは従来どおり 5 列表（`skills/casting/SKILL.md` のセッション宣言書式）で書かなければならない (MUST)。`SKILL.md` はこの区別を明記しなければならない (MUST)。

#### Scenario: 雛形が 2 表を 1 ファイルに持つ

- **WHEN** `plugins/casting/templates/delegation.md` を読む
- **THEN** front matter に `catalog_version` があり、`## 委任` 見出しの下に「許可ツール」と「任された観点」の 2 つの表見出しが並んでいる

#### Scenario: SKILL.md が `## 委任` 節と 5 列上書き表を区別している

- **WHEN** `plugins/casting/skills/casting/SKILL.md` を読む
- **THEN** セッション宣言の `## 委任` 節の書式と、それが 5 列の上書き表とは別物（要約であり上書きではない）であることが書かれている

#### Scenario: 宣言ファイルは check の対象外

- **WHEN** 許可ツール表を含む `delegation.md` がある repo に `casting-check.sh` を実行する
- **THEN** delegation.md の行は malformed-row として報告されない

### Requirement: /casting:policy-interview による policy 文書の対話生成

`/casting:policy-interview <観点名またはslug>` コマンドは、観点名を `catalog/injection.md` の slug 対応表で解決し、1 問ずつ自由回答で主に聞いて `<repo>/.claude/casting/policies/<slug>.md` を `templates/policy.md` から生成しなければならない (MUST)。複数の質問を並べて選択肢から選ばせる形（AskUserQuestion 等）を使ってはならない (MUST NOT)。slug 対応表に無い観点を指定されたときは生成せず、その旨と対応表の場所を返して終了しなければならない (MUST)。既存の policy がある場合は上書きせず、現在の判断基準を示してから差分を聞いて更新しなければならない (MUST)。コマンド実行中に限りメインセッションが対象 policy を読み書きしてよいが、生成後の判断にその内容を使ってはならない (MUST NOT)。生成後は配役表（project.md）の該当行と delegation.md の観点表の更新を主に促さなければならない (MUST)。

#### Scenario: コマンド定義が存在し手順を持つ

- **WHEN** `plugins/casting/commands/policy-interview.md` を読む
- **THEN** front matter の name が `casting:policy-interview` で、「slug」「1 問ずつ」「templates/policy.md」「既存」「project.md」「delegation.md」の語を含む手順（slug 解決・1 問ずつ自由回答・雛形からの生成・既存 policy の更新・生成後の配役表と委任宣言の更新案内）が書かれている

#### Scenario: 対応表に無い観点は生成しない

- **WHEN** コマンド定義の手順を読む
- **THEN** slug 対応表に無い観点を指定されたときは生成せず対応表の場所を返して終了する、と書かれている

### Requirement: 全文未把握の外部規約を前提として書ける

policy 雛形 `templates/policy.md` は「前提とする外部規約」節を持ち、`| 規約 | 参照先 | 主の把握度 | スペシャリストへの指示 |` の表で、主が全文を把握していない規約（把握度「名前のみ」「概要のみ」）を前提として宣言できなければならない (MUST)。観点スペシャリストは把握度が「全文把握」でない規約を判断の前に参照先で読むこと、と雛形に書かなければならない (MUST)。

#### Scenario: 雛形に把握度 3 語の説明がある

- **WHEN** `plugins/casting/templates/policy.md` を読む
- **THEN** 「前提とする外部規約」の表見出しと、把握度の 3 語（全文把握／概要のみ／名前のみ）が書かれている

### Requirement: 返信前チェック手順③でツール側も確認する

`rules/perspective-casting.md` の手順③（担い手は主か）は、観点の担い手に加えてツール側の permission も委任宣言の同じ表で確認する旨を持ち、正本として `plugins/casting/catalog/delegation.md` を指さなければならない (MUST)。rule は 30 行以内を維持しなければならない (MUST)。

#### Scenario: rule に許可ツールの確認と正本ポインタがある

- **WHEN** `rules/perspective-casting.md` を読む
- **THEN** 「許可ツール」の語と `plugins/casting/catalog/delegation.md` が含まれ、行数が 30 以下である
