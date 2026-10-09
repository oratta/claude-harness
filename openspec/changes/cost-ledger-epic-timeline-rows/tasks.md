## 1. 実装前の確認

- [ ] 1.1 変更の前の `gh` の回数と hook 1 回の所要時間を、`design.md` の実測と同じ手順（`gh` を包む stub で回数と時間を記録、書き込みは握りつぶす）で取り直し、PR 本文の「変更前」に書く。子なしの issue のコメント（期待 3 回）とクローズ（期待 4 回）。触る範囲: なし（計測のみ）

## 2. timeline（`cost_ledger.py`）

- [ ] 2.1 `build_parser` の `timeline` に `--child-issue`（複数・整数）と `--child-pr`（複数）を足す。`--issue` と一緒にだけ渡せる検査と、値の形の検査（`--child-pr` は `parse_closing_prs()` を使う）を `cmd_timeline` に足し、崩れていれば何も出さず終了コード 2。`ISSUE_RE` には触らない。触る範囲: plugins/cost-ledger/scripts/cost_ledger.py:2964-2986（`build_parser` の timeline）、plugins/cost-ledger/scripts/cost_ledger.py:2628-2660（`cmd_timeline` の入口の検査）
- [ ] 2.2 `cmd_timeline` で `--child-issue` があるとき、区間をエピック自身と子孫の番号の集合でまとめて読み（`epic_rows()` と同じ。台帳の差分の追記は 1 回）、PR の分は `--child-pr` と `--closing-pr` のヘッドブランチをまとめて読む。`issue_combined_total()` を、区間の行が複数 issue 分でも 1 行 1 回で数えるように広げる。節目の行の累計をこの合計にし、1 行目の帰属の種別を `子 issue 込み` にする。触る範囲: plugins/cost-ledger/scripts/cost_ledger.py:2497-2521（`issue_combined_total`）、plugins/cost-ledger/scripts/cost_ledger.py:2524-2541（`epic_rows`）、plugins/cost-ledger/scripts/cost_ledger.py:2663-2705（`cmd_timeline` の集計と出力）
- [ ] 2.3 `--closing-pr` もあるときの合計の行のきっかけの欄を、子込みでは `合計（子 issue <n> 件込み: PR <m> 件 $<額> + PR 外 $<額>）` にする。子なしの書式（`timeline_total_trigger()`）は変えない。`_is_total_trigger()` がこの形も合計の行と判定することを確かめる。触る範囲: plugins/cost-ledger/scripts/cost_ledger.py:2040-2062（`timeline_total_trigger`・`_is_total_trigger`）

## 3. hook（`gate_report.py`）

- [ ] 3.1 `resolve()` が issue の応答の `sub_issues_summary.total` を返すようにし（整数で 1 以上のときだけ子を持つ扱い。無い・0・整数でない・PR のときは 0）、`work()` から `stack()` まで運ぶ。`gh` は足さない。触る範囲: plugins/cost-ledger/scripts/gate_report.py:706-745（`resolve`）、plugins/cost-ledger/scripts/gate_report.py:888-924（`work`）
- [ ] 3.2 `epic_tree(repo, number)` を足す。GraphQL を子を持つ issue 1 件につき 1 回（1 行につき 5 回まで）呼び、子孫の番号の一覧と、対象と子孫を閉じた PR の一覧（`closing_prs()` と同じ絞り方）を返す。失敗・形の崩れ・100 件超・8 段超・6 回目が必要なときは None。`gh_api()` を使う。触る範囲: plugins/cost-ledger/scripts/gate_report.py:801-843（`CLOSING_QUERY`・`closing_prs` の下に追加）
- [ ] 3.3 `stack()` で、子を持つ issue なら `epic_tree()` を呼び、成功なら `--child-issue`・`--child-pr` を渡し、`issue クローズ` を含む行では `closing_prs()` を呼ばずに数える PR を `--closing-pr` にも渡す。None ならそれらを渡さず、きっかけの欄の最後に `子 issue 照会失敗` を足し、`issue クローズ` でも `--closing-pr` を渡さない。子を持たない issue と PR の経路は 1 文字も変えない。触る範囲: plugins/cost-ledger/scripts/gate_report.py:846-885（`stack`）、plugins/cost-ledger/scripts/gate_report.py:38-45付近（失敗の印の定数 `CLOSING_FAILED` の隣）
- [ ] 3.4 後追い（`backfill.py`）が同じ `stack()` を通ることを確かめる（コードの変更は無い想定。変えるなら理由を記録する）。触る範囲: plugins/cost-ledger/scripts/backfill.py（読むだけ）

