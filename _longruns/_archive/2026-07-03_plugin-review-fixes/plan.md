# Plan: プラグイン全面レビュー修正（plugin-review-fixes）

## 生成情報
- 作成日: 2026-07-03
- Brain Dump元: セッション内（6 エージェント並列レビュー + ルート調査の統合結果）
- 質問回数: 3問

## ゴール
2026-07-03 実施の全面レビュー（公式機能重複・OSS 代替・鮮度・冗長性の 4 観点）で確定した推奨アクションを全て適用し、壊れている機能バグ 3 件の修正・遺物 2 プラグインの完全削除・v5 残骸/重複の掃除により、marketplace 全体を「公式機能と重複せず、参照が全て生きている」状態にする。

## ビジネスコンテキスト
- 対象ユーザー: このユーザー本人（marketplace の唯一のメンテナ兼利用者）
- 提供価値: (1) infra/longrun/worktree の実バグ解消で自律実行・デプロイ構築の信頼性回復、(2) 毎ターン走る不要 hooks と 2 系統スキル掲載の除去でコンテキスト・実行コスト削減、(3) 二重管理（command/skill 全文重複、marketplace description）の根治で今後の保守コスト削減
- 成功指標: 受け入れ条件の grep/bats 機械検証が全て PASS、スキル一覧から重複・遺物掲載が消える

## 技術要件
- スタック: Markdown（SKILL.md / commands / agents）+ bash / node スクリプト + JSON Schema + GitHub Actions YAML テンプレート
- 参照パターン: weekly-report の jsonl 直読は `plugins/daily-report/agents/llm-log-compactor.md:33-100` の jq ロジックを流用。command の薄いラッパー化は `plugins/lr/commands/e.md` 方式（対象 .md を Read してインライン実行）を参照
- 制約:
  - `~/.claude/rules/plugin-editing.md` 準拠: 編集した全プラグインで plugin.json version bump + marketplace.json 同期必須
  - このリポジトリの CLAUDE.md 準拠: worktree 作業は Draft PR バックアップ運用（`/wt-setup --with-pr` 相当）、main 直 push 禁止
  - `openspec/changes/archive/` と `_longruns/_archive/` は履歴のため一切触らない
  - モデル ID を exec.md・テンプレート・plan.md に直書きしない（`references/model-tiers.md` が唯一のソース）
  - 削除は git tracked の状態で行う（履歴から復元可能に）。untracked ファイル（LLM/ 配下）は削除でなく退避
- テストフレームワーク: bats-core（既存: `plugins/longrun/tests/`, `plugins/daily-report/tests/`, `plugins/experience-to-skill/tests/`）+ `node --check`（workflow テンプレ構文）+ grep ベースの参照ゼロ検証
- テスト実行コマンド: `find plugins -name '*.bats' -print0 | xargs -0 bats`

## スコープ
### 含むもの
- infra の機能バグ 2 件 + 整合性修正一式（change-1）
- longrun browser-verifier の workflow 復帰による 4 軸評価の復活 + 一次ソース reference の同梱化（change-2）
- longrun/lr の v5 残骸掃除・description 圧縮・README changelog 分離（change-3）
- worktree の command/skill 全文重複のラッパー化根治（change-4）
- weekly-report の jsonl 直読化 + daily/weekly の /schedule 非対話モード追記 + レポート系小修正（change-5）
- obsidian-llm-session-rules / skill-aware-workflow の完全削除 + LLM/ 53 ファイルの Vault 退避 + backlog 消込み（change-6）
- リポジトリルート掃除（OpenSpec 4 重複製の整理、templates/rules 削除、cooking 残骸）+ e2s/skill-pack 小修正 + marketplace.json 最終同期（change-7）

### 含まないもの
- Phase 2: Codex Builder Integration（理由: backlog の独立大型案件。別 run）
- lr プラグインの dir-discovery 簡素化（理由: レビューで「現状妥当」と評価済み）
- longrun モデル割り当て機構の ROI 実測（理由: 機能として妥当と評価済み。実測は運用データが溜まってから）
- worktree setup の gtr（git-worktree-runner）寄せ等の OSS 借用検討（理由: 検討自体が別テーマ）
- harvest / sns-strategy 等、別 marketplace（marketing-harness）のプラグイン（理由: 対象リポジトリ外）

## Changes分解

