# loops-readme-positioning Specification (Delta)

## ADDED Requirements

### Requirement: README に公式 4 ループタイプと loops プラグインの位置づけが記載されている

ルート `README.md` は、loops プラグインを紹介するセクションを含まなければならない (MUST)。セクションには公式 4 ループタイプ（ターンベース / ゴールベース / タイムベース / プロアクティブ）の名称と、一次ソースである公式記事へのリンク（`https://claude.com/blog/getting-started-with-loops`）、およびインストールコマンド（`/plugin install loops@oratta-claude-harness`）を含めること。

#### Scenario: 4 ループタイプの名称が README に現れる

- **WHEN** ユーザーが `README.md` に対して「ターンベース」「ゴールベース」「タイムベース」「プロアクティブ」の 4 語をそれぞれ grep する
- **THEN** 4 語すべてが loops プラグインのセクション内でヒットする

#### Scenario: 公式記事リンクが記載されている

- **WHEN** ユーザーが `README.md` に対して `https://claude.com/blog/getting-started-with-loops` を grep する
- **THEN** 1 件以上ヒットする

#### Scenario: インストールコマンドが記載されている

- **WHEN** ユーザーが `README.md` に対して `/plugin install loops@oratta-claude-harness` を grep する
- **THEN** 1 件以上ヒットする

### Requirement: README への追記は要約に留め詳細は plugins/loops/ に委ねる

README の loops セクションは要約（位置づけ・4 タイプの一覧・導線）に留めなければならない (MUST)。レシピ本文・State 規約の詳細・レシピ固定見出しの定義を README に複製してはならず (MUST NOT)、詳細への導線として `plugins/loops/`（および調査資料の `research/`）への参照を記載すること。ハーネスの責務は「ネイティブプリミティブの合成レシピ」であり独自ランタイムではない旨を 1 文で示し、定期実行のスケジューラ登録手順を README に書いてはならない (MUST NOT)。

#### Scenario: 詳細への導線がある

- **WHEN** ユーザーが README の loops セクションを読む
- **THEN** `plugins/loops/` への参照（パスまたはリンク）が記載されている

#### Scenario: レシピ本文が README に複製されていない

- **WHEN** ユーザーが `README.md` に対してレシピ固定見出し（「## 停止基準」「## エスカレーション」等のレシピ規約見出し）を grep する
- **THEN** ヒットは 0 件である（README にはレシピの固定見出し構造が現れない）
