# develop のモデル解決の現状（#613）

Dispatch HEAD `219ccc5a60ccbccb4faa3fa736b4748c67027c08` の記録。規則の変更や新たな優先順位の指定ではない。

## 読み方と範囲

次の表は **8 役 × 7 構成分岐 × 4 Fable モード × 3 共有枠モード = 672 行**。
`tests/test_model_resolution_current.py` の動的 unittest 672 ケースと、表の (役, 構成, モード) 行数が一致する。
既存 `test_codex_develop.py` のケース数はこの 672 に含めない。`auto:` は profile の明示指定と区別する。
自動選択は Claude/Codex の margin がそれぞれ `(20,10)`、`(-5,30)`、`(20,-5)` の 3 分岐。
両方不足・Claude に余裕があり Codex が不足または欠測・両方欠測・Codex off も最後の claude-default に合流する（選択理由の既存テストは別途存在）。
旧形式の `--account` / `--model` は全 role が `codex:` 指定 model になり、外部 `--profile-file` は固定表の外にある。どちらも 672 行に含めない。

`request` 列は CLI が返す **requested (executor, model)**。残量モードでは変わらない。
Claude の `applied` は本体が Agent 起動直前に文章の規則で決める値であり、Python が返す値ではない。
この列はコードによる cap 実行を検証した結果ではない。Codex の applied は返却値と同じで、Claude の残量上限は適用しない。
`I/U` は interactive / 自動実行（unmanned・cron・loop）。reserve のみ両者で Fable 上限が異なる。
`F/S` は FABLE_BUDGET_MODE / SHARED_BUDGET_MODE。環境変数の未設定・不正値の導出はここでの全組み合わせに含めない。

`review` は `impl-review` の互換別名（profile 検証で同値が必須）。独立した CLI phase は存在せず、テストは両方とも `--phase review` を通す。
`spec-write` は `--phase spec`、`implement` は `--phase implement`。finish / gate も adapter では implement entry を使う。
Claude だけで本体がモデルを決める従来経路（以下「文章既定」）は、adapter が `claude-default` を返したあと、本体が文章の規則で決める値である。`auto:claude-default` の request 列はその手前で CLI が返す値で、残量上限や事前分類は反映されない。

