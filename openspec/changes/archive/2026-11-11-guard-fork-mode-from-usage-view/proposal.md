# fork の可否を決める共有枠モードを usage_view.py から得る

## Why

#1622 で残量モードを導く式を `plugins/dev-workflow/scripts/usage_view.py` の `budget_mode_details` に寄せ、仕様にも「式は `usage_view.py` の 1 か所にだけ置く（SHALL）」と書いた。ところが `plugins/dev-workflow/scripts/agent-model-guard.sh` の fork 判定には、週経過率と週次使用率から共有枠モード（`SHARED_BUDGET_MODE`）を導く式の写しが残っている（#615 が同じファイルを触っていたため #1622 では範囲外にした）。片方だけを直すと、fork を止めるかどうかと、セッションに注入されるモード・`codex-develop.py request` が格に当てるモードが食い違う。仕様と `usage_view.py` の docstring の「only place of that formula」も今は事実と合わない。

## What Changes

- `agent-model-guard.sh` の fork 判定は共有枠モードを自分で導かず、`usage_view.py` の `budget_mode_details` の結果（正規化後のモード）で許可・拒否を決める。週経過率の計算・90 のしきい値・週経過との比較・明示 env の優先の判定を guard から無くす
- 判定に使う現在時刻（`USAGE_PROBE_NOW`、無ければ現在時刻）の取り方と、active スロットの実効値を `usage_view.build_view` から得る経路は今のまま
- `usage_view.py` を読み込めないときは、明示 env `SHARED_BUDGET_MODE` も読まず `ok` として通す（今は明示 env だけは guard が読んで拒否する）。`session-tripwires.sh` の扱い（読めなければ明示 env も読まず既定を出す）にそろえる
- 拒否理由の文面に出すモード名は、明示値ならその値のまま（未知の値もそのまま出す）
- テスト: 偽の `usage_view.py` を置いた scripts ディレクトリから guard を動かし、導出を `usage_view.py` から得ることを確かめる bats と、guard に式が無いことを確かめる bats を足す

範囲外:
- `usage_view.py` の導出の式そのものと、`session-tripwires.sh`・`codex-develop.py` の読み方は変えない
- fork 以外の判定（model 未指定・Fable・実行役の格の上限）は変えない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-execution-strategy`: 要件「model 未指定の Agent spawn は hook が拒否する」で、fork の共有枠モードを guard 自身の場所の `usage_view.py` から得ること・guard が式を持たないこと・`usage_view.py` を読めないときの fail-open を書き、シナリオを足す

## Impact

- `plugins/dev-workflow/scripts/agent-model-guard.sh`（fork 判定とヘッダのコメント）
- `plugins/dev-workflow/scripts/usage_view.py`（docstring の読み手の記述。式は変えない）
- `plugins/dev-workflow/tests/agent-model-guard.bats`
- `plugins/dev-workflow/changes/1625.md`（変更の記録）
