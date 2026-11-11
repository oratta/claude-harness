## Why

pr-review-gate の手順 2-2（修正サイクルのモデル昇格）が、失敗ループ（#424）で格と `--failure` の値に書き換えた規則と食い違っている。Claude のモデル名（実行役を `opus` で spawn、決める役を `opus` → `fable`）が本文の規則として残り、Codex の構成では読めない。

## What Changes

- `plugins/dev-workflow/skills/pr-review-gate/stages/triage.md` の 2-2 の節と「failed のとき」の本体への提案を、`request --phase implement --failure executor` と `request --phase decider --failure first|judgment` が返した model を使う書き方に揃える
- `plugins/dev-workflow/skills/develop/SKILL.md` (4) の failed 分岐と `plugins/dev-workflow/README.md` の説明を同じ言い方に揃える
- 固定している `model-escalation-policy.bats` と `develop-roles.bats` を直す
- `dev-workflow-develop` の要件「1 ループは W→R1→W→G の順で回る」の failed 分岐を同じ言い方に直す

## Capabilities

### Modified Capabilities

- `dev-workflow-develop`: failed 分岐の昇格を、実行役を `opus` に上げると書く代わりに格と `--failure` の値で書く
