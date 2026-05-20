# Plan: daily-report スキルの2フェーズ・パイプライン化（voice / dailyLLM 中間ファイル分離 + 出力先統一）

## 生成情報
- 作成日: 2026-05-20
- Brain Dump元: /worktree:wt-setup の引数（longrun:plan ... 出力先 / dailyLLM / voice の3点調整）
- 質問回数: 3問（うち voice フィルタは実データ検証で代替、dailyLLM 参照リンクは「両方残す」推奨で代替）

## ゴール

daily-report スキルを **2フェーズ・サブエージェント分離型** に再構成する。

1. **出力先を統一**: diary / voice / dailyLLM を `~/Dropbox/Application/Obsidian/oratta2025/01 - DAILY/<YYYY-MM-DD>/` に集約（旧パス `02 - PERIODIC/Daily/` への保存を停止）
2. **voice.md を新設**: Fieldy DB の音声 transcript を LLM 圧縮した中間表現として保存。生 transcript は保存せず、カテゴリ分類（思考 / 家族会話 / 運転 / メディア視聴 / ペット / デバイス指示 / 未取得）+ 時間範囲 + 要約に圧縮
3. **dailyLLM.md を新設**: 当日の全 Claude Code セッション jsonl から「初回 user 指示 + 最終 assistant 出力」を時系列に並べた中間表現として保存
4. **diary.md は中間ファイル参照ベースに書き換え**: voice.md / dailyLLM.md / 編集ノートを再読み込みして diary 生成。Fieldy DB / jsonl 生データへの直接アクセスはサブエージェント側に閉じ込めて、メインコンテキストへの汚染を回避

## ビジネスコンテキスト

- **対象ユーザー**: oratta（個人開発者、Vault ベースで日記・LLMログ管理）
- **提供価値**:
  - メインコンテキストのトークン消費を **〜80% 削減**（Notion fetch の生 transcript と jsonl ディレクトリ走査履歴がサブエージェントに閉じ込められる）
  - 中間ファイルが残るため、後日の再生成・部分修正が可能（diary だけ書き直すときに Phase 1 をスキップ）
  - voice.md は「ノイズフィルタ済みの音声活動スナップショット」として独立して読み返せる
- **成功指標**:
  - voice.md / dailyLLM.md が `01 - DAILY/<date>/` に生成され、生 transcript / jsonl 全文がメインコンテキストに乗らない
  - diary.md は中間ファイル参照のみで生成され、Fieldy DB / jsonl への再アクセスが発生しない
  - 既存の `--with-album` フラグが新パスでも動作

## 技術要件

- **スタック**:
  - Skill（Markdown + YAML frontmatter）
  - Agent 定義（Markdown + YAML frontmatter、`allowed-tools` で MCP ツール制限）
  - Bash（日付計算、ディレクトリ操作、find / grep）
  - Python3（既存スキルで jsonl パースに使用済み、継続利用）
  - Notion MCP（DB_FIELDY アクセス専用、サブエージェント側でロード）
- **参照パターン**:
  - 既存 `plugins/daily-report/skills/daily-report/SKILL.md`（Step 0〜6 の骨格は流用）
  - `longrun-orchestrator` の Agent 並列起動パターン（単一メッセージ内の複数 tool_use）
  - `harvest:knowledge` スキルの **メインから複数サブエージェントを並列起動して結果を集約** するパターン
- **制約**:
  - Notion MCP は **サブエージェント側でのみロード**（メインスレッドではロードしない）
  - jsonl 全文の本文を **メインスレッドで Read してはならない**（サブエージェント内で完結）
  - 既存スキルの設計思想3原則（ナラティブ > カタログ / 推測補完しない / jsonl は最初の user メッセージだけ読む）を維持
  - 旧パス `02 - PERIODIC/Daily/<date>/` は **過去ファイルそのまま** とし、移行スクリプトは作らない（新規生成は新パスのみ）
