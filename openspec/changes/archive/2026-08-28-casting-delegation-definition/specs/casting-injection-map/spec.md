## MODIFIED Requirements

### Requirement: 注入文書の置き場所規約

観点の移譲に必要な注入文書は `<repo>/.claude/casting/policies/<slug>.md` に置かなければならない (MUST)。`catalog/injection.md` は観点名と slug の対応表を持たなければならない (MUST)。注入文書の生成・更新の入口は `/casting:policy-interview` であり、`injection.md` はそのポインタを持たなければならない (MUST)。既存の別置き文書（repo ルートの PHASE.md 等）がある repo では実体の移動を強制せず、policies/ からの参照 stub を許容することを明記しなければならない (MUST)。

#### Scenario: policies 規約と slug 対応表がある

- **WHEN** `plugins/casting/catalog/injection.md` を読む
- **THEN** `policies/<slug>.md` の置き場所規約、観点→slug の対応表、`/casting:policy-interview` へのポインタが読み取れる
