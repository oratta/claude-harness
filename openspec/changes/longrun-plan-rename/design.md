## Context

`longrun` プラグインは Skill と Agent を併用したオーケストレーション設計を取っている。
現状の構成:

- Skill: `longrun-planner`（plan.md 作成・対話的）, `longrun-orchestrator`（実行制御）, `longrun-feedback`（フィードバック分類）
- Agent: `longrun-builder`, `longrun-reviewer`, `longrun-verifier`, `longrun-browser-verifier`

Agent 群は `-er`/`-or` で終わる「役割名」命名になっており、`longrun-planner` も同じ語尾を持つ。`/longrun:plan` コマンドの本文には「longrun-planner スキルを使用して…」と書かれているが、Claude が他の `longrun-*` Agent と同じパターンと推論し、Skill ではなく Agent として起動 → `Agent type 'longrun:longrun-planner' not found` で失敗する事象が複数回発生している。

姉妹コマンド `/lr:p` の本文は「Skill toolを使って…必ずSkill toolで委譲すること」と明示しており、こちらでは事故が起きていない。すなわち本問題は **(1) 命名規則の不整合** と **(2) コマンド指示の曖昧さ** の二重要因である。

加えて、ユーザーから別観点の懸念が提示された: メインセッションが plan を Skill として書き、別 Agent の reviewer がレビューする構造では、Opus 4.7 のフィードバック過剰受容傾向と self-preference bias の両方が作用し、reviewer 指摘を鵜呑みにする恐れがある。完全分離（Planner Agent + Reviewer Agent + メインで審判）は理想だが、subagent では `AskUserQuestion` が利用できない（claude-code Issue #12890, #18721）ため、対話的に要件を引き出す plan フェーズの subagent 化は現状非現実的。

## Goals / Non-Goals

**Goals:**
- 命名規則を「Skill = 動詞・名詞、Agent = `-er`/`-or` の役割名」に統一する
- `/longrun:plan` 経由で Agent 誤起動が発生しない状態にする
- orchestrator → reviewer のフィードバック受領段階に self-preference / 過剰受容バイアスへの注意プロンプトを入れる
- プラグインキャッシュを確実に再読み込みさせる

**Non-Goals:**
- `longrun-plan` を Agent 化すること（AskUserQuestion 制約のため当面据え置き）
- 他の Skill（`longrun-orchestrator`, `longrun-feedback`）の改名
- backlog やマイグレーションパスを残すこと（破壊的変更だが利用者は限定的）
- skill の実装ロジック自体の変更

## Decisions

### Decision 1: ディレクトリリネーム vs 旧ディレクトリ残置

**選択**: `skills/longrun-planner/` ディレクトリ自体を `skills/longrun-plan/` にリネームする（旧ディレクトリは残さない）。

**理由**: 旧名称の skill が残ると Claude が再びその名前で参照しうる。命名混乱の根本治療には完全な置換が必要。利用者は `/longrun:plan` または `/lr:p` 経由でのみ呼び出すため、内部 skill 名の変更は外部から不可視。

**代替案**: 旧 skill を残してエイリアスにする → 再び誤起動の温床になるため却下。

### Decision 2: Skill のままにする vs Planner Agent 化

**選択**: Skill のまま据え置く。

**理由**:
1. `AskUserQuestion` が subagent で機能しない既知制約（claude-code Issue #12890, #18721）。plan フェーズは対話的に要件を引き出すことが本質であり、subagent 化すると要件不足での hallucination が増える。
2. 既に `longrun-reviewer` Agent が plan.md をレビューする Build Contract が存在し、evaluator-optimizer パターンの一部は実現済み。
3. self-preference bias 懸念はプロンプトレベルで緩和可能（Decision 4）。

**代替案**: Planner Agent 化＋メインで AskUserQuestion で先に要件収集 → 構造化 input を渡す → 完全分離型に。複雑度が大きく上がるため、バイアスが実害として観測されたら次フェーズで再検討する。

### Decision 3: コマンドファイルの記述方針