### change-1: infra-fixes
- **スコープ**: `plugins/infra/` の機能バグ修正と整合性回復。(1) GitHub Secrets 名の投入/参照不一致解消、(2) Phase 5 の旧 .env 設計参照を .env.production.local 方式へ更新、(3) Actions バージョン・Step 番号ズレ・vercel link 矛盾・アーキ図・version drift・個人パスの整合修正、(4) Vercel トークン取得の CLI 化検証（ベストエフォート）。詳細は付録 A
- **使用スキル**: なし（テキスト整合作業）
- **依存関係**: 独立
- **config.yaml rules**:
  - "テンプレート YAML が参照する `secrets.*` 名の集合と Phase 4 の投入リストを 1:1 一致させる（どちらに寄せるかは「テンプレ参照名を正」とする）"
  - "SERVICE_ROLE_KEY はテンプレで実際に使うなら Phase 2 に取得手順を追加、使わないならテンプレから参照を除去（両論併記にしない）"
  - "Actions のバージョン bump は `gh api /repos/actions/checkout/tags` 等で最新メジャータグの実在を確認してから適用する（確認できなければ現行維持 + 注記）"

### change-2: longrun-browser-verify-restore
- **スコープ**: `plugins/longrun/` の Verify 4 軸評価復活。(1) `templates/workflow/build-verify.workflow.js` に browser-verifier の Verify ステップを追加し、静的 verifier（品質/完成度）とブラウザ verifier（機能性/UX）の 2+2 分担を機構化、(2) schema・agent 定義・render-workflow.mjs のパラメータを整合、(3) `workflow-tool-reference.md` を `_longruns/2026-06-12_harness-workflow-overhaul/` から `plugins/longrun/references/` へ移動し、exec.md / 両 workflow テンプレの参照を `${CLAUDE_PLUGIN_ROOT}/references/` に書き換え。詳細は付録 B
- **使用スキル**: browser-verification（手法選択リファレンスとして browser-verifier agent が参照）
- **依存関係**: 独立
- **config.yaml rules**:
  - "schema は外部ファイル（schemas/*.schema.json）を唯一のソースとし、インライン重複コピーしない（既存 GATE の維持）"
  - "verifier の 4 軸分担の具体設計（schema を 2 分割するか、1 schema の部分返却にするか）は builder が設計し reviewer 承認を得る"
  - "生成テンプレは `node --check` 構文検証を必ず通す"

### change-3: longrun-v5-cleanup
- **スコープ**: `plugins/longrun/` と `plugins/lr/` の残骸掃除。(1) 解体済み longrun-orchestrator への参照除去（agent 3 ファイル）、(2) dead code `scripts/update-checkpoint.sh` 削除、(3) `--mode=mvp` 廃止シムの削除（5 ファイル）、(4) README の changelog 部分を CHANGELOG.md へ分離、(5) plugin.json / marketplace 用 description の 1-2 文への圧縮、(6) exec.md の checkpoint.md 節を任意メモに格下げ（runId/workflow-runs.jsonl の機械経路は維持）、(7) 既存 bats（mvp-plan-split.bats / release-and-readme.bats 等）の新仕様への追随。詳細は付録 C
- **使用スキル**: なし
- **依存関係**: change-2（exec.md / README / plugin.json を両方が触るため直列化）
- **config.yaml rules**:
  - "workflow-runs.jsonl の runId 記録と resumeFromRunId フローは削除しない（再開の一次手段）"
  - "既存 bats テストは削除でなく新仕様に更新する。テストが検証していた意図を保つ"

### change-4: worktree-command-dedup
- **スコープ**: `plugins/worktree/` の command/skill 全文重複の根治。`commands/wt-clean.md` と `commands/wt-setup.md` を「対応する SKILL.md を Read してそのまま実行する」薄いラッパーに置き換え、squash マージ検出を含む正を SKILL.md 側に一本化する。command 側 frontmatter（allowed-tools 等）は維持。詳細は付録 D
- **使用スキル**: なし（lr/commands/e.md のラッパー方式を参照）
- **依存関係**: 独立
- **config.yaml rules**:
  - "SKILL.md 側の squash マージ検出（検証A/B/C）と AskUserQuestion 後別ターン実行の絶対禁則は一言一句失わない"
  - "ラッパー化後、command 経由と skill 経由で同一の診断フローになることを検証する"

