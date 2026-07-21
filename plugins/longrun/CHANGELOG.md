# Longrun Plugin Changelog

現行版のドキュメントは [README.md](README.md) を参照。本ファイルは版履歴のみを記録する。

## v6.5 変更点

- **`fable` ティアを追加**（cost-effective harness / claude-harness#26 v2）。ティア語彙は haiku / sonnet / fable / inherit の 4 値になり、判断が集中する場所（checkpoint 再ランク・verify の最終判定・アーキテクチャレビュー）に Fable を割り当てられるようになった。
- **推奨ヒューリスティクスを4象限準拠に更新**: builder は sonnet を出発点（失敗ループは昇格トリップワイヤーが救済）、verifier / reviewer の判断集中点は fable。「迷ったら inherit」の保守的デフォルトは維持。
- **reserve 降格を resolver に実装**: `FABLE_BUDGET_MODE=reserve` かつ `LONGRUN_AUTOMATED=1`（無人配線が設定）のとき、fable を `'opus'` に降格して解決し警告を出す。自動実行での Fable 温存（人間の interactive 利用優先）のため。interactive では降格しない。

## v6.4 変更点

- **ノンストップ実行ポリシーを導入**。`/longrun:exec` の停止ポイント5箇所のうち、ユーザーがほぼ推奨選択肢で即決していた4箇所を自動化した。plan 承認済みなら「AI レビューで問題（REQUEST_CHANGES）が出ない限り、完了レポートまで一度も止まらない」状態になる。exec.md に「停止ポリシー」セクションを新設し、停止してよい条件（権限モード不足 / preflight NO_CLI・NO_INIT / REQUEST_CHANGES）を明文化。
- **OpenSpec 動作モード確認の廃止（Step 0b）**: preflight が `OK` なら AskUserQuestion を出さず通常モードで即続行する。「OpenSpec を使わない」opt-out は新設の **`--degraded` フラグ**（`/lr:e --degraded`）に移行。`NO_CLI` / `NO_INIT` の提案質問は環境異常のため従来どおり停止する。
- **Build Contract 承認の自動化（Step 3）**: reviewer が `APPROVE` を返した場合は AskUserQuestion を出さず Build workflow へ自動続行し、承認記録（verdict 要約 + 自動承認である旨）を `decisions.md` に追記して監査可能性を担保する。`REQUEST_CHANGES` 時のみ従来どおり停止して確認する。
- **Feedback Tier 確認のノンブロッキング化（Step 4）**: Build→Verify 完了後に AskUserQuestion でブロック待機する設計を廃止し、完了レポート（stopReason / change 一覧 / Verify 結果）を出力してターンを終了する。フィードバックは `/lr:f`、アーカイブは `/lr:a` で再開する（`longrun-feedback` スキルは元々セッション切れ後の再開エントリポイントとして自己完結設計）。
- **再開 vs 新規の自動判断（Step 1）**: `workflow-runs.jsonl` に runId 記録がある場合の確認質問を廃止。本セッション起動の runId なら `resumeFromRunId` で自動再開、セッションをまたいでいれば未完了フェーズから新規 runId で自動起動し直す（分岐結果は 1 行報告のみ）。
- 権限モード検査（Step 0a）は事故防止ゲートとして現状維持。
- 連動更新: `longrun-feedback` SKILL の exec 連携セクション（4.3.0）、README アーキテクチャ図、`references/workflow-tool-reference.md` §8、`docs/openspec-cli-verification.md` の案内文言。
- `plugin.json` / `marketplace.json`（plugins[] longrun エントリ）の version を 6.4.0 に同期 bump（lr プラグインは薄い委譲のみで変更なし）。

## v6.2 変更点

