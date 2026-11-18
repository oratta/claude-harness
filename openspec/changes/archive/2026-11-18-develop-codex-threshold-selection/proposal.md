## Why

`/develop` の投げ先の自動選択は、Claude の余裕（週の経過率 − 週の使用率）が 0 以上なら、Codex の余裕がどれだけ大きくても実装を Claude に渡す（構成 `claude-write-codex-review`）。2026-11-18 の実測では Claude +6.9 ポイント・Codex +65.3 ポイントで実装が Claude に回り、Codex の枠は期限で消え、Claude の枠は本来の作業の分まで実装に使われた（issue #1677。親エピック genetta-inc/flatmate#698）。オーナーは 2026-11-18 に「Codex の余裕が基準以上なら全工程を Codex に渡す」と決めた。

## What Changes

- 自動選択の規則の先頭に 1 行を足す: Codex がオンで、代表 Codex account の余裕が基準以上なら、Claude の余裕を問わず `codex-standard`（全役割が Codex）を選び、新しい理由コード `codex-headroom-meets-threshold` を返す
- 基準は環境変数 `DEVELOP_ALL_CODEX_MIN_MARGIN_PCT` で変えられる（既定 10 ポイント。flatmate の `ACCOUNT_ALLOC_MIN_SURPLUS_PCT` の既定と同じ）。未設定・空文字は既定値。数でない・負・100 を超える・有限でない値は既定値に倒さず、自動選択を `status: blocked`・終了コード 2 で止める
- Codex の余裕が 0 以上・基準未満のときと、0 未満か欠測のときの選択は今と同じ。Codex オフ（`codex.enabled: false`）の `claude-default`・`codex-off` も今と同じ
- 開始済みの工程を途中で切り替えない動き、明示 profile・旧形式が自動選択を迂回する動きは変えない

## Capabilities

### Modified Capabilities

- `codex-role-profiles`: 要件「明示指定が無い工程では provider の週次余裕から構成を選ぶ」の選択規則・不正な設定で止める範囲・シナリオを変える

## Impact

- `plugins/dev-workflow/scripts/codex-develop.py`（`select_configuration` と `automatic_selection`）
- `plugins/dev-workflow/tests/test_codex_develop.py`・`plugins/dev-workflow/tests/test_model_resolution_current.py`（Codex の余裕が 10 以上で `claude-write-codex-review` を期待していた入力を直す）
- `plugins/dev-workflow/references/codex-develop.md`「起動と role 解決」（構成の選び方の正本の文書）
- `plugins/dev-workflow/changes/1677.md`
- flatmate のバーンの子もこの自動選択で動くので、同じ規則で Codex に寄る（バーンの起動の判定は genetta-inc/flatmate#2217 の範囲で、ここでは触らない）
