## Why

pr-review-gate の必須 3 点（リスク宣言・動作確認証拠・`agent-review:passed`）には「仕様を更新したか／不要と判断したか」が含まれず、github-issue スキルを通らずに実装された PR（本体直回し・bulldozer・burn-mode）は仕様化判断の記録が無いまま合格できる。flatmate#380 の 6 PR がまさにこの経路で openspec 更新ゼロのままマージされた（claude-harness#191、flatmate#444）。先行 change `spec-decision-record-and-review` が入口の記録書式（`^仕様化判断: (する|しない)$` / `^仕様レビュー: (APPROVE|REQUEST_CHANGES)$`）を定めたので、出口でそれを照合する。

## What Changes

- 手順 3 に**仕様宣言**（positive affirmation）を追加する。リスク宣言と同じく `対象 HEAD:` を 1 行目に持つ PR コメントで、「仕様を更新した（change 名・archive 済み・仕様レビュー APPROVE）」か「仕様変更なし＋理由」のどちらかを必ず書く。「書かない」は選べない
- 手順 5 の API 実測に仕様宣言の見出しを加え（3 見出し揃わなければ passed を付けない）、さらに元 issue の `仕様化判断:` 記録との**整合**を照合する。記録が無い PR は fail-closed（今から記録を取りに戻る。issue の無い PR は PR 自身のコメントに同書式で記録してよい）
- 機械の裏取りとして `scripts/spec-touch-check.sh` を新設する。規範を持ちうるパス（リポごとに `.spec-touch-paths` で上書き可。既定は `docs/` `.claude/` `templates/` `scripts/` `CLAUDE.md` `AGENTS.md`）に触れていて `openspec/` に差分が無い PR を検出し、「変更なし」宣言の理由を要求する材料にする
- auto-merge workflow の合格条件への組み込みは**この change の範囲外**（配備 4 リポへの伝播を伴うため別 issue に切り出す）

## Capabilities

### New Capabilities
（なし）

### Modified Capabilities
- `dev-workflow-pr-review-gate`: 通過の必須点に仕様宣言を加え、手順 5 の実測と整合照合、spec-touch-check スクリプトを規定する

## Impact

- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`（冒頭の必須点・手順 3・手順 5）
- `plugins/dev-workflow/scripts/spec-touch-check.sh`（新規）
- `plugins/dev-workflow/tests/pr-review-gate-spec-declaration.bats`（新規）、`spec-touch-check.bats`（新規）
- `plugins/dev-workflow/.claude-plugin/plugin.json` / `.claude-plugin/marketplace.json` の version（1.13.0）
- 先行 change の `references/spec-review.md`「判断記録の契約」に依存する
