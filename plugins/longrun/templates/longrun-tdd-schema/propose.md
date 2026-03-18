# Propose/FF Template (longrun-tdd)

このテンプレートはロングラン自律実行中のOpenSpecドキュメント作成時に使用される。
ユーザーへの質問を禁止し、自律的に判断してドキュメントを生成する。

## 自律判断ルール

<HARD-GATE>
AskUserQuestion ツールを使ってはならない。
ロングラン自律実行中であり、ユーザーは介入しない。
</HARD-GATE>

判断が必要な場合:
1. instruction.md の要件と受け入れ条件を再確認
2. 既存コードベースを調査（Grep, Glob）して情報を補完
3. 不明点は以下の優先順位で判断:
   - instruction.md に明記 → それに従う
   - 既存コードのパターン → それに合わせる
   - 可逆的な方 → それを選ぶ
   - YAGNI → シンプルな方を選ぶ
4. 判断結果を design.md の Decisions セクションに記録

## ドキュメント品質基準

### proposal.md
- Why が明確で、instruction.md のゴールと整合している
- Capabilities が過不足なく列挙されている
- Impact が影響範囲を網羅している

### specs/
- Requirements が明確で曖昧さがない
- Scenarios の WHEN/THEN がテストコードに直接変換できる具体性を持つ
- 正常系・異常系・エッジケースが考慮されている
- Delta spec（ADDED/MODIFIED/REMOVED）が正しく分類されている

### design.md
- 既存コードのパターンと整合している
- Goals/Non-Goals でスコープが明確
- Decisions に判断根拠が記録されている

### tasks.md
- タスク粒度が適切（1タスク = 1コミット程度）
- 依存関係が正しく反映されている
- specs/ の全 Requirements がカバーされている
- チェックボックス形式 `- [ ]` で記述されている
