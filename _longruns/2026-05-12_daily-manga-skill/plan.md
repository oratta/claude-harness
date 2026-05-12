# Plan: Daily Manga Skill

## 生成情報
- 作成日: 2026-05-12
- Brain Dump元: セッション内（lr:p 引数）
- 質問回数: 4問（Vault パス確認 + 3 連質問）

## ゴール
1日の活動データを集約 → ドラマの主人公視点で物語化 → gpt-image-2 で 2 ページ漫画を生成 → Obsidian Vault に保存する Claude Code skill を、`oratta-claude-harness` marketplace の新規 plugin (`daily-manga`) として実装する。情報収集等の固定作業は bash script に寄せ、LLM は物語生成と漫画プロンプト生成のみ担当する。

## ビジネスコンテキスト
- 対象ユーザー: oratta（自分専用）
- 提供価値: 1日の振り返りを「漫画」という親しみやすい形式で残し、後から見返したときの感情的訴求力を高める。weekly-report の daily 版 + ビジュアル化レイヤー
- 成功指標: 1コマンド `/daily-manga [YYYY-MM-DD]` で 5〜10 分以内に Vault 内に Daily ノート（漫画セクション挿入）+ 漫画画像 2 枚が書き出されること

## 技術要件
- スタック:
  - Bash script（情報収集）
  - Claude Code skill (Markdown SKILL.md 駆動)
  - Claude subagent（Agent ツール、subagent_type: general-purpose）— 物語生成 3 段 + プロンプト生成 + Vault 書き出し
  - **Codex CLI 経由の画像生成**（`codex:codex-rescue` subagent → built-in gpt-image-2 / ChatGPT Pro サブスク枠を使用、API key 不要）
  - jq（JSON パース）
- 参照パターン:
  - `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/weekly-report/skills/weekly-report/SKILL.md` の Step 3-5（データ収集 + project-registry 参照 + Vault 書き出し）
  - `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/weekly-report/.claude-plugin/plugin.json` の plugin manifest 構造
  - `~/.claude/plugins/marketplaces/openai-codex/plugins/codex/agents/codex-rescue.md` の codex-companion CLI 呼び出しパターン
- 制約:
  - skill 本体ロジックは shell script に寄せ、LLM は「物語化・添削・リファイン・漫画プロンプト生成」のみ担当
  - **エージェント分担: 物語生成（storyteller/critic/refiner）+ プロンプト生成 + Vault 書き出し は Claude、画像生成のみ Codex CLI（サブスク枠を活用）**
  - skill は marketplace 経由で配布（`~/.claude/rules/plugin-editing.md` のルール厳守）
  - Vault パスは weekly-report と同じ自動推論方式（`__META` ディレクトリマーカーで検出）
  - 画像生成は Codex CLI のサブスク枠を消費（画像生成 turn は通常の 3-5 倍速く枠を消費。Pro $100 = 10x 枠 / Pro $200 = 20x 枠）
  - `OPENAI_API_KEY` 環境変数は **unset 推奨**（セットされていると Codex が API 課金経路に切り替わる仕様）
- テストフレームワーク: bats（bash script の単体テスト）+ 手動 E2E（生成された Daily ノート + 漫画ファイルの存在 + 構造確認）
- テスト実行コマンド: `bats plugins/daily-manga/tests/*.bats`

## スコープ

### 含むもの
- daily-manga plugin 骨格（plugin.json / SKILL.md / commands/daily-manga.md）
- Bash collection script (`scripts/collect-daily.sh`): git log / Claude JSONL / Vault 更新 / Sunsama / `Daily-Fieldy-{date}.md` → `report.md` 生成
- Claude subagent 3 段（storyteller → critic → refiner）で物語生成
- gpt-image-2 呼び出しスクリプト (`scripts/gen-manga.sh`): プロンプト→curl→base64 デコード→PNG 保存
- Vault 書き出し: `01 - DAILY/YYYY-MM-DD.md` に「## 🎬 今日の漫画（自動生成）」セクションを冪等挿入
- 漫画画像保存: `01 - DAILY/manga/YYYY-MM-DD/page{1,2}.png`
- スラッシュコマンド `/daily-manga [YYYY-MM-DD]`
- bats テスト（情報収集スクリプトの単体テスト）
- README（インストール + 使い方）

