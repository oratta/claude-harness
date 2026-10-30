## MODIFIED Requirements

### Requirement: 役割のモデルは事前分類と残量モードで決める
SKILL.md は役割ごとの格を次のとおり規定しなければならない（MUST。格の語と決め方は `model-tier-resolution` が定め、括弧内の名前は Claude での値）。「モデル」節は規則の説明と `codex-develop.py request` への参照とし、構成名を使った経路ごとのモデル名の書き分けを書いてはならない（MUST NOT）。本体は `request` が返した `model` を使い、値を文章の規則で計算し直してはならない（MUST NOT）。W は既定 中位（`sonnet`）、記録先が設計判断（データモデル・フロー・複数モジュールにまたがる変更）を含むか、実行側が原因の失敗ループでの昇格か、事前分類（聖域パス・マージ権限・層間契約・課金/法務）に当たれば 上位（`opus`）。**W を `fable` で spawn してはならない**（MUST NOT。実行役の上限は `opus` で、強制層は `scripts/agent-model-guard.sh`）。R1 は既定 上位（`opus`）、仕様がマージ条件・層間契約・課金/法務に触れれば `subagent_type: dev-workflow:decider` で spawn する（聖域パスだけでは上げない）。G は既定 中位（`sonnet`）で上げない（G の仕事は照合・ラベル操作で、欠陥探索は Codex か `needs-reviewer` のレビュアーが担う）。G が要求するレビュアーは既定 上位（`opus`）、対象がマージ条件・層間契約・課金/法務に触れれば `dev-workflow:decider`。従来経路では G の `needs-reviewer` が示す推奨 model に従い、adapter 経路では phase `review` の `request` が返した `model`（残量上限を適用済み）を使い、G の推奨 model は参考値として扱わなければならない（MUST）。役割の格は残量モード（`FABLE_BUDGET_MODE`）と共有枠モード（`SHARED_BUDGET_MODE`。全モデル共通の週次枠から導出）の上限に従わなければならない（MUST。新しい起動への適用は `request` が行う）。2 つのモードの値ごとの効果は `plugins/dev-workflow/skills/develop/references/decision-criteria.md` の残量モードと共有枠モードの表 1 か所で定める（その表では、`abundant` はどの役割の既定も上げず、`reserve` は自動実行のみ、`exhausted` は全経路で `opus` 上限、`throttled` は W / R1 / G の既定を `sonnet` に落として昇格上限 `opus`、`depleted` は全役割 `sonnet` 固定で、Fable 残量モードと食い違えば共有枠モードが勝つ。これは SKILL.md が書く中身ではない）。SKILL.md の「モデル」節は 2 つのモードの名前（`FABLE_BUDGET_MODE`・`SHARED_BUDGET_MODE`）と、効果がその表にあることだけを書かなければならない（MUST。値ごとの効果を再掲してはならない。同じ規則を 2 か所に書くと、直すときに片方が漏れて食い違うため）。実行戦略の 3 分岐（solo / delegate+verify / workflow 型）の記述と決定論的シグナルの収集コマンドは develop に存在してはならない（MUST NOT）。昇格トリップワイヤー（同じテストが 2 連続で落ちた・同じ箇所を 2 回書き直した）は、失敗の原因が判断側か実行側かで決める役と実行役のどちらか一方だけを上げるラダー（正本は `templates/escalation-tripwires.md`）として残す（SHALL）。本体は W / G を SendMessage で再開する前に毎回 `scripts/subagent-context.sh <名前>` でコンテキスト量を測らなければならない（MUST）。上限超過（exit 2）を検知したあとの扱い（送ってはならない SendMessage・手渡しを行ってよい条件・return の 1 行目にどちらの宣言を置くか・前任が動作中のまま交代させるときの手順）について、SKILL.md は本文を書かず、`plugins/dev-workflow/skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」への参照だけを置かなければならない（MUST。正本の位置・参照だけにする面の一覧・テストの形は `dev-workflow-execution-strategy` が規定する）。

この要件の守備範囲で入力として扱うのは、G の起動・再開指示にある `レビュー経路:`、G の `needs-reviewer` が示す推奨 model、phase `review` の `request` が返す `model` である。防ぐ誤りは、経路ごとの決定元を取り違えること、`request` が返した model を G の推奨 model で上書きすること、`request` の値を本体が文章の規則で計算し直すことである。一方、`request` が `sonnet` を返して G が `opus` を推奨していても、`request` の値を採用することは許容する。任意の不正な経路・model・残量モード入力を検出して塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 役割別の既定モデルと昇格条件が書かれている
- **WHEN** SKILL.md の「モデル」節を読む
- **THEN** W の既定が 中位（`sonnet`）で上限が 上位（`opus`）、R1 の既定が 上位（`opus`）、G の既定が 中位（`sonnet`）、事前分類（聖域パス・マージ権限・層間契約・課金/法務）で W は `opus` 止まり、R1 とレビュアーの fable は `dev-workflow:decider` 経由と書かれている
- **AND** `FABLE_BUDGET_MODE` と `SHARED_BUDGET_MODE` の効果は `references/decision-criteria.md` の表を見るよう書かれており、`abundant`・`reserve`・`exhausted`・`throttled`・`depleted` の値ごとの効果を述べた文は無い

#### Scenario: レビュアーの model 決定元を経路で分ける
- **WHEN** SKILL.md の「G が要求するレビュアー」の行を読む
- **THEN** 従来経路では G の推奨 model に従い、adapter 経路では `request` が返した `model` を使って推奨 model は参考値とする、と書かれている

#### Scenario: 経路ごとのモデル名の書き分けが無い
- **WHEN** `awk '/^## モデル/{f=1;next} /^## /{f=0} f' plugins/dev-workflow/skills/develop/SKILL.md | grep -cE 'claude-write-codex-review|codex-standard'` を実行する
- **THEN** 0 を返す

#### Scenario: 失敗ループでは片方だけ上げる
- **WHEN** SKILL.md の失敗ループの記述を読む
- **THEN** 決める役と実行役のどちらを上げるかを失敗の原因分類で決め、両方同時に上げないこと、実行役の上限が `opus` であることが書かれている

#### Scenario: 再開前にコンテキスト量を測る
- **WHEN** SKILL.md の「1 ループ」節を読む
- **THEN** W / G を SendMessage で再開する前に `subagent-context.sh` で測ること、G の再開も同じであること、上限超過のあとの扱いは `plugins/dev-workflow/skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本であることが参照として書かれている
- **AND** そこに手渡しの条件・宣言の選び方・停止確認の手順を言い換えた文は無い