### change-5: report-plugins-update
- **スコープ**: `plugins/weekly-report/` と `plugins/daily-report/` の更新。(1) weekly-report Step 3b を auto-save.py 出力（markdown）依存から native セッション jsonl 直読へ移行、(2) weekly-report command の存在しないパス参照修正・個人パスの変数化・cooking 残骸掃除、(3) daily-report command frontmatter の Agent ツール欠落修正、(4) 両プラグインに /schedule（cron 実行）非対話モード節を追記。詳細は付録 E
- **使用スキル**: なし（llm-log-compactor の jq パターンを流用）
- **依存関係**: 独立
- **config.yaml rules**:
  - "weekly-report の新 Step 3b は obsidian-llm-session-rules の成果物（`{source_path}/LLM/*.md`）への参照を完全に断つ（change-6 の削除前提を作る）"
  - "非対話モードは『AskUserQuestion が使えない場合はデフォルト値で続行し、判断ログを出力に残す』方針で書く"

### change-6: plugin-retirement
- **スコープ**: 遺物 2 プラグインの完全削除。(1) リポジトリ直下 `LLM/` の全 53 ファイルを `$LLM_LOG_DIR`（設定済み: Obsidian Vault の `90 - LLM`）へ退避（件数照合付き）、(2) `plugins/obsidian-llm-session-rules/` と `plugins/skill-aware-workflow/` を削除、(3) marketplace.json から両エントリ除去、(4) 旧スキル名（session-logger / context-reader / research-workflow / pre-task-orchestrator / task-analyzer / skill-inventory / skill-finder / execution-tracker / skill-proposer）への参照を全ファイルから掃除、(5) `openspec/backlog.md` の「Skill 命名規則リファクタリング」項目を消込み（対象 7 スキル全てが削除で消滅）、(6) ユーザー向け後始末手順（/plugin uninstall × 2、settings の enabledPlugins 掃除）を run ディレクトリに書き出し。詳細は付録 F
- **使用スキル**: なし
- **依存関係**: change-5（weekly-report の依存切断が前提）
- **config.yaml rules**:
  - "LLM/ のファイルは削除禁止。mv 前後で件数を照合し、退避先の同名衝突は上書きせずスキップしてリスト報告する"
  - "退避直前に LLM/ の件数 snapshot を取得し、退避は単一セッション内で完結させる。mv 完了後に差分（新規発生分）が出た場合は auto-save.py hook 起因として post-merge-steps.md に記録し、照合は snapshot 基準で行う"
  - "openspec/changes/archive/ 内の旧スキル名参照は履歴のため触らない"

### change-7: repo-cleanup-final
- **スコープ**: リポジトリルート掃除と最終統合。(1) OpenSpec スキル 4 重複製（`.claude/skills/openspec-*` ×10 / `.claude/commands/opsx/` ×10 / `.agents/skills/openspec-*` ×10 / `.agents/skills/source-command-opsx-*` ×10）の生成元を調査し、openspec CLI 管理なら CLI 設定で 1 系統に抑制、手動管理なら 1 系統（`.claude/` 側推奨）を残して削除、(2) 参照ゼロの `templates/rules/*.md` 4 ファイル削除、(3) `docs/cooking-mvp-mode-plan.md` 削除と .gitignore の cooking コメント更新、(4) skill-pack への「plugin 個別 skill は skillOverrides 非対象」注記追加 + cooking 言及掃除、(5) e2s `commands/e2s-distill.md` の `$0` → `${CLAUDE_PLUGIN_ROOT}` 修正、(6) 全編集プラグインの marketplace.json version・description 最終同期、(7) 受け入れ条件の統合 grep 検証一式の実行。詳細は付録 G
- **使用スキル**: なし
- **依存関係**: change-1, change-3, change-4, change-6（marketplace.json 同期は全プラグイン編集の完了後。並列時の同一ファイル競合回避のため最後に直列実行）
- **config.yaml rules**:
  - "OpenSpec 重複の削除は生成元調査の結論が出てから。CLI 管理の疑いが残る場合は削除せず調査結果と抑制手順を decisions.md に記録して次善（現状維持+文書化）に倒す"
  - "marketplace.json の version は各プラグインの plugin.json と完全一致させる"

## モデル割り当て

