# Design: model-allocation

## Context

longrun の自律実行（Review → Build → Verify）は 7 種の agent（`plugins/longrun/agents/*.md`）で構成され、現状は**全 7 agent が frontmatter で `model: opus`** を指定している。タスクの性質（定型的検証・要約 vs 複雑な TDD 実装）にかかわらず一律最上位モデルが使われ、コスト・レイテンシの最適化余地が大きい。

本 change は run「harness 大型改修」の change-4 であり、以下の 2 つの先行 change の上に乗る（**依存**）:

- **change-2 (workflow-exec)**: `/longrun:exec` を Workflow ツール載せ替え（v6.0.0）。本 change の `opts.model` 消費は change-2 が導入する workflow スクリプト生成ロジックの拡張として実装する。`opts.model` の正確なセマンティクスは change-2 の実機検証成果物 `_longruns/<run>/workflow-tool-reference.md` を一次ソースとする
- **change-3 (mvp-plan-split)**: MVP モードを `longrun-mvp-plan` に分離済み（v6.1.0）。本 change の推奨生成ステップは**分離後のフルモード `longrun-plan` スキルのみ**に追加する。MVP plan スキルは対象外（MVP plan.md は人間実装前提で exec パイプラインに乗らないため）

Workflow ツールの仕様上、**`opts.model` は agent 定義 frontmatter の `model:` 指定より優先される**。この優先順位が本機構の前提であり、agent .md を書き換えずにロール × change 単位でモデルを差し替えられる根拠である。

バージョン: longrun 6.1.0 → 6.2.0（plugin.json / marketplace.json top-level / marketplace.json plugins[] の 3 箇所同期）。lr プラグインは変更なし。

## Goals / Non-Goals

**Goals:**

- plan 段階で change × agent ロールごとの推奨モデルティアを生成し、plan.md の表としてユーザーが確認・直接編集できるようにする
- exec が表を読み `opts.model` として機械的に消費する経路を作る（推奨ロジックは plan 側、消費は exec 側、という責務分離）
- ティア → モデル ID の対応を `plugins/longrun/references/model-tiers.md` の 1 箇所に集約し、ハードコード散在を構造的に禁止する
- モデル割り当てセクションの無い旧 plan.md でも exec が無変更で動く（全 inherit フォールバック）

**Non-Goals:**

- agent 定義 frontmatter（`model: opus`）の変更（change-2 ルール「既存 agent 定義 7 種の .md は書き直さない」を踏襲）
- MVP plan スキル（`longrun-mvp-plan`）へのモデル割り当て導入
- 実行時の動的なモデル切り替え（コスト超過時の自動降格等）。割り当ては plan 確定時に静的に決まる
- opus を明示ティアとして追加すること（inherit で代替。Decisions 参照）

## Decisions

### D1: ティア語彙は haiku / sonnet / inherit の 3 値とし、opus ティアは設けない

- **選択肢**: (a) haiku/sonnet/opus/inherit の 4 値 / (b) haiku/sonnet/inherit の 3 値
- **決定**: (b)
- **理由**: 全 7 agent が frontmatter で `model: opus` を持つため、`inherit`（= `opts.model` を渡さない）は現状 opus に解決される。opus ティアを別に設けると「inherit と opus の違いは何か」という混乱を生み、かつ agent 定義側が将来 `model:` を外した場合に二重管理になる。「高能力が必要 = 指定しない」は Workflow ツール自体の保守的設計指針（不要な上書きをしない）とも整合する

### D2: inherit のセマンティクスは「opts.model キーを出力しない」

- **選択肢**: (a) `opts.model: 'inherit'` のような明示値を渡す / (b) キー自体を省略する
- **決定**: (b)
- **理由**: `opts.model` は agent 定義の `model:` より優先されるため、何らかの値を渡すと agent frontmatter の指定（opus）を意図せず上書きするリスクがある。キーを省略すれば Workflow ツールの既定の解決順（agent 定義 → 親セッション）がそのまま働き、現状では全 agent が `model: opus` を持つので opus に解決される。将来 agent 定義が `model:` を持たなくなった場合も親セッション継承として自然に縮退する

### D3: ティア → モデル ID 対応は references/model-tiers.md の 1 箇所に集約し、他ファイルはティア名のみを扱う

