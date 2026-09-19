## Why

従来モードの full レビューで companion の不在を Codex CLI 未導入と誤認し、利用可能な `codex exec` を試さず Claude にフォールバックする問題を防ぐ。記録先は https://github.com/genetta-inc/flatmate/issues/715 。仕様化判断は同 issue の comment-5740120122 に記録済み。

## What Changes

- 従来モードのレビュー実行者表に `codex exec` を正式な Codex 経路として明記し、companion を必須にしない。
- Codex 不可の判定を実測したバイナリ無し・認証切れ・総待ち上限到達に限定し、コマンドと結果を PR コメントと G の引き継ぎに残す。
- 各稼働 PC の確認手順と証拠記録方法を文書化する。実機確認は別運用として #715 に記録し、実測が揃うまで issue を完了扱いにしない。
- #707 の新 Codex モード（App Server 固定、暗黙 exec / Claude fallback なし）には適用しない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 従来モードの Codex 経路、実測による不可判定、証拠記録と PC 確認手順。

## Impact

`plugins/dev-workflow/skills/pr-review-gate/SKILL.md`、`skills/develop/references/roles/gate-runner.md`、関連 Bats テストが対象。待ち方は既存の `plugins/dev-workflow/references/subagent-waiting.md` を参照し、実行基盤や新しい導入判定スクリプトは追加しない。

## 分割判定

単一 change。受け入れ条件は一つの capability 内の経路・不可判定と証拠・確認手順で、同じ誤検知を修正する一つの方針にまとまる。実機確認を別運用とする境界は本体決定済み。1 PR で文書化まで完結でき、#706 / #707 の実装を待たない。
