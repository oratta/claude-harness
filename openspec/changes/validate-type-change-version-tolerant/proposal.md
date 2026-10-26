## Why

文言合わせの通し方（proposal.md の無い change）の検証で、W の指示書と `dev-workflow-develop` の Requirement は「`--type change` を付けない `openspec validate <change> --strict` は change を見つけられず `Unknown item` で終了コード 1 になる」「`openspec validate --changes --strict` はこの change を検査せずに終了コード 0 を返す」と書いている。しかし openspec 1.14.1 で実測すると、delta だけの change は `--type change` が無くても `Change '<name>' is valid`・終了コード 0 になり、`--changes --strict` もその change を検査して合格にする。そのため `plugins/dev-workflow/tests/spec-wording-sync-light-path.bats` の「openspec CLI: a change with only a delta spec needs --type change to validate」が 1.14.1 で落ちる（#1269。CI には openspec CLI が無く skip されるので CI では見えない）。挙動が版で変わる以上、指示書とテストは版ごとの挙動に依存しない書き方にする。

## What Changes

- `dev-workflow-develop` の Requirement「W の仕様化経路は openspec CLI だけで進める」の文言合わせの段落を、`--type change` を付ける指示は MUST のまま残し、理由を「付けない形の結果は openspec の版で変わる（古い版は change を見つけられず `Unknown item` で終了コード 1、1.14.1 は change として検証して終了コード 0）。名前の曖昧さを避け版によらず同じ結果にするため付ける」に直す。`--changes --strict` についての断定も、版によって検査しない場合があるので使わない、に直す
- 同 Requirement のシナリオ「proposal.md の無い change を名前だけで検証する」を、`--type change` を付けると版によらず終了コード 0 で、付けない形の結果は版で違う、という内容に直す
- `worker/implement.md`（文言合わせの通し方の場合）と `worker/spec.md`（文言合わせの通し方を当てた場合）の括弧書きを同じ内容に直す
- `tests/spec-wording-sync-light-path.bats` の実測テストを、`--type change` 付きは終了コード 0 を必須とし、付けない形は「終了コード 0」か「`Unknown item` と終了コード 1」のどちらかなら通す形に直す。文言を見るテストは新しい文言に合わせる

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-develop`: Requirement「W の仕様化経路は openspec CLI だけで進める」の文言合わせの段落と、シナリオ「proposal.md の無い change を名前だけで検証する」

## Impact

- `plugins/dev-workflow/skills/develop/references/roles/worker/implement.md`
- `plugins/dev-workflow/skills/develop/references/roles/worker/spec.md`
- `plugins/dev-workflow/tests/spec-wording-sync-light-path.bats`
- `openspec/specs/dev-workflow-develop/spec.md`（archive で反映）
