## 1. テスト先行（Red）

- [x] 1.1 `plugins/dev-workflow/tests/pr-review-gate-skill.bats` に追加: ①手順4-2 の見出しの存在②確認対象4種（JSDoc / usage / README / エラーメッセージ）の列挙③`git grep -n` の具体例④証拠コメントの見出し `## ドキュメント文字列の整合確認` と `対象 HEAD`⑤手順5 の実測が3見出しに増えている⑥「やらないこと」への追記⑦6手順の骨格が壊れていない（回帰ガード）
- [x] 1.2 Red を確認する（SKILL.md 未変更の状態で fail することを exit code つきで確認）

## 2. 実装（Green）

- [x] 2.1 SKILL.md の手順4 を 4-1（既存本文そのまま）／ 4-2（新設）に分割する
- [x] 2.2 手順4-2 を書く: 実測の根拠・確認対象4種の表・`git grep -n` の手順・証拠コメントのテンプレ・先送り禁止
- [x] 2.3 手順5 の実測見出しを3点に更新し、合格の前提に 4-2 を加える
- [x] 2.4 冒頭の必須3点の②に整合確認を含め、「やらないこと」に1行追加する
- [x] 2.5 frontmatter version を 1.3.0 に上げる
- [x] 2.6 `plugins/dev-workflow/.claude-plugin/plugin.json` を 1.11.0 に上げ、`.claude-plugin/marketplace.json` を同期する
- [x] 2.7 bats を実行して Green を確認する（exit code を表示）

## 3. 整合・検証

- [x] 3.1 `openspec validate pr-review-gate-doc-string-consistency --strict` を通す
- [x] 3.2 `scripts/test.sh` 全スイート green（exit code 表示）
- [x] 3.3 `scripts/lint.sh` green（exit code 表示）
- [x] 3.4 issue #166 の受け入れ条件3点を1件ずつ突き合わせる（`git diff origin/main` が追加のみで既存必須ステップの削除を含まないことを含む）
- [x] 3.5 `.claude/casting/precedents.md` に本判断（聖域寄り物件だが「合格条件を足す」方向のみで自走した判断）の判例を追記する
