# Tasks

行番号は dispatch HEAD `fd904b8` の案内。実装前に対象範囲を読み直す。計算器と手順は同じ change で実装し、別々に検証する。聖域・モデル別しきい値・上限値・`tests/injection-budget.txt` は変更しない。

## 1. 入力契約と消費見積もり

- [ ] 1.1 schema_version=1 の入力検査、正規化、JSON 出力と exit 0/1/2、出典付き係数設定を実装する。欠落／bool／負数／非有限／未知・循環依存／不正 repo・path／枠数と入力順不変をテストし、`python3 -m unittest discover -s plugins/dev-workflow/tests -p 'test_epic_granularity.py'` を通す。触る範囲: plugins/dev-workflow/scripts/epic-granularity.py（新規）、plugins/dev-workflow/references/epic-granularity-coefficients.json（新規）、plugins/dev-workflow/tests/test_epic_granularity.py（新規）
- [ ] 1.2 T/E/S/C、全文量の重複排除、変更行数の加算、両方の 0.8 境界、単独配置不能を実装する。F=1,000/L=100 の数値、境界ちょうど／1 超過、同じ path の最大量、別 repo の同名 path、設定差替え、不確かさと出典を同じ unittest で検証する。触る範囲: plugins/dev-workflow/scripts/epic-granularity.py（新規）、plugins/dev-workflow/references/epic-granularity-coefficients.json（新規）、plugins/dev-workflow/tests/test_epic_granularity.py（新規）
- [ ] 1.3 入力 JSON の完全な例、Read/Bash 文字換算、既存の実効上限／親の権限コメントから値と出典を渡す方法、係数と余裕の意味、exit code を必要時だけ読む正本に記す。掲載例を CLI に渡し exit 0 と期待する数値をテストする。触る範囲: plugins/dev-workflow/skills/develop/references/epic-granularity.md（新規）、plugins/dev-workflow/tests/test_epic_granularity.py（新規）、plugins/dev-workflow/scripts/subagent-context.sh:1-65（参照のみ）、plugins/dev-workflow/scripts/pr-token-budget.sh:1-60（参照のみ）

## 2. 梱包と W 空き枠

- [ ] 2.1 三つの分離境界、関係優先の併合と量詰め、子間 DAG、全項目一度だけの配置を実装する。別 repo／聖域混在／承認待ち、6 ファイル・多 capability の容量内併合、関係優先、A→B→C の循環防止、unplaced の保持を unittest で検証する。入力例と選択理由の読み方も正本に足す。触る範囲: plugins/dev-workflow/scripts/epic-granularity.py（新規）、plugins/dev-workflow/tests/test_epic_granularity.py（新規）、plugins/dev-workflow/skills/develop/references/epic-granularity.md（新規）
- [ ] 2.2 空き 0/1 ではまとめ、空き 2 以上だけ並列分離の代理 makespan を比較する。切片の再計上、同値時の少子優先、依存／共有 edit の除外、枠 snapshot と起動許可の区別を実装・文書化する。同じ fixture の slots だけを変える unittest で結果と理由を検証する。触る範囲: plugins/dev-workflow/scripts/epic-granularity.py（新規）、plugins/dev-workflow/tests/test_epic_granularity.py（新規）、plugins/dev-workflow/skills/develop/references/epic-granularity.md（新規）、plugins/dev-workflow/skills/develop/references/epic-worker-slots.md:1-5（参照のみ）

## 3. develop の分割手順と既存 issue の集約