- **テストフレームワーク**: bats-core（bash 用テスト）
- **テスト実行コマンド**: `bats plugins/daily-report/tests/*.bats`

## スコープ

### 含むもの

- `daily-report` Skill の 2フェーズ化リファクタ
- 新規 Agent 2件: `voice-compactor` / `llm-log-compactor`
- voice.md / dailyLLM.md の出力フォーマット仕様策定
- 出力先パスを `01 - DAILY/<YYYY-MM-DD>/` に統一
- 中間ファイル存在チェック + `--force-rebuild` フラグ対応
- 既存 `--with-album` の新パス対応
- 圧縮ロジックの bats テスト（明白なノイズタグ除去・カーナビ正規表現等の決定論的部分）

### 含まないもの

- **旧パス（`02 - PERIODIC/Daily/`）からの過去 diary 移行**（理由: 既存ファイルはそのまま、新規生成のみ新パス）
- **voice.md / dailyLLM.md の自動ファイル分割**（理由: LLM 圧縮後は数十KB止まり想定。500KB 超で警告のみ）
- **diary.md 本体のフォーマット変更**（理由: 既存 v3 形式を維持。入力ソースだけ変わる）
- **Fieldy DB スキーマ変更や Notion 書き戻し**（理由: 読み取り専用）
- **マルチデー処理**（理由: 1コマンド = 1日分。月次まとめは別スキル領域）

## Changes分解

### change-0: agent-mcp-spike（技術検証）

- **スコープ**: サブエージェントから Notion MCP ツールを呼ぶ方式の技術検証スパイク。最小実装の Agent (`plugins/daily-report/agents/_spike-notion-mcp.md`) を作り、DB_FIELDY を1ページだけ fetch して STATUS line を返す動作を実機確認する
- **使用スキル**: なし
- **依存関係**: 独立（最初に着手）
- **config.yaml rules**:
  - "Agent frontmatter の `tools:` フィールドに `mcp__claude_ai_Notion__notion-search`, `mcp__claude_ai_Notion__notion-fetch` を直接書く方式を最初に試す"
  - "失敗した場合は Agent 本文内で `ToolSearch(select:...)` を呼ぶ方式にフォールバック"
  - "検証結果（採用方式 / 制約 / 既知の問題）を plan の「技術要件」セクションに反映してから change-2/3 本実装に着手する"
  - "spike Agent は検証完了後に削除する（プロダクションには残さない）"
- **完了条件**:
  - Skill から Agent ツール経由で `voice-compactor` 的な Agent を起動し、Notion MCP 呼び出しが成功する
  - Agent の戻り値（メインへの返却本文）が STATUS line のみで構成できることを確認
  - 検証結果を plan.md の「技術要件」末尾に追記

### change-1: output-path-migration

- **スコープ**: daily-report Skill の出力先パスを `02 - PERIODIC/Daily/` から `01 - DAILY/` に変更。`--with-album` の生成物パスも追従
- **使用スキル**: なし（直接編集）
- **依存関係**: 独立
- **config.yaml rules**:
  - "出力ディレクトリは `$VAULT_ROOT/01 - DAILY/<YYYY-MM-DD>/` に統一する"
  - "旧パス `02 - PERIODIC/Daily/` への書き込みは禁止（過去ファイルは触らない）"
  - "ディレクトリが既に存在し diary.md がある場合は suffix（diary-v2.md 等）で衝突回避（既存挙動を維持）"

### change-2: voice-compactor-agent

