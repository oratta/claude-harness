# dev-workflow-shared-references Specification

## Purpose
TBD - created by archiving change loops-longrun-retirement. Update Purpose after archive.
## Requirements
### Requirement: 共有契約はプラグイン直下 references/ に置く
dev-workflow プラグインは、他プラグインからも参照される契約文書を `plugins/dev-workflow/references/` 直下に置かなければならない（MUST）。本 change で置く契約は `self-verification.md`・`pr-body-format.md`・`model-tiers.md`・`workflow-execution.md` の 4 本である。develop スキル固有の判定表（`skills/develop/references/`）と混ぜてはならない（MUST NOT）。`plugins/dev-workflow/README.md` は「複数プラグインで共有する契約は `references/` に置く」と、4 本それぞれの一言説明を持たなければならない（MUST）。

#### Scenario: 4 契約が実在する
- **WHEN** `plugins/dev-workflow/references/` を一覧する
- **THEN** `self-verification.md`・`pr-body-format.md`・`model-tiers.md`・`workflow-execution.md` が存在する

#### Scenario: README が置き場の規約と 4 本を説明している
- **WHEN** `plugins/dev-workflow/README.md` を読む
- **THEN** `references/` の節があり、4 本のファイル名がそれぞれ 1 行の説明付きで並ぶ

### Requirement: 自己検証の共通原則は解散プラグインの記述を除いて引き継ぐ
`plugins/dev-workflow/references/self-verification.md` は、旧 `plugins/loops/references/self-verification.md` の中核原則（完了は主張であり証明ではない。evidence を提示してから完了を宣言する）・evidence の 4 種別・スキル側への記載ルール（本リファレンスへの 1 行参照 + 固有手順のみ。共通原則の本文をコピーしない）を維持しなければならない（MUST）。「スキル側への記載ルール」の参照パスは新パス `plugins/dev-workflow/references/self-verification.md` を示す。対象スキル一覧は解散プラグインのスキル（`longrun-plan`・`longrun-feedback`・`longrun-mvp-plan`・`loops-design`・`loops-goalify`）の行を持ってはならず（MUST NOT）、対象は `wt-setup`・`wt-clean`・`daily-report`・`weekly-report`・`infra-setup`・`experience-to-skill` の 6 スキルとする。

#### Scenario: 中核原則と evidence 4 種が残っている
- **WHEN** `plugins/dev-workflow/references/self-verification.md` を読む
- **THEN** 「完了は主張であり証明ではない」の原則と、テスト出力・exit code・生成物の実在と形式チェック・実行結果ログの 4 種別が記載されている

#### Scenario: 対象スキル一覧に解散プラグインが無い
- **WHEN** 対象スキル一覧の表を読む
- **THEN** `plugins/longrun/`・`plugins/loops/` を含む実パスは 1 行も無く、6 スキルの実パスが並ぶ

#### Scenario: 参照元 7 か所が新パスを指す
- **WHEN** `plugins/infra/skills/infra-setup/SKILL.md`・`plugins/weekly-report/skills/weekly-report/SKILL.md`・`plugins/daily-report/skills/daily-report/SKILL.md`・`plugins/experience-to-skill/skills/experience-to-skill/SKILL.md`・`plugins/worktree/skills/wt-setup/SKILL.md`・`plugins/worktree/skills/wt-clean/SKILL.md`・`plugins/worktree/references/wt-clean-verification.md` で `self-verification.md` を grep する
- **THEN** 7 ファイルすべてが `plugins/dev-workflow/references/self-verification.md` を指し、`plugins/loops/references/self-verification.md` は 0 件である

### Requirement: PR / issue 本文の型は内容を維持して引き継ぐ
`plugins/dev-workflow/references/pr-body-format.md` は、旧 `plugins/loops/references/pr-body-format.md` が定義していた PR 本文の 5 セクション型（「位置づけ」「実装方針」「リスク（重い順）」「動作確認ポイント」「実装メモ」の順序固定）・末尾の `Closes #<番号>`・再生成可能な出力のみを入れる任意の `<details>`・二重読者のための設計原則 5 点（同じ情報を 2 回書かない／位置づけは上から降りる 3 段／翻訳の規律に良い例・悪い例 3 組以上／リスクは起きやすさ（高/中/低＋根拠）と影響の重み付きで「なし」にも根拠 1 行／セクションごとの行数上限）・誇張防止の検証紐付け（位置づけの変化は動作確認ポイントで検証できるものに限る。動作確認ポイントは「操作 → 期待される結果」形式）・軽量モード（位置づけ＋動作確認ポイントの 2 節。冒頭に「軽量モード適用（理由: …）」。迷ったらフル 5 節）を維持しなければならない（MUST）。issue ドラフトの承認判断 2 節（「これで何が変わるか」「やらないとどうなるか / 今のコスト」）の規定と、その生成ロジックの正本が `plugins/dev-workflow/skills/issueify/SKILL.md` であることを示さなければならない（MUST）。解散プラグインのパス（`loops-issueify`・`loops-dev-agent-install`・`agent-loop-template.md`）を含んではならない（MUST NOT）。

#### Scenario: 5 セクションが順序どおり定義されている
- **WHEN** `plugins/dev-workflow/references/pr-body-format.md` を読む
- **THEN** 「位置づけ」「実装方針」「リスク（重い順）」「動作確認ポイント」「実装メモ」の 5 見出しがこの順で現れる