自律実行（exec）の各フェーズ agent に割り当てるモデルティアを change × ロールごとに指定する。
exec はこの表を読み、ティアを `plugins/longrun/references/model-tiers.md` で解決して
Workflow の `opts.model` に反映する。

- ティアは `haiku` / `sonnet` / `inherit` の 3 値（モデル ID は書かない）
- **この表は plan 確認時にユーザーが直接編集して上書きできる**。編集後の値は巻き戻されない
- **`上書き` 欄がティア欄より優先される**

| change | ロール | ティア(haiku/sonnet/inherit) | 理由 | 上書き |
|--------|--------|------------------------------|------|--------|
| change-1 | builder | sonnet | テンプレ/文書の整合修正が中心の中規模実装 | |
| change-1 | verifier | haiku | secrets 名照合など grep ベースの定型検証 | |
| change-1 | reviewer | inherit | Secrets 設計・環境分離の妥当性判断を含むレビュー | |
| change-2 | builder | inherit | workflow テンプレ + schema 分担の設計を伴う複雑実装 | |
| change-2 | verifier | sonnet | node --check + schema/agent 間の整合確認（中規模） | |
| change-2 | reviewer | inherit | アーキテクチャレビュー（4 軸分担設計の承認） | |
| change-3 | builder | sonnet | 残骸削除・文書分離が中心の定型寄り作業 | |
| change-3 | verifier | haiku | 参照ゼロ grep + bats 実行の定型検証 | |
| change-3 | reviewer | inherit | 削除範囲の安全性判断（消しすぎ検知）が必要 | |
| change-4 | builder | inherit | 誤削除事故に直結する squash 検出ロジックの一本化。安全性重視 | |
| change-4 | verifier | haiku | command/skill の重複ゼロ確認は定型 | |
| change-4 | reviewer | inherit | データロス防止禁則の保全レビュー | |
| change-5 | builder | sonnet | jq ロジック流用の中規模実装 | |
| change-5 | verifier | haiku | 依存断絶の grep 確認 + bats の定型検証 | |
| change-5 | reviewer | inherit | 確信度が低いため保守的デフォルト（inherit）を適用 | |
| change-6 | builder | sonnet | ファイル退避・削除・参照掃除の定型寄り作業 | |
| change-6 | verifier | haiku | 件数照合・参照ゼロ grep の定型検証 | |
| change-6 | reviewer | inherit | 不可逆操作（削除）の最終安全レビュー | |
| change-7 | builder | inherit | OpenSpec 生成物の調査と削除可否判断を含む | |
| change-7 | verifier | haiku | 統合 grep 検証一式の定型実行 | |
| change-7 | reviewer | inherit | リポジトリ全体整合の最終レビュー | |

## 画面・UI設計
該当なし（Markdown プラグイン集リポジトリ。UI 成果物は生成しない）

## データモデル
該当なし（データベース・エンティティなし。強いて言えば marketplace.json ↔ 各 plugin.json の version 整合が唯一の構造的整合性制約）

## 受け入れ条件

**必須条件（常に含める）:**
1. [ ] 全changeのOpenSpec仕様が作成・レビュー済み
2. [ ] 全changeのテストが作成され全てPASSしている（`find plugins -name '*.bats' -print0 | xargs -0 bats`）
3. [ ] ビルドエラーなし（全 workflow テンプレ・.mjs の `node --check` PASS + 全 *.json の JSON parse PASS）
4. [ ] 統合テストがPASS（worktreeマージ後、下記 5-13 の機械検証を main 上で再実行して全 PASS）

