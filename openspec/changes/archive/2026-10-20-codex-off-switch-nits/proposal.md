## Why

PR #1003（#978）のゲートで出た仕様の nit。pr-review-gate の要件のオフ判定の括弧書きが、名前を出す前のコマンドを「このコマンド」と指し、同じ要件を 2 回参照している。usage-account-registry は、同じ段落（守備範囲）を 2 つの要件に書いていて、片方だけ直すと食い違う。挙動は変わらない。

## What Changes

- 要件「事前判定と障害時フォールバックを区別する」のオフ判定の括弧書きを、`usage_view.py --codex-enabled` が `off` を出すとき、と読み方（要件「Codex を codex.enabled でオフにできる」に従う）、G は設定ファイルを読まず出力だけで分岐する、の順に書き直す
- 要件「アカウントレジストリの所在と形状」の「守備範囲（`codex` の読み取りが扱う入力）」の段落を、要件「Codex を codex.enabled でオフにできる」を参照する 1 文にする。守備範囲の本文は後者に 1 か所だけ残す
- 実装側（spec 外）: archive 済み change `2026-10-12-codex-off-switch` の delta spec 2 本を同じ文に揃える、`plugins/dev-workflow/changes/978.md` の差分範囲に `refuse_explicit_codex_when_off` を足す、`plugins/statusline/tests/statusline.bats` の「codex を起動しない」検査を auth.json を置いた条件で行う

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 要件「事前判定と障害時フォールバックを区別する」の文言のみ
- `usage-account-registry`: 要件「アカウントレジストリの所在と形状」の守備範囲の段落を参照 1 文に。要件「Codex を codex.enabled でオフにできる」は本文を変えず、守備範囲の正本として残す

## Impact

文言のみ。コード・挙動・テストの期待値は変わらない。