- **スコープ**: 新規 Agent `voice-compactor` を `plugins/daily-report/agents/voice-compactor.md` として定義。Fieldy DB から対象日の transcript を取得し、LLM 圧縮で voice.md を生成
- **使用スキル**: なし（Agent 新規作成）
- **依存関係**: change-0 完了後（change-3 とは並列実装可）
- **config.yaml rules**:
  - "MCP ツール呼び出し方式は change-0 の検証結果に従う（`tools:` 直書き or Agent 内 ToolSearch）"
  - "`notion-fetch(include_transcript=true)` は最大5並列まで"
  - "1時間ごと（Fieldy ページ単位）に LLM 圧縮を実施し、生 transcript はファイル出力に含めない"
  - "圧縮カテゴリは固定 8 種類: `[user]`（家族・他者との会話を含む発話） / `[user-思考]`（一人語りの思考メモ） / `[family-talk]`（家族と複数ターンの会話） / `[family-meal]`（食事・調理シーン） / `[driving]`（運転・移動中の包含タグ。配下に thoughts を字下げ） / `[media-listen]`（TV/YouTube/ラジオ流し込み視聴） / `[device-cmd]`（Siri/Spotify/Google等への音声指示） / `[pet]`（ペット呼びかけ・遊び） / `[unknown]`（出所不明・誤認識）。これら8種に該当しないシーン（駐車場到着等）は最も近いカテゴリで包含する（独自カテゴリ追加は禁止、Agent プロンプトでカテゴリ一覧を例示して固定する）"
  - "出力契約（メインへの返却）: Agent の最終 assistant message は `STATUS: <ok|partial|fail> ...` の **1行のみ** とする。voice.md の本文要約・件数詳細・取得ページタイトル・transcript 抜粋等を返却本文に含めることは禁止。すべて Write 経由で voice.md にのみ出力する"
  - "STATUS line のフォーマット: `STATUS: ok` / `STATUS: partial pages=N missing=[hh:00,...]` / `STATUS: fail reason=<short-message>`"
  - "トークン上限超で取得不能なページは `STATUS: partial` で報告し、voice.md 本文には `## hh:00-hh:59` + `- (未取得: token-limit)` を明記"
  - "DB_FIELDY 未接続 / 未ロード時は `STATUS: fail reason=notion-mcp-unavailable` を返す（メイン側で dailyLLM.md のみで Phase 2 継続するためのフォールバック識別子）"

### change-3: llm-log-compactor-agent

- **スコープ**: 新規 Agent `llm-log-compactor` を `plugins/daily-report/agents/llm-log-compactor.md` として定義。jsonl 群から「初回 user + 最終 assistant」を抽出し、dailyLLM.md を生成
- **使用スキル**: なし（Agent 新規作成）
- **依存関係**: change-0 完了後（change-2 とは並列実装可）
- **config.yaml rules**:
  - "`~/.claude/projects/*/` 配下の jsonl を mtime で対象日に絞り込み（既存スキル Step 1d のロジック流用）"
  - "各 jsonl から「**先頭から順次スキャンして最初に見つかった user role メッセージ**（全文 300字まで）」「最後の assistant メッセージ（全文 500字まで）」を抽出。既存スキル Step 1d の `head -5` 制限は撤廃し、sidechain/system message が先行する jsonl にも対応する"
  - "ツール呼び出しログ本文（tool_use の input 詳細 / tool_result の出力本文）はメインに含めないが、**メタデータは jq/grep で集計** して各セッションエントリに以下を含める: (a) `turn数`（user role メッセージの総数）、(b) `files touched 件数`（Edit/Write/MultiEdit ツール呼び出しの uniq ファイルパス数）、(c) `commits 件数`（Bash ツールで `git commit` を含むコマンド実行の回数）、(d) `top3 ツール使用回数`（tool_use の name フィールド集計上位3件）、(e) `Files (top 5)`（Edit/Write/MultiEdit で頻度が高い uniq ファイルパス上位5件）、(f) `Commits`（git commit で作られた hash 一覧、jsonl の tool_result から抽出、最大5件）"
  - "集計は jq/grep ベース。jsonl の本文を行ごとに Read してメインに送ることは禁止（サブエージェント内で完結し、結果のみ dailyLLM.md に書き出す）"
  - "Vault 内 `90 - LLM/<TIMESTAMP>-*.md` および `12 - PROJECT/**/LLM/<date>*.md` を grep し、対応ログがあれば wikilink を構築。なければ jsonl 絶対パスを参照として残す（両方残す方針）"
  - "セッションは jsonl 作成時刻の昇順で並べる"
  - "出力契約（メインへの返却）: change-2 と同じく `STATUS: <ok|partial|fail> ...` の 1行のみ。dailyLLM.md の本文要約・セッション数詳細・抜粋等を返却本文に含めない"