**機能固有の条件:**
5. [ ] infra テンプレの secrets 参照と投入リストが一致: `grep -rho 'secrets\.[A-Z_]*' plugins/infra/templates/ | sort -u` の全項目（GITHUB_TOKEN 除く）が Phase 4 の `gh secret set` 投入リストに存在する
6. [ ] `plugins/infra/agents/infra-phase-5-finalize.md` に「コメントアウトで prod 値を保存」する旧方式の記述が残っていない（`.env.production.local` 方式に統一）
7. [ ] `templates/workflow/build-verify.workflow.js` が browser-verifier を呼ぶ Verify ステップを含み、静的/ブラウザの 2+2 軸分担が schema と矛盾しない（レンダリング後 `node --check` PASS）
8. [ ] `workflow-tool-reference.md` が `plugins/longrun/references/` 配下に存在し、`grep -rn "_longruns/2026-06-12" plugins/` が 0 件
9. [ ] `grep -rn "longrun-orchestrator" plugins/` が 0 件、`plugins/longrun/scripts/update-checkpoint.sh` が不存在、`grep -rn "mode=mvp" plugins/longrun/ plugins/lr/` が 0 件
10. [ ] `plugins/worktree/commands/wt-clean.md` と `wt-setup.md` に診断分類表・手順本文の重複コピーが無い（SKILL.md を Read するラッパー構造）
11. [ ] weekly-report SKILL.md に `{source_path}/LLM/` への markdown 読み込み参照が無く、native jsonl 直読手順に置換されている
12. [ ] `plugins/obsidian-llm-session-rules/` と `plugins/skill-aware-workflow/` が不存在、marketplace.json に両エントリが無く、`grep -rln "obsidian-llm-session-rules\|skill-aware-workflow" plugins/ README.md docs/` が 0 件（openspec/changes/archive・_longruns 除く）
13. [ ] リポジトリ直下 `LLM/` に残るのは退避先で同名衝突したファイルのみで、その一覧が `post-merge-steps.md` に記録されている（衝突ゼロなら LLM/ は空または不存在。照合は退避直前の件数 snapshot 基準）
14. [ ] `templates/rules/` が不存在、`docs/cooking-mvp-mode-plan.md` が不存在
15. [ ] 編集した全プラグインで plugin.json の version が bump され、marketplace.json の対応エントリと一致する
16. [ ] daily-report / weekly-report の SKILL.md に非対話（/schedule cron 実行）モードの節が存在する

## 意思決定ガイドライン
- 優先順位: 安全性（消しすぎない・壊さない） > シンプルさ > 網羅性
- リスク許容度: 保守的。特に削除系は「git tracked の状態で消す（履歴復元可能）」を厳守
- 不明点の扱い: レビュー findings の解釈に迷ったら付録の file:line 原文を再確認。それでも曖昧なら「現状維持 + decisions.md に論点記録」に倒す（勝手に踏み込まない）
- OpenSpec 重複整理（change-7）だけは調査結果次第で「現状維持 + 文書化」への縮退を許容する

## 動作確認方法
- 開発サーバー: なし（Markdown プラグイン集。アプリケーションではない）
- テスト: `find plugins -name '*.bats' -print0 | xargs -0 bats` / `node --check <各 .mjs / レンダリング済み workflow .js>`
- 確認手順:
  1. 受け入れ条件 5-16 の各 grep / ls コマンドを実行し全て期待値になることを確認
  2. `node plugins/longrun/scripts/render-workflow.mjs` でテンプレをレンダリングし `node --check` が通ることを確認
  3. マージ後、新しい Claude Code セッションで `/plugin uninstall` ×2 → `/reload-plugins` を実施し、スキル一覧から遺物スキル・opsx/openspec 二重掲載が消えたことを確認
  4. `/lr:p --help` 相当の起動、`/wt-clean`（引数なし・ドライに選択画面まで）、`/daily-report --help` 相当の起動で各プラグインが壊れていないことを smoke 確認

## Brain Dumpからの原文メモ
> 今のclaude codeの最新の機能を考慮してプラグイン内の機能を全てreviewして。配置して公式の機能に任せる部分とか。スキルで言及してるけど、もしわざわざ言及しなくてもOKだから無駄になっている部分だとか、全体的に幅広くチェックして、もしくはスターがいっぱいついているGitHubのプロジェクトがあって、そっちで同じことができるからそれを使った方がいいとか、いろんな観点でFableの能力を全て最大限活用して、より良いプラグインになるように全部チェックしてください。
> （レビュー完了後）プラグインの修正はおすすめを全て直そう
> 質問回答: browser-verifier は (a) 復帰させる / 廃止 2 プラグインは完全削除 / 低優先グループ（小修正群・OpenSpec 4 重複整理・/schedule 対応）も全て含める

---

## 付録: レビュー findings 原文（file:line 付き実装仕様）

builder はこの付録を実装仕様の一次ソースとして使うこと（レビューセッションのコンテキストは実行時に存在しない）。

