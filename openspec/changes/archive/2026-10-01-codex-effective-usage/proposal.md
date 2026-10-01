## Why

Claude 側の週次余裕は #417 で「取得から 300 秒を過ぎたら捨てる」をやめ、リセット時刻で読む実効値（リセットを過ぎた窓は 0%、過ぎていなければ下限）になった。Codex 側は今も「取得から 300 秒以内」「リセット時刻が 7 日以内」の検査が残り、API が一時的に失敗して値が少し古くなるだけで Codex が欠測になる。Claude と Codex は同じ扱いにする方針なので、Codex 側も同じ規則で読む（#442 の 3 つ目）。

## What Changes

- Codex の自動選択は、`fetched_at` の経過時間（300 秒）で欠測にしない。週次窓（`minutes=10080`）のリセット時刻を過ぎていれば使用率 0%・リセット時刻は 1 週間単位で先へ送った値、過ぎていなければ取得した使用率を下限としてそのまま使う
- リセット時刻が 7 日より先でも欠測にしない（Claude 側と同じ。週経過率が負になり余裕が負になるだけで、選ばれない）
- 取得失敗で前回値を使うときも同じ規則で読む（前回値の古さでは除外しない）
- 欠測のまま残すもの: 週次窓が無い・使用率が有限の 0..100 でない・リセット時刻が整数でない・`fetched_at` が整数でない／未来時刻

## Capabilities

### Modified Capabilities

- `codex-role-profiles`: 「snapshot の鮮度と週次窓を fail-safe に検証する」「複数 Codex account を分離して観測し代表 account を固定する」の 2 要件から 300 秒の鮮度判定と 7 日以内の検査を外し、実効値の規則に置き換える

## Impact

- `plugins/dev-workflow/scripts/codex-develop.py`（`usage_margin`）、`plugins/dev-workflow/tests/test_codex_develop.py`、`plugins/dev-workflow/docs/codex-develop.md`、`plugins/dev-workflow/skills/develop/SKILL.md`、`plugins/dev-workflow/skills/develop/references/decision-criteria.md`