### change-4: skill-2phase-refactor

- **スコープ**: `daily-report` Skill 本体を 2フェーズ構造にリファクタ。Phase 1 で voice-compactor / llm-log-compactor を並列起動、Phase 2 で diary 生成。`--force-rebuild` フラグ追加。既存 Step 4（90 - LLM/ ログ記録）は Phase 2 末尾に維持し、wikilink を新パスに更新
- **使用スキル**: なし（既存スキル本体の改修）
- **依存関係**: change-1, change-2, change-3 が完了していること
- **config.yaml rules**:
  - "Phase 1 は **単一メッセージ内に2つの Agent tool_use** を並べて並列起動する（順次起動禁止）"
  - "Phase 1 の前に中間ファイル存在チェックを行い、`voice.md` と `dailyLLM.md` の両方が存在し `--force-rebuild` が無ければ Phase 1 をスキップ"
  - "サブエージェントの STATUS line を必ずパースし、`fail` の場合の振る舞いは Agent ごとに分岐: voice-compactor の `STATUS: fail reason=notion-mcp-unavailable` は **既存 SKILL.md の `> [!warning] DB_FIELDY が無い場合` の挙動を継承して dailyLLM.md のみで Phase 2 継続**。それ以外の `fail` および llm-log-compactor の `fail` はフェーズ単位でユーザーに報告して中断。`partial` は warning を出して継続"
  - "Phase 1 完了直後、メインは voice.md / dailyLLM.md の **冒頭 40 行だけを Read** して frontmatter + 最初の数セクションの sanity check を実施する（本文全体は読まない）。明らかに空・極端に短い（< 50 行）場合は警告を出してユーザーに `--force-rebuild` を促す"
  - "メインスレッドで Notion MCP をロードしない（旧 Step 1a の `ToolSearch` 呼び出しはメインスキル本文から削除）"
  - "jsonl の本文を Read するコードはメインスレッドから削除"
  - "Step 4（90 - LLM/<TARGET_DATE_COMPACT_TODAY>-<タイトル>.md 生成）は Phase 2 の最後に維持。ただし wikilink は新パス `01 - DAILY/<TARGET_DATE>/diary` に更新する"

### change-5: diary-generation-from-intermediate

- **スコープ**: Phase 2 の diary 生成ロジックを書き換え。voice.md / dailyLLM.md / Vault 編集ノートを入力として diary.md を生成。Fieldy DB / jsonl への直接アクセスを削除
- **使用スキル**: なし（既存スキルの Step 2〜3 を書き換え）
- **依存関係**: change-4 が完了していること
- **config.yaml rules**:
  - "diary 生成のインプットは voice.md / dailyLLM.md / Vault 編集ノートの 3ソース。**dailyLLM.md の `**参照**:` セクションに wikilink がある場合、ナラティブで深堀りしたいセッションに限り該当 LLM ログ（90 - LLM/...）をメインが Read して詳細を補完可能**（必須ではない、全セッションを Read するのは禁止 — コンテキスト効率維持のため）"
  - "diary.md 本文のトーン・構造（既存 SKILL.md の Step 3b/3c/3d）は維持"
  - "voice.md / dailyLLM.md に `(未取得)` セクションがある場合、diary.md でも対応時間帯を「未取得」と明記（推測補完禁止の既存原則を継承）"
  - "diary.md の `source:` frontmatter を新形式に変更: `[[voice|2026-05-19 Voice Log]] / [[dailyLLM|2026-05-19 LLM Log Index]] / Obsidian-edited notes (<date>)` の 3ソース wikilink を含める"
  - "備考（嗜好レベル指摘への反論）: change-4 と change-5 を分割した意図は、change-4 完了時点で「中間ファイル生成 + sanity check + Step 4 ログ」までを動作確認可能なマイルストーンとし、change-5 で diary 生成側を書き換える順序を明示することにある。change-4 単体マージ後の中間状態でも、voice.md / dailyLLM.md / Step 4 ログは生成され、diary は旧経路で動く（または `--skip-diary` 相当のフラグなしでもエラーにならない）よう、change-4 のスコープで diary 生成の旧経路を温存する。change-5 で旧経路を削除する"

