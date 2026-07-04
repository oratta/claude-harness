# Plan: Anthropic公式ナレッジのハーネス反映（anthropic-knowledge-reflect）

## 生成情報
- 作成日: 2026-07-04
- Brain Dump元: /goal 指示「Anthropic公式ナレッジ調査→claude-harness実装 goal指示書」
- 調査体制: 並列3エージェント（Anthropicエージェント設計ナレッジ / Claude Code公式ベストプラクティス / リポジトリ現状マップ）。調査結果の全文は `research/` 配下に保存済み

## ゴール
Anthropic が公式に公開しているエージェント構築ナレッジ（engineering 記事11本 + Claude Code / Agent SDK 公式ドキュメント）を一次ソースとして調査し、その原則をこの marketplace リポジトリの 8 プラグインに反映する。longrun が既に体現している好パターン（schema契約・コードでの上限・単一ソース・context isolation・gate明文化）を基準系とし、未適用プラグイン（infra / weekly-report / worktree 等）への横展開と、公式基準（skill authoring / writing-tools / long-running harness / prompting）による全体監査を行う。

## ビジネスコンテキスト
- 対象ユーザー: このユーザー本人（marketplace の唯一のメンテナ兼利用者）
- 提供価値: (1) infra の散文状態受け渡し・`/tmp` 直書きなど実リスクの解消、(2) description・SKILL.md の公式基準準拠によるスキル自動起動精度とコンテキスト効率の改善、(3) longrun を公式ハーネス論文の語彙で明文化し、今後の設計判断の基準を一次ソースに接続する
- 成功指標: 受け入れ条件の grep/bats 機械検証が全て PASS、`research/` の一次ソース資料が run ディレクトリに永続化され今後の設計判断から参照可能になる

## 一次ソース（実装時の判断基準）
builder / reviewer は迷ったら以下を参照する（全て本 run の `research/` に保存済み・URL 実在確認済み）:
- `research/anthropic-agent-knowledge.md` — engineering 記事11本の統合資料（Building Effective Agents / multi-agent research / writing-tools / Agent SDK / context engineering / Agent Skills / code execution with MCP / advanced tool use / Claude Code best practices / skill authoring / prompting）
- `research/claude-code-official.md` — Claude Code 公式ドキュメント（Skills / Subagents / Hooks / Plugins / Memory / settings / Headless）の推奨・アンチパターン
- `research/repo-survey.md` — このリポジトリの現状マップと弱点 A〜H（ファイルパス特定済み）

## 技術要件
- スタック: Markdown（SKILL.md / commands / agents）+ bash / node スクリプト + JSON Schema + bats-core
- 参照パターン:
  - schema 契約の参照元: `plugins/longrun/schemas/*.schema.json` + `plugins/longrun/commands/exec.md`（外部ファイルが唯一のソース、プロンプトへ重複禁止の GATE 方式）
  - context 分離の参照元: `plugins/daily-report/skills/daily-report/SKILL.md` + `plugins/daily-report/agents/*.md`（サブエージェント並列起動・中間ファイル返却・最終 message は STATUS line のみ）
- 制約:
  - `~/.claude/rules/plugin-editing.md` 準拠: 編集した全プラグインで plugin.json version bump + marketplace.json 同期必須
  - このリポジトリの CLAUDE.md 準拠: worktree 作業は Draft PR バックアップ運用、main 直 push 禁止
  - `openspec/changes/archive/` と `_longruns/_archive/` は履歴のため一切触らない
  - モデル ID を直書きしない（`plugins/longrun/references/model-tiers.md` が唯一のソース）
  - **安全ゲートの文言は弱めない**: wt-clean のデータロス防止禁則・longrun の `<GATE>` 群は「決定論的に守らせる意図を持つ文」であり、強語調調律（change-5）の対象外
- テストフレームワーク: bats-core + `node --check` + grep ベースの参照ゼロ検証
- テスト実行コマンド: `find plugins -name '*.bats' -print0 | xargs -0 bats`