## 4. テスト（`plugins/cost-ledger/tests/epic-timeline.bats` を新規。`attribution.bats` は触らない）

- [ ] 4.1 受け入れ条件: 子 2 件のデータでエピックを閉じたとき、合計の行の額が `cost_ledger.py cost <エピック>` の 1 行目の額と一致する。複数の子が同じ PR に結び付く場合と、区間の行が子の PR のブランチ上にある場合も、一度だけ数えられる。触る範囲: plugins/cost-ledger/tests/epic-timeline.bats（新規）、plugins/cost-ledger/tests/epic.bats:1-70（データと `gh` の stub の作り方の参考）
- [ ] 4.2 受け入れ条件: 子を持たない issue と PR で、hook が呼ぶ `gh` の回数と `timeline` に渡る引数が変更の前後で同じ（コメント 3 回・クローズ 4 回・PR 3 回）。触る範囲: plugins/cost-ledger/tests/epic-timeline.bats（新規）、plugins/cost-ledger/tests/gate-report.bats:1-130（hook 用の stub の参考）
- [ ] 4.3 子を持つ issue の回数（コメント 4 回・クローズ 4 回・子の 1 件が孫を持つとき 5 回・5 回超で止まる）、子孫の問い合わせの失敗・形の崩れ・100 件超・別のリポジトリの子・fork の PR、`--child-issue` を `--pr` と渡す・値が崩れているときの終了コード 2、合計の行のきっかけの欄の書式。触る範囲: plugins/cost-ledger/tests/epic-timeline.bats（新規）
- [ ] 4.4 `epic_tree()` と `fetch_epic_tree()` に同じ応答を食わせて、子孫の集合と PR の集合が一致する。触る範囲: plugins/cost-ledger/tests/epic-timeline.bats（新規）
- [ ] 4.5 `design.md` の「`gh` の回数」の表を満たすかを確かめる既存の bats（`gate-report.bats` の「`gh` の呼び出し回数」の Scenario、`timeline.bats` の子 issue を持つ issue の Scenario）が通る。落ちるものは仕様の変更に合わせて直す（`timeline.bats` の該当 Scenario は spec の差分で書き換えた「`--child-issue` を渡さなければ区間だけ」になる）。触る範囲: plugins/cost-ledger/tests/timeline.bats、plugins/cost-ledger/tests/gate-report.bats

## 5. 仕様・文書・記録

- [ ] 5.1 `openspec/specs/cost-ledger-timeline/spec.md` へ、この change の差分を反映する（archive 時に自動）。触る範囲: openspec/specs/cost-ledger-timeline/spec.md:347-404、openspec/specs/cost-ledger-timeline/spec.md:444-475
- [ ] 5.2 README に hook の説明（子を持つ issue の行・`gh` の回数）があれば直す。触る範囲: plugins/cost-ledger/README.md（該当箇所を検索。常時注入の対象ではない）
- [ ] 5.3 変更の記録 `plugins/cost-ledger/changes/745.md` を、既存の `690.md` の形に合わせて書く（何が変わるか・`gh` の回数・反映に `/reload-plugins` が要らないこと・仕様とテストの場所）。触る範囲: plugins/cost-ledger/changes/745.md（新規）

## 6. 実測と仕上げ

- [ ] 6.1 変更の後の `gh` の回数と hook 1 回の所要時間を、1.1 と同じ手順で取り、変更の前後の表を PR 本文に書く（子なし・子 1 件・子あり、コメントとクローズ）。同期の部分の所要時間（セッションを止める分）も書く
- [ ] 6.2 `bats plugins/cost-ledger/tests` と `bats tests/injection-budget.bats` を流し、通ることを確かめる。常時注入（`rules/`・`CLAUDE.md`・`description`）は増やしていないことを確認する
