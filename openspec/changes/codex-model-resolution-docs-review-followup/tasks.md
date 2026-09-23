## 1. 受け入れ条件のテスト

- [x] 1.1 利用者向け docs の系統名・完全 ID の説明と archive tasks の 3.2 / 3.3 の訂正文言を検証するテストを先に追加し、Red を確認する
- [x] 1.2 Codex review 結果の requested / resolved を G に渡す手順と、G のコメントへの `<requested>→<resolved>` 記録を検証するテストを先に追加し、Red を確認する。`plugins/dev-workflow/tests/develop-adapter-review-routing.bats:104,125` の既存固定文字列は変えない

## 2. 文書とレビュー記録手順

- [x] 2.1 `plugins/dev-workflow/docs/codex-develop.md` の 16 行目の使用例と 43 行目付近の説明を #405 の受け入れ条件どおり更新する
- [x] 2.2 `plugins/dev-workflow/skills/develop/SKILL.md` の手順 4-④に、Codex review worker の `execution.model_resolution.requested` / `resolved` を G に渡す指示を追加する
- [x] 2.3 `gate-runner.md` と `pr-review-gate/SKILL.md` の既存コメント形を保ち、Codex の `<model>` を `<requested>→<resolved>` として書く説明を追加する
- [x] 2.4 archive 済み `codex-model-family-resolution/tasks.md` の 3.2 と 3.3 の括弧内を指定文言へ訂正する

## 3. 検証

- [x] 3.1 追加したテストを Green にし、`openspec validate codex-model-resolution-docs-review-followup --strict` を実行する
- [ ] 3.2 `scripts/test.sh` を実行し、exit code と結果要約を記録する
