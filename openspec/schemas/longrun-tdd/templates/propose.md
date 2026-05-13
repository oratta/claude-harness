# Propose/FF Template (longrun-tdd)

このテンプレートは自律実行中のOpenSpecドキュメント作成時に使用される。
ユーザーへの質問を禁止し、自律的に判断してドキュメントを生成する。

## 自律判断ルール

<GATE>
AskUserQuestion ツールを使ってはならない。
自律実行中であり、ユーザーは介入しない。
</GATE>

判断が必要な場合:
1. plan.md の要件と受け入れ条件を再確認
2. 既存コードベースを調査（Grep, Glob）して情報を補完
3. 不明点は以下の優先順位で判断:
   - plan.md に明記 → それに従う
   - 既存コードのパターン → それに合わせる
   - 可逆的な方 → それを選ぶ
   - YAGNI → シンプルな方を選ぶ
4. 判断結果を design.md の Decisions セクションに記録

## ドキュメント品質基準

### proposal.md
- Why が明確で、plan.md のゴールと整合している
- Capabilities が過不足なく列挙されている
- Impact が影響範囲を網羅している

### specs/
- Requirements が明確で曖昧さがない
- **Scenarios はユーザーアクションレベルで記述する**（最重要）:
  - WHEN は「ユーザーが画面上で行う操作」で書く
  - THEN は「ユーザーが画面上で確認できる結果」で書く
  - ❌ 避ける: 「削除リクエストが送信される」「DBからレコードが削除される」
  - ✅ 良い: 「ユーザーが確認モーダルでOKを押す → アイテムが一覧から消え、トースト通知が表示される」
  - このScenarioは以下の3つの用途で使い回される:
    1. **E2Eテスト生成**（Build: Playwright等のテストケースに直接変換）
    2. **longrun-verifier検証**（Verify: ブラウザ動作確認のチェックリスト）
    3. **ユーザー手動確認**（Feedback: verification-guide.mdの確認項目として転記）
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
