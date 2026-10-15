## 1. auto-merge.yml（展開先と原本を同じに直す。差は MERGE_CONDITION の値だけ）

- [ ] 1.1 `SACRED` の直後に、マーカー `# >>> merge-condition-paths` 〜 `# <<< merge-condition-paths` で囲んだ `MERGE_CONDITION` を足す。展開先は `^\.github/workflows/|^plugins/dev-workflow/skills/pr-review-gate/|^plugins/dev-workflow/templates/auto-merge/`、原本は `^\.github/workflows/`（リポ固有のマージ条件はこのマーカーの間に足す旨をコメントに書く）。`tests/injection-budget.txt` は入れない。触る範囲: .github/workflows/auto-merge.yml:160-188（sacred-paths と BLOCKING_LABELS の定義）、plugins/dev-workflow/templates/auto-merge/.github/workflows/auto-merge.yml:153-181
- [ ] 1.2 ジョブの `if:` を、labeled で付いたラベルが `agent-review:passed` か `parent-merge-approved` のときに走る形にする。`on: pull_request_target: types` は labeled のまま変えない。触る範囲: .github/workflows/auto-merge.yml:107-112、plugins/dev-workflow/templates/auto-merge/.github/workflows/auto-merge.yml:107-112
- [ ] 1.3 `human-merge` と同じ形で `parent-merge-approved` ラベルを `gh label create` で作っておく（失敗しても止めない既存の書き方に合わせる）。触る範囲: .github/workflows/auto-merge.yml:190-192、plugins/dev-workflow/templates/auto-merge/.github/workflows/auto-merge.yml:183-185
- [ ] 1.4 PR ごとのループで、見送りラベルの判定より前に変更ファイルの一覧（filename と previous_filename）を取り、マーカー `# >>> parent-merge-judgment` 〜 `# <<< parent-merge-judgment` で囲んだ判定で `PARENT_OK` を求める。判定の中身: `HEAD_SHA` が 40 桁の 16 進かを先に確かめる／コメントは `gh api` で JSON のまま取り、`jq --arg` で `author_association` が OWNER・MEMBER・COLLABORATOR、1 行目がちょうど `親のマージ判断: 可`、ある行がちょうど `親が見た HEAD: $HEAD_SHA` のものに絞り、その URL を `PARENT_COMMENT_URL` に控える／`parent-merge-approved` ラベルがある／付いている見送りラベルが `human-merge` だけ／変更ファイルのどれかが `SACRED` に一致する／どれも `MERGE_CONDITION` に一致しない。取得の失敗はすべて `PARENT_OK=false`。触る範囲: .github/workflows/auto-merge.yml:259-303（合格の HEAD 束縛 → 見送りラベル判定 → 聖域判定）、plugins/dev-workflow/templates/auto-merge/.github/workflows/auto-merge.yml:252-296
- [ ] 1.5 見送りラベルの判定で、`PARENT_OK` が真のときだけ `human-merge` を見送りの理由から外す。聖域判定で、`PARENT_OK` が真のときだけ `human-merge` を付けて continue する代わりに、親の判断で進む旨をログに 1 行出して次へ進む（`DRY_RUN` でも同じ判定をしてログに出す）。既存の変更ファイル取得（sacred-paths-jq）は 1.4 で先に取った一覧を使う形にし、二度取らない。触る範囲: .github/workflows/auto-merge.yml:267-303、plugins/dev-workflow/templates/auto-merge/.github/workflows/auto-merge.yml:260-296
- [ ] 1.6 マージ直前の取り直し（pre-merge-recheck）で `parent-merge-judgment` の判定をやり直し、`PARENT_OK` が偽なら `human-merge` を見送りの理由に数える。判定の重複を避けるため、1.4 の判定はシェル関数として定義し、初回と取り直しの両方から呼ぶ。触る範囲: .github/workflows/auto-merge.yml:336-392、plugins/dev-workflow/templates/auto-merge/.github/workflows/auto-merge.yml:329-385
- [ ] 1.7 マージ後の `auto-merged` コメントに、`PARENT_OK` で進んだときだけ「親の判断で `human-merge` を外した」ことと `PARENT_COMMENT_URL` を書き足す（それ以外の PR のコメントは変えない）。触る範囲: .github/workflows/auto-merge.yml:406-409、plugins/dev-workflow/templates/auto-merge/.github/workflows/auto-merge.yml:399-402
- [ ] 1.8 冒頭のコメント（条件の一覧）に、親の判断の印で `human-merge` を外せる条件を足す。触る範囲: .github/workflows/auto-merge.yml:1-60、plugins/dev-workflow/templates/auto-merge/.github/workflows/auto-merge.yml:1-60

## 2. 静的検査（test-auto-merge-workflow.sh。展開先と原本に同じ検査を足す）