### Requirement: 本体は role profile から executor を選ぶ
develop 本体は、Claude 既定の経路を含めて、新しい role を起動する直前に事前分類・設計判断・失敗の原因・自動実行かどうかを共通 resolver（`codex-develop.py request`）に渡し、canonical role の executor/account/model/effort を取得して、executor=claude なら Agent、executor=codex なら foreground request/run 経路を選ばなければならない（MUST）。resolver が `role: decider` を返したとき（事前分類に当たる R1 または G が要求したレビュアー）は、`subagent_type: dev-workflow:decider` として起動しなければならない（MUST）。本体は resolver の `requested_model`・`model`・`tier_reason` を要求 model・適用 model・変更理由として記録し、Agent には `model` を渡さなければならない（MUST）。上限を文章の規則で再計算してはならない（MUST NOT）。executor の選択は transport と execution setting だけを変え、仕様化判断、工程順、独立レビュー、差戻し上限、verify、archive、PR gate の条件を変えてはならない（MUST NOT）。

#### Scenario: 1 つの profile で executor が工程間に変わる
- **WHEN** spec-write=codex、spec-review=claude の profile で仕様化工程を進める
- **THEN** W は Codex foreground 経路、R1 は Claude Agent 経路で別 thread として動き、R1 の APPROVE が記録されるまで実装へ進まない

#### Scenario: 事前分類に当たる R1 またはレビュアーを起動する
- **WHEN** R1 または G が要求したレビュアーの対象がマージ条件・層間契約・課金/法務に触れる
- **THEN** 本体が `--pre-class` を渡した `request` が `role: decider` と構成の `decider` entry の executor/account を返し、本体は `subagent_type: dev-workflow:decider` として起動する

#### Scenario: executor 切替でも canonical role を維持する
- **WHEN** 同じ role の executor を profile で Claude から Codex または Codex から Claude へ変える
- **THEN** role の指示書、read-only/write 権限、return 契約、記録先、次工程の判定は変わらず、provider 固有の起動操作だけが変わる

#### Scenario: 通常モードでは要求 model をそのまま適用する
- **WHEN** decider の resolver 結果が `requested_model`=`fable` で、Fable と共有枠の残量モードがその model を制限しない
- **THEN** `model`=`fable`、`tier_reason`=`unchanged` で、本体はその `model` で Agent を起動する

#### Scenario: exhausted は Fable 要求を Opus に制限する
- **WHEN** decider を `FABLE_BUDGET_MODE=exhausted`、`SHARED_BUDGET_MODE=ok` で解決する
- **THEN** resolver は `requested_model`=`fable`、`model`=`opus`、`tier_reason`=`FABLE_BUDGET_MODE=exhausted` を返し、本体はその `model` で Agent を起動する

#### Scenario: depleted はすべての要求を Sonnet に固定する
- **WHEN** Claude の decider を `SHARED_BUDGET_MODE=depleted` で解決する
- **THEN** resolver は `requested_model`=`fable`、`model`=`sonnet`、`tier_reason`=`SHARED_BUDGET_MODE=depleted` を返し、本体はその `model` で Agent を起動する