- **選択肢**: (a) exec の workflow 生成テンプレートに ID を直書き / (b) plan.md に解決済み ID を書き込む / (c) リファレンスドキュメント 1 箇所で解決
- **決定**: (c)。plan.md・SKILL.md・workflow スクリプト生成テンプレートはティア名（haiku/sonnet/inherit）だけを扱い、exec が workflow スクリプト生成時に `references/model-tiers.md` を読んで解決する
- **理由**: モデル ID は世代交代で変わる。散在すると更新漏れで無言のドリフトが起きる（本 run のゴール「散文契約のドリフト排除」と同根の問題）。1 箇所参照なら新世代対応はリファレンスドキュメントの 1 行変更で済む。config.yaml rule「モデル ID のハードコードを plan.md・workflow スクリプトに散在させない」をそのまま実装する

### D4: 上書き欄 > ティア欄 の優先順位。上書き欄もティア語彙で記入する

- **選択肢**: (a) 上書き欄にモデル ID を直接書かせる / (b) 上書き欄もティア名で書かせる
- **決定**: (b)。`上書き` 欄が非空ならティア欄より優先し、値はティア語彙（haiku/sonnet/inherit）として解釈する
- **理由**: ユーザー編集面でも D3 の「ティア名のみを扱う」原則を貫く。推奨（ティア欄 + 理由）を保存したまま上書きの事実が表に残るため、後から推奨と実際の乖離をレビューできる

### D5: 未知ティア値・パース不能行は inherit + 警告で続行（fail-soft）

- **選択肢**: (a) エラーで exec を中断 / (b) inherit に倒して警告表示し続行
- **決定**: (b)
- **理由**: モデル割り当ては最適化機構であり、正しく読めないことが run を止める理由にならない。inherit は「agent 定義どおり」という最も安全な動作。保守的デフォルト「迷ったら inherit」を実装レベルでも適用する。セクション自体が無い旧 plan.md の全 inherit フォールバックも同じ分岐の特殊ケースとして実装できる

### D6: 推奨ヒューリスティクスは longrun-plan SKILL.md 側に持ち、exec は判断しない

- **選択肢**: (a) exec が実行時にロールから自動推定 / (b) plan 段階で推奨を生成しユーザー確認を経て確定
- **決定**: (b)
- **理由**: plan 確認はユーザーが必ず通るゲートであり、そこに表として出せば上書き機会が自然に提供される。exec は「表を読んで渡すだけ」の機械的処理に留めることで、change-2 の workflow 生成ロジックへの追加が最小になり、推奨ロジックの改善（ヒューリスティクス調整）が exec に波及しない

## Risks / Trade-offs

- [`opts.model` が受け付ける値の形式（エイリアス か フルモデル ID か）が想定と異なる] → change-2 の `workflow-tool-reference.md`（実機検証済み一次ソース）を実装前に必ず参照する。差異があっても変更は `references/model-tiers.md` の解決値 1 箇所で吸収できる（D3 の効果）
- [change-2 / change-3 が未マージのまま本 change を実装すると、exec・SKILL.md の編集対象が存在しない] → 実行順序を change-2 → change-3 → change-4 の直列で固定済み（plan.md の依存関係定義）。本 change の worktree は change-3 の PR マージ後に切る
- [ユーザーの直接編集で表の Markdown が崩れ、パース不能になる] → D5 の fail-soft（inherit + 警告）で run は止まらない。警告にどの行が読めなかったかを含め、ユーザーが修正して再実行できるようにする
- [haiku 割り当てが過剰になり成果物品質が落ちる] → ヒューリスティクスは「定型的検証・要約」に限定して haiku を推奨し、確信度が低ければ inherit に倒す。Verify ループ（change-2 の 4 軸スコア + 上限 3 周）が品質低下時の検出網として機能する
- [リファレンスドキュメントの更新忘れでティア解決が陳腐化する] → 集約先が 1 ファイルである時点で更新コストは最小。モデル世代交代時の更新箇所として README からも `references/model-tiers.md` へリンクする

## Migration Plan

1. `references/model-tiers.md` 新設 → plan-template.md セクション追加 → SKILL.md 推奨生成ステップ追加 → exec 消費ロジック追加 → version 3 箇所同期、の順で実装する（各ステップが独立に bats 検証可能）
2. **後方互換**: モデル割り当てセクションの無い既存 plan.md（_longruns/ 配下の過去 run・進行中 run）は全 inherit フォールバックで従来どおり動く。plan.md の移行作業は不要
3. **ロールバック**: 本機構は追加的（plan-template のセクション + exec の任意読み取り）であり、6.1.0 に戻せば旧動作に完全復帰する。plan.md に書かれた割り当て表は旧 exec からは単なる無視されるセクションになるだけで害がない

## Open Questions

- `opts.model` に渡す具体的な値（`'haiku'` / `'sonnet'` のエイリアスで足りるか、フルモデル ID が必要か）は change-2 の `workflow-tool-reference.md` 確定後に `references/model-tiers.md` の解決値として記入する（仕様・設計はどちらでも変わらない）