- [ ] 2.1 `MERGE_CONDITION` の must-match（`.github/workflows/ci.yml`。展開先は加えて `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`・`plugins/dev-workflow/templates/auto-merge/README.md`）と must-not-match（`rules/example.md`・`CLAUDE.md`・`.claude/settings.json`。展開先は加えて `plugins/dev-workflow/hooks/x.sh`・`tests/injection-budget.txt`）を足す。触る範囲: scripts/test-auto-merge-workflow.sh:79-139、plugins/dev-workflow/templates/auto-merge/scripts/test-auto-merge-workflow.sh:69-117
- [ ] 2.2 `MERGE_CONDITION` の must-match がすべて `SACRED` にも一致すること（部分集合）を検査する。触る範囲: scripts/test-auto-merge-workflow.sh:79-139、plugins/dev-workflow/templates/auto-merge/scripts/test-auto-merge-workflow.sh:69-117
- [ ] 2.3 ジョブの `if:` が `parent-merge-approved` を受けること、`pull_request_target` のイベント種が labeled だけのままであることを検査する。触る範囲: scripts/test-auto-merge-workflow.sh:186-258、plugins/dev-workflow/templates/auto-merge/scripts/test-auto-merge-workflow.sh:164-236
- [ ] 2.4 `parent-merge-judgment` のブロックが `親が見た HEAD:` を使い、`対象 HEAD:` を含まないこと（親のコメントが合格の HEAD 束縛を満たさないこと）と、pre-merge-recheck の中でも判定が呼ばれていることを検査する。触る範囲: scripts/test-auto-merge-workflow.sh:506-576・674-692、plugins/dev-workflow/templates/auto-merge/scripts/test-auto-merge-workflow.sh:407-477・575-593

## 3. 挙動のテスト（automerge-templates.bats）

- [ ] 3.1 マーカー一覧のテストに `merge-condition-paths` と `parent-merge-judgment` を足す。触る範囲: plugins/dev-workflow/tests/automerge-templates.bats:69-74
- [ ] 3.2 見送りラベルのテストの近くに、`human-merge` 以外の 3 つの見送りラベルが `PARENT_OK` で外れないことを静的に固定するテストを足す。触る範囲: plugins/dev-workflow/tests/automerge-templates.bats:131-137
- [ ] 3.3 `parent-merge-judgment` のブロックを取り出し、スタブの `gh`（ラベル・コメント JSON・変更ファイル JSON を fixture で返す）で動かすヘルパーを、revert script のテストと同じ形で足す。触る範囲: plugins/dev-workflow/tests/automerge-templates.bats:333-370
- [ ] 3.4 spec のシナリオごとにテストを 1 つ足す: 聖域だけ＋印あり → 真／マージ条件のパス（rename 元を含む）→ 偽／HEAD 不一致 → 偽／他の見送りラベル併存 → 偽／聖域非接触 → 偽／ラベルだけ・コメントだけ・投稿者 NONE か CONTRIBUTOR → 偽／コメント取得の失敗・HEAD が 40 桁の 16 進でない → 偽／マージ直前に印のラベルが外れた → 偽。触る範囲: plugins/dev-workflow/tests/automerge-templates.bats:370-416（revert script のテストの後ろ）
- [ ] 3.5 `bats plugins/dev-workflow/tests/automerge-templates.bats` と、展開先・原本の `scripts/test-auto-merge-workflow.sh` が通ることを確かめる。触る範囲: なし（実行のみ）

## 4. 運用ガイドと README

- [ ] 4.1 展開先と原本の `docs/auto-merge.md` に、`human-merge` を外せる 4 つの条件、`MERGE_CONDITION` のパスと `SACRED` との関係、印の書式（`parent-merge-approved` ラベルと `親のマージ判断: 可`・`親が見た HEAD:` の行）、他の見送りラベルと他の条件はそのまま効くこと、マージされないときの調べ方を書く。「マージの実行権は常に自動マージの処理の側」の原則は変えない。触る範囲: docs/auto-merge.md:14-32・92-95・99-143・260-282、plugins/dev-workflow/templates/auto-merge/docs/auto-merge.md:14-32・92-95・99-141・237-262
- [ ] 4.2 原本の README の差し替え必須の表に `merge-condition-paths`（`MERGE_CONDITION`）を足し、見出しの点数を合わせる。bats の README テストに `merge-condition-paths` の grep を足す。触る範囲: plugins/dev-workflow/templates/auto-merge/README.md:37-45、plugins/dev-workflow/tests/automerge-templates.bats:81-88

## 5. 変更の記録

- [ ] 5.1 変更の記録を書く（何を変えたか・なぜ・この PR はマージ条件に触れるので主がマージすること・原本を使う他のリポは展開し直すまで経路を持たないこと）。触る範囲: plugins/dev-workflow/changes/1030.md（新規）
