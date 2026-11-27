## 1. guard の fork 判定を usage_view.py の導出に置き換える

- [x] 1.1 偽の `usage_view.py` を置いた一時の scripts ディレクトリ（guard と `tier_caps.py` を写す）から guard を動かす bats を足す: 共有枠モードを `throttled` で返す偽物で、`SHARED_BUDGET_MODE` 未設定・記録も snapshot も無い fork が拒否され理由に `throttled` が入る／`usage_view.py` の無い（import で例外を出す）ディレクトリで `SHARED_BUDGET_MODE=depleted` の fork が無出力・exit 0 で通る／guard の本文に週の秒数（`7 * 86400`・`86400`）と `> 90` の比較が無い。置き換え前は前の 2 つが落ちることを確かめる。確認: `bats plugins/dev-workflow/tests/agent-model-guard.bats` で足した 3 件が置き換え後に通る。触る範囲: plugins/dev-workflow/tests/agent-model-guard.bats:88-149（fork のテスト群の後ろに足す）
- [x] 1.2 fork 判定を `budget_mode_details({}, now)` →（出どころが明示 env でなければ）`build_view` の active スロットで `budget_mode_details(slot, now)` の 2 段に置き換える。判定は `shared["mode"] == "ok"`、拒否理由のモード名は `shared["shown"]`、import・呼び出しの例外は `ok`。`USAGE_PROBE_NOW` の扱いは残す。確認: `bats plugins/dev-workflow/tests/agent-model-guard.bats` が exit 0（既存の fork の 6 件を含む）。触る範囲: plugins/dev-workflow/scripts/agent-model-guard.sh:64-91（`if stype == "fork":` の中）
- [x] 1.3 guard のヘッダのコメント（fork の行）と、`usage_view.py` の docstring の読み手の記述（guard も `budget_mode_details` を使う）を事実に合わせる。`openspec/specs/dev-workflow-execution-strategy/spec.md` と `openspec/specs/dev-workflow-escalation-tripwires/spec.md` の「式は `usage_view.py` の 1 か所」の文と docstring の「only place of that formula」が事実と合うことを `grep -n "7 \* 86400\|weekly_all_pct\") >\|> 90" plugins/dev-workflow/scripts/*.sh` が guard に当たらないことで確かめる。触る範囲: plugins/dev-workflow/scripts/agent-model-guard.sh:21-22、plugins/dev-workflow/scripts/usage_view.py:1-8

## 2. 記録と全体の確認

- [x] 2.1 変更の記録 `plugins/dev-workflow/changes/1625.md` を既存の記録の形式で書く。確認: ファイルがあり、何を・なぜを書いている。触る範囲: plugins/dev-workflow/changes/1625.md（新規）
- [x] 2.2 `scripts/test.sh` を通す。確認: exit 0。触る範囲: なし（実行のみ）

## Workflow follow-up

- archive で `openspec/specs/dev-workflow-execution-strategy/spec.md` に差分を反映する