### 含まないもの
- Codex を物語添削（critic）に使うこと（理由: ユーザー指示で「全 Claude エージェント」、ただし画像生成のみ例外的に Codex CLI のサブスク枠活用）。リサーチ §5 赤旗3「同一モデル loop の self-bias」リスクは残ることを認識した上での決定。v0.2 で外部モデル critic（Codex / Sonnet 等）導入を再検討する前提
- OpenAI API の直接呼び出し（理由: 画像生成は Codex CLI built-in 経由でサブスク枠を使用するため API key 不要）
- リアルタイム更新・cron 自動化（理由: 手動起動で十分。v0.2 以降）
- HTML/SVG 漫画レイアウト（理由: gpt-image-2 で完結）
- Fieldy webhook → Notion → Markdown 変換 pipeline 自体の実装（理由: 既存パイプライン済み — `Daily-Fieldy-{date}.md` を Read するのみ）
- weekly-report との統合（理由: 既存 skill が担当、daily-manga は独立）
- キャラクター一貫性の管理（LoRA / seed 固定）（理由: MVP では gpt-image-2 のプロンプト埋め込みで簡易対応、本格対応は v1.0）
- dailyReport repo 自体への commit/push（理由: Vault 書き出しは Vault 側 git で管理）

## Changes分解

### change-A: daily-manga plugin 骨格 + 情報収集スクリプト
- **スコープ**:
  - `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/daily-manga/.claude-plugin/plugin.json`
  - `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/daily-manga/skills/daily-manga/SKILL.md`（スケルトンのみ。Step 1: 引数パース + 作業ディレクトリ作成 + collect-daily.sh 起動まで）
  - `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/daily-manga/commands/daily-manga.md`
  - `scripts/collect-daily.sh`（情報収集の本体）
  - `scripts/lib/vault-detect.sh`（Vault パス自動検出）
  - `scripts/lib/iso-week.sh`（日付パース）
  - `tests/collect-daily.bats`
- **使用スキル**: なし（shell + Markdown のみ）
- **依存関係**: 独立
- **config.yaml rules**:
  - "shell script は POSIX bash 互換、macOS bash 3.2 で動作すること"
  - "weekly-report SKILL.md の Step 3-5 のデータ収集ロジックを daily 単位で踏襲（`--since={date} --until={date+1}`）"
  - "Vault パス検出は `__META` ディレクトリマーカーで `find ~/Dropbox -maxdepth 4 -name __META -type d` パターン。検出 0 件 → exit 1 + 明示エラー、検出 2 件以上 → 環境変数 `DAILY_MANGA_VAULT` を要求 + exit 1"
  - "Fieldy データは Vault root の `Daily-Fieldy-YYYY-MM-DD.md` を Read（存在しなければ Fieldy セクションは『Fieldy データなし』で出力して続行）"
  - "Fieldy ファイルから storyteller に渡す抽出範囲: frontmatter 直下の `> [!info]` 引用（一日の通底テーマ）+ `## 今日のテーマ` 全体 + `## タイムライン` 配下の `> [!quote]` 引用のみ。本文表は要約せず元の Markdown 行を維持"
  - "Sunsama は MCP 経由（weekly-report と同じ ToolSearch ロード手順）。MCP 未接続時は Sunsama セクションを `⚠️ Sunsama MCP 未接続` で出力して続行"
  - "出力 `report.md` は `<repo>/.tmp/daily-manga/<date>/report.md` に固定"
  - "report.md の各セクションの 1 行フォーマット（storyteller が安定 parse できるよう確定）:
     - Git: `- {repo-name}: {sha7} {commit-subject} (+{add}/-{del})`
     - Claude セッション: `- {project-slug}: {N} ターン / 主トピック: {first-user-message-100chars}`
     - Sunsama: `- [{完了/未完}] {task-title} (planned: {min}min)`
     - Fieldy: 上記抽出範囲をそのまま転記（要約しない）
     - Vault 更新: `- {relative-path-from-vault} ({mtime HH:MM})`"
  - "対象 Daily ノート `<vault>/01 - DAILY/<date>.md` が Templater 未展開リテラル（`<% tp.date.now() %>` 等）を含む状態を検出した場合、collect-daily.sh は警告を report.md 末尾に追記して続行（Vault 書き出しフェーズで判定材料とする）"