## スコープ
### 含むもの
- 全プラグインの description（plugin.json / SKILL.md / agents frontmatter）の公式基準監査と修正（change-1）
- infra の構造化出力契約導入と状態ファイルの `/tmp` 直書き是正（change-2）
- weekly-report の重量処理サブエージェント隔離（change-3）
- longrun のハーネス論文アラインメント（委譲契約・verify三層・敵対的レビュー調整・スケーリングルール・early-stop 抑制の明文化）（change-4）
- SKILL.md の progressive disclosure 準拠（500行制限・1階層参照・目次）と強語調の調律（change-5）
- プラグイン衛生の最終監査（`${CLAUDE_PLUGIN_ROOT}` 統一・永続データの `${CLAUDE_PLUGIN_DATA}` 検討・version/marketplace 最終同期）（change-6）

### 含まないもの
- harvest / sns-strategy / codex / vlog-album 等、別 marketplace（marketing-harness 等）のプラグイン（理由: 対象リポジトリ外。ただし本指示書の原則は将来そちらにも適用可能）
- 新規プラグイン・新規スキルの開発（理由: 本 run は既存資産への公式ナレッジ反映に限定）
- longrun の resumeFromRunId セッション跨ぎ制約（repo-survey 弱点H）の解消（理由: Claude Code 本体機能の制約であり plugin 側で解決不能。decisions.md に制約として記録するに留める）
- skill 評価スイート（3シナリオ評価・Claude A/B法）の本格導入（理由: 公式推奨だが工数大。backlog に記録して別 run）
- CLAUDE.md・`.claude/rules/` の変更（理由: 調査の結論は「現行運用ルールは公式仕様で追認される正しい設計。変更不要」）

## Changes分解

### change-1: description-audit
- **スコープ**: 全 8 プラグインの description をスキルオーサリング公式基準で監査・修正する。対象は (a) `plugins/*/.claude-plugin/plugin.json` の description、(b) `plugins/*/skills/*/SKILL.md` frontmatter の description、(c) `plugins/*/agents/*.md` frontmatter の description。基準: **三人称で書く（"I can help you..." 禁止）／「何をするか＋いつ使うか」の両方を含む／具体的トリガーキーワードを含む／1024字以内／曖昧語（helper/utils等）排除**。agent description には**委譲トリガー**（いつ委譲されるべきか）を明示する。特に `plugins/worktree/.claude-plugin/plugin.json` の複数段落 description を 1〜2 文に圧縮し、詳細は README へ移す。lr（6.2.0）と longrun（6.3.0）のバージョン非同期はエイリアス関係を確認し、意図的でなければ揃える。詳細は付録 A
- **使用スキル**: なし
- **依存関係**: 独立
- **config.yaml rules**:
  - "description の書き換えは『トリガー精度の改善』が目的。既存のトリガー句・限定句（Triggered ONLY by 等）の意図を保ったまま公式基準の型に整える（機能や発火条件を変えない）"
  - "marketplace.json の description 同期は change-6 に委ねる（本 change では plugin 側のみ）"
  - "SKILL.md frontmatter の description 変更後、当該スキルの発火条件が変わっていないことを変更前後の diff レビューで確認する"

### change-2: infra-structured-output
- **スコープ**: `plugins/infra/` の 5 フェーズ agent（`agents/infra-phase-*.md`）に構造化出力契約を導入する。(1) longrun の `schemas/*.schema.json` 方式に倣い `plugins/infra/schemas/phase-result.schema.json`（フェーズ毎の完了状態・生成物パス・警告・次フェーズへの引き継ぎ値）を新設し、各フェーズ agent の返却をこれに準拠させる、(2) 状態受け渡しファイル `/tmp/infra-setup-state.md` のハードコードを廃し、`${CLAUDE_PLUGIN_DATA}` 配下（または呼び出し元が指定するセッション毎パス）に移す、(3) 各フェーズの失敗時に「何が失敗し・どう直すか・リトライ可能か」を構造化して返すエラー契約を追加（writing-tools の actionable error 原則）。詳細は付録 B
- **使用スキル**: なし（longrun schemas/ パターンを流用）
- **依存関係**: 独立
- **config.yaml rules**:
  - "schema は外部ファイルを唯一のソースとし、agent プロンプトへ JSON 構造を重複コピーしない（longrun と同じ GATE）"
  - "`${CLAUDE_PLUGIN_DATA}` が実行環境で未定義の場合のフォールバック（ユーザー確認 or セッション scratchpad）を必ず定義する。`/tmp` 固定パスへのフォールバックは禁止"
  - "infra は対話型スキル（AskUserQuestion 使用）のため、フェーズ agent の schema 化が対話フローを壊さないことを SKILL.md のフェーズ受け渡し記述と突き合わせて確認する"

