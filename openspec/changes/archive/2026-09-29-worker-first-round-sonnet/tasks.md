## 1. 検証の準備（W。対象・実績・指示案は (1) の return に記録済み）

- [x] 1.1 対象 PR 3 件を確定する（本体が (1) の return の候補から選ぶ）。触る範囲: なし（本体の判断）
- [x] 1.2 再実行の W に渡す指示書を用意する（元の記録先の本文と同じ指示＋GitHub に書かない制約）。触る範囲: なし（本体が Agent 起動時に渡す）

## 2. 検証の再実行（本体）

- [x] 2.1 各 PR のマージ前の base から worktree を切り、W を `model: sonnet` で 1 件ずつ再実行する。触る範囲: なし（本体の操作）
- [x] 2.2 各再実行の W のトリップワイヤー発火有無・テスト結果（exit code）・subagent jsonl の `"model"` を集める。本体は再実行ごとに独立レビュアーを起動し（元のゲートと同じ指摘基準を渡し、指摘一覧をローカルのファイルで返させる）、severity が blocking かつ status が confirmed の件数を集計する。テストは各 PR の追加・変更テストと `bats plugins/dev-workflow/tests` の exit code を取る。証拠が欠けた項目は「同等」としない。触る範囲: なし

## 3. 記録（W）

- [x] 3.1 `plugins/dev-workflow/changes/605.md` を新規に書く: 対象 3 件・元 / 新の比較表（`| #<PR番号> |` で始まる行が 3 件以上）・model の証拠（コマンドと結果）・判定と根拠。触る範囲: plugins/dev-workflow/changes/605.md（新規）
- [x] 3.2 判定が「変えない」なら 4 を飛ばして 5 へ。判定が「変える」なら、この change の specs に既存 3 要件（役割の指示書は references/roles/ に分かれている／役割のモデルは事前分類と残量モードで決める／W と G は役割ごとの種別で起こす）を変える差分を足し、worker.md の表・SKILL.md の 86・240・246 行付近と一緒に示して、表を変える前に R1 の再レビューを受ける。触る範囲: openspec/changes/worker-first-round-sonnet/specs/dev-workflow-develop/spec.md

## 4. 表を変える場合のみ（TDD）

判定が「変えない」ため、4.1〜4.4 は対象外（条件不成立で実施しない）。チェックボックスは未チェックのまま残し、archive は未完了タスクを承知のうえで進める。

- [ ] 4.1 `model-escalation-policy.bats` の `pre-classification: the first-round column has no fable` を、表に `` `sonnet` `` があり `` `opus` `` が無いと assert する形に直し、先に落ちることを確かめる。触る範囲: plugins/dev-workflow/tests/model-escalation-policy.bats（該当テスト。着手時に grep で位置を確かめる）
- [ ] 4.2 worker.md の「重要実装の事前分類」表の「1 周目」列を `sonnet` にし、直後の「W の上限は `opus`」段落を、上限は `opus` のまま 1 周目の既定だけ下げる説明にする。触る範囲: plugins/dev-workflow/skills/develop/references/roles/worker.md:138-157（#610 で位置が動いていれば main を取り込んで確かめる）
- [ ] 4.3 SKILL.md の事前分類で W を `opus` にする記述（W の spawn の model 指定、役割表の W 行、W の既定の理由の段落）を、1 周目は `sonnet`・上限は `opus` の説明に合わせる。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:86、240、246（行番号は着手時に main を取り込んで確かめる）
- [ ] 4.4 README.md 14 行目付近の「事前分類に当たってもそこ止まり」と、`session-tripwires.sh` 103・110 行目付近の役割表の説明を合わせる。触る範囲: plugins/dev-workflow/README.md:14 付近、plugins/dev-workflow/scripts/session-tripwires.sh:103-110

## 5. 検査

- [x] 5.1 `bats plugins/dev-workflow/tests/model-escalation-policy.bats plugins/dev-workflow/tests/develop-roles.bats tests/injection-budget.bats` が exit 0。CI 相当の検査（`.github/workflows` の `run:`）を全部流す。`openspec validate worker-first-round-sonnet --strict` が exit 0。触る範囲: なし（実行のみ）
