## MODIFIED Requirements

### Requirement: Step B 基準の重心移動
develop スキルの `plugins/dev-workflow/skills/develop/references/spec-decision.md` の仕様化要否（Step B）は、「設計判断・トレードオフを含むか（= 意図と決定の記録価値があるか)」を一次基準としなければならない（SHALL）。受け入れ条件が記録先（issue または Draft PR 本文）に明記された機械的な振る舞い変更は、記録先とテストを記録として spec 化を省略できる。テスト作成の必須性は、軽い通し方（`dev-workflow-spec-review` の「些細な修正は軽い通し方で新しいテストと W の起動を省く」Requirement）を除くいかなる判定でも緩めてはならない（MUST NOT）。軽い通し方では、記録先に書いた既存のテストかチェックのコマンドを走らせることが新しいテストの代わりになる（SHALL）。unmanned モードの「迷ったら spec 化に倒す」は維持する。

#### Scenario: 機械的な振る舞い変更は spec を省略できる
- **WHEN** 受け入れ条件が記録先に明記され、設計判断（トレードオフの選択）を含まない振る舞い変更を interactive で判定する
- **THEN** spec 化を省略してコード直行し、テストは必ず先に書く

#### Scenario: unmanned は安全側を維持
- **WHEN** unmanned モードで spec 化要否の判断がつかない
- **THEN** spec 化する側に倒す

#### Scenario: 軽い通し方だけが新しいテストを省く
- **WHEN** 記録先の最新の仕様化判断のコメントが `仕様化判断: しない` で `通し方: 軽い` の行を持つ
- **THEN** 新しいテストは書かず、`確かめ方:` の行のコマンドを走らせて確かめる。この行が無い判断では、どの判定でもテストを書く

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
- **WHEN** `SHARED_BUDGET_MODE=depleted` の状態で decision-criteria の残量モードと共有枠モードの優先順位の表の共有枠モードの行と、`session-tripwires.sh` が注入する `depleted` の効果の文を読む
- **THEN** どちらも explore と summarize を最安のまま残し、それ以外の役の上限を中位とする。「全役割 Sonnet 固定」の語を含まない

## ADDED Requirements

### Requirement: 残量モードと共有枠モードの優先順位の表は 1 か所に置く

Fable 残量モード（`FABLE_BUDGET_MODE`）と共有枠モード（`SHARED_BUDGET_MODE`）の値ごとの効果と、両者と事前分類が重なったときの優先順位（①共有枠モード ②その範囲内で事前分類による決める役 ③Fable 残量モード）は、`plugins/dev-workflow/skills/develop/references/decision-criteria.md` の 1 つの表に置かなければならない（MUST）。この表と同じ形の表を他のファイルに置いてはならない（MUST NOT）。値ごとの効果の文は、`scripts/session-tripwires.sh` が注入する効果の文と食い違ってはならない（MUST NOT）。

#### Scenario: 表は decision-criteria.md だけにある

- **WHEN** develop 配下の手順書と `plugins/dev-workflow/references/model-tiers.md` から、残量モードと共有枠モードの値ごとの効果を表の行で並べた箇所を探す
- **THEN** `decision-criteria.md` の 1 つの表だけが見つかる

### Requirement: 他のファイルは残量モードと共有枠モードの優先順位を 1 行で指す

`skills/develop/references/pre-classification.md`・`skills/develop/references/roles/spec-reviewer.md`・`skills/develop/references/roles/worker/common.md`・`plugins/dev-workflow/references/model-tiers.md` は、優先順位を言い換えて書いてはならず（MUST NOT）、適用は `codex-develop.py request` が行うことと、表が `decision-criteria.md` にあることを 1 行で指さなければならない（MUST）。`skills/develop/references/roles/gate-runner.md` の本文にある同じ言い換えはこの要件の対象外とする（`gate-runner.md` の本文はゲートの手順書を割る別の変更が直す。この変更では参照先のパスだけを直す）。

#### Scenario: 他のファイルは 1 行で指す

- **WHEN** `pre-classification.md`・`spec-reviewer.md`・`worker/common.md`・`model-tiers.md` を読む
- **THEN** 優先順位の言い換えが無く、`request` が適用することと `decision-criteria.md` の表への参照が 1 行で書かれている
