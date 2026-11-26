## MODIFIED Requirements

### Requirement: 共有枠モードが役割の既定モデルの下限を決める
共有枠モード `SHARED_BUDGET_MODE` は active スロットの週次の実効値（`usage-session-records` の規則でセッション記録と snapshot から求めた `weekly_all_pct`。全モデル共通の週次枠の消化率）から導出し、`scripts/session-tripwires.sh` が Fable 残量モードと並べてセッション文脈に注入しなければならない（SHALL）。導出の式は `scripts/usage_view.py` の 1 か所にだけ置く（SHALL）。導出の優先順位: ① 明示 env `SHARED_BUDGET_MODE` ② 明示 env が無く、セッション記録と snapshot の双方から週次の実効値が求まらない → `ok` ③ 週次の実効値 `weekly_all_pct > 90` → `depleted` ④ `weekly_all_pct` が週経過%（週次リセット時刻から算出）より大きい → `throttled` ⑤ それ以外 → `ok`。効果は `plugins/dev-workflow/skills/develop/references/decision-criteria.md` の表に置く（SHALL）: `ok` は制約なし、`throttled` は W / R1 / G の既定を Sonnet に落とし昇格上限 Opus・`abundant` の押し上げ無効、`depleted` は最安の役（explore と summarize）はそのまま、それ以外の役は中位（Sonnet）が上限・昇格なし（事前分類に当たっても Fable / Opus を使わない）。Fable 残量モードと共有枠モードが食い違うときは共有枠モードの下限が勝たなければならない（MUST）。導出は Fable 残量モードの導出を変えてはならない（MUST NOT）。Fable 残量モードの既定 `conserve` に倒れるのは、明示 env が無く、active スロットの実効値の `fable_weekly_pct` が求まらないとき（Fable 週次はセッション記録に無く snapshot だけから求めるので、snapshot が無い・その値かリセット時刻が無いとき）である。

守備範囲: 残量モードの導出の入力の出どころ・拾いたい誤り・通してよい入力・完了条件は、`dev-workflow-escalation-tripwires` の要件「SessionStart で残量モードを自動導出注入」の守備範囲の段落に従う（式が 1 か所なので守備範囲も 1 か所に置く）。

#### Scenario: Fable が余っていても全モデル枠が速く減っていれば throttled
- **WHEN** active スロットの実効値の `fable_weekly_pct` が週経過% 以下（abundant）で、週次の実効値 `weekly_all_pct` が週経過% より大きく 90 以下
- **THEN** `FABLE_BUDGET_MODE` は abundant、`SHARED_BUDGET_MODE` は throttled と注入され、役割の既定は Sonnet 起点になる

#### Scenario: 全モデル枠 90% 超は depleted
- **WHEN** 週次の実効値 `weekly_all_pct` が 90 を超え、`SHARED_BUDGET_MODE` が未設定
- **THEN** 共有枠モードは depleted に導出される

#### Scenario: データが無ければ ok
- **WHEN** `SHARED_BUDGET_MODE` と `FABLE_BUDGET_MODE` が未設定で、active スロットのセッション記録も snapshot も無い（週次の実効値も Fable 週次も求まらない）
- **THEN** 共有枠モードは ok（制約なし）に導出され、Fable 残量モードの導出は従来どおり conserve に倒れる

#### Scenario: snapshot が無くてもセッション記録の週次で depleted
- **WHEN** snapshot が無く、active スロットの鍵のセッション記録に週次 95% があり、`SHARED_BUDGET_MODE` が未設定
- **THEN** 共有枠モードは depleted に導出される（ok にならない）

#### Scenario: depleted でも最安の役は上げない
- **WHEN** `SHARED_BUDGET_MODE=depleted` の状態で decision-criteria の共有枠モードの表と、`session-tripwires.sh` が注入する `depleted` の効果の文を読む
- **THEN** どちらも explore と summarize を最安のまま残し、それ以外の役の上限を中位とする。「全役割 Sonnet 固定」の語を含まない