#### Scenario: 設計原則・検証紐付け・軽量モードの規定が残っている
- **WHEN** 同ファイルで「同じ情報を 2 回書かない」「上から降りる」「❌」「✅」「起きやすさ」「高/中/低」「戻し方」「動作確認ポイントで検証できないこと」「期待される結果」「軽量モード適用」「迷った」を grep する
- **THEN** すべてヒットし、❌ と ✅ はそれぞれ 3 回以上現れる

#### Scenario: 生成ロジックの正本が issueify の新パス
- **WHEN** 同ファイルの issue 本文の型の節を読む
- **THEN** 正本として `plugins/dev-workflow/skills/issueify/SKILL.md` が示され、`loops-issueify`・`loops-dev-agent-install`・`agent-loop-template` の文字列は無い

### Requirement: モデルティアはロール別の対応表と降格規則だけを引き継ぐ
`plugins/dev-workflow/references/model-tiers.md` は、Workflow スクリプトの `agent(prompt, opts)` に渡す `opts.model` について (1) ティア名（`haiku` / `sonnet` / `fable` / `inherit`）→ 渡す値の対応表、(2) 値はエイリアス（`'haiku'` `'sonnet'` `'opus'` `'fable'`）で渡しフル ID を直書きしない規則、(3) `inherit` は `opts.model` キー自体を省略する（値として `'inherit'` を渡さない）意味、(4) ロールの目安（builder は `sonnet` から出発、checkpoint の再ランク・verify の最終判定・アーキテクチャ判断は `fable`、定型検証・要約は `haiku`）、(5) 残量モードによる降格（`FABLE_BUDGET_MODE=reserve` の自動実行と `exhausted` の全経路では `fable` を `'opus'` として渡す。モードの定義の正本は `skills/develop/references/decision-criteria.md`）を定めなければならない（MUST）。longrun 固有の機構（plan.md のモデル割り当てセクション・resolver スクリプト・`LONGRUN_AUTOMATED` 環境変数・未知ティアの fail-soft）を含んではならない（MUST NOT）。`rules/subagent-model-selection.md` はロール別ティアの正本としてこのファイルを指さなければならない（MUST）。

#### Scenario: 対応表とエイリアス規則がある
- **WHEN** `plugins/dev-workflow/references/model-tiers.md` を読む
- **THEN** `haiku` / `sonnet` / `fable` / `inherit` の 4 行を持つ表と、「エイリアス」で渡す規則、`inherit` はキーを省略する旨がある

#### Scenario: longrun 固有の機構が無い
- **WHEN** 同ファイルで `LONGRUN`・`resolve-model-allocation`・`plan.md`・`plan-template` を grep する
- **THEN** ヒットは 0 件である

#### Scenario: rules がこのファイルを指す
- **WHEN** `rules/subagent-model-selection.md` を読む
- **THEN** ロール別ティアの正本として `plugins/dev-workflow/references/model-tiers.md` が示され、`plugins/longrun/` は現れない。ポインタは 1 行に収め、この差し替えでファイルの行数を増やさない（rules は常時ロード層なので薄く保つ）

### Requirement: Workflow 実行の型を 1 ファイルで定める
`plugins/dev-workflow/references/workflow-execution.md` は、develop の 1 ループに収まらない規模（トリップワイヤー 1 の発火・エピック化でも足りない探索的な実装）をネイティブ Workflow ツールで回すときの型を定めなければならない（MUST）。内容は (1) Review → Build → Verify の 3 フェーズを `meta.phases` で表す構成、(2) Build Contract レビュー（実装前に別コンテキストが計画を審査する。develop では R1 が担う工程で、Workflow 内では reviewer agent を `fable` で立てる）、(3) verifier の姿勢（自分が作っていないものを壊す立場・品質＝テスト/lint/型/ビルド 100% 必須・完成度 80% 以上・疑わしければ FAIL・`schema` 付きの構造化レポートで自己申告を排除）、(4) ロール別ティアは `model-tiers.md` を参照、(5) 外部状態は Workflow の `args` / return 値と `resumeFromRunId` で持つ（独自の状態ファイル形式を作らない）、(6) スクリプト API・resume・品質パターンの正本は `workflow-authoring` スキルであり、このファイルはそれを繰り返さない、の 6 点である。`/lr:e`・`/longrun:exec`・plan.md への言及を含んではならない（MUST NOT）。

#### Scenario: 3 フェーズと verifier の姿勢が書かれている
- **WHEN** `plugins/dev-workflow/references/workflow-execution.md` を読む
- **THEN** Review・Build・Verify の 3 フェーズ、Build Contract、品質 100% と完成度 80% のしきい値、`schema` によるレポートの構造化が記載されている

#### Scenario: workflow-authoring を正本として指す
- **WHEN** 同ファイルを読む
- **THEN** `workflow-authoring` スキルがスクリプトの書き方の正本であると明記され、`/lr:e`・`longrun:exec`・`plan.md` の文字列は無い

#### Scenario: トリップワイヤーと develop がこのファイルを乗り換え先として指す
- **WHEN** `plugins/dev-workflow/templates/escalation-tripwires.md` のトリップワイヤー 1 と `plugins/dev-workflow/skills/develop/SKILL.md` を読む
- **THEN** 規模超過時の乗り換え先として「ネイティブ Workflow 実行（`references/workflow-execution.md`）」が示され、`/lr:e` は現れない