- **モデル割り当て機構を追加**。plan.md に「モデル割り当て」セクション（`| change | ロール | ティア(haiku/sonnet/inherit) | 理由 | 上書き |` の表）を導入し、change × agent ロール（builder / verifier / reviewer）ごとに使用モデルのティアを指定できるようにした。全 agent 一律 opus からの最適化余地（コスト・レイテンシ）を plan 段階で構造的に扱う。
- **推奨生成は `longrun-plan` スキル側**。Synthesis（Step 5c）でヒューリスティクスに基づきティアを推奨生成する:
  - アーキテクチャレビュー・複雑な TDD 実装 → **inherit**（`opts.model` を渡さず agent 定義の opus を継承）
  - 定型的な検証・要約 → **haiku**
  - リサーチ・ブラウザ操作・中規模実装 → **sonnet**
  - **保守的デフォルト: 迷ったら inherit**（確信度が低いタスクは inherit に倒す）
- **ユーザーが plan 確認時に表を直接編集して上書きできる**。`上書き` 欄が非空ならティア欄より優先される（編集後の値は巻き戻されない）。
- **消費は `/longrun:exec` 側**（責務分離）。exec が表を読み、ティアを `references/model-tiers.md` で解決して Workflow の `opts.model` に反映する。`inherit` は `opts.model` キー自体を出力しない（agent frontmatter の `model:` を上書きしない）。
- **ティア → モデル ID の対応は [`references/model-tiers.md`](references/model-tiers.md) の 1 箇所に集約**。plan.md・SKILL.md・exec.md・workflow テンプレートはティア名（haiku/sonnet/inherit）のみを扱い、モデル ID を直書きしない（世代交代時の更新箇所はこのリファレンス 1 ファイルのみ）。
- **fail-soft**: 未知のティア値・パース不能行は inherit + 警告で続行（exec を中断しない／AskUserQuestion を出さない）。
- **旧 plan.md 後方互換**: 「モデル割り当て」セクションが無い旧形式の plan.md は全ロール inherit にフォールバックし、無変更で動く（移行作業不要）。
- 消費ロジックは `scripts/resolve-model-allocation.mjs`（plan.md + model-tiers.md → 解決済み JSON）に集約。workflow テンプレートは条件付きスプレッド `...(model ? { model } : {})` で inherit 時にキーを省略する。
- `plugin.json` / `marketplace.json`（plugins[] longrun エントリ）/ longrun-plan・longrun-mvp-plan SKILL.md frontmatter の version を 6.2.0 に同期 bump（lr プラグインは変更なし＝6.1.0 据え置き）。

## v6.1 変更点

- **MVP プラン作成を独立スキル `longrun-mvp-plan` に分離**。新コマンド `/longrun:mvp`（短縮 `/lr:m`）で起動する。旧 `longrun-plan` 内のモード分岐（旧フラグ形式のモード切り替え）は廃止され、独立スキルとして自己完結したステップ群に再構成された。詳細は README.md「MVP プランモード」セクション参照。
- **旧フラグ形式のモード切り替えを廃止（deprecation）**。`/longrun:plan` に旧フラグを付けて実行すると、MVP フローを走らせる代わりに `/longrun:mvp` への移行案内を出力して終了する仕様だった（サイレント無視・フルモードへの暗黙フォールバックはしない）。※この移行案内自体は change-3（longrun-v5-cleanup）で完全撤去された。
- MVP 用 agent 3 種（`longrun-mvp-research` / `longrun-mvp-plan-reviewer` / `longrun-mvp-bestpractice-reviewer`）と軽量テンプレ `plan-template-mvp.md` は配置を変えず、帰属記述を `longrun-mvp-plan` スキルに整理（出力契約は不変）。
- Gap Analysis / Interview の方法論を `references/plan-interview-methodology.md` に切り出し、新スキルが自己完結に参照できるようにした。
- `<!-- mvp-mode -->` マーカーと `/longrun:archive` 側のマーカー分岐は現状維持（成果物形式は不変）。
- `plugin.json` / `marketplace.json`（top-level / plugins[]）の version を longrun・lr とも 6.1.0 に同期 bump。

## v6.0 変更点（BREAKING）

