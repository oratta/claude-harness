# Proposal

## Why

develop が Codex に投げた仕事は、使った枠がどのリセット期間のものかを後から判定できない。`scripts/codex-worker.py` は CODEX_HOME を毎回使い捨てのフォルダに作るので rollout が登録した CODEX_HOME に残らず、flatmate の `burn_consumption.py` の Codex 行の時刻が null になるためである。読み取り側（genetta-inc/flatmate#1776、CLOSED）は `Codex 消費:` コメントの印の `開始=<ISO8601>` `終了=<ISO8601>` を rollout の代わりに読む契約を入れ終えたので、書く側を揃える（issue #1321）。

## What Changes

- codex-worker の前景実行の結果 JSON に、実行の開始と終了の時刻（UTC の ISO8601、秒まで、末尾 `Z`）を 2 つのキーで足す。成功・失敗を問わず同じ形で出す
- develop の本体が投稿する `Codex 消費:` コメントの印に、executor が `codex` の委譲では結果 JSON の時刻から `開始=` `終了=` を書く
- 「消費の記録の印」の「時刻の `開始=` `終了=` は書かない」の規則を改める。時刻を書くのは `Codex 消費:` コメントの印だけで、description と `develop 開始` コメントの印には書かない（読み取り側がそこでは読まない）。時刻が取れない呼び出し（G の full レビューで Bash から呼んだ Codex、時刻のキーが無いか null の結果 JSON）では、推測で埋めずにキーごと省く
- 結果 JSON のキーを列挙している文書（`references/codex-develop.md`・`docs/codex-develop.md`・`scripts/CODEX-WORKER.md`）に時刻のキーを足す

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `codex-worker`: 「前景実行の結果は 1 行の JSON で返す」の必須キーに開始・終了の時刻を足す
- `dev-workflow-pr-token-budget`: 要件「Codex 消費コメントの印に実行の時刻を書く」を足し、「消費の記録に工程・試行・アカウントの印を書く」の時刻を含まない印の Scenario の前提を「結果 JSON に時刻が無い場合」に限り、「消費の記録の印のアカウントと時刻の扱いを決める」の時刻の規則を「書いてはならない」から「`Codex 消費:` コメントの印にだけ書く」に改める

## Impact

- `plugins/dev-workflow/scripts/codex-worker.py`（`run()` の結果 JSON）
- `plugins/dev-workflow/tests/test_codex_worker.py`（`tests/python-suites.bats` 経由で `scripts/test.sh` から走る）
- `plugins/dev-workflow/skills/develop/SKILL.md`「PR トークン上限」節
- `plugins/dev-workflow/tests/develop-skill.bats`（時刻の規則の検査を書き換える）
- `plugins/dev-workflow/references/codex-develop.md`・`plugins/dev-workflow/docs/codex-develop.md`・`plugins/dev-workflow/scripts/CODEX-WORKER.md`（結果 JSON のキーの列挙）
- `plugins/dev-workflow/changes/1321.md`（変更の記録）
- 読み取り側（flatmate の `burn_consumption.py`）は変えない。キーを足しても既存の読み取りは壊れない（結果 JSON の利用者は develop の本体だけで、キーの集合を固定で照合しているのは codex-worker 自身のテストだけ）
