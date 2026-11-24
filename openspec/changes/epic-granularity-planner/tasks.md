# Tasks

既存タスクの行番号は初回 dispatch HEAD `fd904b8`、今回更新した 1.1〜1.3・4.1〜4.3 の行番号は差戻し dispatch HEAD `38ce3fdd2e4a4b49a777d5d2d91d1b33e09aebca` の案内。実装前に対象範囲を読み直す。計算器と手順は同じ change で実装し、別々に検証する。#1799 の結論以外の係数を作らず、既存の 0.8 政策値・聖域・モデル別しきい値・上限値・#1800 の範囲・`tests/injection-budget.txt` は変更しない。既存の循環防止・境界テストも維持する。

## 1. 入力契約と消費見積もり

- [ ] 1.1 `validate()` と読取単位の正規化を修正し、schema_version=1 の files[] に必須の read_id・read_scope を追加する。path/access を維持し、入力全体の同一 (repo, path, read_id) の read_scope または tokens が矛盾すれば exit 1 にする。欠落／空文字／bool／負数／非有限／未知・自己・循環依存／不正 repo・path／枠数の拒否、JSON 出力と exit 0/1/2、出典付き設定検査を維持し、読取キーを含む files・項目・依存の入力順不変をテストする。申告範囲の意味や実物は CLI で照合しない。触る範囲: plugins/dev-workflow/scripts/epic-granularity.py:65-132（validate）、plugins/dev-workflow/tests/test_epic_granularity.py:17-125
- [ ] 1.2 `estimate()` を最大全文量から子内の読取キーごとの tokens の和へ変更する。同一出力 1,000 tokens の共有で F=1,000/L=100 の既存 T/E/S、同じ path の別出力 1,000＋2,000 で F=3,000、部分的に重なる別出力・同じ出力の別 read_id での再取得の加算、別 repo の同名 path をテストする。T/E/S の係数・C の式・変更行数の加算・両方の 0.8 境界・設定差替え・不確かさと出典を維持し、保持出力を F と追加保持量に二重計上しない。単独超過は exit 2 / unplaced とし、超過へ寄与した path/read_id/読取量も診断する。「全文 120,000 超だが必要読取量と C/S が収まる例」と「必要な一つの読取出力自体が 120,000 超で exit 2 の例」を別テストにし、起動分等を含む C だけが超える例、境界ちょうど／1 超過、既存の循環防止も維持する。触る範囲: plugins/dev-workflow/scripts/epic-granularity.py:139-315（estimate・超過診断・出力）、plugins/dev-workflow/tests/test_epic_granularity.py:55-210
- [ ] 1.3 正本の入力例、F/C の説明、配置不能、増分更新を予定読取範囲と出力量の契約へ修正する。read_id/read_scope、同一出力共有と別出力加算、Read 0.77／Bash 0.65 の切上げ換算、source の revision・範囲・出力文字数・換算方法、保持出力との二重計上防止を記す。既存の実効上限／親の権限コメントから値と出典を渡す方法、係数・余裕の意味は維持し、計画上の仮定を過去の実測や検証済み精度とは呼ばない。再入力は必要情報を保存した作業・読取範囲・依存の再設計後だけとし、名目上の分割・tokens の切詰めを禁じ、分離できなければ未完了で返す。増分は全文量でなく読む範囲・出力量・変更行数・保持出力を更新して再計算する。掲載例を CLI に渡し exit 0 と既存の期待数値を検証する。触る範囲: plugins/dev-workflow/skills/develop/references/epic-granularity.md:5-64、plugins/dev-workflow/tests/test_epic_granularity.py:212-217、plugins/dev-workflow/scripts/subagent-context.sh:1-65（参照のみ）、plugins/dev-workflow/scripts/pr-token-budget.sh:1-60（参照のみ）

## 2. 梱包と W 空き枠

- [ ] 2.1 三つの分離境界、関係優先の併合と量詰め、子間 DAG、全項目一度だけの配置を実装する。別 repo／聖域混在／承認待ち、6 ファイル・多 capability の容量内併合、関係優先、A→B→C の循環防止、unplaced の保持を unittest で検証する。入力例と選択理由の読み方も正本に足す。触る範囲: plugins/dev-workflow/scripts/epic-granularity.py（新規）、plugins/dev-workflow/tests/test_epic_granularity.py（新規）、plugins/dev-workflow/skills/develop/references/epic-granularity.md（新規）
- [ ] 2.2 空き 0/1 ではまとめ、空き 2 以上だけ並列分離の代理 makespan を比較する。切片の再計上、同値時の少子優先、依存／共有 edit の除外、枠 snapshot と起動許可の区別を実装・文書化する。同じ fixture の slots だけを変える unittest で結果と理由を検証する。触る範囲: plugins/dev-workflow/scripts/epic-granularity.py（新規）、plugins/dev-workflow/tests/test_epic_granularity.py（新規）、plugins/dev-workflow/skills/develop/references/epic-granularity.md（新規）、plugins/dev-workflow/skills/develop/references/epic-worker-slots.md:1-5（参照のみ）

