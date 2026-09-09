## Why

2026-09-08 に PR のゲート実行者（G）が 5 回止まり、合計約 4 時間の停止をオーナーの一言で毎回起こす必要があった（flatmate #579 / #580 / #581、claude-harness #252）。原因はハングではなく手順書で、G が Codex レビューやフルテストを `run_in_background` で起動したあと「完了通知を待つ」という素のテキストでターンを終えていた。名前付き background サブエージェントは idle になると自分の背景タスクの完了では再起動されないため、完了通知はキューに積まれるだけで新しいターンを起こさない。dev-workflow の手順書にはターンを終えずに 10 分より長く待つ方法がどこにも書かれていない。

## What Changes

- サブエージェント（W / R1 / G）に対して「完了を待つためにターンを終えない」禁止を明文化し、代わりの待ち方（前景 Bash の有限 `until` ループを、同一ターン内で必要な回数だけ呼び直す）を規定する
- 待ちの終了条件（完了シグナル）を起動経路ごとに定める。`codex exec` 直叩きは起動コマンドに完了マーカーを書き足し、companion 経由は `status --wait` の exit code を使う
- 総待ちの上限（前景ループ 3 回 = 27 分）と超過時の分岐を定める。これが pr-review-gate のフォールバック条件にある「タイムアウト」の定義になる
- `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` の Codex レビュー起動手順を 2 経路それぞれ書き換える
- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` の Codex 呼び出し規約を読み手（メインセッション / サブエージェント）で書き分け、`--timeout-ms 900000` を 540000 に直し、「最長 15 分待てる」のような前景上限を超える待ちを示唆する散文を消す
- `roles/worker.md` と `roles/spec-reviewer.md` にも同じ禁止を 1 行入れる
- 上記の退行を機械検出する bats スイートを `plugins/dev-workflow/tests/` に追加する

## Capabilities

### New Capabilities
- `dev-workflow-subagent-waiting`: サブエージェントが長時間処理の完了を待つ方法の契約（ターンを終えない・完了シグナルの定義・前景ポーリング・前景上限 600000 ms・総待ちの上限と分岐）と、その正本の置き場

### Modified Capabilities
- `dev-workflow-develop`: 役割の指示書（`references/roles/`）が持つべき内容に「待ち方の禁止 1 行」が加わり、G の Codex 起動手順が 2 経路とも前景ポーリングに変わる
- `dev-workflow-pr-review-gate`: Codex 呼び出し規約が読み手別に分かれ、`--timeout-ms` の指定値の上限とフォールバック条件「タイムアウト」の定義が入る
- `dev-workflow-shared-references`: `plugins/dev-workflow/references/` に置く契約が 4 本から 5 本になり（`subagent-waiting.md` を追加）、dev-workflow 内の複数スキルが読む契約もここに置く旨が加わる

## Impact

- `plugins/dev-workflow/references/subagent-waiting.md`（新規・正本）
- `plugins/dev-workflow/README.md`（`references/` の表に 1 行追加。`dev-workflow-shared-references` の MUST）
- `plugins/dev-workflow/skills/develop/references/roles/{gate-runner,worker,spec-reviewer}.md`
- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`
- `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json`（バージョン bump と同期。S131 が merge-base からの bump を、S130 が marketplace エントリとの一致を要求する）
- `plugins/dev-workflow/tests/subagent-waiting.bats`（新規）
- 振る舞いへの影響は「エージェントの行動規約」。実行時のコード変更は無い