### change-3: weekly-report-isolation
- **スコープ**: `plugins/weekly-report/` の jsonl 直読・集約処理をサブエージェントに隔離する。daily-report の `agents/llm-log-compactor.md` パターン（生データをサブエージェント内に閉じ込め、凝縮した中間ファイルだけメインに返す。最終 message は STATUS line 1 行）を流用し、`plugins/weekly-report/agents/` に週次版 compactor を新設。SKILL.md 側は「compactor 起動 → 中間ファイル読込 → レポート合成」の薄いオーケストレーションに書き換える。サブエージェントの返却サマリは公式推奨の **1,000〜2,000 トークンの高シグナル凝縮**を目安とする。詳細は付録 C
- **使用スキル**: なし（daily-report の compactor パターンを流用）
- **依存関係**: 独立
- **config.yaml rules**:
  - "既存の非対話（cron）モードと bats テスト（`plugins/weekly-report/tests/*.bats`）を壊さない。テストは新構造に追随更新する"
  - "サブエージェント隔離により機能が変わらないこと（同じ週・同じデータで同等のレポートが出ること）を検証手順に含める"
  - "サブエージェント定義には objective / output format / tool guidance / task boundaries の 4 点を明記する（multi-agent research の委譲フレームワーク）"

### change-4: longrun-paper-alignment
- **スコープ**: `plugins/longrun/` を公式ハーネス論文・ベストプラクティスの語彙で強化する。(1) **委譲契約の明文化**: `agents/longrun-{builder,verifier,browser-verifier,reviewer}.md` 等の定義に objective / output format / tool guidance / task boundaries の 4 点が揃っているか監査し、欠けを補う、(2) **verify 三層の明示**: verifier 系ドキュメントに rules-based（lint/test）＋ visual（ブラウザ/スクショ）＋ LLM-judge の三層分担と「『成功した』と主張せず evidence（テスト出力・exit code・スクショ）を提示する」原則を明文化、(3) **敵対的レビューの調整**: reviewer/verifier のプロンプトに「correctness / 要件に関わるギャップのみ flag する（健全でも何か報告しようとする過剰指摘・過剰エンジニアリング誘発を抑止）」を追加、(4) **スケーリングルール**: exec.md / workflow テンプレに「サブエージェントはチャットの約15倍のトークンを消費する。並列 fan-out は変更の複雑度に応じてスケールさせる」旨の努力量スケーリング指針を追加、(5) **early-stop 抑制**: builder 系プロンプトに「トークン残量を理由に早期終了せず、限界前に進捗を外部状態（git commit / decisions.md）へ保存する」を追加、(6) **1セッション1機能・外部状態+git**: exec.md の設計思想節に公式論文の語彙（compaction だけでは不十分、状態の外部化、説明的 commit）で現行設計の根拠を記述し references/ の一次ソースリンクを付す、(7) 弱点G（frontmatter `model:` と実行時 `opts.model` の二重管理）の優先順位を exec.md か references/model-tiers.md に 1 行で明記。詳細は付録 D
- **使用スキル**: なし
- **依存関係**: 独立（ただし change-5 と同一ファイルを触る場合は change-5 を後に直列化）
- **config.yaml rules**:
  - "既存の `<GATE>` 群・schema 外部ファイル原則・stopReason 構造化・model-tiers 単一ソースは変更しない（既に公式準拠。触るのは追記と語彙の接続のみ）"
  - "追記は『最小の高シグナルトークン集合』原則に従い、各追記に対して『この行を消すと agent がミスするか？』を自問して過剰な説明を足さない"
  - "workflow テンプレ（*.workflow.js）を触った場合はレンダリング後 `node --check` PASS を必須とする"

