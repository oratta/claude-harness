## MODIFIED Requirements

### Requirement: frontmatter は限定した書式だけを受理する

frontmatter の各行の 5 形のうち入れ子キー行について、`description:` で始まるもの（`^  description:`）は違反としなければならない（MUST）。frontmatter 全体を字下げすると YAML ではトップレベルの `description` と読まれるが、集計は `^description:` だけを数えて 0 バイトにするため。入れ子の `description` は注入対象ではないので許可する理由がない。他の条件は変えない。

#### Scenario: 字下げした description を落とす

- **WHEN** 一時ディレクトリに frontmatter 全体を半角空白 2 個で字下げしたファイル（`  description: <長文>`、または `  name:` と `  description:` の両方）を置き、検査ヘルパに渡す
- **THEN** 違反として検出され、該当ファイル名が出力される。`metadata:` の下の入れ子キー（`description` 以外）は引き続き受理される