- **`/longrun:exec` を Workflow ツールに載せ替え**。plan.md を読んで Workflow スクリプト（`templates/workflow/review.workflow.js` / `build-verify.workflow.js`）を生成・起動し、`agent()` / `pipeline()` / `parallel()` でオーケストレーションする。旧 orchestrator スキル（SKILL.md）のインライン展開・Agent 手動制御・checkpoint.md の散文パースは**全廃**された。
- **サブエージェント成果物を JSON Schema（StructuredOutput）で機構的に強制**。builder 完了レポート / verifier 4 軸スコア / reviewer 判定を `schemas/*.schema.json` に外部化し、`agent(prompt, {schema})` で検証層が不正形式を拒否する（散文ドリフトの無言破壊を排除）。
- **Verify ループに上限 3 周 + budget ガード**。`while (round < 3)` + `budget.total && budget.remaining()` の null ガードで暴走を構造的に防止。上限到達 / budget 枯渇時は状態を報告して停止（LLM の自制に依存しない）。
- **中断再開を `resumeFromRunId` 一次手段に**。runId を `_longruns/<run>/workflow-runs.jsonl` に記録し、同一 scriptPath + args で再開すると完了済み change の builder agent が再実行されない（same-session only）。
- **`/longrun:status` `/longrun:decisions` `/lr:s` `/lr:d` を削除**。進捗確認はネイティブの **`/workflows` ライブビュー**、意思決定は `decisions.md` を直接 Read で代替する。
- **旧 orchestrator スキルを解体**（命名規則 backlog の -or 終わり廃止分を消化）。生成ロジックは exec コマンド + 同梱テンプレートへ移管。
- builder の agentType をパラメータ化（デフォルト `longrun:longrun-builder` 固定。Codex Builder Phase 2 の受け皿）。
- `plugin.json` / `marketplace.json` plugins[] の version を longrun・lr とも 6.0.0 に同期 bump。

### v6.0 移行ノート

- v6.0 は BREAKING。互換シムや deprecation 期間は設けない。marketplace 配布はバージョン単位キャッシュのため、bump で明示的に伝播する。
- 旧 `/longrun:status` `/longrun:decisions` `/lr:s` `/lr:d` は削除された。進捗は `/workflows`、意思決定は `decisions.md` の直接 Read を使う。
- 旧 checkpoint.md 形式の機械可読パースは廃止。checkpoint.md は人間向け監査ログとして書き続けられるが、状態復元には使わない（再開は `resumeFromRunId`）。
- 既存 agent 定義 7 種（`agents/*.md`）は無変更で、`agentType` 参照によりそのまま再利用される。

## v5.3 変更点

- **OpenSpec 縮退モードを一級の動作モードとして追加**。OpenSpec CLI が解決できない / 未 init の環境、またはユーザーが OpenSpec 不要と明示した場合に、spec 類を `_longruns/<run>/` 内に自己完結生成して run を完走させる。詳細は README.md「OpenSpec 縮退モード」セクション参照。
- `/longrun:exec`（`/lr:e`）に **Step 0（preflight）** を追加。`scripts/openspec-preflight.sh` で前提条件（CLI 解決可 + init 済み）を判定し、AskUserQuestion で動作モード（通常 / 縮退）を確定する。
- 旧 orchestrator の多段フォールバック検出（which → command -v → npx → ~/.volta → `npm install -g openspec`）を廃止し、preflight に一元化。
- `plugins/longrun/tests/` を新設（longrun プラグイン初の bats テストディレクトリ）。
- 通常モード（既存の openspec/ あり repo）の挙動は完全維持（regression なし）。
- `plugin.json` / `marketplace.json`（top-level / plugins[]）の version を 5.3.0 に 3 箇所同期 bump。

## v5.2 変更点