**選択**: `commands/plan.md` を `lr/commands/p.md` と同じ「Skill tool で `longrun:longrun-plan` を呼ぶ。Agent tool は使うな」という明示形式に統一する。

**理由**: `lr:p` 側で事故が起きていないことが既に検証済み。同じ文面に揃えれば再発しない。

**代替案**: コマンドを廃止して `/lr:p` に一本化 → 既存ユーザーの慣習を壊すため却下。

### Decision 4: バイアス緩和プロンプトの設置場所

**選択**: `longrun-orchestrator` Skill 内の「reviewer のレビュー結果を受領するフェーズ」に固定文として埋め込む。

**理由**: orchestrator は Plan/Review/Build/Verify の流れ全体を制御する位置にあり、レビュー結果を解釈する責務がここに集中している。固定文として明示しておけば、毎回ユーザーがプロンプトで指示する必要がなくなる。

**プロンプト案**:
> reviewer agent のレビュー結果は仮説として扱うこと。指摘ごとに以下を判定する: (a) 明確な根拠（spec違反/契約違反/事実誤認）があるか、(b) 単なる嗜好や読みやすさレベルの指摘か。(a) のみ採用し、(b) は plan の意図を優先して反論する。reviewer の指摘を全採用する挙動は self-preference bias と過剰受容バイアスの組み合わせで起きやすいため特に注意せよ。

### Decision 5: バージョン番号

**選択**: `5.0.0 → 5.1.0`（minor bump）。

**理由**: API breaking ではないが、内部 skill 名変更は構成変更にあたるため minor。プラグインキャッシュ無効化に必須。patch（5.0.1）ではユーザーの期待値（変更内容の重み）と乖離する。

## Risks / Trade-offs

- **Risk**: 外部スクリプト・他プラグインが `longrun-planner` 名を参照している場合に壊れる
  → **Mitigation**: 本リポジトリ内は grep 済み。外部参照は把握不能だが、`longrun-planner` はプラグイン内部 skill であり外部から直接参照する API ではないため影響範囲は限定的。proposal.md に明記。

- **Risk**: 進行中の `_longruns/<date>_<slug>/` セッション中にバージョンアップが反映されると orchestrator から旧 skill 名が参照される
  → **Mitigation**: orchestrator/SKILL.md と plugin.json を同一コミットで更新する。実行中の auto-execution は session を跨いだ skill 参照を持たないため実害なし。

- **Risk**: バイアス緩和プロンプトが冗長で orchestrator 全体のコンテキスト圧迫
  → **Mitigation**: プロンプトは50行未満に抑える。冗長になりそうなら別ファイル（references/bias-guard.md）に切り出して読み込み参照にする。

- **Risk**: バージョンを上げ忘れると他プロジェクトのキャッシュが古いまま動く
  → **Mitigation**: tasks.md のチェックリストで version bump を必須項目にする。

## Migration Plan

1. ディレクトリリネーム（git mv で履歴保持）
2. SKILL.md の `name:` 更新
3. plugin.json の skills パスと version 更新
4. 参照箇所（orchestrator/README/lr）を新名称に追従
5. commands/plan.md を Skill tool 明示形式に書き換え
6. orchestrator にバイアス緩和プロンプト追加
7. ローカルで `/longrun:plan "テスト"` を実行して Agent 誤起動が発生しないことを動作確認
8. コミット → push → 他プロジェクトでは `/plugin update` または再インストールで反映

ロールバック: コミット単位で revert 可能。version 5.1.0 のキャッシュが残るため、revert 後は version を 5.1.1 に上げて再配布する。

## Open Questions

- `longrun-feedback` Skill も `-back` 終わりで命名規則上は曖昧だが、本変更スコープ外とする。今後同様の事故が出たら別 change で扱う。
- バイアス緩和プロンプトの effectiveness を定量測定する方法はまだ無い。orchestrator 実行ログから「reviewer 指摘の採用率」を観測できるよう将来的に decisions.jsonl に記録する案あり（別 change）。