## 画面・UI設計

CLI スキル（UI なし）。コマンドラインインタフェースの形:

```bash
/daily-report 2026-05-19              # 通常実行（中間ファイル無ければ生成、あれば再利用）
/daily-report 2026-05-19 --force-rebuild   # 中間ファイル含めて再生成
/daily-report 2026-05-19 --with-album      # diary 後にアルバム生成
/daily-report                              # yesterday を対象（既存挙動）
```

出力ディレクトリ構造:

```
$VAULT_ROOT/01 - DAILY/2026-05-19/
├── diary.md           ← Phase 2 で生成（既存 v3 形式維持）
├── voice.md           ← Phase 1 で voice-compactor が生成
├── dailyLLM.md        ← Phase 1 で llm-log-compactor が生成
├── album.png          ← --with-album 指定時のみ
└── album-prompt.md    ← --with-album 指定時のみ
```

## データモデル

### voice.md frontmatter + 本文構造

```yaml
---
created: 2026-05-19T23:59:00+09:00
type: voice-log
date: 2026-05-19
source: DB_FIELDY
pages_fetched: 14
pages_missing: []
filter: llm-compress-v1
---
```

本文: `## hh:00-hh:59` 見出し + `- hh:mm [category] 内容` または `- hh:mm-hh:mm [category] 時間範囲の要約` の bullet list。ネスト可（移動中の思考など）。

### dailyLLM.md frontmatter + 本文構造

```yaml
---
created: 2026-05-19T23:59:00+09:00
type: llm-log-index
date: 2026-05-19
source: ~/.claude/projects/
sessions: 12
---
```

本文: `## hh:mm — <cwd-slug>` 見出し + `**指示**: ...` + `**最終出力**: ...` + `**参照**: [[wikilink]] · jsonl-path` の繰り返し。

### サブエージェント STATUS line スキーマ

```
STATUS: ok                                              # 全件成功
STATUS: partial pages=12 missing=[20:00,21:00]          # 部分失敗
STATUS: fail reason=<short-message>                     # 完全失敗
```

メインはこれを正規表現でパース（`^STATUS: (ok|partial|fail)`）。

## 受け入れ条件

**必須条件（常に含める）:**
1. [ ] 全changeのOpenSpec仕様が作成・レビュー済み
2. [ ] 全changeのテストが作成され全てPASSしている
3. [ ] ビルドエラーなし（型チェック + ビルド） — 該当なし（Bash + Markdown のため lint のみ）
4. [ ] 統合テストがPASS（worktreeマージ後）— `/daily-report 2026-05-19` を実機実行して新パスに3ファイル生成されることを確認