### 付録 A: change-1 (infra) の findings
1. **[高] Phase 5 が Phase 2 の旧設計を参照**: Phase 2 は `.env.production.local` 別ファイル方式に書換済み（`agents/infra-phase-2-supabase.md:244-247`「以前はコメントアウト保存だったが脆すぎた」）。だが `agents/infra-phase-5-finalize.md` は旧方式前提（:13 / :49 / :225）。Phase 5 の .env.local 検証（:39-60）が常に誤検出し、自動修正で正しい設定を壊す恐れ。`.env.production.local` 方式へ更新する。
2. **[高] Secrets 名の投入/参照不一致**: `deploy-staging.yml:50-52,83-85` は `secrets.PROD_SUPABASE_URL / PROD_SUPABASE_ANON_KEY / PROD_SUPABASE_SERVICE_ROLE_KEY` を参照するが、`agents/infra-phase-4-github-actions.md:160-165` は `PROD_SUPABASE_PROJECT_REF / PROD_SUPABASE_DB_URL` のみ投入。`ci.yml:66-67` の `secrets.NEXT_PUBLIC_SUPABASE_URL / ANON_KEY` も未投入。SERVICE_ROLE_KEY は Phase 2（:184 で anon のみ抽出）で取得すらしていない。→ テンプレ参照名を正として Phase 4 の投入リストを揃え、SERVICE_ROLE_KEY は使用実態に合わせ取得追加 or 参照除去。
3. **[中] Vercel トークン CLI 化**: Phase 4 と SKILL.md:237 は「dashboard 手動のみ」前提で Playwright 化しているが、2026 年時点で `vercel tokens add` CLI と REST API が存在。`vercel login` の OAuth セッションで動くか検証し、動けば Playwright/手動を CLI 一発に置換（動かなければ現状維持 + 調査結果を注記）。
4. **[中] Actions が 2 世代古い**: 全テンプレの `actions/checkout@v4` / `actions/setup-node@v4` → v6 へ（upload-artifact@v4 / github-script@v7 は現行のまま）。
5. **[中] Preview deploy 方針の文書間矛盾**: README.md:30 / `agents/infra-phase-5-finalize.md:179` / `deploy-preview.yml:23` で「PR 時に Preview deploy するか」の記述が矛盾。実装（Draft skip、Ready for review で deploy）を正として文書側を統一。
6. **[中] Phase 1 の Step 番号ズレ**: `agents/infra-phase-1-hearing.md:156-162` の「Phase 2 の Step 10 / 10.5」→ 実体は Step 11 / 11.5。
7. **[低] vercel link の用法矛盾**: `agents/infra-phase-3-vercel.md:64-67`（--project は既存用）vs :286（--yes --project {name} を使う）。正しい方に統一。
8. **[低] アーキ図の欠落**: `skills/infra-setup/SKILL.md:25` の Phase 4 説明に deploy-preview が欠落（実体は 5 本）。
9. **[低] version drift + 個人パス**: SKILL.md:4 の `version: 0.1.0` vs plugin.json 0.2.0。SKILL.md:261 の `/Users/oratta/Dropbox/...` ハードコード除去。

### 付録 B: change-2 (longrun browser-verify) の findings
1. **[最優先] browser-verifier orphan 化**: `templates/workflow/build-verify.workflow.js:98-111` は `longrun-verifier` のみ呼ぶが、workflow プロンプト（:99-103）と `schemas/verifier-score.schema.json` は 4 軸（functionality/quality/completeness/ux）+ `functionality=100, ux>=70` を要求。`agents/longrun-verifier.md:28-32` は自分の担当を 2 軸（品質・完成度）と宣言し functionality/ux は browser-verifier 担当と明記。だが browser-verifier はどの実行経路からも呼ばれていない。→ **(a) 復帰** で確定: build-verify.workflow.js に browser-verifier の Verify ステップを追加し 2+2 軸分担を機構化。render-workflow.mjs / params.json に `BROWSER_VERIFIER_AGENT_TYPE`（既定 `longrun:longrun-browser-verifier`）等の埋め込みポイントを追加。schema の分割 or 部分返却の設計は builder 判断・reviewer 承認。
2. **[高] 一次ソースが配布物の外**: `commands/exec.md:16-17`、`build-verify.workflow.js:7`、`review.workflow.js:7` が `_longruns/2026-06-12_harness-workflow-overhaul/workflow-tool-reference.md` を一次ソースに指定。archive・plugin 更新で消える。→ `plugins/longrun/references/workflow-tool-reference.md` へ移動し 3 箇所を `${CLAUDE_PLUGIN_ROOT}/references/...` に書換え（元の run ディレクトリには移動先を示すスタブを残す）。

