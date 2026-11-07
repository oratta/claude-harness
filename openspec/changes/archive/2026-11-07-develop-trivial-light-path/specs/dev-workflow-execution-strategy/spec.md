## MODIFIED Requirements

### Requirement: Step B 基準の重心移動
develop スキルの `plugins/dev-workflow/skills/develop/references/decision-criteria.md` の仕様化要否（Step B）は、「設計判断・トレードオフを含むか（= 意図と決定の記録価値があるか)」を一次基準としなければならない（SHALL）。受け入れ条件が記録先（issue または Draft PR 本文）に明記された機械的な振る舞い変更は、記録先とテストを記録として spec 化を省略できる。テスト作成の必須性は、軽い通し方（`dev-workflow-spec-review` の「些細な修正は軽い通し方で新しいテストと W の起動を省く」Requirement）を除くいかなる判定でも緩めてはならない（MUST NOT）。軽い通し方では、記録先に書いた既存のテストかチェックのコマンドを走らせることが新しいテストの代わりになる（SHALL）。unmanned モードの「迷ったら spec 化に倒す」は維持する。

#### Scenario: 機械的な振る舞い変更は spec を省略できる
- **WHEN** 受け入れ条件が記録先に明記され、設計判断（トレードオフの選択）を含まない振る舞い変更を interactive で判定する
- **THEN** spec 化を省略してコード直行し、テストは必ず先に書く

#### Scenario: unmanned は安全側を維持
- **WHEN** unmanned モードで spec 化要否の判断がつかない
- **THEN** spec 化する側に倒す

#### Scenario: 軽い通し方だけが新しいテストを省く
- **WHEN** 記録先の最新の仕様化判断のコメントが `仕様化判断: しない` で `通し方: 軽い` の行を持つ
- **THEN** 新しいテストは書かず、`確かめ方:` の行のコマンドを走らせて確かめる。この行が無い判断では、どの判定でもテストを書く
