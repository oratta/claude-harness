# Tasks

## 1. codex-worker の結果 JSON に開始・終了の時刻を足す

- [x] 1.1 `tests/test_codex_worker.py` に、完走した前景実行の結果の `started_at` / `ended_at` が `^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$` に一致し、`started_at <= ended_at` で、テストが worker を起動した前後の UTC 時刻（秒で切り捨て）の範囲に入ることを確かめるテストを足し、先に落ちることを確かめる。ターン開始前の失敗の形を固定で照合している `test_failures_before_the_turn_keep_the_same_shape` のキーの集合に 2 つを足し、そこでも書式どおりで `null` でないことを確かめる 触る範囲: plugins/dev-workflow/tests/test_codex_worker.py:704-735（`test_foreground_run_completes_without_a_ledger` の近く）、plugins/dev-workflow/tests/test_codex_worker.py:786-800（`test_failures_before_the_turn_keep_the_same_shape`）
- [x] 1.2 `run()` の入口（依頼を読む前）で `started_at` を、`finally` のあと `print` の直前で `ended_at` を UTC・秒まで・末尾 `Z` で取り、結果 JSON に足して 1.1 のテストが通ることを確かめる（`datetime` の import を足す。単調時計は使わない） 触る範囲: plugins/dev-workflow/scripts/codex-worker.py:3-18（import）、plugins/dev-workflow/scripts/codex-worker.py:692-757（`run()`）
- [x] 1.3 結果 JSON のキーを列挙している 3 つの文書に `started_at` / `ended_at`（UTC の ISO8601・秒まで）を足し、`grep -n 'started_at' <3 ファイル>` がそれぞれ 1 件以上を返すことを確かめる 触る範囲: plugins/dev-workflow/references/codex-develop.md:41、plugins/dev-workflow/docs/codex-develop.md:47、plugins/dev-workflow/scripts/CODEX-WORKER.md:43

## 2. develop の本体が `Codex 消費:` コメントの印に時刻を書く

- [ ] 2.1 `tests/develop-skill.bats` の `consumption mark: no time keys, ...` を、時刻を `Codex 消費:` コメントの印にだけ書く規則の検査に書き換え（`` `開始=` `終了=` は書かない`` の文字列を探す行を外し、置き場の限定の文を探す）、「Codex の消費の記録」の段落に `started_at` → `開始=`・`ended_at` → `終了=`・取れなければキーごと省く・G の full レビューの分には書かない、の 4 点があることを検査するテストを足して、先に落ちることを確かめる 触る範囲: plugins/dev-workflow/tests/develop-skill.bats:682-686
- [ ] 2.2 SKILL.md「PR トークン上限」節の「消費の記録の印」の時刻の行を「`開始=` `終了=` は `Codex 消費:` コメントの印にだけ書き、description と `develop 開始` コメントの印には書かない」に改め、「Codex の消費の記録」の段落に結果 JSON の `started_at` / `ended_at` を `開始=` / `終了=` に写す書き方（例の印を 1 つ添える）・キーが無いか `null` なら省いて推測で埋めない・G の full レビューの分には書かない、を足して、2.1 のテストと `bats plugins/dev-workflow/tests/develop-skill.bats` が通ることを確かめる 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:240（時刻の行）、plugins/dev-workflow/skills/develop/SKILL.md:247（「Codex の消費の記録」の段落）

## 3. 変更の記録と全体の確認

- [ ] 3.1 `plugins/dev-workflow/changes/1321.md` に変更の記録（何が変わったか・読み取り側 genetta-inc/flatmate#1776 との関係）を書き、`version` を上げていないことを `git diff origin/main -- plugins/dev-workflow/.claude-plugin/plugin.json` が空であることで確かめる 触る範囲: plugins/dev-workflow/changes/1321.md（新規）
- [ ] 3.2 `scripts/test.sh` が exit 0 で終わることを確かめる（`tests/python-suites.bats` 経由の `test_codex_worker.py`、`tests/injection-budget.bats` を含む） 触る範囲: なし（確認のみ）

## Workflow follow-up

- R1 の仕様レビューで APPROVE を受けてから実装に入る
- 実装と verify のあと、change を archive して Draft PR を更新する
