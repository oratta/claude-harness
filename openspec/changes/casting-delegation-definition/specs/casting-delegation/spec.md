## ADDED Requirements

### Requirement: 委任の定義正本

casting プラグインは委任の定義正本 `plugins/casting/catalog/delegation.md` を持たなければならない (MUST)。定義は「委任＝許可されたツール集合 × 判断を任された観点集合」の 2 プリミティブで書き、ツール側の正本は Claude Code の permission 設定、観点側の正本は配役表の 3 層解決であると明記しなければならない (MUST)。ロール（プリセット）はこの 2 集合の組み合わせに付けた名前と位置づけ、ロールの一覧表を正本として持ってはならない (MUST NOT)。「論点＝別の観点を入れると結論が変わるもの。LLM 側が情報を持つものは論点ではなく自分で決める」を定義に含めなければならない (MUST)。

#### Scenario: 定義正本に 2 プリミティブと正本の所在が書かれている

- **WHEN** `plugins/casting/catalog/delegation.md` を読む
- **THEN** 「許可ツール」「任された観点」の 2 プリミティブ、permission と配役表がそれぞれの正本であること、ロールが組み合わせ名であることが読み取れる

### Requirement: 委任宣言の書式と置き場

委任宣言は `## 委任` 見出しの下に「許可ツール」表（`| ツール/パターン | 許可 | 出どころ |`）と「任された観点」表（`| 観点 | 担い手 | 根拠 |`）の 2 表を並べる書式でなければならない (MUST)。置き場は repo ファイル `<repo>/.claude/casting/delegation.md`（git 追跡）と起動プロンプト中のセッション宣言の 2 つとし、どちらも同じ書式を使わなければならない (MUST)。宣言ファイルは両正本の要約であり、正本と食い違った場合は正本が勝つと定義文に明記しなければならない (MUST)。宣言ファイルは `casting-check.sh` の 5 列検査の対象に含めてはならない (MUST NOT)。

#### Scenario: 雛形が 2 表を 1 ファイルに持つ

- **WHEN** `plugins/casting/templates/delegation.md` を読む
- **THEN** front matter に `catalog_version` があり、`## 委任` 見出しの下に「許可ツール」と「任された観点」の 2 つの表見出しが並んでいる

#### Scenario: 宣言ファイルは check の対象外

- **WHEN** 許可ツール表を含む `delegation.md` がある repo に `casting-check.sh` を実行する
- **THEN** delegation.md の行は malformed-row として報告されない

### Requirement: /casting:policy-interview による policy 文書の対話生成

`/casting:policy-interview <観点名またはslug>` コマンドは、観点名を `catalog/injection.md` の slug 対応表で解決し、1 問ずつ自由回答で主に聞いて `<repo>/.claude/casting/policies/<slug>.md` を `templates/policy.md` から生成しなければならない (MUST)。複数の質問を並べて選択肢から選ばせる形（AskUserQuestion 等）を使ってはならない (MUST NOT)。既存の policy がある場合は上書きせず、現在の判断基準を示してから差分を聞いて更新しなければならない (MUST)。コマンド実行中に限りメインセッションが対象 policy を読み書きしてよいが、生成後の判断にその内容を使ってはならない (MUST NOT)。生成後は配役表（project.md）の該当行と delegation.md の観点表の更新を主に促さなければならない (MUST)。

#### Scenario: コマンド定義が存在し手順を持つ

- **WHEN** `plugins/casting/commands/policy-interview.md` を読む
- **THEN** front matter の name が `casting:policy-interview` で、slug 解決・1 問ずつ自由回答・`templates/policy.md` からの生成・既存 policy の更新手順・生成後の配役表更新の案内が書かれている

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