### change-B: 物語生成 3 段サブエージェント
- **スコープ**:
  - SKILL.md の Step 2-4 セクション追加（storyteller / critic / refiner の Agent ツール呼び出し定義）
  - 各 subagent への prompt template（SKILL.md 内に埋め込み）
  - 中間ファイル（story-draft.md / story-review.json / story-final.md）の構造定義
- **使用スキル**: なし（Agent ツール経由）
- **依存関係**: change-A
- **3 段化の維持判断（reviewer の 1 段化提案への返答）**:
  reviewer は「全 subagent が同一 Claude モデルなら critic→refiner の self-bias 軽減効果は限定的」として 1 段化を推奨したが、ユーザーが Step 4 Interview で明示的に「別サブエージェントで 3 段（推奨）」を選択しているため**3 段を維持する**。
  ただし「全 Claude では完全な self-bias 解消は不可」であることは認め、v0.2 で外部モデル critic（Codex / Sonnet）導入を計画として残す。
  MVP 段階での 3 段化の効用は (a) コンテキスト分離による偏りリセット、(b) 出力フォーマットを 3 段化前提で安定化させ v0.2 の差し込みを容易にすること、の 2 点に限定する。
- **config.yaml rules**:
  - "3 段は必ず別 subagent として呼ぶ（同一 context 内での処理は禁止 — コンテキスト分離による偏りリセット効果を担保）"
  - "全 subagent は subagent_type: general-purpose で foreground 実行"
  - "subagent 間は ファイル経由（プロンプト直接埋め込み禁止 — context 肥大化防止）"
  - "critic 出力は valid JSON 必須、構造: `{\"issues\": [...], \"rewrites\": {\"<コマ番号>\": \"<修正案>\"}}`"
  - "refiner はコマ数を減らしてはならない（受け入れ条件 #8）"
  - "story-final.md の構造は story-draft.md と同一（refiner が JSON や別フォーマットで出さない）。これにより v0.2 で外部 critic を差し込んでも refiner 以降の処理が無変更で済む"

### change-C: Codex CLI 経由 gpt-image-2 漫画化 + Vault 書き出し
- **スコープ**:
  - SKILL.md の Step 5-6 セクション追加（manga-prompt-builder subagent + codex:codex-rescue 呼び出し + vault-writer subagent）
  - `scripts/invoke-codex-image.sh`（codex-companion CLI を呼び出すラッパー）
  - `scripts/vault-insert.sh`（既存 Daily ノートへの冪等セクション挿入）
  - `tests/invoke-codex-image.bats`（モック codex-companion で動作確認）
  - `tests/vault-insert.bats`（4 種 fixture で冪等挿入アルゴリズム検証）