### change-5: progressive-disclosure-slim
- **スコープ**: 全プラグインの SKILL.md / commands を progressive disclosure 公式基準に揃える。(1) **500 行超の SKILL.md を分割**: `plugins/worktree/skills/wt-clean/SKILL.md`（506行）を本文と `references/` に分割（他に 500 行超が見つかれば同様に）。477 行の daily-report、420 行の longrun-plan は「500 行未満」基準内のため必須対象外（余裕があれば参照分離を検討）、(2) **参照は 1 階層のみ**: SKILL.md → 参照ファイル → さらに別ファイル、というネスト参照を検出して 1 階層に平坦化、(3) **100 行超の参照ファイルに目次**を付す、(4) **強語調の調律**: 全プラグインの指示文から「CRITICAL / You MUST / 絶対に」等の強語調の**乱用**を検出し、現行モデルでは overtrigger を招くため通常語調に落とす。ただし技術要件の制約に定めた通り、**安全ゲート（データロス防止・破壊的操作の禁則・GATE 表記）は対象外として維持**、(5) 時限情報（「2026年時点では」等、賞味期限のある記述）の排除。詳細は付録 E
- **使用スキル**: なし
- **依存関係**: change-1, change-4（同一ファイル群を触るため、description 確定・longrun 追記の後に直列実行）
- **config.yaml rules**:
  - "分割は『本文=ワークフローの骨格と判断基準、references/=詳細手順・具体例・トラブルシュート』の切り方とする。発火時に必要な判断材料を references へ追い出さない"
  - "強語調の調律は 1 ファイルずつ diff レビューし、安全ゲート・禁則に該当する文が 1 つでも弱まっていないかを明示的に確認する。迷ったら現状維持"
  - "wt-clean の squash マージ検出（検証A/B/C）と AskUserQuestion 後別ターン実行の禁則は一言一句失わない（過去 run の GATE を継承）"

### change-6: plugin-hygiene-final
- **スコープ**: プラグイン衛生の最終監査と統合。(1) plugin 内スクリプト・ドキュメントの `${CLAUDE_PLUGIN_ROOT}` 参照統一（plugin 外への `../` 相対参照が残っていないか棚卸し。キャッシュ配布で壊れるため）、(2) 永続データ（実行間で残すべき状態・キャッシュ）を持つプラグインの `${CLAUDE_PLUGIN_DATA}` 移行検討（少なくとも infra の状態ファイルは change-2 で移行済み。他に該当があれば同方式）、(3) 編集した全プラグインの plugin.json version bump、(4) marketplace.json の version・description 最終同期（plugin.json と完全一致）、(5) 受け入れ条件の統合 grep 検証一式の実行。詳細は付録 F
- **使用スキル**: なし
- **依存関係**: change-1〜5 全て（marketplace.json 同期は全プラグイン編集の完了後。同一ファイル競合回避のため最後に直列実行）
- **config.yaml rules**:
  - "version bump は SemVer に従う（description のみ=patch、schema/構造変更=minor）"
  - "marketplace.json と plugin.json の両方に version を書いた場合 plugin.json が無警告で優先される公式仕様に注意し、両者を機械照合する"
  - "`${CLAUDE_PLUGIN_DATA}` への移行は『update で消えては困るデータ』のみ。一時ファイルはセッション scratchpad のままでよい（過剰移行しない）"

## モデル割り当て

自律実行（exec）の各フェーズ agent に割り当てるモデルティアを change × ロールごとに指定する。
ティアは `plugins/longrun/references/model-tiers.md` で解決する（モデル ID は書かない）。

| change | ロール | ティア(haiku/sonnet/inherit) | 理由 | 上書き |
|--------|--------|------------------------------|------|--------|
| change-1 | builder | sonnet | description 書き換えは基準明確な文書修正 | |
| change-1 | verifier | haiku | 三人称・字数・型の grep/目視定型検証 | |
| change-1 | reviewer | inherit | トリガー精度への影響判断（発火条件を変えない）が必要 | |
| change-2 | builder | inherit | schema 設計 + 対話フロー非破壊の複雑実装 | |
| change-2 | verifier | sonnet | schema/agent 間の整合確認（中規模） | |
| change-2 | reviewer | inherit | 状態受け渡し設計のアーキテクチャレビュー | |
| change-3 | builder | sonnet | 既存 compactor パターンの流用実装 | |
| change-3 | verifier | sonnet | 同等出力の機能検証（bats + 実行比較） | |
| change-3 | reviewer | inherit | 委譲契約 4 点の充足判断 | |
| change-4 | builder | inherit | 論文語彙と既存設計の接続。過剰追記の抑制判断が必要 | |
| change-4 | verifier | haiku | 追記箇所の存在確認と node --check の定型検証 | |
| change-4 | reviewer | inherit | 「最小の高シグナル」原則との整合レビュー | |
| change-5 | builder | inherit | 安全ゲートを弱めない調律判断が必要（誤修正リスク高） | |
| change-5 | verifier | sonnet | 分割後の参照整合・行数・目次の検証 | |
| change-5 | reviewer | inherit | 禁則文言の保全レビュー（一言一句） | |
| change-6 | builder | sonnet | version bump・同期・棚卸しの定型寄り作業 | |
| change-6 | verifier | haiku | 統合 grep 検証一式の定型実行 | |
| change-6 | reviewer | inherit | リポジトリ全体整合の最終レビュー | |