### 付録 C: change-3 (longrun v5 掃除) の findings
1. **orchestrator 残骸**: `agents/longrun-verifier.md:38,:98` / `agents/longrun-browser-verifier.md:102,:151,:188` / `agents/longrun-builder.md:3`（description「checkpoint.mdを更新する」も実態と不一致）。存在しない orchestrator への修正依頼・checkpoint.md 起点のコンテキスト復元を、現構造（Workflow が FAIL 時 builder 再呼び出し / longrun-dir + plan.md + decisions.md 起点）に書き直す。
2. **dead code**: `scripts/update-checkpoint.sh`（31 行、フック設定が無く呼び出し経路ゼロ）を削除。
3. **--mode=mvp シム**: `skills/longrun-plan/SKILL.md:8-35` の GATE + 移行案内、`commands/plan.md`、`plugins/lr/commands/p.md:11`、`README.md:23-24,59,144-146`、`commands/mvp.md` の言及を削除・整理（marketplace はバージョン単位キャッシュのため恒久シム不要）。
4. **README changelog 化**: `README.md:5-85` の版履歴を CHANGELOG.md へ分離し、README は現行版概要 + アーキテクチャ + コマンド表に縮小。
5. **description 圧縮**: `plugins/longrun/.claude-plugin/plugin.json:4`（約 600 字）と `plugins/lr/.claude-plugin/plugin.json:4` を 1-2 文へ。marketplace.json 側の反映は change-7。
6. **checkpoint 節の格下げ**: `commands/exec.md:262-271` 等の checkpoint.md 運用を「decisions.md に統合可能な任意の人間向けメモ」に格下げ。`workflow-runs.jsonl` の runId 記録（:218-225）と Step 5 再開フローは維持。
7. **テスト追随**: `tests/mvp-plan-split.bats` / `tests/release-and-readme.bats` が旧仕様（シム存在・README 構成）を検証している場合は新仕様に更新。

### 付録 D: change-4 (worktree) の findings
1. **[高] command/skill 乖離**: `commands/wt-clean.md:226-245` の遅延診断が旧分類表（AHEAD_COUNT>0 → 🔴）のままで、SKILL.md v2.0.0 の squash マージ検出（Step B 検証 A/B/C）と「squash マージの罠」警告が欠落。command 経由で誤削除事故が再発しうる。
2. **[中] wt-setup も全文重複**: `commands/wt-setup.md:39-133` が SKILL.md とほぼ同一で drift の温床。
→ 両 command を「`${CLAUDE_PLUGIN_ROOT}/skills/<name>/SKILL.md` を Read してそのまま実行する」薄いラッパーに置換（frontmatter は維持、引数透過を保証）。
3. **[低・任意] `scripts/wt-setup.sh:35` の find -path グロブ挙動と `:62-67` の settings.local.json symlink 是非**: 実挙動を確認し、問題があれば修正、なければ現状維持 + コメント追記。

### 付録 E: change-5 (レポート系) の findings
1. **[中] weekly-report Step 3b の依存切断**: `SKILL.md:92-106` が `{source_path}/LLM/*.md`（auto-save.py の出力）を読む設計。`plugins/daily-report/agents/llm-log-compactor.md:33-100` の jq による native jsonl（`~/.claude/projects/*/`）直読ロジックを流用して置換。
2. **[低] command の古いパス**: `commands/weekly-report.md:8` が存在しない `.claude/skills/weekly-report/SKILL.md` を参照。plugin-relative な `skills/weekly-report/SKILL.md` 参照（daily-report と同方式）に修正。
3. **[低] 個人パス**: `SKILL.md:159` の `/Users/oratta/Dropbox/WorkSpace` を環境変数 / 設定ベースに置換。
4. **[低] cooking 残骸**: weekly-report SKILL.md 内の「1h-cooking」言及を現行の harvest 命名・実態に合わせて更新。
5. **[低] daily-report command frontmatter**: `commands/daily-report.md:2` の allowed-tools に `Agent` が無いが SKILL は Phase 1 で Agent 2 並列起動。実挙動を確認し、必要なら追加。
6. **[中] /schedule 非対話モード**: daily/weekly 両 SKILL.md に「cron / 非対話実行時: AskUserQuestion をスキップしデフォルト（daily=昨日、weekly=先週）で続行、対話依存 Step（口頭報告等）はファイル出力に代替」の節を追加。

