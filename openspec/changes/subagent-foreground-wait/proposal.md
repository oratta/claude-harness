## Why

2026-09-08 に PR のゲート実行者（G）が 5 回止まり、合計約 4 時間の停止をオーナーの一言で毎回起こす必要があった（flatmate #579 / #580 / #581、claude-harness #252）。原因はハングではなく手順書で、G が Codex レビューやフルテストを `run_in_background` で起動したあと「完了通知を待つ」という素のテキストでターンを終えていた。名前付き background サブエージェントは idle になると自分の背景タスクの完了では再起動されないため、完了通知はキューに積まれるだけで新しいターンを起こさない。dev-workflow の手順書にはターンを終えずに 10 分より長く待つ方法がどこにも書かれていない。

## What Changes

- サブエージェント（W / R1 / G）に対して「完了を待つためにターンを終えない」禁止を明文化し、代わりの待ち方（前景 Bash の有限 `until` ループを、同一ターン内で必要な回数だけ呼び直す）を規定する
- `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` の Codex レビュー起動手順を、`run_in_background` ＋出力ファイル読みから前景ポーリングに書き換える
- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md` の Codex 呼び出し規約を、読み手（メインセッション / サブエージェント）で待ち方が分かれることが分かる形に直し、`--timeout-ms 900000` を Bash 前景上限 600 秒未満の値に修正する
- `roles/worker.md` と `roles/spec-reviewer.md` にも同じ禁止を 1 行入れる
- 上記の退行を機械検出する bats スイートを追加する（`run_in_background` での完了待ち指示が残っていないこと、`--timeout-ms` が 600000 未満であること、各役割の指示書に禁止行があること）

## Capabilities

### New Capabilities
- `dev-workflow-subagent-waiting`: サブエージェントが長時間処理の完了を待つ方法の契約（ターンを終えない・前景ポーリング・前景上限 600 秒）と、その正本の置き場

### Modified Capabilities
- `dev-workflow-develop`: 役割の指示書（`references/roles/`）が持つべき内容に「待ち方の禁止 1 行」が加わり、G の Codex 起動手順が前景ポーリングに変わる
- `dev-workflow-pr-review-gate`: Codex 呼び出し規約の「フォアグラウンドで完了を待つ呼び方を禁止する」が読み手別に分かれ、`--timeout-ms` の指定値の上限が入る

## Impact

- `plugins/dev-workflow/references/subagent-waiting.md`（新規・正本）
- `plugins/dev-workflow/skills/develop/references/roles/{gate-runner,worker,spec-reviewer}.md`
- `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`
- `plugins/dev-workflow/.claude-plugin/plugin.json`（バージョン bump。テスト S131 が merge-base からの bump を要求する）
- `tests/`（新規 bats スイート）
- 振る舞いへの影響は「エージェントの行動規約」。実行時のコード変更は無い
