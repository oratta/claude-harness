## Why

使用量を手で取り直すとき（flatmate #1717 の「使用量を取り直す」ボタン、リセットチケットを使った直後など）、今は `USAGE_PROBE_STALE=0 USAGE_PROBE_INTERVAL=0` を付けて `usage-probe.sh` を叩くしかない。`USAGE_PROBE_INTERVAL` は 429（呼びすぎで断られた）の待ち（間隔 × 2^(連続回数-1)、上限 1 日）の基準でもあるため、0 にすると待ちも 0 になり、待ち中のアカウントにも API を叩いてしまう。そのため flatmate 側は、待ち中のスロットが 1 つでもあると取り直しを諦めており、待ちの無いアカウントも最大 3 時間古い値のまま残る（#1256）。

## What Changes

- `usage-probe.sh` に引数 `--refresh` を足す。付けたときは、スロットごとの実行条件のうち「鮮度（`USAGE_PROBE_STALE`）」と「前回の試行からの間隔（`USAGE_PROBE_INTERVAL`）」の 2 つを外し、「429 による待ち時間の中にいない」と「オフでない」の 2 つは残す
- 429 の待ちの長さは `--refresh` を付けても付けなくても同じ式（`USAGE_PROBE_INTERVAL × 2^(回数-1)`、上限 86400 秒）で測る。待ち中のスロットは叩かず、試行状態ファイル（試行時刻と連続 429 回数）も変えない
- 引数なしの呼び方（SessionStart の hook など既存の呼び出し）の振る舞いは変えない
- flatmate #1717 の呼び方の切り替えはこの change に含めない（flatmate 側の別 issue）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-escalation-tripwires`: 要件「usage-probe と snapshot 契約」の実行条件に、`--refresh` を付けたときに外す条件と残す条件を足す

## Impact

- `plugins/dev-workflow/scripts/usage-probe.sh`（引数の読み取り、実行条件の判定 `due`、冒頭の契約コメント）
- `plugins/dev-workflow/tests/usage-probe-multi-account.bats`（`--refresh` のテストを足す。既存テストは変えない）
- `plugins/dev-workflow/changes/1256.md`（新規。変更の記録）
- `openspec/specs/dev-workflow-escalation-tripwires/spec.md`（archive 時に反映）
- ロック（マシン全体で 1 本）は変えない。別の probe が走っている最中に `--refresh` で呼ぶと、従来どおり何もせず exit 0 で終わる