## 画面・UI設計
該当なし（Markdown プラグイン集リポジトリ。UI 成果物は生成しない）

## データモデル
該当なし。構造的整合性制約は (1) marketplace.json ↔ 各 plugin.json の version 一致、(2) 新設する `plugins/infra/schemas/phase-result.schema.json` ↔ 各フェーズ agent の返却構造の一致、の 2 点

## 受け入れ条件

**必須条件（常に含める）:**
1. [ ] 全changeのOpenSpec仕様が作成・レビュー済み
2. [ ] 全changeのテストが作成され全てPASSしている（`find plugins -name '*.bats' -print0 | xargs -0 bats`）
3. [ ] ビルドエラーなし（全 workflow テンプレ・.mjs の `node --check` PASS + 全 *.json の JSON parse PASS）
4. [ ] 統合テストがPASS（worktreeマージ後、下記 5-14 の機械検証を main 上で再実行して全 PASS）

**機能固有の条件:**
5. [ ] 全 SKILL.md / agents の frontmatter description に一人称表現（"I can" / 「私が」等）が無い: `grep -rn '^description:.*\bI can\b' plugins/` が 0 件
6. [ ] `plugins/worktree/.claude-plugin/plugin.json` の description が 2 文以内（複数段落ブロブの解消）
7. [ ] `grep -rn "/tmp/infra-setup-state" plugins/infra/` が 0 件、`plugins/infra/schemas/phase-result.schema.json` が存在し JSON parse PASS、全 5 フェーズ agent が同 schema を参照している
8. [ ] `plugins/weekly-report/agents/` に compactor agent が存在し、その定義に objective / output format / tool guidance / task boundaries の 4 節がある。SKILL.md 本体に jsonl 直読の jq 手順が残っていない
9. [ ] longrun の builder/verifier/reviewer 系 agent 定義すべてに委譲契約 4 点（objective / output format / tool guidance / task boundaries）が確認できる
10. [ ] longrun の verifier 系ドキュメントに「evidence 提示」原則と verify 三層（rules-based / visual / LLM-judge）の記述があり、reviewer 系プロンプトに「correctness / 要件に関わるもののみ flag」の記述がある
11. [ ] `plugins/*/skills/*/SKILL.md` に 500 行以上のファイルが無い: `find plugins -path '*/skills/*/SKILL.md' | xargs wc -l | awk '$1>=500 && $2!="total"'` が 0 件
12. [ ] wt-clean の squash マージ検出（検証A/B/C）と AskUserQuestion 後別ターン実行の禁則文言が変更前と同一内容で存在する（diff で確認）
13. [ ] plugin 外への相対参照が無い: `grep -rn '\.\./\.\./' plugins/*/skills/ plugins/*/commands/ plugins/*/agents/` で plugin ルートを越える参照が 0 件
14. [ ] 編集した全プラグインで plugin.json の version が bump され、marketplace.json の対応エントリと version・description が一致する

## 意思決定ガイドライン
- 優先順位: 安全性（安全ゲートを弱めない・機能を壊さない） > 公式基準準拠 > トークン効率 > 網羅性
- リスク許容度: 保守的。特に change-5 の語調調律は「迷ったら現状維持」。削除・書き換えは git tracked の状態で行う
- 不明点の扱い: 公式基準の解釈に迷ったら `research/` の一次ソース資料を再読する。それでも曖昧なら「現状維持 + decisions.md に論点記録」に倒す
- 過剰反映の抑制: 公式ナレッジの反映自体が overengineering にならないこと。「この行を消すと agent がミスするか？」を全追記に適用する（Claude Code best practices の CLAUDE.md 基準を plugin 指示文にも準用）
- スコープ外事項の発見: 実装中に見つけた改善候補（skill 評価スイート等）は実装せず `openspec/backlog.md` に記録する

