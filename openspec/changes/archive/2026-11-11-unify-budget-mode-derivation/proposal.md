# 残量モードの導出を usage_view.py の 1 か所にし、注入文面を格の規則に合わせる

## Why

#614（PR #1621）で残量モード（`FABLE_BUDGET_MODE` / `SHARED_BUDGET_MODE`）を導く式が `plugins/dev-workflow/scripts/usage_view.py` の `budget_modes` に置かれたが、`plugins/dev-workflow/scripts/session-tripwires.sh` にも同じ式の写しが残った。片方だけを直すと、セッション開始時に注入されるモードと、`codex-develop.py request` が格に当てるモードが食い違う。

また `session-tripwires.sh` が注入する `depleted` の効果の文は「全役割 sonnet 固定」のままで、#614 の規則（最安の役はそのまま、それ以外は中位が上限・昇格なし）と合わない。注入文を読んだ本体が最安（haiku）の役を sonnet に上げる誤りが起きうる。同じ語が `openspec/specs/dev-workflow-execution-strategy/spec.md` の要件「共有枠モードが役割の既定モデルの下限を決める」にも残っている。

## What Changes

- `session-tripwires.sh` は残量モードを自分で導出せず、`usage_view.py` から得る。注入するモード名・出どころ（明示 env / 既定（usage データなし）/ 自動導出）・未知の明示値の表示は今と変えない
- `usage_view.py` に、モードと出どころを返す導出を 1 つ置き、既存の `budget_modes` はその結果のモード名だけを返す形にする（`codex-develop.py` の結果 JSON の `budget_modes` 欄は変わらない）
- `session-tripwires.sh` が注入する各モードの効果の文を、`skills/develop/references/decision-criteria.md` の残量モード表・共有枠モード表と `model-tier-resolution` の要件「残量モードを格に適用する」に合わせる。`depleted` は「最安の役はそのまま、それ以外は中位が上限・昇格なし」と読める文にする
- 仕様の文言: 導出の置き場を `session-tripwires.sh` と書いている要件を `usage_view.py` に改め、`dev-workflow-execution-strategy` の `depleted` の「全役割 Sonnet 固定」を上限の語に直す

範囲外:
- `openspec/specs/dev-workflow-develop/spec.md` の scenario 見出し「depleted はすべての要求を Sonnet に固定する」。THEN の中身は上限の規則でも正しく、食い違いは見出しの語だけ。直すには要件「本体は role profile から executor を選ぶ」を丸ごと写す必要があり、並列の #424・#615 が触る見込みが高いので別 issue に切り出す
- `scripts/agent-model-guard.sh` の fork 判定にある共有枠モードの導出の写し。#615 が同じファイルを触るので、別 issue に切り出す

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-escalation-tripwires`: 要件「SessionStart で残量モードを自動導出注入」と「SubagentStart hook が dev-workflow の役に運用情報を注入する」で、式の置き場を `usage_view.py` に改め、注入する効果の文が decision-criteria の表と一致することを求める
- `dev-workflow-execution-strategy`: 要件「共有枠モードが役割の既定モデルの下限を決める」で、導出の置き場を `usage_view.py` に改め、`depleted` の効果を上限の語に直す
- `model-tier-resolution`: 要件「残量モードの導出」で、閾値を「`session-tripwires.sh` の式と同じ」とする文を、式の実装が `usage_view.py` の 1 か所であることに改める

## Impact

- コード: `plugins/dev-workflow/scripts/session-tripwires.sh`、`plugins/dev-workflow/scripts/usage_view.py`
- テスト: `plugins/dev-workflow/tests/tripwire-hook.bats`（導出を `usage_view.py` から得ることと効果の文を固定する bats を足す）、`plugins/dev-workflow/tests/test_codex_develop.py`（`BudgetModeDerivation` の「`session-tripwires.sh` は写しで手を付けない」という注記を直す）
- `tests/injection-budget.bats` は SessionStart の additionalContext を数えていないので、効果の文の長さが変わっても予算は動かない
- `tests/hook-python-isolation.bats` の `CLAUDE_PLUGIN_ROOT` が空の経路（`usage_view.py` を読み込めない）は、今と同じく fail-soft で出力を保つ
- 依存: なし。Refs #1622（エピック #616 の子）
