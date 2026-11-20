# Tasks

行番号は仕様化時の HEAD `d188693f771cb72d149946b5ebce971e1b8769b5` の値。編集前に要件名と対象段落を読み直す。本体がこの change の R1 承認を記録先で確認してから着手する。

## 1. 規則段落の配置と回帰テスト

- [x] 1.1 #1695 の配置検査のケース表に、子の返事の要件の「根拠には、2026-10-23 の子のログで、」と親の返事の要件の「親の状態はエピックと子 issue のコメント・依存グラフ・子の状態記録から復元できる」で始まる各段落の全文を追加する。要件を最初の Scenario で分け、本文に完全一致で 1 回・シナリオに 0 回を検査する。`./scripts/test.sh openspec-specs-format` を移動前に実行し、追加した 2 ケースを失敗理由として非 0 になることを確認する。触る範囲: tests/openspec-specs-format.bats:85-155（#1695 のケース表と境界検査）
- [x] 1.2 delta と同じく 2 段落をそれぞれ同じ要件の最初の Scenario の直前へ、全文を変えず移す。`./scripts/test.sh openspec-specs-format` が exit 0 となり、`git diff -- openspec/specs/dev-workflow-develop/spec.md` が 2 段落の移動と必要な空行だけで、要件名・全シナリオ・その他の文・過去の archive delta が保持されていることを確認する。触る範囲: openspec/specs/dev-workflow-develop/spec.md:4306-4347（子・親の待機後の返事の 2 要件）
- [x] 1.3 `openspec show dev-workflow-develop --type spec --json` が exit 0 となり、対応する 2 要件の `text` に各段落の全文が各 1 回、全 `requirements[].scenarios[].rawText` に各 0 回であることを確認する（検証のみ）。触る範囲: openspec/specs/dev-workflow-develop/spec.md:4306-4347（2 段落の CLI 上の帰属）

## 2. 統合検証

- [ ] 2.1 `./scripts/test.sh` と `./scripts/lint.sh` を実行し、両方 exit 0 を確認する。コマンドが実行不可なら成功扱いせず、実行できないコマンドと理由を本体へ報告する（検証のみ）。触る範囲: scripts/test.sh:3-42（統一テストランナー）、scripts/lint.sh:3-33（統一 lint ランナー）
- [x] 2.2 `openspec validate move-develop-idle-rules-to-requirement-text --type change --strict` と `openspec validate --specs --json` が exit 0、spec 検証の失敗が基準の 0 件から増えていないことを確認する（基準 99 passed / 0 failed。検証のみ）。触る範囲: openspec/changes/move-develop-idle-rules-to-requirement-text/specs/dev-workflow-develop/spec.md:1-44（MODIFIED delta）、openspec/specs/dev-workflow-develop/spec.md:4306-4347（本 change の正本要件）