### 付録 F: change-6 (廃止) の findings
1. **obsidian-llm-session-rules 廃止根拠**: `hooks/hooks.json:3-14` の Stop hook（auto-save.py）が native transcript の劣化コピーを毎ターン全文再書込（`auto-save.py:119-122`）、保存先 `Path(cwd)/'LLM'` ハードコード（:110）が CLAUDE.md の LLM_LOG_DIR 規約違反。research-workflow は `research-with-fallback` と 1:1 重複 + 壊れた tool ID（`SKILL.md:17-18` の `mcp__context7__*` は現行 `mcp__plugin_context7_context7__*` と不一致）。context-reader / session-logger は native memory / /export の下位互換。
2. **skill-aware-workflow 廃止根拠**: タスク前スキル探索はネイティブのスキル自動発見と冗長・衝突。`hooks/hooks.json:3-13` の PostToolUse matcher `"*"` が全ツール呼び出しで bash+jq を起動。Stop フックの「1 タスク完了」前提が実際の発火単位（毎ターン）と不整合（`finalize_log.sh:59`）。`/mnt/skills/` 前提（`skill-inventory/SKILL.md:22-24` 等）はローカル CLI に不在。plugin.json 未登録の孤児 `skills/n8n-workflow-git/` 同梱。
3. **退避**: `LLM/` 直下 53 ファイル → `"$LLM_LOG_DIR"`（= Vault `90 - LLM`。設定済み確認済）。mv 前後で件数照合、同名衝突はスキップしてリスト報告。
4. **backlog 消込み**: `openspec/backlog.md` の「Skill 命名規則リファクタリング」は対象 7 スキル全てが本 change の削除で消滅するため、項目ごと削除（消化の経緯を 1 行残すか backlog から完全除去かは builder 判断）。
5. **後始末手順の書き出し**: `{longrun-dir}/post-merge-steps.md` に `/plugin uninstall obsidian-llm-session-rules@oratta-claude-harness` / `/plugin uninstall skill-aware-workflow@oratta-claude-harness` / `/reload-plugins` / 各プロジェクト settings の enabledPlugins 掃除（skill-pack 利用）を記載。
6. **marketplace.json の責務分担（reviewer NOTE 反映）**: 廃止 2 プラグインの**エントリ除去は change-6** が行い、全編集プラグインの **version・description 同期は change-7** が行う。change-6 は version/description の同期に手を出さない。

### 付録 G: change-7 (ルート掃除・最終同期) の findings
1. **OpenSpec 4 重複製（計 40 ファイル）**: `.claude/skills/openspec-*` ×10 / `.claude/commands/opsx/` ×10 / `.agents/skills/openspec-*` ×10 / `.agents/skills/source-command-opsx-*` ×10。スキル一覧に `openspec-apply-change` と `opsx:apply` が二重掲載されコンテキスト汚染。openspec CLI（`openspec init --tools claude`）の生成物か調査 → CLI 管理なら設定で 1 系統に抑制、手動管理なら `.claude/` 側 1 系統を残して削除。判断がつかない場合は現状維持 + decisions.md 文書化に縮退。
2. **templates/rules/*.md（4 ファイル）**: どのプラグインからも参照ゼロ（grep 確認済み）。削除。
3. **cooking 残骸**: `docs/cooking-mvp-mode-plan.md` 削除、`.gitignore` の「1h-cooking session output」コメントを現行の harvest 命名に更新、`plugins/skill-pack/skills/skill-pack/SKILL.md` 内の cooking 言及掃除。
4. **skill-pack 注記**: `skillOverrides` は plugin skill（`plugin:skill` 形式）を制御しない旨を SKILL.md の `on/off` 説明付近に明記（`enabledPlugins` 側で扱う既存設計は正しい）。
5. **e2s 修正**: `commands/e2s-distill.md:21` の `realpath "$0"` → `${CLAUDE_PLUGIN_ROOT}` ベースに修正。
6. **最終同期**: 全編集プラグイン（infra / longrun / lr / worktree / daily-report / weekly-report / skill-pack / experience-to-skill）の plugin.json version bump を確認し、marketplace.json の version・description を同期。受け入れ条件 5-16 の統合検証を実行。