## 動作確認方法
- 開発サーバー: なし（Markdown プラグイン集。アプリケーションではない）
- テスト: `find plugins -name '*.bats' -print0 | xargs -0 bats` / `node --check <各 .mjs / レンダリング済み workflow .js>`
- 確認手順:
  1. 受け入れ条件 5-14 の各 grep / find コマンドを実行し全て期待値になることを確認
  2. `node plugins/longrun/scripts/render-workflow.mjs` でテンプレをレンダリングし `node --check` が通ることを確認
  3. マージ後、新しい Claude Code セッションで `/reload-plugins` を実施し、スキル一覧の description が更新されていることを確認
  4. `/wt-clean`（引数なし・選択画面まで）、`/daily-report --help` 相当、`/lr:p` 起動で各プラグインが壊れていないことを smoke 確認
  5. weekly-report を過去週に対して実行し、隔離前と同等のレポートが生成されることを確認

## Brain Dumpからの原文メモ
> /goal Anthropic公式ナレッジ調査→claude-harness実装 goal指示書
>
> （解釈: Anthropic 公式のエージェント構築ナレッジ（論文・エンジニアリングブログ・公式ドキュメント）を調査し、この claude-harness リポジトリへの実装計画を goal 指示書としてまとめる。調査は並列 3 エージェントで実施し、結果は research/ に永続化した）

---

## 付録: 公式ナレッジ → 実装対応表（一次ソース要約）

builder はこの付録と `research/*.md` を実装仕様の一次ソースとして使うこと（調査セッションのコンテキストは実行時に存在しない）。

### 付録 A: change-1 (description-audit) の根拠
- **Skill authoring best practices**（`research/anthropic-agent-knowledge.md` ソース10）: description はトリガー精度を決める最重要フィールド。**必ず三人称**（システムプロンプトに注入されるため）・「何をするか＋いつ使うか」の両方・具体的キーワード・最大1024字。曖昧名（helper/utils）回避。Claude は 100+ スキルから description だけで選ぶ。
- **Subagents 公式Doc**（`research/claude-code-official.md` §2）: agent description には**委譲トリガー**を書く（例: "Expert code reviewer. Use proactively after code changes."）。範囲は狭く具体的に。
- **context engineering**（ソース5）: トリガー条件が重複するスキルは bloated tool set 問題を起こす。「人間がどのツールを使うか断定できないなら AI にも無理」。
- **現状の問題**（`research/repo-survey.md` 弱点C）: `plugins/worktree/.claude-plugin/plugin.json` の description が複数段落の巨大ブロブで marketplace.json にも重複コピーされ、全セッションでトークンを消費。lr 6.2.0 vs longrun 6.3.0 のバージョン非同期。

### 付録 B: change-2 (infra-structured-output) の根拠
- **multi-agent research**（ソース2）: サブエージェントには objective / **output format** / tool guidance / task boundaries を明示。曖昧だと重複・欠落が起きる。
- **writing-tools**（ソース3）: エラーメッセージは不透明コードでなく「具体的で実行可能な改善」を返す。返り値は高シグナルのみ。
- **Plugins 公式Doc**（`research/claude-code-official.md` §4）: 永続データは `${CLAUDE_PLUGIN_DATA}`（plugin update で消えない領域）。plugin 外パスのハードコードはキャッシュ配布で壊れる。
- **現状の問題**（repo-survey 弱点A・B）: `plugins/infra/agents/infra-phase-*.md` は構造化出力契約がなく `/tmp/infra-setup-state.md` 直書きの散文で状態を受け渡す。longrun が v6.0.0 で廃止した「散文パース」方式の真逆。longrun の `schemas/{builder-report,verifier-score,reviewer-verdict}.schema.json` + 「schema は外部ファイルが唯一のソース」GATE が流用元。

### 付録 C: change-3 (weekly-report-isolation) の根拠
- **context engineering**（ソース5）: サブエージェントは「親のコンテキストを汚さない関心の分離装置」。クリーンなコンテキストで探索し **1,000〜2,000 トークンの凝縮サマリ**を返す。
- **Claude Code best practices**（ソース9）: 調査・大量データ処理はサブエージェントに委譲し、メインコンテキストを保護する。
- **現状の問題**（repo-survey 弱点E）: weekly-report は agent 0 本で jsonl 直読・集約をメインコンテキストで実行。daily-report が確立した隔離パターン（`agents/llm-log-compactor.md`: 生データを閉じ込め voice.md/dailyLLM.md だけ返す、最終 message は STATUS line 1 行）と非対称。
- **委譲契約**（ソース2）: 新設 agent には objective / output format / tool guidance / task boundaries の 4 点を明記。