- **MVP モード（旧フラグ形式のモード切り替え）を `/longrun:plan` に追加**（このフラグは v6.1 で廃止され、独立コマンド `/longrun:mvp` に移行した）。詳細は README.md「MVP プランモード」セクション参照。
- フルモードの既存挙動は完全維持（regression なし）。旧フラグ（v6.1 で廃止・移行案内化）なし or フルモード指定の場合は従来通り Step 1〜8 を実行する。
- `plugins/longrun/templates/plan-template-mvp.md`（軽量テンプレ）を新規追加。
- `/longrun:archive` に `<!-- mvp-mode -->` マーカー判定を追加。MVP モード plan.md は OpenSpec change archive をスキップしてランディレクトリのみアーカイブ。
- `plugin.json` と `longrun-plan` SKILL.md frontmatter の version を 5.2.0 に同期 bump（プラグインキャッシュ無効化）。

## v5.1 変更点

- **Skill 命名統一**: `longrun-planner` → `longrun-plan` にリネーム（命名規則 §参照）。`/longrun:plan` 経由で Agent 誤起動が発生するエラー（`Agent type 'longrun:longrun-planner' not found`）を解消。
- `commands/plan.md` を Skill tool 明示呼び出しに変更（Agent tool 禁止を明記）
- 当時の旧 orchestrator の Build Contract レビュー段階に **バイアス緩和ガード** を追加。reviewer の指摘を仮説として扱い、根拠（spec違反・契約違反・事実誤認）の有無で採否を判定するルールを固定文として埋め込み。Opus 系の self-preference bias と過剰受容バイアスへの対処。（旧 orchestrator は v6.0 で解体され、このガードは exec が生成する Review workflow と Build Contract 承認ゲートの手順に引き継がれた。）

## v5.0 変更点

- **リネーム**: `run` → `longrun` に戻した（一般名詞との衝突回避）
- `_runs/` → `_longruns/`、エージェント/スキル名も `longrun-*` に統一

## v4.0 変更点（旧 longrun → run 時代）

- `instruction.md` → `plan.md`、`progress.md` → `checkpoint.md`
- **Skill/Agent正しい使い分け**: 対話型 = Skill、自律実行 = Agent
- **フェーズ簡素化**: 8フェーズ → 5フェーズ（Plan → Build → Verify → Feedback → Archive）
- **Build Contract**: 実装前に longrun-reviewer がレビュー
- **4軸定量評価**: 機能性/品質/完成度/UX にハードしきい値
- **コンテキストリセット**: フェーズ間で Agent を分離し、checkpoint.md でハンドオフ
- **Context Anxiety 対策**: 完了条件チェックリストで早期終了を防止
- **spec-review-agent を longrun-reviewer に統合**

## v6.3 変更点（change-3: longrun-v5-cleanup）

- **v6.0 で解体済みの旧 orchestrator への参照を全廃**。`longrun-verifier.md` / `longrun-browser-verifier.md` のコンテキスト復元・FAIL エスカレーション記述を、現構造（`plan.md` + `decisions.md` 起点の復元、Workflow による `longrun-builder` 再呼び出し）に書き直した。`longrun-builder.md` description の「checkpoint.mdを更新する」という実態不一致な記述も修正。
- **dead code 削除**: 呼び出し経路ゼロだった checkpoint 更新用スクリプト（`scripts/` 配下）を削除。
- **旧フラグ形式のモード切り替えシムを完全撤去**: `longrun-plan` SKILL.md 冒頭の GATE ブロック、`plugins/lr/commands/p.md` の移行案内文を削除。marketplace のバージョン単位キャッシュ更新という恒久シム不要の設計に沿う。
- **README → CHANGELOG.md 分離**: 版履歴（本ファイル）を README から切り出し、README は現行版ドキュメントに縮小。
- **plugin.json description 圧縮**: longrun・lr とも 1〜2 文に圧縮。
- **checkpoint.md の位置づけを明確化**: 「任意の人間向けメモ。decisions.md に統合してもよい」という位置づけに書き換え。`workflow-runs.jsonl` / `resumeFromRunId` フローは変更なし。
- `plugin.json` の version を longrun 6.3.0・lr 6.2.0 に同期 bump（`marketplace.json` の同期は change-7）。