## 3. develop の分割手順と既存 issue の集約

- [ ] 3.1 Step C と epic.md の条件・作り方を計算結果基準へ変え、計算入力・出力と逸脱理由の記録を必須にする。worker/spec の分割説明も同じ参照先へ揃える。`bats plugins/dev-workflow/tests/epic-granularity-workflow.bats plugins/dev-workflow/tests/spec-decision-and-review.bats` で旧個数条件が強制分割に残らず、CLI 実行→記録→代表子作成の順序が読めることを検証する。触る範囲: plugins/dev-workflow/skills/develop/references/spec-decision.md:71-108、plugins/dev-workflow/skills/develop/references/epic.md:7-21、plugins/dev-workflow/skills/develop/references/roles/worker/spec.md:45-67、plugins/dev-workflow/skills/develop/references/epic-granularity.md（新規）、plugins/dev-workflow/tests/epic-granularity-workflow.bats（新規）、plugins/dev-workflow/tests/spec-decision-and-review.bats:1-120
- [ ] 3.2 規模超過を「増分を反映して再計算、容量超過／不明なら止まる」に揃える。template は短い条件と参照に留め、W の指示書も更新する。上記 workflow テストでファイル 6 個／項目増加 2 回だけでは分割しない契約を検証し、`bats plugins/dev-workflow/tests/tripwire-hook.bats tests/injection-budget.bats tests/develop-worker-stage-budget.bats` を通す。触る範囲: plugins/dev-workflow/templates/escalation-tripwires.md:18-38、plugins/dev-workflow/skills/develop/references/roles/worker/common.md:25-32、plugins/dev-workflow/skills/develop/references/epic-granularity.md（新規）、plugins/dev-workflow/tests/epic-granularity-workflow.bats（新規）
- [ ] 3.3 代表子と多対多の対応表、元 issue への参照、親の直接の子の付替え、外部依存の移設、進行中 issue の除外を正本に記す。親の入口から案内する。小さい手順 fixture で「元 A/B→代表 C」の起動対象が C だけ、C が nested にならないこと、着手済みと付替え失敗では起動しないことを workflow テストで検証する。再利用は元 issue の全項目が単一 group に収まり他 group が参照しない場合だけとし、元 A だけを容量で二分した両 group には A を再利用せず別々の代表 C/D を新設し、起動・監視も C/D だけにするケースを同じテストに加える。触る範囲: plugins/dev-workflow/skills/develop/references/epic-granularity.md（新規）、plugins/dev-workflow/skills/develop/references/epic.md:15-39、plugins/dev-workflow/tests/epic-granularity-workflow.bats（新規）、plugins/dev-workflow/scripts/epic-state.sh:4-14（参照のみ）、plugins/dev-workflow/scripts/epic-dispatch.sh:2113-2155（参照のみ）
- [ ] 3.4 マージ後に元 issue を証拠付きで completed に精算する手順と、代表一件一回の進捗・精算待ち・親の実機確認を文書化する。既存 closed/done の読み方は維持する。workflow fixture で C 完了→A/B 精算でも増分 1、元 A だけの容量分割で新設した C/D の各 PR の Closes がそれぞれの代表だけを指し、C 完了時は A を開いたまま、D 完了後に全条件の証拠を確認して A を精算し、親の増分は C/D の計 2 件だけになること、元の閉鎖失敗から再試行しても二重計上しないことを検証する。触る範囲: plugins/dev-workflow/skills/develop/references/epic-granularity.md（新規）、plugins/dev-workflow/skills/develop/references/epic.md:54-56、plugins/dev-workflow/skills/develop/references/epic-loop.md:98-102、plugins/dev-workflow/tests/epic-granularity-workflow.bats（新規）、plugins/dev-workflow/scripts/epic-dispatch.sh:2113-2199（参照のみ）

## 4. 過去エピックへの適用と統合確認

