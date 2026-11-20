# Tasks

行番号は仕様化時の HEAD `d188693f771cb72d149946b5ebce971e1b8769b5` の値。編集前に要件名と対象段落を読み直す。本体がこの change の R1 承認を記録先で確認し、同じ PR の develop の change に続けて着手する。

## 1. 守備範囲の配置と回帰テスト

- [x] 1.1 #1695 の配置検査のケース表に「memory-refresh スキルで承認と控えを取ってから整理する」の「`patches:` による分類の守備範囲は次のとおり。」で始まる段落の全文を追加する。要件を最初の Scenario で分け、本文に完全一致で 1 回・シナリオに 0 回を検査する。既存のケースと前の change の 2 ケースを保持し、`./scripts/test.sh openspec-specs-format` を移動前に実行して追加ケースを失敗理由として非 0 になることを確認する。触る範囲: tests/openspec-specs-format.bats:85-155（#1695 のケース表と境界検査）
- [x] 1.2 delta と同じく 1 段落を同じ要件の最初の Scenario の直前へ、全文を変えず移す。`./scripts/test.sh openspec-specs-format` が exit 0 となり、`git diff -- openspec/specs/dev-workflow-memory-refresh/spec.md` が 1 段落の移動と必要な空行だけで、要件名・全シナリオ・その他の文・過去の archive delta が保持されていることを確認する。触る範囲: openspec/specs/dev-workflow-memory-refresh/spec.md:62-97（承認・控え・整理の要件）
- [x] 1.3 `openspec show dev-workflow-memory-refresh --type spec --json` が exit 0 となり、対応する要件の `text` に対象段落の全文が 1 回、全 `requirements[].scenarios[].rawText` に 0 回であることを確認する（検証のみ）。触る範囲: openspec/specs/dev-workflow-memory-refresh/spec.md:62-97（守備範囲の CLI 上の帰属）

## 2. 両 change の統合検証

- [x] 2.1 `openspec/specs/*/spec.md` の各 capability に `openspec show <capability> --type spec --json` を実行し、全シナリオの `rawText` を #1696 の判断記録の条件（空行区切り、コードフェンス内と GIVEN / WHEN / THEN / AND / BUT の行・その折り返しを除外、単語境界付き MUST / SHALL）で再走査する。全 show が exit 0、規則段落の残りが 0 件であることを件数とともに報告する。新たな対象があれば本体へ戻す（検証のみ、全 spec が読み取り対象・archive は除外）。触る範囲: openspec/specs/dev-workflow-develop/spec.md:4306-4347（先行 change の 2 要件）、openspec/specs/dev-workflow-memory-refresh/spec.md:62-97（本 change の 1 要件）
- [ ] 2.2 `./scripts/test.sh` と `./scripts/lint.sh` を実行し、両方 exit 0 を確認する。コマンドが実行不可なら成功扱いせず、実行できないコマンドと理由を本体へ報告する（検証のみ）。触る範囲: scripts/test.sh:3-42（統一テストランナー）、scripts/lint.sh:3-33（統一 lint ランナー）
- [x] 2.3 `openspec validate move-memory-refresh-scope-to-requirement-text --type change --strict` と `openspec validate --specs --json` が exit 0、spec 検証の失敗が基準の 0 件から増えていないことを確認する（基準 99 passed / 0 failed。検証のみ）。触る範囲: openspec/changes/move-memory-refresh-scope-to-requirement-text/specs/dev-workflow-memory-refresh/spec.md:1-38（MODIFIED delta）、openspec/specs/dev-workflow-memory-refresh/spec.md:62-97（本 change の正本要件）
