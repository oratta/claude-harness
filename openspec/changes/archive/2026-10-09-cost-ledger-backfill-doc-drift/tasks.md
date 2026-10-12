## 1. 現行 spec と archive 済みの文書

- [x] 1.1 `openspec/specs/cost-ledger-backfill/spec.md` の Scenario「壊れた控え」の WHEN に「一覧が 1 件以上を返す」を足す。archive 済みの `openspec/changes/archive/2026-10-07-cost-ledger-backfill/specs/cost-ledger-backfill/spec.md` も同じ直し。触る範囲: openspec/specs/cost-ledger-backfill/spec.md:195-197、openspec/changes/archive/2026-10-07-cost-ledger-backfill/specs/cost-ledger-backfill/spec.md:152-154
- [x] 1.2 `openspec/specs/cost-ledger-timeline/spec.md` の `--backfill` の守備範囲（Requirement「`--backfill` を付けた `timeline` は…」）に、手でマージ・クローズした直後の 1〜2 秒に別セッションが始まると 2 行並ぶ場合を足す。触る範囲: openspec/specs/cost-ledger-timeline/spec.md:603
- [x] 1.3 archive 済みの `design.md` 決定 6 の「記録と対応しない行（最終行が壊れたあとの先頭の行）」を、表の行数が記録より多いときの先頭の余りの行と、最終行が読めない本文のすべての行、の 2 つに直す。触る範囲: openspec/changes/archive/2026-10-07-cost-ledger-backfill/design.md:109

## 2. README と changes の記述

- [x] 2.1 README の「上限は 61 回」に、20 件目と同じ秒の候補が続く回は超えると書く（`backfill.py` の `MAX_CANDIDATES` と spec の「20 件目と出来事の時刻が同じ候補は同じ実行で処理」に合わせる）。「300 秒以上ずれていると」を「GitHub より 300 秒を超えて遅れていると」に直す。触る範囲: plugins/cost-ledger/README.md:329-335
- [x] 2.2 `plugins/cost-ledger/changes/691.md` の 27 行目（と、台帳の場所を指す 33 行目）の「`COST_LEDGER_PATH` 未設定」を「cost-ledger-persistence で解決した台帳のパスが未設定」に直す。53 行目は実測で `COST_LEDGER_PATH` を実際に設定した記述なので直さない。触る範囲: plugins/cost-ledger/changes/691.md:27、:33

## 3. ロックのファイル名

- [x] 3.1 `gate_report.py` の `lock()` のファイル名を `repo.lower().replace("/", "__")` にする。触る範囲: plugins/cost-ledger/scripts/gate_report.py:760
- [x] 3.2 大文字小文字だけが違う 2 つのリポジトリ名で `lock()` を呼ぶと同じロックファイル名になるテストを、`attribution.bats` 以外の bats に足す（既存の `plugins/cost-ledger/tests/gate-report.bats` の `lock()` を直接呼ぶテストの近く）。触る範囲: plugins/cost-ledger/tests/gate-report.bats:1735-1770

## 4. 検証と実測

- [x] 4.1 `cost-ledger` の bats を実行し、全件通ることを確かめる。`cost_ledger.py` と `attribution.bats` は変更していないことを `git diff --stat` で確かめる
- [x] 4.2 エピック #272 の全体の制約: 変更の前後で hook 1 回の所要時間（`backfill.sh` に SessionStart の JSON を流して `time.perf_counter` で測る）と `gh` の呼び出し回数（`gh` を記録するラッパーで数える）を測り、PR 本文に前後の値を書く。LLM のトークンを使わないこと（hook が出力しない・スキル本文に手順を足していない）も書く。差が無ければ「差なし」と書く（上限値は置かず結果を記録する）
- [x] 4.3 範囲外の問題を見つけたら直さず PR 本文に書き、本体が子 issue にして #272 の sub-issue に加える