参照元:
- [profile の固定表](codex-role-profiles.json)、[request 実装](../scripts/codex-develop.py)（claude_default / build_request / PHASES）
- [モデル節](../skills/develop/SKILL.md#モデル)、[事前分類](../skills/develop/references/pre-classification.md)
- [R1 の指示書](../skills/develop/references/roles/spec-reviewer.md)、[G の指示書](../skills/develop/references/roles/gate-runner.md)、[worker 索引](../skills/develop/references/roles/worker.md)（現在は分類本文を持たず段別指示書への索引）
- [残量モード表](../skills/develop/references/decision-criteria.md#残量モード-fable_budget_mode)、[adapter の本体操作](codex-develop.md#本体が行う操作)
- [失敗の昇格ラダー](../templates/escalation-tripwires.md)

## 文章既定の経路（同じ役・構成・モード軸への対応）

構成が「文章既定」のときの読み取りをここに置く。下の 672 行の adapter 出力ケースには加算しない。
各行のモード軸は、後述のモード表の全 12 組を適用する。`C:` は executor=claude。

| 役 | 通常 | 設計判断を含む | 事前分類 | 失敗による変更 |
|---|---|---|---|---|
| spec-write（W） | C:sonnet | C:opus | C:opus | 役自身のモデルは変わらない。実行側の失敗では W を opus で再開する（上限は opus） |
| implement（W） | C:sonnet | C:opus | C:opus | 役自身のモデルは変わらない。実行側の失敗では W を opus で再開する（上限は opus） |
| spec-review（R1） | C:opus | C:opus | decider に切替、C:fable（※） | 役自身のモデルは変わらない。判断側は decider を別に起こす |
| impl-review / review（レビュアー） | C:opus | C:opus | decider に切替、C:fable（※） | 役自身のモデルは変わらない。判断側は decider を別に起こす |
| decider | C:fable（種別の既定） | 用途による明示値 | C:fable | 初回失敗は opus、判断側の2回目は fable |
| explore / summarize | C:haiku（機械的作業） | 専用の設計昇格の記載なし | 専用の分類昇格の記載なし | 専用ラダーの記載なし |
| gate-runner（G、8役の外） | C:sonnet | 上げない | 上げない | 欠陥探索は独立レビュアーへ |
| 画面確認（V、8役の外） | C:sonnet | 上げない | 上げない | 専用ラダーの記載なし |
| 引き継ぎ判定（8役の外） | C:opus を明示（depleted では起こさない） | 同左 | 同左 | 専用ラダーの記載なし |

explore / summarize の Haiku は [model-tiers.md](model-tiers.md) の最安ティア（ファイル探索・grep 的な調査・機械的編集・fan-out ワーカー・要約）と、decision-criteria.md の「結果が変わらない大量トークン仕事は常に安いモデル」の方針に、adapter の既定を対応させたもの。
モデル節にこの2役を名指しした独立の役割表はないため、文章経路の全調査作業が必ず Haiku になるという意味ではない。

※ 食い違い（聖域パスだけの R1/レビュアー）: 上げる側は [pre-classification.md](../skills/develop/references/pre-classification.md) 20 行目（4分類に当たる R1/レビュアーは decider）と decision-criteria.md 106 行目（事前分類に当たれば decider で Fable）。上げない側は SKILL.md 288・292 行目、spec-reviewer.md 33 行目、gate-runner.md 118 行目、pr-review-gate の prepare.md 87 行目（聖域パスだけでは上げない、聖域パスは opus 止まり）。
この記録では両記述を残し、聖域だけのレビューの値を一方に統一しない。

| F/S モード | W/R1/G の通常起点 | 分類・設計による W | 決める役の上限 I/U |
|---|---|---|---|
| abundant/ok | 役割表どおり | opus | fable/fable |
| conserve/ok | 役割表どおり | opus | fable/fable |
| reserve/ok | 役割表どおり | opus | fable/opus |
| exhausted/ok | 役割表どおり | opus | opus/opus |
| abundant/throttled | sonnet | opus 上限 | opus/opus |
| conserve/throttled | sonnet | opus 上限 | opus/opus |
| reserve/throttled | sonnet | opus 上限 | opus/opus |
| exhausted/throttled | sonnet | opus 上限 | opus/opus |
| abundant/depleted | sonnet | sonnet | sonnet/sonnet |
| conserve/depleted | sonnet | sonnet | sonnet/sonnet |
| reserve/depleted | sonnet | sonnet | sonnet/sonnet |
| exhausted/depleted | sonnet | sonnet | sonnet/sonnet |

共有枠が優先する。abundant でも役割の既定は上げない。throttled は Sonnet 起点・Opus 上限。
Claude profile の通常起動の opus レビューは throttled で Sonnet 起点、fable decider は Opus 上限。
haiku は throttled ではそのまま（文章に明記はなく、「残量モードの影響を受けない」と depleted の「落とす」からの読み取り）、depleted は requested にかかわらず sonnet 固定。
事前分類に当たる R1/レビュアーは adapter でも元の review entry でなく **decider entry** に切り替えるため、下表の decider 行を参照する。
文章既定の失敗ラダーは、初回失敗で decider=opus・W=sonnet、2回目の実行側失敗で W=opus、判断側失敗で decider=fable。
判断側と実行側を同時に上げない。
ゲート由来の昇格は別系統で、pr-review-gate の 2-2 に従う。段 A だけで戻した failed では昇格せず W のモデルを据え置く。fable のレート制限では decider を `model: opus` に落とし、model-tiers.md 39 行目の形で 1 行残す。
上限を超えた分はモード表で抑え、depleted では昇格しない。fable が決めて opus が実行しても落ちたら人間へ返す。fable を使えないモード（reserve の自動実行・exhausted・共有枠制約）では、Opus が決めて Opus が実行しても2連続失敗なら人間へ返す。
コンテキスト上限は手渡しの条件で、モデル昇格の条件ではない。

## 食い違いセルの一覧

下表の † は、同じ役・モードの文章既定との差を持つ返却セル。対象集合を次に列挙する（実行結果の不具合とは断定しない）。

† は、request 列の値が同じモードの文章既定の applied と異なるセルの印。
- †C: 全構成の executor=codex セル。文章既定の executor=claude と異なる。Claude の残量モードで Codex model は変わらない。Codex の W は設計判断・事前分類・失敗でも model が変わらない。
- †W: claude-write-codex-review と auto:claude-write-codex-review、および auto:claude-default の spec-write / implement の全12モード。requested は sonnet 固定。設計判断・事前分類の文章既定は depleted 以外で opus（depleted では applied が sonnet に合流）。実行側の失敗での opus 昇格も request には現れない。
- †R: hybrid-standard と auto:claude-default の spec-review / impl-review / review のthrottled / depleted の8モードだけ（ok の4モードは文章既定の opus と同じで印なし）。requested は opus 固定で、通常起点が sonnet になるため異なる。重要レビューでは元のセルではなく decider entry を使う。
- †H: claude-write-codex-review・auto:claude-write-codex-review・auto:claude-default の explore / summarize の depleted の4モード。requested は haiku 固定だが、文章では depleted が全役割 sonnet 固定。
- †D: hybrid-standard と auto:claude-default の decider の全12モード。requested は fable 固定だが、失敗1回目の文章ラダーは opus。reserve の自動実行・exhausted・共有枠制約で applied も下がる。
- 事前分類で opus になった W が1回目の失敗後どのモデルになるかは、文章に書かれていない。
- throttled の haiku を据え置くかは文章に明記がなく、読み取りである（上の注記）。
- 聖域だけの R1/レビュアーの文章間の食い違いは上記 ※。固定 profile の decider 切替に関する説明も4分類を参照しており、この曖昧さを解消していない。
- G は文章既定で sonnet 固定だが、adapter の phase gate は implement entry を使う。codex-standard / hybrid-standard は codex:sol、codex-economy は codex:luna。この差も通常の W と G を同一役と解釈して隠さない。

## request の全672ケース

| 役 | 構成 | F/S モード | request (executor:model) | Claude applied I/U または Codex model |
|---|---|---|---|---|
| spec-write | codex-standard | abundant/ok | codex:sol †C | sol/sol |
| spec-write | codex-standard | abundant/throttled | codex:sol †C | sol/sol |
| spec-write | codex-standard | abundant/depleted | codex:sol †C | sol/sol |
| spec-write | codex-standard | conserve/ok | codex:sol †C | sol/sol |
| spec-write | codex-standard | conserve/throttled | codex:sol †C | sol/sol |
| spec-write | codex-standard | conserve/depleted | codex:sol †C | sol/sol |
| spec-write | codex-standard | reserve/ok | codex:sol †C | sol/sol |
| spec-write | codex-standard | reserve/throttled | codex:sol †C | sol/sol |
| spec-write | codex-standard | reserve/depleted | codex:sol †C | sol/sol |
| spec-write | codex-standard | exhausted/ok | codex:sol †C | sol/sol |
| spec-write | codex-standard | exhausted/throttled | codex:sol †C | sol/sol |
| spec-write | codex-standard | exhausted/depleted | codex:sol †C | sol/sol |
| spec-review | codex-standard | abundant/ok | codex:sol †C | sol/sol |
| spec-review | codex-standard | abundant/throttled | codex:sol †C | sol/sol |
| spec-review | codex-standard | abundant/depleted | codex:sol †C | sol/sol |
| spec-review | codex-standard | conserve/ok | codex:sol †C | sol/sol |
| spec-review | codex-standard | conserve/throttled | codex:sol †C | sol/sol |
| spec-review | codex-standard | conserve/depleted | codex:sol †C | sol/sol |
| spec-review | codex-standard | reserve/ok | codex:sol †C | sol/sol |
| spec-review | codex-standard | reserve/throttled | codex:sol †C | sol/sol |
| spec-review | codex-standard | reserve/depleted | codex:sol †C | sol/sol |
| spec-review | codex-standard | exhausted/ok | codex:sol †C | sol/sol |
| spec-review | codex-standard | exhausted/throttled | codex:sol †C | sol/sol |
| spec-review | codex-standard | exhausted/depleted | codex:sol †C | sol/sol |
| implement | codex-standard | abundant/ok | codex:sol †C | sol/sol |
| implement | codex-standard | abundant/throttled | codex:sol †C | sol/sol |
| implement | codex-standard | abundant/depleted | codex:sol †C | sol/sol |
| implement | codex-standard | conserve/ok | codex:sol †C | sol/sol |
| implement | codex-standard | conserve/throttled | codex:sol †C | sol/sol |
| implement | codex-standard | conserve/depleted | codex:sol †C | sol/sol |
| implement | codex-standard | reserve/ok | codex:sol †C | sol/sol |
| implement | codex-standard | reserve/throttled | codex:sol †C | sol/sol |
| implement | codex-standard | reserve/depleted | codex:sol †C | sol/sol |
| implement | codex-standard | exhausted/ok | codex:sol †C | sol/sol |
| implement | codex-standard | exhausted/throttled | codex:sol †C | sol/sol |
| implement | codex-standard | exhausted/depleted | codex:sol †C | sol/sol |
| impl-review | codex-standard | abundant/ok | codex:sol †C | sol/sol |
| impl-review | codex-standard | abundant/throttled | codex:sol †C | sol/sol |
| impl-review | codex-standard | abundant/depleted | codex:sol †C | sol/sol |
| impl-review | codex-standard | conserve/ok | codex:sol †C | sol/sol |
| impl-review | codex-standard | conserve/throttled | codex:sol †C | sol/sol |
| impl-review | codex-standard | conserve/depleted | codex:sol †C | sol/sol |
| impl-review | codex-standard | reserve/ok | codex:sol †C | sol/sol |
| impl-review | codex-standard | reserve/throttled | codex:sol †C | sol/sol |
| impl-review | codex-standard | reserve/depleted | codex:sol †C | sol/sol |
| impl-review | codex-standard | exhausted/ok | codex:sol †C | sol/sol |
| impl-review | codex-standard | exhausted/throttled | codex:sol †C | sol/sol |
| impl-review | codex-standard | exhausted/depleted | codex:sol †C | sol/sol |
| review | codex-standard | abundant/ok | codex:sol †C | sol/sol |
| review | codex-standard | abundant/throttled | codex:sol †C | sol/sol |
| review | codex-standard | abundant/depleted | codex:sol †C | sol/sol |
| review | codex-standard | conserve/ok | codex:sol †C | sol/sol |
| review | codex-standard | conserve/throttled | codex:sol †C | sol/sol |
| review | codex-standard | conserve/depleted | codex:sol †C | sol/sol |
| review | codex-standard | reserve/ok | codex:sol †C | sol/sol |
| review | codex-standard | reserve/throttled | codex:sol †C | sol/sol |
| review | codex-standard | reserve/depleted | codex:sol †C | sol/sol |
| review | codex-standard | exhausted/ok | codex:sol †C | sol/sol |
| review | codex-standard | exhausted/throttled | codex:sol †C | sol/sol |
| review | codex-standard | exhausted/depleted | codex:sol †C | sol/sol |
| decider | codex-standard | abundant/ok | codex:astra †C | astra/astra |
| decider | codex-standard | abundant/throttled | codex:astra †C | astra/astra |
| decider | codex-standard | abundant/depleted | codex:astra †C | astra/astra |
| decider | codex-standard | conserve/ok | codex:astra †C | astra/astra |
| decider | codex-standard | conserve/throttled | codex:astra †C | astra/astra |
| decider | codex-standard | conserve/depleted | codex:astra †C | astra/astra |
| decider | codex-standard | reserve/ok | codex:astra †C | astra/astra |
| decider | codex-standard | reserve/throttled | codex:astra †C | astra/astra |
| decider | codex-standard | reserve/depleted | codex:astra †C | astra/astra |
| decider | codex-standard | exhausted/ok | codex:astra †C | astra/astra |
| decider | codex-standard | exhausted/throttled | codex:astra †C | astra/astra |
| decider | codex-standard | exhausted/depleted | codex:astra †C | astra/astra |
| explore | codex-standard | abundant/ok | codex:luna †C | luna/luna |
| explore | codex-standard | abundant/throttled | codex:luna †C | luna/luna |
| explore | codex-standard | abundant/depleted | codex:luna †C | luna/luna |
| explore | codex-standard | conserve/ok | codex:luna †C | luna/luna |
| explore | codex-standard | conserve/throttled | codex:luna †C | luna/luna |
| explore | codex-standard | conserve/depleted | codex:luna †C | luna/luna |
| explore | codex-standard | reserve/ok | codex:luna †C | luna/luna |
| explore | codex-standard | reserve/throttled | codex:luna †C | luna/luna |
| explore | codex-standard | reserve/depleted | codex:luna †C | luna/luna |
| explore | codex-standard | exhausted/ok | codex:luna †C | luna/luna |
| explore | codex-standard | exhausted/throttled | codex:luna †C | luna/luna |
| explore | codex-standard | exhausted/depleted | codex:luna †C | luna/luna |
| summarize | codex-standard | abundant/ok | codex:luna †C | luna/luna |
| summarize | codex-standard | abundant/throttled | codex:luna †C | luna/luna |
| summarize | codex-standard | abundant/depleted | codex:luna †C | luna/luna |
| summarize | codex-standard | conserve/ok | codex:luna †C | luna/luna |
| summarize | codex-standard | conserve/throttled | codex:luna †C | luna/luna |
| summarize | codex-standard | conserve/depleted | codex:luna †C | luna/luna |
| summarize | codex-standard | reserve/ok | codex:luna †C | luna/luna |
| summarize | codex-standard | reserve/throttled | codex:luna †C | luna/luna |
| summarize | codex-standard | reserve/depleted | codex:luna †C | luna/luna |
| summarize | codex-standard | exhausted/ok | codex:luna †C | luna/luna |
| summarize | codex-standard | exhausted/throttled | codex:luna †C | luna/luna |
| summarize | codex-standard | exhausted/depleted | codex:luna †C | luna/luna |
| spec-write | codex-economy | abundant/ok | codex:luna †C | luna/luna |
| spec-write | codex-economy | abundant/throttled | codex:luna †C | luna/luna |
| spec-write | codex-economy | abundant/depleted | codex:luna †C | luna/luna |
| spec-write | codex-economy | conserve/ok | codex:luna †C | luna/luna |
| spec-write | codex-economy | conserve/throttled | codex:luna †C | luna/luna |
| spec-write | codex-economy | conserve/depleted | codex:luna †C | luna/luna |
| spec-write | codex-economy | reserve/ok | codex:luna †C | luna/luna |
| spec-write | codex-economy | reserve/throttled | codex:luna †C | luna/luna |
| spec-write | codex-economy | reserve/depleted | codex:luna †C | luna/luna |
| spec-write | codex-economy | exhausted/ok | codex:luna †C | luna/luna |
| spec-write | codex-economy | exhausted/throttled | codex:luna †C | luna/luna |
| spec-write | codex-economy | exhausted/depleted | codex:luna †C | luna/luna |
| spec-review | codex-economy | abundant/ok | codex:sol †C | sol/sol |
| spec-review | codex-economy | abundant/throttled | codex:sol †C | sol/sol |
| spec-review | codex-economy | abundant/depleted | codex:sol †C | sol/sol |
| spec-review | codex-economy | conserve/ok | codex:sol †C | sol/sol |
| spec-review | codex-economy | conserve/throttled | codex:sol †C | sol/sol |
| spec-review | codex-economy | conserve/depleted | codex:sol †C | sol/sol |
| spec-review | codex-economy | reserve/ok | codex:sol †C | sol/sol |
| spec-review | codex-economy | reserve/throttled | codex:sol †C | sol/sol |
| spec-review | codex-economy | reserve/depleted | codex:sol †C | sol/sol |
| spec-review | codex-economy | exhausted/ok | codex:sol †C | sol/sol |
| spec-review | codex-economy | exhausted/throttled | codex:sol †C | sol/sol |
| spec-review | codex-economy | exhausted/depleted | codex:sol †C | sol/sol |
| implement | codex-economy | abundant/ok | codex:luna †C | luna/luna |
| implement | codex-economy | abundant/throttled | codex:luna †C | luna/luna |
| implement | codex-economy | abundant/depleted | codex:luna †C | luna/luna |
| implement | codex-economy | conserve/ok | codex:luna †C | luna/luna |
| implement | codex-economy | conserve/throttled | codex:luna †C | luna/luna |
| implement | codex-economy | conserve/depleted | codex:luna †C | luna/luna |
| implement | codex-economy | reserve/ok | codex:luna †C | luna/luna |
| implement | codex-economy | reserve/throttled | codex:luna †C | luna/luna |
| implement | codex-economy | reserve/depleted | codex:luna †C | luna/luna |
| implement | codex-economy | exhausted/ok | codex:luna †C | luna/luna |
| implement | codex-economy | exhausted/throttled | codex:luna †C | luna/luna |
| implement | codex-economy | exhausted/depleted | codex:luna †C | luna/luna |
| impl-review | codex-economy | abundant/ok | codex:sol †C | sol/sol |
| impl-review | codex-economy | abundant/throttled | codex:sol †C | sol/sol |
| impl-review | codex-economy | abundant/depleted | codex:sol †C | sol/sol |
| impl-review | codex-economy | conserve/ok | codex:sol †C | sol/sol |
| impl-review | codex-economy | conserve/throttled | codex:sol †C | sol/sol |
| impl-review | codex-economy | conserve/depleted | codex:sol †C | sol/sol |
| impl-review | codex-economy | reserve/ok | codex:sol †C | sol/sol |
| impl-review | codex-economy | reserve/throttled | codex:sol †C | sol/sol |
| impl-review | codex-economy | reserve/depleted | codex:sol †C | sol/sol |
| impl-review | codex-economy | exhausted/ok | codex:sol †C | sol/sol |
| impl-review | codex-economy | exhausted/throttled | codex:sol †C | sol/sol |
| impl-review | codex-economy | exhausted/depleted | codex:sol †C | sol/sol |
| review | codex-economy | abundant/ok | codex:sol †C | sol/sol |
| review | codex-economy | abundant/throttled | codex:sol †C | sol/sol |
| review | codex-economy | abundant/depleted | codex:sol †C | sol/sol |
| review | codex-economy | conserve/ok | codex:sol †C | sol/sol |
| review | codex-economy | conserve/throttled | codex:sol †C | sol/sol |
| review | codex-economy | conserve/depleted | codex:sol †C | sol/sol |
| review | codex-economy | reserve/ok | codex:sol †C | sol/sol |
| review | codex-economy | reserve/throttled | codex:sol †C | sol/sol |
| review | codex-economy | reserve/depleted | codex:sol †C | sol/sol |
| review | codex-economy | exhausted/ok | codex:sol †C | sol/sol |
| review | codex-economy | exhausted/throttled | codex:sol †C | sol/sol |
| review | codex-economy | exhausted/depleted | codex:sol †C | sol/sol |
| decider | codex-economy | abundant/ok | codex:astra †C | astra/astra |
| decider | codex-economy | abundant/throttled | codex:astra †C | astra/astra |
| decider | codex-economy | abundant/depleted | codex:astra †C | astra/astra |
| decider | codex-economy | conserve/ok | codex:astra †C | astra/astra |
| decider | codex-economy | conserve/throttled | codex:astra †C | astra/astra |
| decider | codex-economy | conserve/depleted | codex:astra †C | astra/astra |
| decider | codex-economy | reserve/ok | codex:astra †C | astra/astra |
| decider | codex-economy | reserve/throttled | codex:astra †C | astra/astra |
| decider | codex-economy | reserve/depleted | codex:astra †C | astra/astra |
| decider | codex-economy | exhausted/ok | codex:astra †C | astra/astra |
| decider | codex-economy | exhausted/throttled | codex:astra †C | astra/astra |
| decider | codex-economy | exhausted/depleted | codex:astra †C | astra/astra |
| explore | codex-economy | abundant/ok | codex:luna †C | luna/luna |
| explore | codex-economy | abundant/throttled | codex:luna †C | luna/luna |
| explore | codex-economy | abundant/depleted | codex:luna †C | luna/luna |
| explore | codex-economy | conserve/ok | codex:luna †C | luna/luna |
| explore | codex-economy | conserve/throttled | codex:luna †C | luna/luna |
| explore | codex-economy | conserve/depleted | codex:luna †C | luna/luna |
| explore | codex-economy | reserve/ok | codex:luna †C | luna/luna |
| explore | codex-economy | reserve/throttled | codex:luna †C | luna/luna |
| explore | codex-economy | reserve/depleted | codex:luna †C | luna/luna |
| explore | codex-economy | exhausted/ok | codex:luna †C | luna/luna |
| explore | codex-economy | exhausted/throttled | codex:luna †C | luna/luna |
| explore | codex-economy | exhausted/depleted | codex:luna †C | luna/luna |
| summarize | codex-economy | abundant/ok | codex:luna †C | luna/luna |
| summarize | codex-economy | abundant/throttled | codex:luna †C | luna/luna |
| summarize | codex-economy | abundant/depleted | codex:luna †C | luna/luna |
| summarize | codex-economy | conserve/ok | codex:luna †C | luna/luna |
| summarize | codex-economy | conserve/throttled | codex:luna †C | luna/luna |
| summarize | codex-economy | conserve/depleted | codex:luna †C | luna/luna |
| summarize | codex-economy | reserve/ok | codex:luna †C | luna/luna |
| summarize | codex-economy | reserve/throttled | codex:luna †C | luna/luna |
| summarize | codex-economy | reserve/depleted | codex:luna †C | luna/luna |
| summarize | codex-economy | exhausted/ok | codex:luna †C | luna/luna |
| summarize | codex-economy | exhausted/throttled | codex:luna †C | luna/luna |
| summarize | codex-economy | exhausted/depleted | codex:luna †C | luna/luna |
| spec-write | hybrid-standard | abundant/ok | codex:sol †C | sol/sol |
| spec-write | hybrid-standard | abundant/throttled | codex:sol †C | sol/sol |
| spec-write | hybrid-standard | abundant/depleted | codex:sol †C | sol/sol |
| spec-write | hybrid-standard | conserve/ok | codex:sol †C | sol/sol |
| spec-write | hybrid-standard | conserve/throttled | codex:sol †C | sol/sol |
| spec-write | hybrid-standard | conserve/depleted | codex:sol †C | sol/sol |
| spec-write | hybrid-standard | reserve/ok | codex:sol †C | sol/sol |
| spec-write | hybrid-standard | reserve/throttled | codex:sol †C | sol/sol |
| spec-write | hybrid-standard | reserve/depleted | codex:sol †C | sol/sol |
| spec-write | hybrid-standard | exhausted/ok | codex:sol †C | sol/sol |
| spec-write | hybrid-standard | exhausted/throttled | codex:sol †C | sol/sol |
| spec-write | hybrid-standard | exhausted/depleted | codex:sol †C | sol/sol |
| spec-review | hybrid-standard | abundant/ok | claude:opus | opus/opus |
| spec-review | hybrid-standard | abundant/throttled | claude:opus †R | sonnet/sonnet |
| spec-review | hybrid-standard | abundant/depleted | claude:opus †R | sonnet/sonnet |
| spec-review | hybrid-standard | conserve/ok | claude:opus | opus/opus |
| spec-review | hybrid-standard | conserve/throttled | claude:opus †R | sonnet/sonnet |
| spec-review | hybrid-standard | conserve/depleted | claude:opus †R | sonnet/sonnet |
| spec-review | hybrid-standard | reserve/ok | claude:opus | opus/opus |
| spec-review | hybrid-standard | reserve/throttled | claude:opus †R | sonnet/sonnet |
| spec-review | hybrid-standard | reserve/depleted | claude:opus †R | sonnet/sonnet |
| spec-review | hybrid-standard | exhausted/ok | claude:opus | opus/opus |
| spec-review | hybrid-standard | exhausted/throttled | claude:opus †R | sonnet/sonnet |
| spec-review | hybrid-standard | exhausted/depleted | claude:opus †R | sonnet/sonnet |
| implement | hybrid-standard | abundant/ok | codex:sol †C | sol/sol |
| implement | hybrid-standard | abundant/throttled | codex:sol †C | sol/sol |
| implement | hybrid-standard | abundant/depleted | codex:sol †C | sol/sol |
| implement | hybrid-standard | conserve/ok | codex:sol †C | sol/sol |
| implement | hybrid-standard | conserve/throttled | codex:sol †C | sol/sol |
| implement | hybrid-standard | conserve/depleted | codex:sol †C | sol/sol |
| implement | hybrid-standard | reserve/ok | codex:sol †C | sol/sol |
| implement | hybrid-standard | reserve/throttled | codex:sol †C | sol/sol |
| implement | hybrid-standard | reserve/depleted | codex:sol †C | sol/sol |
| implement | hybrid-standard | exhausted/ok | codex:sol †C | sol/sol |
| implement | hybrid-standard | exhausted/throttled | codex:sol †C | sol/sol |
| implement | hybrid-standard | exhausted/depleted | codex:sol †C | sol/sol |
| impl-review | hybrid-standard | abundant/ok | claude:opus | opus/opus |
| impl-review | hybrid-standard | abundant/throttled | claude:opus †R | sonnet/sonnet |
| impl-review | hybrid-standard | abundant/depleted | claude:opus †R | sonnet/sonnet |
| impl-review | hybrid-standard | conserve/ok | claude:opus | opus/opus |
| impl-review | hybrid-standard | conserve/throttled | claude:opus †R | sonnet/sonnet |
| impl-review | hybrid-standard | conserve/depleted | claude:opus †R | sonnet/sonnet |
| impl-review | hybrid-standard | reserve/ok | claude:opus | opus/opus |
| impl-review | hybrid-standard | reserve/throttled | claude:opus †R | sonnet/sonnet |
| impl-review | hybrid-standard | reserve/depleted | claude:opus †R | sonnet/sonnet |
| impl-review | hybrid-standard | exhausted/ok | claude:opus | opus/opus |
| impl-review | hybrid-standard | exhausted/throttled | claude:opus †R | sonnet/sonnet |
| impl-review | hybrid-standard | exhausted/depleted | claude:opus †R | sonnet/sonnet |
| review | hybrid-standard | abundant/ok | claude:opus | opus/opus |
| review | hybrid-standard | abundant/throttled | claude:opus †R | sonnet/sonnet |
| review | hybrid-standard | abundant/depleted | claude:opus †R | sonnet/sonnet |
| review | hybrid-standard | conserve/ok | claude:opus | opus/opus |
| review | hybrid-standard | conserve/throttled | claude:opus †R | sonnet/sonnet |
| review | hybrid-standard | conserve/depleted | claude:opus †R | sonnet/sonnet |
| review | hybrid-standard | reserve/ok | claude:opus | opus/opus |
| review | hybrid-standard | reserve/throttled | claude:opus †R | sonnet/sonnet |
| review | hybrid-standard | reserve/depleted | claude:opus †R | sonnet/sonnet |
| review | hybrid-standard | exhausted/ok | claude:opus | opus/opus |
| review | hybrid-standard | exhausted/throttled | claude:opus †R | sonnet/sonnet |
| review | hybrid-standard | exhausted/depleted | claude:opus †R | sonnet/sonnet |
| decider | hybrid-standard | abundant/ok | claude:fable †D | fable/fable |
| decider | hybrid-standard | abundant/throttled | claude:fable †D | opus/opus |
| decider | hybrid-standard | abundant/depleted | claude:fable †D | sonnet/sonnet |
| decider | hybrid-standard | conserve/ok | claude:fable †D | fable/fable |
| decider | hybrid-standard | conserve/throttled | claude:fable †D | opus/opus |
| decider | hybrid-standard | conserve/depleted | claude:fable †D | sonnet/sonnet |
| decider | hybrid-standard | reserve/ok | claude:fable †D | fable/opus |
| decider | hybrid-standard | reserve/throttled | claude:fable †D | opus/opus |
| decider | hybrid-standard | reserve/depleted | claude:fable †D | sonnet/sonnet |
| decider | hybrid-standard | exhausted/ok | claude:fable †D | opus/opus |
| decider | hybrid-standard | exhausted/throttled | claude:fable †D | opus/opus |
| decider | hybrid-standard | exhausted/depleted | claude:fable †D | sonnet/sonnet |
| explore | hybrid-standard | abundant/ok | codex:luna †C | luna/luna |
| explore | hybrid-standard | abundant/throttled | codex:luna †C | luna/luna |
| explore | hybrid-standard | abundant/depleted | codex:luna †C | luna/luna |
| explore | hybrid-standard | conserve/ok | codex:luna †C | luna/luna |
| explore | hybrid-standard | conserve/throttled | codex:luna †C | luna/luna |
| explore | hybrid-standard | conserve/depleted | codex:luna †C | luna/luna |
| explore | hybrid-standard | reserve/ok | codex:luna †C | luna/luna |
| explore | hybrid-standard | reserve/throttled | codex:luna †C | luna/luna |
| explore | hybrid-standard | reserve/depleted | codex:luna †C | luna/luna |
| explore | hybrid-standard | exhausted/ok | codex:luna †C | luna/luna |
| explore | hybrid-standard | exhausted/throttled | codex:luna †C | luna/luna |
| explore | hybrid-standard | exhausted/depleted | codex:luna †C | luna/luna |
| summarize | hybrid-standard | abundant/ok | codex:luna †C | luna/luna |
| summarize | hybrid-standard | abundant/throttled | codex:luna †C | luna/luna |
| summarize | hybrid-standard | abundant/depleted | codex:luna †C | luna/luna |
| summarize | hybrid-standard | conserve/ok | codex:luna †C | luna/luna |
| summarize | hybrid-standard | conserve/throttled | codex:luna †C | luna/luna |
| summarize | hybrid-standard | conserve/depleted | codex:luna †C | luna/luna |
| summarize | hybrid-standard | reserve/ok | codex:luna †C | luna/luna |
| summarize | hybrid-standard | reserve/throttled | codex:luna †C | luna/luna |
| summarize | hybrid-standard | reserve/depleted | codex:luna †C | luna/luna |
| summarize | hybrid-standard | exhausted/ok | codex:luna †C | luna/luna |
| summarize | hybrid-standard | exhausted/throttled | codex:luna †C | luna/luna |
| summarize | hybrid-standard | exhausted/depleted | codex:luna †C | luna/luna |
| spec-write | claude-write-codex-review | abundant/ok | claude:sonnet †W | sonnet/sonnet |
| spec-write | claude-write-codex-review | abundant/throttled | claude:sonnet †W | sonnet/sonnet |
| spec-write | claude-write-codex-review | abundant/depleted | claude:sonnet †W | sonnet/sonnet |
| spec-write | claude-write-codex-review | conserve/ok | claude:sonnet †W | sonnet/sonnet |
| spec-write | claude-write-codex-review | conserve/throttled | claude:sonnet †W | sonnet/sonnet |
| spec-write | claude-write-codex-review | conserve/depleted | claude:sonnet †W | sonnet/sonnet |
| spec-write | claude-write-codex-review | reserve/ok | claude:sonnet †W | sonnet/sonnet |
| spec-write | claude-write-codex-review | reserve/throttled | claude:sonnet †W | sonnet/sonnet |
| spec-write | claude-write-codex-review | reserve/depleted | claude:sonnet †W | sonnet/sonnet |
| spec-write | claude-write-codex-review | exhausted/ok | claude:sonnet †W | sonnet/sonnet |
| spec-write | claude-write-codex-review | exhausted/throttled | claude:sonnet †W | sonnet/sonnet |
| spec-write | claude-write-codex-review | exhausted/depleted | claude:sonnet †W | sonnet/sonnet |
| spec-review | claude-write-codex-review | abundant/ok | codex:sol †C | sol/sol |
| spec-review | claude-write-codex-review | abundant/throttled | codex:sol †C | sol/sol |
| spec-review | claude-write-codex-review | abundant/depleted | codex:sol †C | sol/sol |
| spec-review | claude-write-codex-review | conserve/ok | codex:sol †C | sol/sol |
| spec-review | claude-write-codex-review | conserve/throttled | codex:sol †C | sol/sol |
| spec-review | claude-write-codex-review | conserve/depleted | codex:sol †C | sol/sol |
| spec-review | claude-write-codex-review | reserve/ok | codex:sol †C | sol/sol |
| spec-review | claude-write-codex-review | reserve/throttled | codex:sol †C | sol/sol |
| spec-review | claude-write-codex-review | reserve/depleted | codex:sol †C | sol/sol |
| spec-review | claude-write-codex-review | exhausted/ok | codex:sol †C | sol/sol |
| spec-review | claude-write-codex-review | exhausted/throttled | codex:sol †C | sol/sol |
| spec-review | claude-write-codex-review | exhausted/depleted | codex:sol †C | sol/sol |
| implement | claude-write-codex-review | abundant/ok | claude:sonnet †W | sonnet/sonnet |
| implement | claude-write-codex-review | abundant/throttled | claude:sonnet †W | sonnet/sonnet |
| implement | claude-write-codex-review | abundant/depleted | claude:sonnet †W | sonnet/sonnet |
| implement | claude-write-codex-review | conserve/ok | claude:sonnet †W | sonnet/sonnet |
| implement | claude-write-codex-review | conserve/throttled | claude:sonnet †W | sonnet/sonnet |
| implement | claude-write-codex-review | conserve/depleted | claude:sonnet †W | sonnet/sonnet |
| implement | claude-write-codex-review | reserve/ok | claude:sonnet †W | sonnet/sonnet |
| implement | claude-write-codex-review | reserve/throttled | claude:sonnet †W | sonnet/sonnet |
| implement | claude-write-codex-review | reserve/depleted | claude:sonnet †W | sonnet/sonnet |
| implement | claude-write-codex-review | exhausted/ok | claude:sonnet †W | sonnet/sonnet |
| implement | claude-write-codex-review | exhausted/throttled | claude:sonnet †W | sonnet/sonnet |
| implement | claude-write-codex-review | exhausted/depleted | claude:sonnet †W | sonnet/sonnet |
| impl-review | claude-write-codex-review | abundant/ok | codex:sol †C | sol/sol |
| impl-review | claude-write-codex-review | abundant/throttled | codex:sol †C | sol/sol |
| impl-review | claude-write-codex-review | abundant/depleted | codex:sol †C | sol/sol |
| impl-review | claude-write-codex-review | conserve/ok | codex:sol †C | sol/sol |
| impl-review | claude-write-codex-review | conserve/throttled | codex:sol †C | sol/sol |
| impl-review | claude-write-codex-review | conserve/depleted | codex:sol †C | sol/sol |
| impl-review | claude-write-codex-review | reserve/ok | codex:sol †C | sol/sol |
| impl-review | claude-write-codex-review | reserve/throttled | codex:sol †C | sol/sol |
| impl-review | claude-write-codex-review | reserve/depleted | codex:sol †C | sol/sol |
| impl-review | claude-write-codex-review | exhausted/ok | codex:sol †C | sol/sol |
| impl-review | claude-write-codex-review | exhausted/throttled | codex:sol †C | sol/sol |
| impl-review | claude-write-codex-review | exhausted/depleted | codex:sol †C | sol/sol |
| review | claude-write-codex-review | abundant/ok | codex:sol †C | sol/sol |
| review | claude-write-codex-review | abundant/throttled | codex:sol †C | sol/sol |
| review | claude-write-codex-review | abundant/depleted | codex:sol †C | sol/sol |
| review | claude-write-codex-review | conserve/ok | codex:sol †C | sol/sol |
| review | claude-write-codex-review | conserve/throttled | codex:sol †C | sol/sol |
| review | claude-write-codex-review | conserve/depleted | codex:sol †C | sol/sol |
| review | claude-write-codex-review | reserve/ok | codex:sol †C | sol/sol |
| review | claude-write-codex-review | reserve/throttled | codex:sol †C | sol/sol |
| review | claude-write-codex-review | reserve/depleted | codex:sol †C | sol/sol |
| review | claude-write-codex-review | exhausted/ok | codex:sol †C | sol/sol |
| review | claude-write-codex-review | exhausted/throttled | codex:sol †C | sol/sol |
| review | claude-write-codex-review | exhausted/depleted | codex:sol †C | sol/sol |
| decider | claude-write-codex-review | abundant/ok | codex:astra †C | astra/astra |
| decider | claude-write-codex-review | abundant/throttled | codex:astra †C | astra/astra |
| decider | claude-write-codex-review | abundant/depleted | codex:astra †C | astra/astra |
| decider | claude-write-codex-review | conserve/ok | codex:astra †C | astra/astra |
| decider | claude-write-codex-review | conserve/throttled | codex:astra †C | astra/astra |
| decider | claude-write-codex-review | conserve/depleted | codex:astra †C | astra/astra |
| decider | claude-write-codex-review | reserve/ok | codex:astra †C | astra/astra |
| decider | claude-write-codex-review | reserve/throttled | codex:astra †C | astra/astra |
| decider | claude-write-codex-review | reserve/depleted | codex:astra †C | astra/astra |
| decider | claude-write-codex-review | exhausted/ok | codex:astra †C | astra/astra |
| decider | claude-write-codex-review | exhausted/throttled | codex:astra †C | astra/astra |
| decider | claude-write-codex-review | exhausted/depleted | codex:astra †C | astra/astra |
| explore | claude-write-codex-review | abundant/ok | claude:haiku | haiku/haiku |
| explore | claude-write-codex-review | abundant/throttled | claude:haiku | haiku/haiku |
| explore | claude-write-codex-review | abundant/depleted | claude:haiku †H | sonnet/sonnet |
| explore | claude-write-codex-review | conserve/ok | claude:haiku | haiku/haiku |
| explore | claude-write-codex-review | conserve/throttled | claude:haiku | haiku/haiku |
| explore | claude-write-codex-review | conserve/depleted | claude:haiku †H | sonnet/sonnet |
| explore | claude-write-codex-review | reserve/ok | claude:haiku | haiku/haiku |
| explore | claude-write-codex-review | reserve/throttled | claude:haiku | haiku/haiku |
| explore | claude-write-codex-review | reserve/depleted | claude:haiku †H | sonnet/sonnet |
| explore | claude-write-codex-review | exhausted/ok | claude:haiku | haiku/haiku |
| explore | claude-write-codex-review | exhausted/throttled | claude:haiku | haiku/haiku |
| explore | claude-write-codex-review | exhausted/depleted | claude:haiku †H | sonnet/sonnet |
| summarize | claude-write-codex-review | abundant/ok | claude:haiku | haiku/haiku |
| summarize | claude-write-codex-review | abundant/throttled | claude:haiku | haiku/haiku |
| summarize | claude-write-codex-review | abundant/depleted | claude:haiku †H | sonnet/sonnet |
| summarize | claude-write-codex-review | conserve/ok | claude:haiku | haiku/haiku |
| summarize | claude-write-codex-review | conserve/throttled | claude:haiku | haiku/haiku |
| summarize | claude-write-codex-review | conserve/depleted | claude:haiku †H | sonnet/sonnet |
| summarize | claude-write-codex-review | reserve/ok | claude:haiku | haiku/haiku |
| summarize | claude-write-codex-review | reserve/throttled | claude:haiku | haiku/haiku |
| summarize | claude-write-codex-review | reserve/depleted | claude:haiku †H | sonnet/sonnet |
| summarize | claude-write-codex-review | exhausted/ok | claude:haiku | haiku/haiku |
| summarize | claude-write-codex-review | exhausted/throttled | claude:haiku | haiku/haiku |
| summarize | claude-write-codex-review | exhausted/depleted | claude:haiku †H | sonnet/sonnet |
| spec-write | auto:claude-write-codex-review | abundant/ok | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-write-codex-review | abundant/throttled | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-write-codex-review | abundant/depleted | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-write-codex-review | conserve/ok | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-write-codex-review | conserve/throttled | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-write-codex-review | conserve/depleted | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-write-codex-review | reserve/ok | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-write-codex-review | reserve/throttled | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-write-codex-review | reserve/depleted | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-write-codex-review | exhausted/ok | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-write-codex-review | exhausted/throttled | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-write-codex-review | exhausted/depleted | claude:sonnet †W | sonnet/sonnet |
| spec-review | auto:claude-write-codex-review | abundant/ok | codex:sol †C | sol/sol |
| spec-review | auto:claude-write-codex-review | abundant/throttled | codex:sol †C | sol/sol |
| spec-review | auto:claude-write-codex-review | abundant/depleted | codex:sol †C | sol/sol |
| spec-review | auto:claude-write-codex-review | conserve/ok | codex:sol †C | sol/sol |
| spec-review | auto:claude-write-codex-review | conserve/throttled | codex:sol †C | sol/sol |
| spec-review | auto:claude-write-codex-review | conserve/depleted | codex:sol †C | sol/sol |
| spec-review | auto:claude-write-codex-review | reserve/ok | codex:sol †C | sol/sol |
| spec-review | auto:claude-write-codex-review | reserve/throttled | codex:sol †C | sol/sol |
| spec-review | auto:claude-write-codex-review | reserve/depleted | codex:sol †C | sol/sol |
| spec-review | auto:claude-write-codex-review | exhausted/ok | codex:sol †C | sol/sol |
| spec-review | auto:claude-write-codex-review | exhausted/throttled | codex:sol †C | sol/sol |
| spec-review | auto:claude-write-codex-review | exhausted/depleted | codex:sol †C | sol/sol |
| implement | auto:claude-write-codex-review | abundant/ok | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-write-codex-review | abundant/throttled | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-write-codex-review | abundant/depleted | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-write-codex-review | conserve/ok | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-write-codex-review | conserve/throttled | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-write-codex-review | conserve/depleted | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-write-codex-review | reserve/ok | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-write-codex-review | reserve/throttled | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-write-codex-review | reserve/depleted | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-write-codex-review | exhausted/ok | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-write-codex-review | exhausted/throttled | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-write-codex-review | exhausted/depleted | claude:sonnet †W | sonnet/sonnet |
| impl-review | auto:claude-write-codex-review | abundant/ok | codex:sol †C | sol/sol |
| impl-review | auto:claude-write-codex-review | abundant/throttled | codex:sol †C | sol/sol |
| impl-review | auto:claude-write-codex-review | abundant/depleted | codex:sol †C | sol/sol |
| impl-review | auto:claude-write-codex-review | conserve/ok | codex:sol †C | sol/sol |
| impl-review | auto:claude-write-codex-review | conserve/throttled | codex:sol †C | sol/sol |
| impl-review | auto:claude-write-codex-review | conserve/depleted | codex:sol †C | sol/sol |
| impl-review | auto:claude-write-codex-review | reserve/ok | codex:sol †C | sol/sol |
| impl-review | auto:claude-write-codex-review | reserve/throttled | codex:sol †C | sol/sol |
| impl-review | auto:claude-write-codex-review | reserve/depleted | codex:sol †C | sol/sol |
| impl-review | auto:claude-write-codex-review | exhausted/ok | codex:sol †C | sol/sol |
| impl-review | auto:claude-write-codex-review | exhausted/throttled | codex:sol †C | sol/sol |
| impl-review | auto:claude-write-codex-review | exhausted/depleted | codex:sol †C | sol/sol |
| review | auto:claude-write-codex-review | abundant/ok | codex:sol †C | sol/sol |
| review | auto:claude-write-codex-review | abundant/throttled | codex:sol †C | sol/sol |
| review | auto:claude-write-codex-review | abundant/depleted | codex:sol †C | sol/sol |
| review | auto:claude-write-codex-review | conserve/ok | codex:sol †C | sol/sol |
| review | auto:claude-write-codex-review | conserve/throttled | codex:sol †C | sol/sol |
| review | auto:claude-write-codex-review | conserve/depleted | codex:sol †C | sol/sol |
| review | auto:claude-write-codex-review | reserve/ok | codex:sol †C | sol/sol |
| review | auto:claude-write-codex-review | reserve/throttled | codex:sol †C | sol/sol |
| review | auto:claude-write-codex-review | reserve/depleted | codex:sol †C | sol/sol |
| review | auto:claude-write-codex-review | exhausted/ok | codex:sol †C | sol/sol |
| review | auto:claude-write-codex-review | exhausted/throttled | codex:sol †C | sol/sol |
| review | auto:claude-write-codex-review | exhausted/depleted | codex:sol †C | sol/sol |
| decider | auto:claude-write-codex-review | abundant/ok | codex:astra †C | astra/astra |
| decider | auto:claude-write-codex-review | abundant/throttled | codex:astra †C | astra/astra |
| decider | auto:claude-write-codex-review | abundant/depleted | codex:astra †C | astra/astra |
| decider | auto:claude-write-codex-review | conserve/ok | codex:astra †C | astra/astra |
| decider | auto:claude-write-codex-review | conserve/throttled | codex:astra †C | astra/astra |
| decider | auto:claude-write-codex-review | conserve/depleted | codex:astra †C | astra/astra |
| decider | auto:claude-write-codex-review | reserve/ok | codex:astra †C | astra/astra |
| decider | auto:claude-write-codex-review | reserve/throttled | codex:astra †C | astra/astra |
| decider | auto:claude-write-codex-review | reserve/depleted | codex:astra †C | astra/astra |
| decider | auto:claude-write-codex-review | exhausted/ok | codex:astra †C | astra/astra |
| decider | auto:claude-write-codex-review | exhausted/throttled | codex:astra †C | astra/astra |
| decider | auto:claude-write-codex-review | exhausted/depleted | codex:astra †C | astra/astra |
| explore | auto:claude-write-codex-review | abundant/ok | claude:haiku | haiku/haiku |
| explore | auto:claude-write-codex-review | abundant/throttled | claude:haiku | haiku/haiku |
| explore | auto:claude-write-codex-review | abundant/depleted | claude:haiku †H | sonnet/sonnet |
| explore | auto:claude-write-codex-review | conserve/ok | claude:haiku | haiku/haiku |
| explore | auto:claude-write-codex-review | conserve/throttled | claude:haiku | haiku/haiku |
| explore | auto:claude-write-codex-review | conserve/depleted | claude:haiku †H | sonnet/sonnet |
| explore | auto:claude-write-codex-review | reserve/ok | claude:haiku | haiku/haiku |
| explore | auto:claude-write-codex-review | reserve/throttled | claude:haiku | haiku/haiku |
| explore | auto:claude-write-codex-review | reserve/depleted | claude:haiku †H | sonnet/sonnet |
| explore | auto:claude-write-codex-review | exhausted/ok | claude:haiku | haiku/haiku |
| explore | auto:claude-write-codex-review | exhausted/throttled | claude:haiku | haiku/haiku |
| explore | auto:claude-write-codex-review | exhausted/depleted | claude:haiku †H | sonnet/sonnet |
| summarize | auto:claude-write-codex-review | abundant/ok | claude:haiku | haiku/haiku |
| summarize | auto:claude-write-codex-review | abundant/throttled | claude:haiku | haiku/haiku |
| summarize | auto:claude-write-codex-review | abundant/depleted | claude:haiku †H | sonnet/sonnet |
| summarize | auto:claude-write-codex-review | conserve/ok | claude:haiku | haiku/haiku |
| summarize | auto:claude-write-codex-review | conserve/throttled | claude:haiku | haiku/haiku |
| summarize | auto:claude-write-codex-review | conserve/depleted | claude:haiku †H | sonnet/sonnet |
| summarize | auto:claude-write-codex-review | reserve/ok | claude:haiku | haiku/haiku |
| summarize | auto:claude-write-codex-review | reserve/throttled | claude:haiku | haiku/haiku |
| summarize | auto:claude-write-codex-review | reserve/depleted | claude:haiku †H | sonnet/sonnet |
| summarize | auto:claude-write-codex-review | exhausted/ok | claude:haiku | haiku/haiku |
| summarize | auto:claude-write-codex-review | exhausted/throttled | claude:haiku | haiku/haiku |
| summarize | auto:claude-write-codex-review | exhausted/depleted | claude:haiku †H | sonnet/sonnet |
| spec-write | auto:codex-standard | abundant/ok | codex:sol †C | sol/sol |
| spec-write | auto:codex-standard | abundant/throttled | codex:sol †C | sol/sol |
| spec-write | auto:codex-standard | abundant/depleted | codex:sol †C | sol/sol |
| spec-write | auto:codex-standard | conserve/ok | codex:sol †C | sol/sol |
| spec-write | auto:codex-standard | conserve/throttled | codex:sol †C | sol/sol |
| spec-write | auto:codex-standard | conserve/depleted | codex:sol †C | sol/sol |
| spec-write | auto:codex-standard | reserve/ok | codex:sol †C | sol/sol |
| spec-write | auto:codex-standard | reserve/throttled | codex:sol †C | sol/sol |
| spec-write | auto:codex-standard | reserve/depleted | codex:sol †C | sol/sol |
| spec-write | auto:codex-standard | exhausted/ok | codex:sol †C | sol/sol |
| spec-write | auto:codex-standard | exhausted/throttled | codex:sol †C | sol/sol |
| spec-write | auto:codex-standard | exhausted/depleted | codex:sol †C | sol/sol |
| spec-review | auto:codex-standard | abundant/ok | codex:sol †C | sol/sol |
| spec-review | auto:codex-standard | abundant/throttled | codex:sol †C | sol/sol |
| spec-review | auto:codex-standard | abundant/depleted | codex:sol †C | sol/sol |
| spec-review | auto:codex-standard | conserve/ok | codex:sol †C | sol/sol |
| spec-review | auto:codex-standard | conserve/throttled | codex:sol †C | sol/sol |
| spec-review | auto:codex-standard | conserve/depleted | codex:sol †C | sol/sol |
| spec-review | auto:codex-standard | reserve/ok | codex:sol †C | sol/sol |
| spec-review | auto:codex-standard | reserve/throttled | codex:sol †C | sol/sol |
| spec-review | auto:codex-standard | reserve/depleted | codex:sol †C | sol/sol |
| spec-review | auto:codex-standard | exhausted/ok | codex:sol †C | sol/sol |
| spec-review | auto:codex-standard | exhausted/throttled | codex:sol †C | sol/sol |
| spec-review | auto:codex-standard | exhausted/depleted | codex:sol †C | sol/sol |
| implement | auto:codex-standard | abundant/ok | codex:sol †C | sol/sol |
| implement | auto:codex-standard | abundant/throttled | codex:sol †C | sol/sol |
| implement | auto:codex-standard | abundant/depleted | codex:sol †C | sol/sol |
| implement | auto:codex-standard | conserve/ok | codex:sol †C | sol/sol |
| implement | auto:codex-standard | conserve/throttled | codex:sol †C | sol/sol |
| implement | auto:codex-standard | conserve/depleted | codex:sol †C | sol/sol |
| implement | auto:codex-standard | reserve/ok | codex:sol †C | sol/sol |
| implement | auto:codex-standard | reserve/throttled | codex:sol †C | sol/sol |
| implement | auto:codex-standard | reserve/depleted | codex:sol †C | sol/sol |
| implement | auto:codex-standard | exhausted/ok | codex:sol †C | sol/sol |
| implement | auto:codex-standard | exhausted/throttled | codex:sol †C | sol/sol |
| implement | auto:codex-standard | exhausted/depleted | codex:sol †C | sol/sol |
| impl-review | auto:codex-standard | abundant/ok | codex:sol †C | sol/sol |
| impl-review | auto:codex-standard | abundant/throttled | codex:sol †C | sol/sol |
| impl-review | auto:codex-standard | abundant/depleted | codex:sol †C | sol/sol |
| impl-review | auto:codex-standard | conserve/ok | codex:sol †C | sol/sol |
| impl-review | auto:codex-standard | conserve/throttled | codex:sol †C | sol/sol |
| impl-review | auto:codex-standard | conserve/depleted | codex:sol †C | sol/sol |
| impl-review | auto:codex-standard | reserve/ok | codex:sol †C | sol/sol |
| impl-review | auto:codex-standard | reserve/throttled | codex:sol †C | sol/sol |
| impl-review | auto:codex-standard | reserve/depleted | codex:sol †C | sol/sol |
| impl-review | auto:codex-standard | exhausted/ok | codex:sol †C | sol/sol |
| impl-review | auto:codex-standard | exhausted/throttled | codex:sol †C | sol/sol |
| impl-review | auto:codex-standard | exhausted/depleted | codex:sol †C | sol/sol |
| review | auto:codex-standard | abundant/ok | codex:sol †C | sol/sol |
| review | auto:codex-standard | abundant/throttled | codex:sol †C | sol/sol |
| review | auto:codex-standard | abundant/depleted | codex:sol †C | sol/sol |
| review | auto:codex-standard | conserve/ok | codex:sol †C | sol/sol |
| review | auto:codex-standard | conserve/throttled | codex:sol †C | sol/sol |
| review | auto:codex-standard | conserve/depleted | codex:sol †C | sol/sol |
| review | auto:codex-standard | reserve/ok | codex:sol †C | sol/sol |
| review | auto:codex-standard | reserve/throttled | codex:sol †C | sol/sol |
| review | auto:codex-standard | reserve/depleted | codex:sol †C | sol/sol |
| review | auto:codex-standard | exhausted/ok | codex:sol †C | sol/sol |
| review | auto:codex-standard | exhausted/throttled | codex:sol †C | sol/sol |
| review | auto:codex-standard | exhausted/depleted | codex:sol †C | sol/sol |
| decider | auto:codex-standard | abundant/ok | codex:astra †C | astra/astra |
| decider | auto:codex-standard | abundant/throttled | codex:astra †C | astra/astra |
| decider | auto:codex-standard | abundant/depleted | codex:astra †C | astra/astra |
| decider | auto:codex-standard | conserve/ok | codex:astra †C | astra/astra |
| decider | auto:codex-standard | conserve/throttled | codex:astra †C | astra/astra |
| decider | auto:codex-standard | conserve/depleted | codex:astra †C | astra/astra |
| decider | auto:codex-standard | reserve/ok | codex:astra †C | astra/astra |
| decider | auto:codex-standard | reserve/throttled | codex:astra †C | astra/astra |
| decider | auto:codex-standard | reserve/depleted | codex:astra †C | astra/astra |
| decider | auto:codex-standard | exhausted/ok | codex:astra †C | astra/astra |
| decider | auto:codex-standard | exhausted/throttled | codex:astra †C | astra/astra |
| decider | auto:codex-standard | exhausted/depleted | codex:astra †C | astra/astra |
| explore | auto:codex-standard | abundant/ok | codex:luna †C | luna/luna |
| explore | auto:codex-standard | abundant/throttled | codex:luna †C | luna/luna |
| explore | auto:codex-standard | abundant/depleted | codex:luna †C | luna/luna |
| explore | auto:codex-standard | conserve/ok | codex:luna †C | luna/luna |
| explore | auto:codex-standard | conserve/throttled | codex:luna †C | luna/luna |
| explore | auto:codex-standard | conserve/depleted | codex:luna †C | luna/luna |
| explore | auto:codex-standard | reserve/ok | codex:luna †C | luna/luna |
| explore | auto:codex-standard | reserve/throttled | codex:luna †C | luna/luna |
| explore | auto:codex-standard | reserve/depleted | codex:luna †C | luna/luna |
| explore | auto:codex-standard | exhausted/ok | codex:luna †C | luna/luna |
| explore | auto:codex-standard | exhausted/throttled | codex:luna †C | luna/luna |
| explore | auto:codex-standard | exhausted/depleted | codex:luna †C | luna/luna |
| summarize | auto:codex-standard | abundant/ok | codex:luna †C | luna/luna |
| summarize | auto:codex-standard | abundant/throttled | codex:luna †C | luna/luna |
| summarize | auto:codex-standard | abundant/depleted | codex:luna †C | luna/luna |
| summarize | auto:codex-standard | conserve/ok | codex:luna †C | luna/luna |
| summarize | auto:codex-standard | conserve/throttled | codex:luna †C | luna/luna |
| summarize | auto:codex-standard | conserve/depleted | codex:luna †C | luna/luna |
| summarize | auto:codex-standard | reserve/ok | codex:luna †C | luna/luna |
| summarize | auto:codex-standard | reserve/throttled | codex:luna †C | luna/luna |
| summarize | auto:codex-standard | reserve/depleted | codex:luna †C | luna/luna |
| summarize | auto:codex-standard | exhausted/ok | codex:luna †C | luna/luna |
| summarize | auto:codex-standard | exhausted/throttled | codex:luna †C | luna/luna |
| summarize | auto:codex-standard | exhausted/depleted | codex:luna †C | luna/luna |
| spec-write | auto:claude-default | abundant/ok | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-default | abundant/throttled | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-default | abundant/depleted | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-default | conserve/ok | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-default | conserve/throttled | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-default | conserve/depleted | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-default | reserve/ok | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-default | reserve/throttled | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-default | reserve/depleted | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-default | exhausted/ok | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-default | exhausted/throttled | claude:sonnet †W | sonnet/sonnet |
| spec-write | auto:claude-default | exhausted/depleted | claude:sonnet †W | sonnet/sonnet |
| spec-review | auto:claude-default | abundant/ok | claude:opus | opus/opus |
| spec-review | auto:claude-default | abundant/throttled | claude:opus †R | sonnet/sonnet |
| spec-review | auto:claude-default | abundant/depleted | claude:opus †R | sonnet/sonnet |
| spec-review | auto:claude-default | conserve/ok | claude:opus | opus/opus |
| spec-review | auto:claude-default | conserve/throttled | claude:opus †R | sonnet/sonnet |
| spec-review | auto:claude-default | conserve/depleted | claude:opus †R | sonnet/sonnet |
| spec-review | auto:claude-default | reserve/ok | claude:opus | opus/opus |
| spec-review | auto:claude-default | reserve/throttled | claude:opus †R | sonnet/sonnet |
| spec-review | auto:claude-default | reserve/depleted | claude:opus †R | sonnet/sonnet |
| spec-review | auto:claude-default | exhausted/ok | claude:opus | opus/opus |
| spec-review | auto:claude-default | exhausted/throttled | claude:opus †R | sonnet/sonnet |
| spec-review | auto:claude-default | exhausted/depleted | claude:opus †R | sonnet/sonnet |
| implement | auto:claude-default | abundant/ok | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-default | abundant/throttled | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-default | abundant/depleted | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-default | conserve/ok | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-default | conserve/throttled | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-default | conserve/depleted | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-default | reserve/ok | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-default | reserve/throttled | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-default | reserve/depleted | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-default | exhausted/ok | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-default | exhausted/throttled | claude:sonnet †W | sonnet/sonnet |
| implement | auto:claude-default | exhausted/depleted | claude:sonnet †W | sonnet/sonnet |
| impl-review | auto:claude-default | abundant/ok | claude:opus | opus/opus |
| impl-review | auto:claude-default | abundant/throttled | claude:opus †R | sonnet/sonnet |
| impl-review | auto:claude-default | abundant/depleted | claude:opus †R | sonnet/sonnet |
| impl-review | auto:claude-default | conserve/ok | claude:opus | opus/opus |
| impl-review | auto:claude-default | conserve/throttled | claude:opus †R | sonnet/sonnet |
| impl-review | auto:claude-default | conserve/depleted | claude:opus †R | sonnet/sonnet |
| impl-review | auto:claude-default | reserve/ok | claude:opus | opus/opus |
| impl-review | auto:claude-default | reserve/throttled | claude:opus †R | sonnet/sonnet |
| impl-review | auto:claude-default | reserve/depleted | claude:opus †R | sonnet/sonnet |
| impl-review | auto:claude-default | exhausted/ok | claude:opus | opus/opus |
| impl-review | auto:claude-default | exhausted/throttled | claude:opus †R | sonnet/sonnet |
| impl-review | auto:claude-default | exhausted/depleted | claude:opus †R | sonnet/sonnet |
| review | auto:claude-default | abundant/ok | claude:opus | opus/opus |
| review | auto:claude-default | abundant/throttled | claude:opus †R | sonnet/sonnet |
| review | auto:claude-default | abundant/depleted | claude:opus †R | sonnet/sonnet |
| review | auto:claude-default | conserve/ok | claude:opus | opus/opus |
| review | auto:claude-default | conserve/throttled | claude:opus †R | sonnet/sonnet |
| review | auto:claude-default | conserve/depleted | claude:opus †R | sonnet/sonnet |
| review | auto:claude-default | reserve/ok | claude:opus | opus/opus |
| review | auto:claude-default | reserve/throttled | claude:opus †R | sonnet/sonnet |
| review | auto:claude-default | reserve/depleted | claude:opus †R | sonnet/sonnet |
| review | auto:claude-default | exhausted/ok | claude:opus | opus/opus |
| review | auto:claude-default | exhausted/throttled | claude:opus †R | sonnet/sonnet |
| review | auto:claude-default | exhausted/depleted | claude:opus †R | sonnet/sonnet |
| decider | auto:claude-default | abundant/ok | claude:fable †D | fable/fable |
| decider | auto:claude-default | abundant/throttled | claude:fable †D | opus/opus |
| decider | auto:claude-default | abundant/depleted | claude:fable †D | sonnet/sonnet |
| decider | auto:claude-default | conserve/ok | claude:fable †D | fable/fable |
| decider | auto:claude-default | conserve/throttled | claude:fable †D | opus/opus |
| decider | auto:claude-default | conserve/depleted | claude:fable †D | sonnet/sonnet |
| decider | auto:claude-default | reserve/ok | claude:fable †D | fable/opus |
| decider | auto:claude-default | reserve/throttled | claude:fable †D | opus/opus |
| decider | auto:claude-default | reserve/depleted | claude:fable †D | sonnet/sonnet |
| decider | auto:claude-default | exhausted/ok | claude:fable †D | opus/opus |
| decider | auto:claude-default | exhausted/throttled | claude:fable †D | opus/opus |
| decider | auto:claude-default | exhausted/depleted | claude:fable †D | sonnet/sonnet |
| explore | auto:claude-default | abundant/ok | claude:haiku | haiku/haiku |
| explore | auto:claude-default | abundant/throttled | claude:haiku | haiku/haiku |
| explore | auto:claude-default | abundant/depleted | claude:haiku †H | sonnet/sonnet |
| explore | auto:claude-default | conserve/ok | claude:haiku | haiku/haiku |
| explore | auto:claude-default | conserve/throttled | claude:haiku | haiku/haiku |
| explore | auto:claude-default | conserve/depleted | claude:haiku †H | sonnet/sonnet |
| explore | auto:claude-default | reserve/ok | claude:haiku | haiku/haiku |
| explore | auto:claude-default | reserve/throttled | claude:haiku | haiku/haiku |
| explore | auto:claude-default | reserve/depleted | claude:haiku †H | sonnet/sonnet |
| explore | auto:claude-default | exhausted/ok | claude:haiku | haiku/haiku |
| explore | auto:claude-default | exhausted/throttled | claude:haiku | haiku/haiku |
| explore | auto:claude-default | exhausted/depleted | claude:haiku †H | sonnet/sonnet |
| summarize | auto:claude-default | abundant/ok | claude:haiku | haiku/haiku |
| summarize | auto:claude-default | abundant/throttled | claude:haiku | haiku/haiku |
| summarize | auto:claude-default | abundant/depleted | claude:haiku †H | sonnet/sonnet |
| summarize | auto:claude-default | conserve/ok | claude:haiku | haiku/haiku |
| summarize | auto:claude-default | conserve/throttled | claude:haiku | haiku/haiku |
| summarize | auto:claude-default | conserve/depleted | claude:haiku †H | sonnet/sonnet |
| summarize | auto:claude-default | reserve/ok | claude:haiku | haiku/haiku |
| summarize | auto:claude-default | reserve/throttled | claude:haiku | haiku/haiku |
| summarize | auto:claude-default | reserve/depleted | claude:haiku †H | sonnet/sonnet |
| summarize | auto:claude-default | exhausted/ok | claude:haiku | haiku/haiku |
| summarize | auto:claude-default | exhausted/throttled | claude:haiku | haiku/haiku |
| summarize | auto:claude-default | exhausted/depleted | claude:haiku †H | sonnet/sonnet |