- **使用スキル**: `codex:codex-rescue` (画像生成タスク委譲)
- **依存関係**: change-B
- **config.yaml rules**:
  - "画像生成は `codex:codex-rescue` Agent を foreground 同期で 2 回呼ぶ（page1, page2）。**並列起動禁止**（Codex 枠の同時消費を制御するため）"
  - "Codex 呼び出しの実体は `node ${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs task --wait --write 'プロンプト本文'`（codex-rescue agent 定義準拠）"
  - "Codex への画像生成プロンプト構造（plan 確定値、再調査不要）:
     - 冒頭固定文: `gpt-image-2 で画像を 1 枚生成してください。model=gpt-image-2, size=1024x1536, quality=medium。`
     - 続けて: `生成画像を <絶対パス: <vault>/01 - DAILY/manga/<date>/pageN.png> に保存してください。`
     - 続けて: `画像内容: <manga-prompts.json から page N の prompt を埋め込み>`
     - Codex CLI が built-in image generation で gpt-image-2 を呼び、`--write` フラグで指定パスに PNG 保存"
  - "OPENAI_API_KEY 環境変数は明示的に unset してから Codex を呼ぶ（API 課金経路への意図しない切替防止）。invoke-codex-image.sh 冒頭で `unset OPENAI_API_KEY` を実行"
  - "Codex 呼び出しはリトライ 1 回まで、それ以上失敗したら exit 1 + エラーメッセージで終了"
  - "Codex CLI 未セットアップ（`codex-companion.mjs` が見つからない）の場合は `/codex:setup` の実行を促すエラーメッセージで exit 1"
  - "画像最終保存先: `<vault>/01 - DAILY/manga/YYYY-MM-DD/page{1,2}.png`（Codex に直接書かせる）"
  - "Daily ノートには `![[manga/YYYY-MM-DD/page1.png]]` 形式で wikilink 埋め込み"
  - "冪等挿入アルゴリズム（確定仕様、vault-insert.sh で実装）:
     1. 対象ファイル `<vault>/01 - DAILY/<date>.md` を Read。frontmatter（先頭 `---` から次の `---` まで）と本文を分離
     2. 本文を行単位で走査し、行頭が `## 🎬 今日の漫画（自動生成）` で始まる行を探す
     3. 見つかった場合: その行から、次に出現する行頭 `## ` 行（または同レベル以上の見出し）の直前まで（または EOF まで）を新セクションで置換
     4. 見つからない場合: 本文末尾に `\\n\\n` + 新セクションを追記
     5. ` ``` ... ``` ` で囲まれたコードブロック内の `## 🎬` 行は無視する（ブロック内外フラグで判定）
     6. 対象ファイル自体が存在しなければ、Daily Template (`__META/TEMPLATE/01 - DAILY Template.md`) を雛形として作成してから挿入。Templater 構文 `<% ... %>` は値展開せずそのまま残す（Obsidian 側 Templater が後で展開）
     7. 編集前に対象ファイルを `<repo>/.tmp/daily-manga/<date>/vault-backup.md` に複製（diff 検証用）"
  - "上記アルゴリズム検証用の bats fixture を 4 種類 `tests/fixtures/vault-insert/` に用意:
     (1) `case1-no-section.md` — 既存ファイルに 🎬 セクション無し（追記ケース）
     (2) `case2-replace.md` — 既存ファイルに 🎬 セクション有り（置換ケース）
     (3) `case3-codeblock.md` — Dataview/コードブロック内に偽の `## 🎬` 文字列あり（無視確認）
     (4) `case4-not-exist.md` — 対象ファイル自体が存在しない（Template から新規作成）"
  - "Codex 出力の検証:
     - bats テストでは `tests/mocks/codex-companion.mjs` をモックとして PATH 注入し、実サブスク枠を消費しない（mock は 1024x1536 のテスト PNG を指定パスに書く）
     - 実行ログには Codex の出力をそのまま転記（API key を含まないので mask 不要）
     - `.tmp/daily-manga/<date>/` には中間 Markdown のみ残し、Codex の生応答 JSON は残さない（Codex CLI は標準出力に進捗を出すが、ファイル保存は Codex 側が直接行うので中間 JSON は不要）"

## 画面・UI設計

成果物の Daily ノート構造（既存 `01 - DAILY/2026-05-12.md` に挿入される `## 🎬` セクション）:

```markdown
（既存セクション: # 7 Rules / 🎯 今週のフォーカス / 🗓️ Plan / 📝 Conscious Note 等を保持）

## 🎬 今日の漫画（自動生成）

> 生成日: 2026-05-12 | 主人公: oratta（プロジェクト軸: [[Genetta-inc]] etc）

### あらすじ
（storyteller の出力する 1-2 文ログライン）

### 漫画
![[manga/2026-05-12/page1.png]]
![[manga/2026-05-12/page2.png]]

### 物語全文
<details><summary>展開</summary>

（refiner の最終物語、コマ単位）

</details>

### 元データ
- Git: N コミット / N 行変更
- Claude セッション: N 件
- Sunsama タスク: N 件
- Fieldy: [[Daily-Fieldy-2026-05-12]]
- Vault 更新: N ファイル

---
```

## データモデル

中間ファイル（`<dailyReport repo>/.tmp/daily-manga/<date>/`）:
| ファイル | 生成元 | 構造 |
|---|---|---|
| `report.md` | `scripts/collect-daily.sh` | Markdown、6 セクション固定 |
| `story-draft.md` | storyteller subagent | Markdown、ログライン + 3 幕 + コマ 6〜8 |
| `story-review.json` | critic subagent | JSON `{issues: [], rewrites: {}}` |
| `story-final.md` | refiner subagent | Markdown、draft と同構造 |
| `manga-prompts.json` | manga-prompt-builder subagent | JSON `{page1: {prompt, panels: []}, page2: {...}}` |
| `page1.png` / `page2.png` | `scripts/gen-manga.sh` | PNG 1024x1536 |

