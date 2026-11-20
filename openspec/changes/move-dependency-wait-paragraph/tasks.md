# Tasks

行番号は main spec の直接編集を戻した仕様化時点の値。実装前に要件名と対象段落を読み直す。R1 の APPROVE を記録先 #1725 で確認してから apply 段に進む。一般配置検査の実装は基準 HEAD `f4ffa2591aacd02a92d66dc8c4fe64d3b02b6b1c` に既にあるため、検査の再実装は不要。

## 1. archive 前の配置確認

- [ ] 1.1 `bats tests/openspec-specs-format.bats` を実行し、一般配置検査だけが対象段落1件（`dev-workflow-develop/spec.md:5702`）を検出して失敗し、他の7テストが成功することを確認する。失敗を消すために検査の除外条件を変えない。触る範囲: tests/openspec-specs-format.bats:18-61（既存の一般配置検査、検証のみ）、openspec/specs/dev-workflow-develop/spec.md:5678-5702（依存待ちの要件、検証のみ）
- [ ] 1.2 delta から `## MODIFIED Requirements` を除いた要件全文が、基準 HEAD の同じ要件全文とバイト単位で一致し、本文の対象段落が1回・全5シナリオが保持されていることを確認する。`openspec validate move-dependency-wait-paragraph --type change --strict` が exit 0 であることも確認する。触る範囲: openspec/changes/move-dependency-wait-paragraph/specs/dev-workflow-develop/spec.md:1-27（要件全文の MODIFIED delta、検証のみ）

## Workflow follow-up

- apply 段で `openspec archive move-dependency-wait-paragraph --yes` を実行して delta を main spec に反映する。`--skip-specs` は使わない。差分が対象1段落と空行の移動だけであり、反映後の main spec が基準 HEAD の同ファイルと一致することを確認する。触る範囲: openspec/specs/dev-workflow-develop/spec.md:5678-5702（対象要件）、openspec/changes/move-dependency-wait-paragraph/（archive への移動）
- `bats tests/openspec-specs-format.bats` が exit 0（8件成功）になることを確認する。`openspec show dev-workflow-develop --type spec --json` の対象要件の `text` に対象段落全文が1回、全シナリオの `rawText` に0回であることも確認する。触る範囲: tests/openspec-specs-format.bats:18-61（検証のみ）、openspec/specs/dev-workflow-develop/spec.md:5678-5702（検証のみ）
- `./scripts/test.sh` と `./scripts/lint.sh` を実行し、終了コードを報告する。全体テストが未完了なら合格扱いにしない。PR #1734 の古い「仕様化しない／archive なし」の説明と仕様宣言を、実際の判断・archive・検証結果に合わせて更新する。触る範囲: scripts/test.sh:3-42（検証のみ）、scripts/lint.sh:3-33（検証のみ）、PR #1734 本文