- [ ] 3.1 Step C と epic.md の条件・作り方を計算結果基準へ変え、計算入力・出力と逸脱理由の記録を必須にする。worker/spec の分割説明も同じ参照先へ揃える。`bats plugins/dev-workflow/tests/epic-granularity-workflow.bats plugins/dev-workflow/tests/spec-decision-and-review.bats` で旧個数条件が強制分割に残らず、CLI 実行→記録→代表子作成の順序が読めることを検証する。触る範囲: plugins/dev-workflow/skills/develop/references/spec-decision.md:71-108、plugins/dev-workflow/skills/develop/references/epic.md:7-21、plugins/dev-workflow/skills/develop/references/roles/worker/spec.md:45-67、plugins/dev-workflow/skills/develop/references/epic-granularity.md（新規）、plugins/dev-workflow/tests/epic-granularity-workflow.bats（新規）、plugins/dev-workflow/tests/spec-decision-and-review.bats:1-120
- [ ] 3.2 規模超過を「増分を反映して再計算、容量超過／不明なら止まる」に揃える。template は短い条件と参照に留め、W の指示書も更新する。上記 workflow テストでファイル 6 個／項目増加 2 回だけでは分割しない契約を検証し、`bats plugins/dev-workflow/tests/tripwire-hook.bats tests/injection-budget.bats tests/develop-worker-stage-budget.bats` を通す。触る範囲: plugins/dev-workflow/templates/escalation-tripwires.md:18-38、plugins/dev-workflow/skills/develop/references/roles/worker/common.md:25-32、plugins/dev-workflow/skills/develop/references/epic-granularity.md（新規）、plugins/dev-workflow/tests/epic-granularity-workflow.bats（新規）
- [ ] 3.3 代表子と多対多の対応表、元 issue への参照、親の直接の子の付替え、外部依存の移設、進行中 issue の除外を正本に記す。親の入口から案内する。小さい手順 fixture で「元 A/B→代表 C」の起動対象が C だけ、C が nested にならないこと、着手済みと付替え失敗では起動しないことを workflow テストで検証する。触る範囲: plugins/dev-workflow/skills/develop/references/epic-granularity.md（新規）、plugins/dev-workflow/skills/develop/references/epic.md:15-39、plugins/dev-workflow/tests/epic-granularity-workflow.bats（新規）、plugins/dev-workflow/scripts/epic-state.sh:4-14（参照のみ）、plugins/dev-workflow/scripts/epic-dispatch.sh:2113-2155（参照のみ）
- [ ] 3.4 マージ後に元 issue を証拠付きで completed に精算する手順と、代表一件一回の進捗・精算待ち・親の実機確認を文書化する。既存 closed/done の読み方は維持する。workflow fixture で C 完了→A/B 精算でも増分 1、A→C/D は全 group 完了まで開放、元の閉鎖失敗から再試行しても二重計上しないことを検証する。触る範囲: plugins/dev-workflow/skills/develop/references/epic-granularity.md（新規）、plugins/dev-workflow/skills/develop/references/epic.md:54-56、plugins/dev-workflow/skills/develop/references/epic-loop.md:98-102、plugins/dev-workflow/tests/epic-granularity-workflow.bats（新規）、plugins/dev-workflow/scripts/epic-dispatch.sh:2113-2199（参照のみ）

## 4. 過去エピックへの適用と統合確認

- [ ] 4.1 #1701・#1732 の本文／子／マージ PR の作業を入力へ展開し、量と根拠・聖域境界・固定 W 枠を fixture に残す。各 JSON を CLI に渡し、全項目保存・境界・非循環・両容量を unittest で検証する。#1799 のログを再測定しない。触る範囲: plugins/dev-workflow/tests/fixtures/epic-granularity/epic-1701.json（新規）、plugins/dev-workflow/tests/fixtures/epic-granularity/epic-1732.json（新規）、plugins/dev-workflow/tests/test_epic_granularity.py（新規）
- [ ] 4.2 両 fixture の CLI 出力を保存し、元と計算後の子数・所属・依存・全子の T/E/S/C・実効／計画用上限と余裕・減らなければ理由・再実行コマンドと exit code を比較記録にまとめる。`python3 plugins/dev-workflow/scripts/epic-granularity.py --input plugins/dev-workflow/tests/fixtures/epic-granularity/epic-1701.json` と 1732 の同形コマンドが exit 0 で保存出力と一致することを検証する。触る範囲: plugins/dev-workflow/tests/fixtures/epic-granularity/epic-1701.expected.json（新規）、plugins/dev-workflow/tests/fixtures/epic-granularity/epic-1732.expected.json（新規）、plugins/dev-workflow/docs/epic-granularity-validation.md（新規）、plugins/dev-workflow/tests/test_epic_granularity.py（新規）
- [ ] 4.3 unittest と workflow Bats に加え、`bats tests/injection-budget.bats tests/develop-epic-scene-budget.bats tests/develop-worker-stage-budget.bats`、`openspec validate epic-granularity-planner --type change --strict` を通す。既存の場面別予算を超えたら対象段落を短くする。実装による変更記録を追加し、8 受け入れ条件と証拠の対応を記録する。触る範囲: plugins/dev-workflow/changes/1802.md（新規）、plugins/dev-workflow/docs/epic-granularity-validation.md（新規）、openspec/changes/epic-granularity-planner/tasks.md:1-32、tests/injection-budget.bats:1-1405（実行のみ）、tests/develop-epic-scene-budget.bats:1-358（実行のみ）、tests/develop-worker-stage-budget.bats:1-209（実行のみ）

## Workflow follow-up

- R1 の APPROVE 後に実装へ進む。実装＋verify の return 後、coordinator が finish 工程を指示する。
- archive・PR 作成・仕様宣言は finish 工程。今回の spec 工程では行わない。