最終成果物（Vault 内）:
- `01 - DAILY/YYYY-MM-DD.md`（既存ファイルにセクション追記、冪等）
- `01 - DAILY/manga/YYYY-MM-DD/page1.png`
- `01 - DAILY/manga/YYYY-MM-DD/page2.png`

外部依存:
- Fieldy 既存 pipeline: `<vault>/Daily-Fieldy-YYYY-MM-DD.md`（Read のみ、存在しなければ skip）
- Sunsama MCP: `mcp__sunsama__read_resource`（未接続時は警告で続行）
- Codex CLI（`openai-codex` plugin の `codex-companion.mjs`）— ChatGPT Pro サブスク枠で gpt-image-2 を呼ぶ。未セットアップ時は `/codex:setup` で初期化

## 受け入れ条件

**必須条件（常に含める）:**
1. [ ] 全 change の OpenSpec 仕様が作成・レビュー済み
2. [ ] 全 change のテストが作成され全て PASS している（bats テスト）
3. [ ] ビルドエラーなし（`bash -n` syntax check + plugin.json の `jq -e .` 妥当性チェック）
4. [ ] 統合テスト（worktree マージ後）で `/daily-manga 2026-05-12` がエラー終了せず Vault に成果物が出ること

**機能固有の条件:**
5. [ ] `bash scripts/collect-daily.sh 2026-05-12` 実行で `<repo>/.tmp/daily-manga/2026-05-12/report.md` が生成され、以下のセクションを必ず含む:
   - `## 活動サマリー`
   - `## Git コミット`
   - `## Claude Code セッション`
   - `## Sunsama タスク`
   - `## Fieldy`（データなしなら「Fieldy データなし」と明記）
   - `## Vault 更新`
6. [ ] storyteller subagent 出力 `story-draft.md` に「ログライン」「3 幕構成（朝/昼/夜 等）」「6〜8 コマ」のセクションが存在
7. [ ] critic subagent 出力 `story-review.json` が valid JSON で `issues` キー（配列）を含む
8. [ ] refiner subagent 出力 `story-final.md` のコマ数 >= draft のコマ数（削除されていない）
9. [ ] gpt-image-2 呼び出しで `page1.png` `page2.png` が生成され、各 PNG が `file` コマンドで `PNG image data, 1024 x 1536` と表示される
10. [ ] Vault `01 - DAILY/2026-05-12.md` に `## 🎬 今日の漫画（自動生成）` セクションが挿入され、wikilink で 2 枚の画像が参照されている
11. [ ] 既存 Daily ノートのセクション（`# 7 Rules` / `🎯` / `🗓️` / `📝` / `## Memo` / `## Review` / Dataview ブロック）が一切変更されていない（diff で確認、`tests/fixtures/vault-insert/case1-no-section.md` で再現テスト）
12. [ ] 同じ日付で再実行（冪等）した際、`## 🎬 今日の漫画（自動生成）` セクションは置換され、それ以外のセクションは無変更（`tests/fixtures/vault-insert/case2-replace.md` で再現テスト）
13. [ ] コードブロック (` ``` ... ``` `) 内に偶発的に `## 🎬` 文字列がある場合でも誤置換しない（`tests/fixtures/vault-insert/case3-codeblock.md` で再現テスト）
14. [ ] 対象 Daily ノートが存在しない場合、Daily Template から雛形を生成してから 🎬 セクションを挿入する（`tests/fixtures/vault-insert/case4-not-exist.md` で再現テスト、Templater 構文は未展開のまま）
15. [ ] Codex CLI 未セットアップ（`codex-companion.mjs` not found）時は明示的なエラーで exit 1 + `/codex:setup` の案内
16. [ ] `invoke-codex-image.sh` 実行時に `OPENAI_API_KEY` が unset されている（API 課金経路に意図せず切り替わらない）
17. [ ] 画像生成は `codex:codex-rescue` の foreground 同期実行 × 2 回（page1, page2 を逐次）。並列起動していないことをログで確認
18. [ ] 中間ファイル `.tmp/daily-manga/<date>/` に Codex 応答 JSON が残っていない（許容ファイル: `report.md` / `story-draft.md` / `story-review.json` / `story-final.md` / `manga-prompts.json` / `vault-backup.md` のみ）
19. [ ] Sunsama MCP 未接続時もパイプライン全体は完走し、report.md の Sunsama セクションに `⚠️ Sunsama MCP 未接続` が記載される
20. [ ] Vault 検出が 0 件 / 2 件以上の場合、明示的エラーで exit 1（環境変数 `DAILY_MANGA_VAULT` での明示要求メッセージ含む）