**機能固有の条件:**
5. [ ] `/daily-report 2026-05-19` 実行後、`$VAULT_ROOT/01 - DAILY/2026-05-19/` に `diary.md` / `voice.md` / `dailyLLM.md` の 3ファイルが生成される
6. [ ] voice.md の frontmatter に `type: voice-log` / `date: 2026-05-19` / `pages_fetched: <数>` が含まれる
7. [ ] voice.md の本文に生 transcript（`**[Speaker Unknown] **` 形式）が含まれない。すべて `- hh:mm [category]` 形式の bullet で表現されている
8a. [ ] voice.md 内に圧縮カテゴリタグ（`[user]` / `[user-思考]` / `[family-talk]` / `[family-meal]` / `[driving]` / `[media-listen]` / `[device-cmd]` / `[pet]` / `[unknown]`）が grep で検出できる（決定論的、ただし対象日のデータに該当カテゴリが存在することが前提なので「カテゴリのうち少なくとも3種類が存在する」を最低条件とする）
8b. [ ] **2026-05-19 の実データで** カーナビ音声・デバイス応答・TV/YouTube/ラジオ流し込み・ペット呼びかけが期待通りメタタグ形式に圧縮されているか目視確認（10ステップ動作確認の手順 4 に含む）
9. [ ] dailyLLM.md の frontmatter に `type: llm-log-index` / `sessions: <数>` が含まれる
10. [ ] dailyLLM.md の各セッションエントリに以下の6項目が含まれる: `**指示**:` / `**最終出力**:` / `**規模**:`（turn数 / files touched 件数 / commits 件数 / top3 ツール使用回数） / `**Files (top 5)**:` / `**Commits**:` / `**参照**:`（wikilink または jsonl 絶対パスの少なくとも一方）
11. [ ] Phase 1 で voice-compactor と llm-log-compactor が **並列起動** される（実装確認: skill 本文に「単一メッセージ内に2つの Agent tool_use」と明記されていること）
12. [ ] `--force-rebuild` 無しで再実行した場合、中間ファイル存在チェックにより Phase 1 がスキップされる（実装確認 + 動作確認）
13. [ ] 旧パス `$VAULT_ROOT/02 - PERIODIC/Daily/` への書き込みが発生しない（実装の grep で確認）
14. [ ] Notion MCP のロード（`ToolSearch`）がメインスレッドのスキル本文から削除されている（grep 確認）
15. [ ] jsonl 本体の `Read` がメインスレッドのスキル本文から削除されている（grep 確認）
16. [ ] サブエージェントが `STATUS: partial` を返した場合、diary.md の該当時間帯セクションに「未取得」記載が出る
17. [ ] `--with-album` フラグが新パス `01 - DAILY/<date>/` 配下で動作する（album.png / album-prompt.md が同ディレクトリに配置される）
18. [ ] bats テストで以下を検証: (a) ノイズタグ除去関数、(b) カーナビ定型句マッチ、(c) STATUS line パーサ、(d) 中間ファイル存在チェック、(e) Phase 1 sanity check（冒頭40行 Read で行数下限を満たすか判定）
19. [ ] Phase 1 完了直後の sanity check が機能する（voice.md / dailyLLM.md が < 50 行の場合に警告ログが出る）
20. [ ] Fieldy 不在時（`STATUS: fail reason=notion-mcp-unavailable`）でも dailyLLM.md + 編集ノートのみで diary.md が生成できる（既存挙動継承）
21. [ ] 既存 Step 4 の `90 - LLM/<timestamp>-*.md` ログが生成され、本文の wikilink が新パス `01 - DAILY/<date>/diary` を指している
22. [ ] diary.md の `source:` frontmatter が新形式（voice.md / dailyLLM.md / 編集ノート の wikilink）になっている
23. [ ] サブエージェントの最終 assistant message が STATUS line 1行のみであることを、実機実行ログ（または worktree commit のレビューコメント）で確認

## 意思決定ガイドライン

- **優先順位**: コンテキスト効率 > 既存挙動の維持 > 実装シンプルさ > 拡張性
- **リスク許容度**: 中程度（過去 diary の移行はしない、旧パスは触らない、新パスのみで完結）
- **不明点の扱い**: シンプルな方を選ぶ。LLM 圧縮の精度が悪い場合は **再生成（--force-rebuild）で対処** する設計とし、リトライ自動化までは作り込まない
- **Agent 失敗時**: メインはサブエージェント STATUS をパースし、`fail` なら明示エラー + ユーザー判断を仰ぐ。`partial` なら警告のみ出して継続（推測補完しない）

## 動作確認方法