- [ ] 4.1 #1701 の元 3 子と #1732 本文の元 21 子をすべて対応表に残し、#1799 の測定 PR だけに縮めない。子本文・結論、対応するすべてのマージ PR、base/head SHA、変更ファイル、追加・削除行数を固定資料に保存する。各 PR のファイル別 diff 出力を読取範囲の初期案とし、必要な関数・仕様節・共通手順の周辺読取を追加する。追加・削除・コンテキスト・ヘッダーを含む出力文字列を固定して Bash 0.65 で切上げ換算し、read_id/read_scope と source（revision・範囲・出力文字数・換算方法）から F を検算可能にする。L は追加＋削除だけを使い、行数・ファイル数から F の係数を作らない。patch 欠落・打切りを空文字や 0 にせず、完全な diff または必要範囲を取得できなければ未完了とする。PR のない調査・実機検証・不要判定も作業と根拠、必要情報・保持出力を入力に残す。両 fixture は比較用仮定として起動 40,000・reserve 10,000 を共通使用でき、追加保持 0 は reserve の扱う内容を説明できる場合だけとする。W 枠は max_parallel=2, occupied=1、文脈上限は出典付き実効値、累計 60M は確認できる既存権限だけとし、通すために付与しない。聖域・承認待ち・別 repo の境界を保存し、当時の実読取量・最大文脈の復元とは呼ばず #1799 のログも再測定しない。触る範囲: plugins/dev-workflow/tests/fixtures/epic-granularity/epic-1701.json（新規）、plugins/dev-workflow/tests/fixtures/epic-granularity/epic-1732.json（新規）、plugins/dev-workflow/tests/fixtures/epic-granularity/ 配下の出力量検算用固定資料（新規）、plugins/dev-workflow/tests/test_epic_granularity.py:219-245
- [ ] 4.2 両 fixture の期待 JSON と、元 3 子／21 子から全項目への対応・計算後の所属と子数・依存・固定 W 枠・全子の T/E/S/C・実効／計画用上限と余裕・仮定・不確かさ・再実行コマンドと exit code を保存する。「GitHub の実データから構成した、読取計画の仮定付き再計画」と明記し、当時の消費・上限遵守の実証とは主張しない。子数の減少自体は必須にせず減らなければ理由を残す。各入力を CLI に渡して exit 0 と期待 JSON との一致を unittest で検証し、全項目が一度だけ保存され、境界・依存の保存と非循環・全子の両容量の余裕を確認する。配置不能なら成功扱いせず、必要情報を保存した作業・読取範囲・依存の再設計後に再検証する。触る範囲: plugins/dev-workflow/tests/fixtures/epic-granularity/epic-1701.expected.json（新規）、plugins/dev-workflow/tests/fixtures/epic-granularity/epic-1732.expected.json（新規）、plugins/dev-workflow/docs/epic-granularity-validation.md（新規）、plugins/dev-workflow/tests/test_epic_granularity.py:219-245
- [ ] 4.3 下記の R1 承認・実装修正後の検査をすべて exit 0 で通す。不正入力 exit 1・配置不能 exit 2 と履歴出力の期待 JSON 一致は unittest 内で確認する。workflow Bats による入力・増分・配置不能の手順検査も更新し、既存の循環防止・境界テストと場面別予算を維持する。予算を超えたら対象段落を短くし、予算ファイルは緩めない。最終変更の記録と 8 受け入れ条件・証拠の対応を残す。触る範囲: plugins/dev-workflow/tests/epic-granularity-workflow.bats:1-99、plugins/dev-workflow/changes/1802.md（新規）、plugins/dev-workflow/docs/epic-granularity-validation.md（新規）、openspec/changes/epic-granularity-planner/tasks.md:1-60、tests/injection-budget.bats:1-1405（実行のみ）、tests/develop-epic-scene-budget.bats:1-358（実行のみ）、tests/develop-worker-stage-budget.bats:1-209（実行のみ）

今回の仕様差分で行う検査（期待 exit は各 0）:

```sh
OPENSPEC_TELEMETRY=0 openspec validate epic-granularity-planner --type change --strict
git diff --check
```

R1 承認・実装修正後の検査（期待 exit は各 0）:

```sh
python3 -B -m unittest discover -s plugins/dev-workflow/tests -p test_epic_granularity.py -v
python3 -B plugins/dev-workflow/scripts/epic-granularity.py --input plugins/dev-workflow/tests/fixtures/epic-granularity/epic-1701.json
python3 -B plugins/dev-workflow/scripts/epic-granularity.py --input plugins/dev-workflow/tests/fixtures/epic-granularity/epic-1732.json
bats plugins/dev-workflow/tests/epic-granularity-workflow.bats
bats tests/injection-budget.bats tests/develop-epic-scene-budget.bats tests/develop-worker-stage-budget.bats
OPENSPEC_TELEMETRY=0 openspec validate epic-granularity-planner --type change --strict
git diff --check
```

## Workflow follow-up

- 今回は spec・design・tasks の差分だけを作る。fresh R1 の差分再レビューで APPROVE が記録された後、coordinator の指示で実装修正へ進む。実装＋verify の return 後、coordinator が finish 工程を指示する。
- archive・PR 作成・仕様宣言は finish 工程。今回の spec 工程では行わない。