## 意思決定ガイドライン
- 優先順位: 確実性 > 効率 > 拡張性
- リスク許容度: 中程度（OpenAI API 呼び出しはリトライ 1 回まで、それ以上は失敗報告）
- 不明点の扱い: 既存 weekly-report の実装パターンに合わせる方を優先

## 動作確認方法
- 開発サーバー: なし（CLI skill）
- テスト: `bats ~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/daily-manga/tests/*.bats`
- 確認手順:
  1. `_longruns/2026-05-12_daily-manga-skill/` で plan に沿って builder が implement
  2. plugin が `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/daily-manga/` に作成される（marketplace 直接編集、ローカルコピー禁止）
  3. plugin.json の version を `1.0.0` で初期化、commit & push（marketplace リポジトリへ）
  4. 別 Claude Code セッションで `/plugin install daily-manga@oratta-claude-harness` → `/reload-plugins`
  5. Codex CLI 動作確認: `/codex:setup` を 1 度実行して認証済み状態にする
  6. `unset OPENAI_API_KEY` （サブスク経路を強制）してから `/daily-manga 2026-05-12` を実行
  7. `<repo>/.tmp/daily-manga/2026-05-12/` に中間ファイル 6 種（report/draft/review/final/prompts/backup）が揃うことを確認、Codex 応答 JSON が残っていないことを確認
  8. Vault `01 - DAILY/2026-05-12.md` を Obsidian で開いて漫画セクション + 画像 2 枚が表示されることを目視確認
  9. 同日付で再実行し、`## 🎬` セクションのみ更新され他セクション無変更を `git diff` で確認
  10. Codex usage dashboard で枠消費が想定範囲内か確認

## Brain Dumpからの原文メモ
> じゃぁ一回全ての流れをclaudeのエージェントで実行する前提でskillとしての実装プランを立ててください。weekly Reportを参考にしながら、情報収集などの固定作業はなるべくスクリプト化して、効率化して

> 物語のテキスト丸ごと渡してgpt-image2で作りたい。gpt-image2を知らなかったらちゃんとcontext7で調べて

> Fieldyの情報習得はどっかでやってるはずだからvault内を検索して調べて。MVPに入れる。わからなかったら聞いて。多分NotionのどっかにDBがあるはず

## 関連リソース
- 参照: `research/plan-v0.md`（main セッション初期プラン）
- 参照: `research/plan-v1.md`（評価 subagent による v0 批判 + リサーチ統合プラン、本 plan の前提となるアーキ判断あり）
- 参照: `research/research.md`（codex 連携 / multi-subagent / text-to-manga / Vault 設計の事前リサーチ）
- 参照: `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/weekly-report/skills/weekly-report/SKILL.md`
- 参照: `~/.claude/plugins/marketplaces/openai-codex/plugins/codex/agents/codex-rescue.md`（Codex CLI 呼び出しパターン）
- 参照: `/Users/oratta/Dropbox/Application/Obsidian/oratta2025/__META/TEMPLATE/01 - DAILY Template.md`
- 参照: `/Users/oratta/Dropbox/Application/Obsidian/oratta2025/Daily-Fieldy-2026-04-24.md`（Fieldy 出力サンプル）
- 参照: gpt-image-2 仕様（OpenAI API、Context7 調査済み 2026-05-12）+ Codex CLI built-in image generation（WebSearch 確認済み 2026-05-12）

## 移行メモ
本 plan は当初 `~/Dropbox/WorkSpace/00_IndieDev/dailyReport/_longruns/2026-05-12_daily-manga-skill/` で生成されたが、daily-manga skill の実装が claude-harness marketplace の `plugins/daily-manga/` 配下になるため、履歴と実装を同一 repo に集約する目的で claude-harness の `_longruns/` 配下に移動した。元のセッション履歴は dailyReport repo 側に保全されている。