### 付録 D: change-4 (longrun-paper-alignment) の根拠
- **effective-harnesses-for-long-running-agents**（`research/claude-code-official.md` §7、直接確認済み）: compaction だけでは不十分。外部状態ファイル + git で一貫性担保。**1セッション1機能**で過剰実装を防ぐ。セッション末に説明的 commit。検証は人間と同じ E2E で、丁寧なテスト後にのみ passing を立てる。→ longrun は既にほぼ同型。論文の語彙で明文化し一次ソースに接続する。
- **Agent SDK**（ソース4）: verify は rules-based ＋ visual ＋ LLM-judge の**三層**。longrun の verifier（品質/完成度）+ browser-verifier（機能性/UX）分担を三層の語彙で説明する。
- **Claude Code best practices**（ソース9）: 「成功した」と主張させず **evidence**（テスト出力・exit code・スクショ）を提示させる。**敵対的レビューは correctness / 要件に関わるもののみ flag**（レビュアーは健全でも何か報告しようとするため過剰エンジニアリングを誘発する）。
- **multi-agent research**（ソース2）: エージェントはチャットの約4倍、マルチエージェントは約15倍のトークン消費。**努力量スケーリングルールをスキル内に明記**して過剰 fan-out を防ぐ（初期版は単純クエリに 50 サブエージェントを生成する暴走をした）。
- **Prompting best practices**（ソース11）: 「トークン残量を理由に早期終了するな、限界前に progress を外部保存せよ」を明示。状態追跡は git が得意。
- **現状の問題**（repo-survey 弱点G）: frontmatter `model: opus` と実行時 `opts.model` の優先順位が読めない。1 行の明記で解消。

### 付録 E: change-5 (progressive-disclosure-slim) の根拠
- **Skill authoring best practices**（ソース10）: SKILL.md 本文は **500 行未満**。**参照は SKILL.md から 1 階層のみ**（ネストすると部分読みで不完全になる）。**100 行超の参照ファイルには目次**。時限情報を避ける。「Claude は既に賢い」前提で既知のことは書かない（良い例≈50トークン、悪い例≈150トークン）。
- **Agent Skills**（ソース6）: progressive disclosure 3層により、バンドルできるコンテキスト量は事実上無制限（読まれるまでコスト0）。→ 分割はペナルティなし。
- **Prompting best practices**（ソース11）: **現行モデルは system prompt への反応が強く、旧来の「CRITICAL: You MUST…」は overtrigger する**ため通常語調に落とす。ただし本 plan の制約どおり安全ゲートは対象外。
- **現状の問題**（repo-survey 弱点D）: `wt-clean` SKILL.md が 506 行で公式基準超過。daily-report(477)/longrun-plan(420) は基準内。

### 付録 F: change-6 (plugin-hygiene-final) の根拠
- **Plugins 公式Doc**（`research/claude-code-official.md` §4）: version bump しない内容変更はキャッシュのため他プロジェクトに反映されない（既知事故の公式裏付け）。plugin.json と marketplace.json 両方に version を書くと **plugin.json が無警告で優先**。plugin 内参照は `${CLAUDE_PLUGIN_ROOT}`、永続データは `${CLAUDE_PLUGIN_DATA}`。
- **現行運用ルールの追認**: 調査の結論として、`~/.claude/rules/plugin-editing.md`（marketplace 版のみ編集・version 必須 bump・ローカルコピー禁止）と CLAUDE.md の Draft PR 運用は**公式仕様から導かれる正しい設計であり変更不要**。

### 付録 G: 今回反映しない公式ナレッジ（backlog 候補）
- **skill 評価スイート**: 「広範なドキュメントを書く前に評価を作れ」「3シナリオ評価 + Claude A/B 法」「約20クエリの LLM-as-judge」（ソース2・10）。→ 効果は大きいが工数大。`openspec/backlog.md` へ記録。
- **Tool Use Examples**: 複雑パラメータのツール定義に利用例を添えると精度 72%→90%（ソース8）。→ 自作 MCP ツールを持たない本リポジトリでは適用面が薄い。将来 MCP を同梱する際の基準として記録。
- **Stop hook による決定論的検証ゲート**: 「check を出せないなら ship しない」（ソース9）。→ longrun の verify は Workflow 内で機構化済みのため二重化しない。プロジェクト側 CI の将来課題として記録。