- **開発サーバー**: なし（Skill のため）
- **テスト**:
  ```bash
  bats plugins/daily-report/tests/*.bats
  ```
- **確認手順（統合動作確認）**:
  1. `cd ~/Dropbox/Application/Obsidian/oratta2025` で Vault root に移動
  2. `/daily-report 2026-05-19` を実行
  3. `ls "$VAULT_ROOT/01 - DAILY/2026-05-19/"` で diary.md / voice.md / dailyLLM.md の 3ファイル生成を確認
  4. voice.md を開き、frontmatter + 圧縮版本文（`- hh:mm [category]` 形式）になっていることを確認
  5. dailyLLM.md を開き、セッション単位の `**指示**:` / `**最終出力**:` / `**参照**:` 形式になっていることを確認
  6. diary.md を開き、既存 v3 形式（ナラティブトーン）になっていることを確認
  7. `/daily-report 2026-05-19` を再実行し、voice.md / dailyLLM.md の `created:` 時刻が変わらない（Phase 1 スキップ）ことを確認
  8. `/daily-report 2026-05-19 --force-rebuild` で全再生成されることを確認
  9. `/daily-report 2026-05-19 --with-album` で album.png が `01 - DAILY/2026-05-19/` 配下に配置されることを確認
  10. `grep -r "02 - PERIODIC/Daily" plugins/daily-report/` で旧パス参照が残っていないことを確認
11. サブエージェントの返却本文を実機ログで確認: `Agent (voice-compactor): STATUS: ...` 形式の1行のみで構成されており、transcript 抜粋や本文要約が含まれていない
12. 意図的に Notion MCP が未ロード状態で `/daily-report 2026-05-19 --force-rebuild` を実行し、`voice-compactor` の fail を受けて dailyLLM.md + 編集ノートのみで diary.md が生成される（フォールバック検証）
13. Phase 1 完了直後の sanity check ログを実機実行で確認（voice.md と dailyLLM.md の冒頭 40 行のみ Read され、警告条件（< 50 行）に該当しないこと）

## Brain Dumpからの原文メモ

> daily-reportの出力に関して色々調整したいです。で一つ目が出力先ですね。出力先を`/Users/oratta/Dropbox/Application/Obsidian/oratta2025/01 - DAILY/<日付dir>` にして、harvest の knowledge の出力先と合わせる。で、二つ目がdailyLLM.md を作成して、時系列で当日の全ての LLM セッションでの指示と最終アウトプットの内容を並べる（Obsidian が扱えないくらい行数が増えたらファイル分けても良い）。3つ目がvoice.md を作成して FieldyDB から取得した時系列の全ての会話を保存する。ただし、文章をなしてないものや意味のないものを除くフィルタは必要

> Dailyを作る時もこのファイルを一時情報に使う。だから、Dailyのファイルを作る時はまずこのLLMのログもそうだしFieldyのVoiceログもそうだしこのログを元にDailyを作るみたいな流れにしたいのよ

> カーナビ音声に関しては、車両で移動してたっていうことだけ事実として残して。細かい音声を消していい。ボイスのメモにはカーナビ音声自体はログしなくてもいいんだけどカッコ書きでここからしばらくカーナビの音声車で移動中みたいなことを書いておくイメージ。デバイスの音声応答もいらないですが、デバイスに指示したという記録は残っててほしい。テレビとかYouTubeとかラジオの流し込みに関してはこういうのを聞いていたこういう情報を聞いていたっていうのを残しておいてほしい

> それぞれ中間ファイルを作成するときにコンテキストを一回リセットできた方がいい。Notion DBとのやりとりもコンテキストに入っちゃってる状態で、次の作業が進むからそれ遠くもったいない。であればこの一時データを中間ファイル、voice.mdやdailyLLMなどに変換するのはサブエージェントに任せ、メインスレッドではサブエージェントが作成したファイルのみをコンテキストとしてdaily.mdを作成していくというスタンスにすることで、トークンの節約ができると考えた
