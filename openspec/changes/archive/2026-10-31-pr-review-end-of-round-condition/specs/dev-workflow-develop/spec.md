## MODIFIED Requirements

### Requirement: 条件の確かめは PR のレビューに当てない

**PR のレビュー**: この節の本体の手順は G の `needs-fix-check` には当てない（MUST NOT）。PR のレビューの指摘の条件は、G が `stages/triage.md` の段 B と段落「周の終わりの止める指摘の条件」で確かめ、本体は判定しない（MUST NOT）。本体が決める役に渡すのは `needs-fix-check` で渡された指摘に限る（MUST）。

#### Scenario: PR のレビューには当てない
- **WHEN** G が Status `needs-fix-check` で return する
- **THEN** 本体はこの節の手順を通さず、「レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける」Requirement の手順で判定に進む

#### Scenario: G が条件で閉じた指摘は判定に渡さない
- **WHEN** G が周の終わりに 1 件を条件で閉じ、残った 1 件を Status `needs-fix-check` で return する
- **THEN** 本体は残った 1 件だけを決める役に渡し、閉じた指摘を判定の入力に入れず、R1 の当て直しに当たる手順も通さない
