# Tasks: agent-pr-issue-body-format

## 1. 受け入れテスト（Red）

- [ ] 1.1 spec のシナリオを grep ベースで検証するテストスクリプト `tests/pr-body-format.test.sh` を作成する（reference の 5 見出し順・翻訳例 3 組・軽量モード理由行・issueify とインストールテンプレの 2 節・agent-loop-template の参照差し替え・両 plugin.json のバージョンを検証）。この時点で失敗することを確認する

## 2. 正本 reference の新設

- [ ] 2.1 `plugins/loops/references/pr-body-format.md` を作成する: PR 5 セクション型（コメント付き雛形）・設計原則（順序・同じ情報を 2 回書かない・翻訳の規律＋良い例/悪い例 3 組・ネガティブ欄の根拠必須・行数上限）・誇張防止の 1:1 紐付け制約・`<details>` の再生成可能物限定・軽量モード（自己判断基準＋理由 1 行明記）・承認要求コメントの 3 行ルール

## 3. 参照配線（loops）

- [ ] 3.1 `plugins/loops/templates/agent-loop-template.md` Step 3-5 の「本文に `Closes #<番号>` と検証ログを書き」を `pr-body-format.md` 参照に差し替える
- [ ] 3.2 `plugins/loops/skills/loops-issueify/SKILL.md` の issue ドラフト構造の先頭に「これで何が変わるか」「やらないとどうなるか / 今のコスト」の 2 節を追加する
- [ ] 3.3 `plugins/loops/skills/loops-dev-agent-install/SKILL.md` Step 3 の `agent-task.md` テンプレートに同 2 節を追加する

## 4. 追従（dev-workflow）

- [ ] 4.1 `plugins/dev-workflow/commands/work-issue.md` の fail-soft 縮退手順の issue ドラフト最小構成に同 2 節を追加する

## 5. バージョン更新と検証（Green）

- [ ] 5.1 `plugins/loops/.claude-plugin/plugin.json` を 0.17.0 に、`plugins/dev-workflow/.claude-plugin/plugin.json` を 1.5.1 に更新する
- [ ] 5.2 テストスクリプトを実行し全件 pass（exit 0）を確認する
- [ ] 5.3 issue #47 にスコープ外項目（生成済み docs/agent-loop.md への反映・D-4・wt-setup テンプレ据え置き判断）をコメントで残す
