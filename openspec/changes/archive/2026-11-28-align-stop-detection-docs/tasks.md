## 1. 文書を実装の `>=` に揃える

- [x] 1.1 spec の要件 3 つ（デルタ spec のとおり）の「最後の入力（の時刻）より後」を「以降」に直す。触る範囲: openspec/specs/dev-workflow-develop/spec.md:2372-2400、openspec/specs/dev-workflow-develop/spec.md:2607-2620、openspec/specs/dev-workflow-develop/spec.md:5197-5205
- [x] 1.2 `parent-merge-criteria.md` の「作成時刻が最後の入力より後のもの」を「以降」に直す。触る範囲: plugins/dev-workflow/skills/develop/references/parent-merge-criteria.md:3

## 2. 読み替えの対象ファイルの数と列挙を実物に合わせる

- [x] 2.1 `channel.md` の「次の 11 個」の列挙から、AskUserQuestion に触れない `skills/develop/references/roles/worker/spec.md` を外し、数と列挙を一致させる。触る範囲: plugins/dev-workflow/skills/develop/references/channel.md:14-27

## 3. #1543 の残りの指摘を今の main と照合する

- [x] 3.1 P3-F2・P6-F4・P7-F5・P7-F7・P7-F8・P2-F7・P2-F8・P4-F8・P6-F1 を、`stop-judge.sh`・`epic-dispatch.sh` のコメント・`epic-stop.md` 手順 8・spec と 1 件ずつ照合する。直っているものは記録先に証拠（ファイルと行）を書いて済みにし、残るものだけ文を直す。触る範囲: plugins/dev-workflow/scripts/stop-judge.sh:1-30、plugins/dev-workflow/scripts/epic-dispatch.sh:78-135、plugins/dev-workflow/skills/develop/references/epic-stop.md:7、openspec/specs/dev-workflow-develop/spec.md:2372-2400

## 4. #1714 を bats で固定する

- [x] 4.1 通常の作業報告（`dependency_wait` が欠落か false）で `止まった理由: なし…` の発言を持つ子が、`wait --resolve --watch-stopped` で `stopped` を返さず judge を呼ばないテストを通す。あわせて `dependency_wait: true` の作業報告は `stopped` を返し judge を呼ばない境界のテストも置く（どちらも仕様づくりの段で追加し、今の main で通ることを確認済み）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:7859-7900
- [x] 4.2 spec の同じ秒の Scenario に対応する `stop-judge.bats` の既存テスト（`a record in the same second as the last input is this stop's record`）が通ることを確かめる。触る範囲: plugins/dev-workflow/tests/stop-judge.bats:501-508

## 5. 検証

- [x] 5.1 `bats plugins/dev-workflow/tests/epic-dispatch.bats`・`tests/develop-channel-mode.bats`・`stop-judge.bats` と `openspec validate align-stop-detection-docs --type change --strict` を通す
