## MODIFIED Requirements

### Requirement: 共有枠モードが役割の既定モデルの下限を決める
共有枠モード `SHARED_BUDGET_MODE` は usage snapshot の `weekly_all_pct`（全モデル共通の週次枠の消化率）から導出し、`scripts/session-tripwires.sh` が Fable 残量モードと並べてセッション文脈に注入しなければならない（SHALL）。導出の式は `scripts/usage_view.py` の 1 か所にだけ置く（SHALL）。導出の優先順位: ① 明示 env `SHARED_BUDGET_MODE` ② `weekly_all_pct` が読めない / snapshot 無し → `ok` ③ `weekly_all_pct > 90` → `depleted` ④ `weekly_all_pct` が週経過%（週次リセット時刻から算出）より大きい → `throttled` ⑤ それ以外 → `ok`。効果は `plugins/dev-workflow/skills/develop/references/decision-criteria.md` の表に置く（SHALL）: `ok` は制約なし、`throttled` は W / R1 / G の既定を Sonnet に落とし昇格上限 Opus・`abundant` の押し上げ無効、`depleted` は最安の役（explore と summarize）はそのまま、それ以外の役は中位（Sonnet）が上限・昇格なし（事前分類に当たっても Fable / Opus を使わない）。Fable 残量モードと共有枠モードが食い違うときは共有枠モードの下限が勝たなければならない（MUST）。導出は Fable 残量モードの導出を変えてはならない（MUST NOT）。

#### Scenario: Fable が余っていても全モデル枠が速く減っていれば throttled
- **WHEN** snapshot の `fable_weekly_pct` が週経過% 以下（abundant）で、`weekly_all_pct` が週経過% より大きく 90 以下
- **THEN** `FABLE_BUDGET_MODE` は abundant、`SHARED_BUDGET_MODE` は throttled と注入され、役割の既定は Sonnet 起点になる

#### Scenario: 全モデル枠 90% 超は depleted
- **WHEN** snapshot の `weekly_all_pct` が 90 を超え、`SHARED_BUDGET_MODE` が未設定
- **THEN** 共有枠モードは depleted に導出される

#### Scenario: データが無ければ ok
- **WHEN** snapshot が無い、または `weekly_all_pct` が読めない
- **THEN** 共有枠モードは ok（制約なし）に導出され、Fable 残量モードの導出は従来どおり conserve に倒れる

#### Scenario: depleted でも最安の役は上げない
- **WHEN** `SHARED_BUDGET_MODE=depleted` の状態で decision-criteria の共有枠モードの表と、`session-tripwires.sh` が注入する `depleted` の効果の文を読む
- **THEN** どちらも explore と summarize を最安のまま残し、それ以外の役の上限を中位とする。「全役割 Sonnet 固定」の語を含まない
