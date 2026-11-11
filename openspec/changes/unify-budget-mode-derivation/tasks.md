# Tasks

実装に入る前に `git fetch origin && git merge origin/main` で main を取り込む（親エピック #616 の指示）。

## 1. usage_view.py に出どころ付きの導出を置く

- [ ] 1.1 `test_codex_develop.py` の `BudgetModeDerivation` に、出どころ付きの導出関数のテスト（明示 env・未知の明示値（表示する値はそのまま、モードは conserve / throttled）・空白だけの明示値・データ無し・自動導出の各出どころ）を先に足し、落ちることを確かめる。クラス冒頭の注記（`session-tripwires.sh` は写しで手を付けない）を、導出が `usage_view.py` の 1 か所にあることに直す。確認: `python3 -m unittest plugins/dev-workflow/tests/test_codex_develop.py -k BudgetModeDerivation` が新しいテストだけ落ちる。触る範囲: plugins/dev-workflow/tests/test_codex_develop.py:1395-1463（`BudgetModeDerivation`）
- [ ] 1.2 `usage_view.py` に、モードごとに `mode`・`shown`・`source` を返す関数を足し、`budget_modes` をその結果のモード名だけを返す包みにする。docstring の「The formula is the one in session-tripwires.sh」を、この関数が式の唯一の置き場である旨に直す。週経過の割合を表示に使えるよう `_elapsed_pct` を公開名でも呼べるようにする。確認: 1.1 のテストと既存の `BudgetModeDerivation`・`budget_modes` を使う `test_codex_develop.py` の全テストが通る。触る範囲: plugins/dev-workflow/scripts/usage_view.py:1-15（docstring）、plugins/dev-workflow/scripts/usage_view.py:249-284（`_elapsed_pct`・`budget_modes`）

## 2. session-tripwires.sh から導出の写しを除く

- [ ] 2.1 `tripwire-hook.bats` に、scripts ディレクトリを一時領域に写してモードを固定値で返す偽の `usage_view.py` に差し替え、そこから `session-tripwires.sh` を走らせると注入されるモードが偽物の値になることを確かめる bats を先に足し、落ちることを確かめる（受け入れ条件「導出を `usage_view.py` から得る」）。確認: `bats plugins/dev-workflow/tests/tripwire-hook.bats` で新しいテストだけ落ちる。触る範囲: plugins/dev-workflow/tests/tripwire-hook.bats:105-215（「active スロットの実効値からの導出」の節）
- [ ] 2.2 `session-tripwires.sh` の heredoc の Python から、モードの導出（明示 env の読み取り・閾値の比較）と週経過の計算を除き、1.2 の関数の `shown`・`source`・`mode` と公開した週経過の関数を使う形にする。`usage_view.py` はスクリプト自身のディレクトリ（`BASH_SOURCE[0]` の dirname を絶対パスにしたもの）から読み込み、読み込めないときは `conserve` / `ok`・出どころ `既定（usage_view.py を読めない）` を出す。ファイル冒頭の注記「導出式はこのファイルの 1 か所だけに置く」を直す。確認: 2.1 の bats と `tripwire-hook.bats`・`subagent-start-context.bats`・`tests/hook-python-isolation.bats`・`test_codex_develop.py` の `test_same_values_as_session_tripwires` がすべて通る。触る範囲: plugins/dev-workflow/scripts/session-tripwires.sh:1-12（冒頭の注記）、plugins/dev-workflow/scripts/session-tripwires.sh:37-121（読み込みと導出）、plugins/dev-workflow/scripts/session-tripwires.sh:138-150（表示の行）
- [ ] 2.3 呼び手側の注記を直す: `subagent-start-context.sh` の「導出式は session-tripwires.sh の 1 か所だけに置き」を `usage_view.py` に改め、`decision-criteria.md` の共有枠モードの節の「自動導出（`scripts/session-tripwires.sh`）」を、式が `scripts/usage_view.py` にあり注入は `session-tripwires.sh` が行う旨に直す。確認: `grep -n "session-tripwires.sh の 1 か所" plugins/dev-workflow/scripts/subagent-start-context.sh` が 0 件。触る範囲: plugins/dev-workflow/scripts/subagent-start-context.sh:4-11、plugins/dev-workflow/skills/develop/references/decision-criteria.md:161-173（「共有枠モード `SHARED_BUDGET_MODE`」）

## 3. 効果の文を格の規則に合わせる

- [ ] 3.1 `tripwire-hook.bats` に、各モードの効果の文を固定する bats を先に足し、落ちることを確かめる。`depleted` は最安（explore と summarize）をそのままにし、それ以外は中位（sonnet）が上限・昇格なしと読めること、「全役割 sonnet 固定」を含まないこと。`throttled` は中位に落として上限が上位で、最安はそのままと読めること。`ok`・`conserve` は今の意味（`conserve` の「opus 止まり」を含む）を保つこと。確認: 新しいテストだけ落ちる。触る範囲: plugins/dev-workflow/tests/tripwire-hook.bats:70-92（「injection: budget-mode effects …」の近く）
- [ ] 3.2 `session-tripwires.sh` の `EFFECT` と `SHARED_EFFECT` の文を、decision-criteria の表と `model-tier-resolution` の格の語に合わせて直す（design.md「効果の文は格の規則の語で書き、モデル名を添える」）。`abundant` と `reserve`・`exhausted` は表と食い違う点だけを直す。確認: 3.1 の bats と既存の「injection: budget-mode effects route Fable through the decider type」が通る。触る範囲: plugins/dev-workflow/scripts/session-tripwires.sh:123-136（`EFFECT`・`SHARED_EFFECT`）

## 4. 全体の確認

- [ ] 4.1 `scripts/test.sh` が exit 0 で終わり、`openspec validate unify-budget-mode-derivation --type change --strict` が通る。PR を出す前に `git fetch origin && git merge origin/main` で main を取り込み、もう一度 `scripts/test.sh` を通す。触る範囲: なし（確認だけ）

## Workflow follow-up

- 範囲外にした 2 件を別 issue の候補として本体に返す: `openspec/specs/dev-workflow-develop/spec.md` の scenario 見出し「depleted はすべての要求を Sonnet に固定する」の語、`scripts/agent-model-guard.sh` の fork 判定にある共有枠モードの導出の写し
- R1 の APPROVE と実装・verify のあと、archive して PR を出す
