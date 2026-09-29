## Why

worker.md の「重要実装の事前分類」表は、聖域パス・マージ権限・層間契約・課金/法務に当たる実装の 1 周目を `opus` と決めている。このリポはエージェント設定が製品なのでほぼ全実装が当たり、実装担当 W の Opus 消費が直近 30 日で約 $970 になっている。Sonnet 5.5（`claude-sonnet-5-5`）は Opus 5.5 の半額で、W は「確定した内容を落とす役」なので足りる可能性がある。ただし根拠なく表を変えると、失敗 1 周のコスト（再実装・再レビュー・ゲート往復）が単価差を上回りうる。過去 PR の再実行で比べてから決める。

## What Changes

- 過去にマージされた PR 3 件を、マージ前の base から W を `model: sonnet` で再実行し、Opus 側の実績（テスト・ゲート指摘件数・トリップワイヤー発火）と比べる。再実行は本体が行い、結果を受けて W が記録する
- 検証の記録 `plugins/dev-workflow/changes/605.md` を新規に置く（対象 3 件・比較表・Sonnet 5.5 で動いた証拠・判定と根拠）
- 判定が「表を変える」のときだけ、事前分類表の「1 周目」列を `sonnet` にし、関連するテスト・説明文を合わせる（上限は `opus` のまま）。「変えない」のときは記録だけで閉じ、既存 spec は変えない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: W の 1 周目モデルを下げる判断は、過去 PR の再実行による比較記録に基づくという要件を足す。検証が合格して表を変える場合は、この change に「事前分類表の 1 周目列の要件」を変える差分を追加してから archive する

## Impact

- 常に: `plugins/dev-workflow/changes/605.md`（新規）、`openspec/specs/dev-workflow-develop/spec.md`
- 表を変える場合のみ: `plugins/dev-workflow/skills/develop/references/roles/worker.md`、`plugins/dev-workflow/tests/model-escalation-policy.bats`、`plugins/dev-workflow/README.md`、`plugins/dev-workflow/scripts/session-tripwires.sh`
- 並行中の PR #610 が worker.md を索引・共通・段のファイルに分けるため、表を変える段階で衝突しうる。着手時に main を取り込んで表の現在位置を確かめる
