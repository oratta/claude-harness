# Daily Manga Pipeline — Plan v1

> 作者: 評価 subagent（v0 批判 + リサーチ統合）
> 基底: plan-v0 + daily-manga-research.md
> 日付: 2026-05-12

---

## 1. TL;DR

毎日の活動ログを Claude が収集・物語化し、Codex が添削、Claude がリファイン、Codex がコマ割り脚本に変換して Obsidian Vault に保存するパイプライン。
エントリポイントは `/daily-manga [YYYY-MM-DD]`（手動）。
v0.1 では漫画は「テキストコマ割り脚本」のみ（画像生成なし）。
Codex は逐次 foreground 実行（並列 I/O 競合を回避）。
Fieldy 統合と HTML 漫画は v0.2 以降。

---

## 2. アーキテクチャ図（subagent 間データフロー）

```
/daily-manga YYYY-MM-DD
        |
        v
[Main Session]
  ├─ 引数検証・作業ディレクトリ確認
  ├─ .tmp/YYYY-MM-DD/ 作成（冪等）
  │
  ├─ [Subagent A: collector] foreground, Claude
  │   Sources: git log / Claude JSONL / Vault mtime / (Fieldy: v0.2)
  │   Output: .tmp/YYYY-MM-DD/report.md
  │
  ├─ [Subagent B: storyteller] foreground, Claude
  │   Input: report.md
  │   Output: .tmp/YYYY-MM-DD/story-draft.md
  │
  ├─ [Subagent C: story-critic] foreground, Codex (codex:codex-rescue --wait)
  │   Input: story-draft.md
  │   Output: .tmp/YYYY-MM-DD/story-review.json
  │
  ├─ [Subagent D: story-refiner] foreground, Claude
  │   Input: story-draft.md + story-review.json
  │   Output: .tmp/YYYY-MM-DD/story-final.md
  │
  ├─ [Subagent E: manga-scripter] foreground, Codex (codex:codex-rescue --wait)
  │   Input: story-final.md
  │   Output: .tmp/YYYY-MM-DD/manga-script.md
  │
  └─ [Subagent F: vault-writer] foreground, Claude
      Input: report.md + manga-script.md
      Output: Vault/Daily/YYYY/MM/YYYY-MM-DD.md (+ Vault index 更新)
```

全サブエージェント間のデータ受け渡しはファイル経由のみ。プロンプト直接埋め込みは使わない（コンテキスト肥大化・デバッグ困難のため）。

---

## 3. MVP スコープ（v0.1）— 1 日で動かせる最小構成

前提条件（実装着手前に確定が必要）:
- [ ] Vault の絶対パスを user に確認済み
- [ ] WeeklyReport サンプルを 1 ファイル参照済み

v0.1 チェックリスト:
- [ ] `.tmp/YYYY-MM-DD/` 作業ディレクトリ作成（冪等: 存在すれば skip）
- [ ] Subagent A (collector): git log + Claude JSONL → report.md 生成
- [ ] Subagent B (storyteller): report.md → story-draft.md 生成（6〜8 コマ想定）
- [ ] Subagent C (story-critic): Codex (codex:codex-rescue --wait) → story-review.json 生成
- [ ] Subagent D (story-refiner): draft + review → story-final.md 生成
- [ ] Subagent E (manga-scripter): Codex (codex:codex-rescue --wait) → manga-script.md 生成（テキストコマ割りのみ）
- [ ] Subagent F (vault-writer): Vault/Daily/YYYY/MM/YYYY-MM-DD.md 書き出し
- [ ] Vault/Daily/YYYY/MM/YYYY-MM-DD.md に WeeklyReport への wiki-link 挿入
- [ ] スラッシュコマンド `/daily-manga` として起動可能

NOT in v0.1:
- Fieldy 統合（未確認のためスキップ。report.md の Fieldy セクションは空欄で出力）
- HTML/SVG 漫画（テキスト脚本のみ）
- 画像生成（v1.0 以降）
- 自動化（cron/スケジューラ）

---

## 4. 段階リリース計画

| バージョン | 追加内容 | ブロッカー |
|---|---|---|
| v0.1 | 全 6 subagent でテキストパイプライン完走 | Vault パス確定 |
| v0.2 | Fieldy 統合 + HTML/SVG 漫画（Codex 生成コード）| Fieldy アクセス方式確定 + キャラビジュアル設定 |
| v1.0 | 画像生成（DALL-E API 等）各コマ画像化 + キャラ一貫性管理 | 画像生成 API key + キャラ LoRA or 固定 seed |

v0.1 → v0.2 の差分: subagent A に Fieldy 収集を追加。subagent E を「manga-script.md → HTML/SVG ファイル生成」に昇格。
v0.2 → v1.0 の差分: 各コマに画像 URL を付与するサブエージェントを追加（image-generator）。character consistency 管理ファイルを別途設計。

---

## 5. 各 Phase の詳細仕様

### Phase 0: 起動・準備（Main Session）

- トリガー: `/daily-manga [YYYY-MM-DD]`（引数省略時は today）
- 作業ディレクトリ: `.tmp/YYYY-MM-DD/` を `mkdir -p`（冪等）
- 各フェーズの成果物が既に存在する場合は skip する設計（再実行可能）
- 所要時間目安: 5 秒
- 失敗時: 日付フォーマット不正なら即終了・メッセージ表示

### Phase 1: 情報収集（Subagent A: collector）

- type: Claude subagent（general-purpose）
- 実行: foreground（結果を待ってから次 phase へ）
- 入力:
  - 引数: date (YYYY-MM-DD)、vault_path（確定後）
  - ファイル: なし（初段）
- 収集ソース v0.1:
  1. `~/.claude/projects/` 配下の当日 JSONL（セッションログ）
  2. 主要 git repo の `git log --since=<date> --until=<date+1> --oneline`
  3. Vault 内当日更新ファイル（`find <vault> -newer <date_start> -not -newer <date_end>`）
  4. WeeklyReport テンプレ参照（フォーマット踏襲）
  - Fieldy: v0.1 では空欄（セクション見出しだけ挿入）
- 出力: `.tmp/YYYY-MM-DD/report.md`
  - セクション: 活動サマリー / Claude Code セッション / Git activity / Fieldy（空欄） / Vault updates / Tomorrow's hint
- 受け入れ条件: report.md が存在し、「活動サマリー」セクションに 1 行以上のテキストがある
- 失敗時: report.md が空の場合は後続 phase を中断。Main がメッセージで通知

### Phase 2: 物語化（Subagent B: storyteller）

- type: Claude subagent（general-purpose）
- 実行: foreground
- 入力ファイル: `.tmp/YYYY-MM-DD/report.md`
- 物語スタイル指針（プロンプト内埋め込み）:
  - 「ドラマの主人公」視点で 1 日を再構成
  - 3 幕構成（日常 → 葛藤/挑戦 → 解決/次への一歩）
  - コマ数: 6〜8 コマに収まる尺
  - 主人公の内面モノローグ必須（1 コマ以上）
  - 感情の山場は 1 つに絞る（複数山場は分散して平坦に見える）
- 出力: `.tmp/YYYY-MM-DD/story-draft.md`
  - セクション: ログライン（1文）/ 登場人物 / あらすじ（3幕） / コマ1〜N（ト書き・セリフ・モノローグ）
- 受け入れ条件: コマが 6 個以上存在し、各コマにト書きまたはセリフが 1 行以上ある
- 所要時間目安: 2〜3 分
- 失敗時: コマ数不足なら再生成を 1 回リトライ。それでも不足なら Main に警告して続行

### Phase 3: 物語添削（Subagent C: story-critic）

- type: Codex（codex:codex-rescue agent）
- 実行: foreground（`--wait` フラグ）、`--effort high`、`--fresh`（前回 run の汚染を防ぐ）
- 入力ファイル: `.tmp/YYYY-MM-DD/story-draft.md`（ファイルパスをプロンプトに明記）
- Codex へのプロンプト方針:
  - ドラマ性チェック（葛藤・転機・解決の 3 点が揃っているか）
  - キャラクター性（主人公の声に一貫性があるか）
  - 漫画翻訳容易性（各コマがビジュアルとして成立するか）
  - 2 ページ尺（8 コマ以内）の妥当性
  - 出力フォーマット: JSON（`{"issues": [...], "rewrites": {"コマ番号": "修正案"}}`）
- 出力: `.tmp/YYYY-MM-DD/story-review.json`
- 受け入れ条件: story-review.json が valid JSON であり `issues` キーが存在する
- 所要時間目安: 3〜5 分
- 失敗時: JSON パースエラーの場合、story-review.json に `{"issues": [], "error": "parse_failed"}` を書き込み Phase 4 で raw フィードバックとして扱う

### Phase 4: 物語リファイン（Subagent D: story-refiner）

- type: Claude subagent（general-purpose）
- 実行: foreground
- 入力ファイル: `.tmp/YYYY-MM-DD/story-draft.md` + `.tmp/YYYY-MM-DD/story-review.json`
- 処理:
  - story-review.json の `rewrites` を story-draft に適用
  - `issues` が empty なら story-draft をそのまま story-final としてコピー
  - モデル分化の効果: Codex が見つけた視点（GPT 系）を Claude（Anthropic 系）が文章として統合
- 出力: `.tmp/YYYY-MM-DD/story-final.md`（story-draft と同フォーマット）
- 受け入れ条件: story-final.md のコマ数 >= story-draft.md のコマ数（削除されていない）
- 所要時間目安: 2 分
- 失敗時: 出力が空の場合は story-draft.md を story-final.md にコピーして警告

### Phase 5: 漫画脚本化（Subagent E: manga-scripter）

- type: Codex（codex:codex-rescue agent）
- 実行: foreground（`--wait`）、`--effort high`、`--fresh`
- 入力ファイル: `.tmp/YYYY-MM-DD/story-final.md`
- v0.1 確定方針: テキストコマ割り脚本のみ（Markdown）
  - 理由: リサーチ赤旗2「漫画化の現実性」を受けて確定。SVG/HTML は panel layout アルゴリズムが未成熟で 1 日実装の範囲外。character 一貫性も画像生成では保証不可
- Codex へのプロンプト:
  - story-final.md の各コマを「漫画コマ脚本」形式に変換
  - 各コマ: コマ番号 / 背景描写（1〜2行） / キャラクター配置 / セリフ（吹き出し内） / ト書き（ナレーション）
  - ページ割り: コマ1〜4 = 1ページ目、コマ5〜8 = 2ページ目
- 出力: `.tmp/YYYY-MM-DD/manga-script.md`
- 受け入れ条件: コマ 6〜8 個が存在し、各コマに「背景描写」と「セリフまたはト書き」がある
- 所要時間目安: 3〜5 分
- 失敗時: manga-script.md が受け入れ条件を満たさない場合は Phase 5 を 1 回リトライ。それでも失敗なら story-final.md のコマ割りをそのまま manga-script.md として出力

### Phase 6: Vault 統合（Subagent F: vault-writer）

- type: Claude subagent（general-purpose）
- 実行: foreground
- 入力ファイル: `.tmp/YYYY-MM-DD/report.md` + `.tmp/YYYY-MM-DD/manga-script.md`
- Vault 書き出しパス: `<vault_path>/Daily/YYYY/MM/YYYY-MM-DD.md`
  - 既存ファイルがあれば上書き確認プロンプトを Main に上げる
- ファイル構成:
  - フロントマター（date / tags: [daily, manga] / weekly-link）
  - 活動サマリー（report.md から転記）
  - 漫画脚本（manga-script.md をインライン）
  - WeeklyReport へのリンク（`[[YYYY-Www]]`）
- index 更新: `<vault_path>/Daily/_index.md` に当日エントリを追記（dataview 対応フォーマット）
- 受け入れ条件: Vault ファイルが存在し、フロントマターに date が含まれる
- 所要時間目安: 1〜2 分
- 失敗時: Vault パスが存在しない場合は `.tmp/YYYY-MM-DD/vault-output.md` に出力し警告

---

## 6. Subagent 起動仕様

| Subagent | Type | 実行モード | 入力渡し方 | 出力ファイル |
|---|---|---|---|---|
| A: collector | Claude (general-purpose) | foreground | プロンプト内に date + vault_path を文字列で明記 | report.md |
| B: storyteller | Claude (general-purpose) | foreground | プロンプト内にファイルパス明記 + Read で内容取得 | story-draft.md |
| C: story-critic | Codex (codex:codex-rescue) | foreground `--wait --fresh --effort high` | プロンプト内にファイルパス明記（Codex が Read ツールで取得） | story-review.json |
| D: story-refiner | Claude (general-purpose) | foreground | プロンプト内に 2 ファイルパス明記 | story-final.md |
| E: manga-scripter | Codex (codex:codex-rescue) | foreground `--wait --fresh --effort high` | プロンプト内にファイルパス明記 | manga-script.md |
| F: vault-writer | Claude (general-purpose) | foreground | プロンプト内に 2 ファイルパス + vault_path 明記 | Vault ファイル |

背景実行（background）を使わない理由:
- パイプライン全体が直列依存（前フェーズの出力が次の入力）
- background にすると完了待機のポーリングが必要で複雑度が上がる
- Codex の同時実行数上限が不明確（赤旗1）なので逐次で確実に制御

---

## 7. Codex 呼び出し方式の確定

採用: `codex:codex-rescue` subagent + `--wait --fresh --effort high`

理由:
- リサーチ結論「推奨方式: codex:codex-rescue agent（subagent）を使用」を採用
- `--wait`: 同期実行でエラー検知を確実に。background にしないことで I/O 競合（赤旗1）を回避
- `--fresh`: 前回 Codex 実行のコンテキスト汚染を防ぐ（story-critic と manga-scripter でコンテキストが混ざらない）
- `--effort high`: 物語評価・脚本変換は多段階推論が必要。xhigh は Opus 4.7 専用なので high で十分
- CLI 直叩き（`codex review --wait`）は採用しない: subagent 経由の方がコンテキスト分離が強い

---

## 8. 漫画化フェーズの v0.1 確定方針

決定: テキストコマ割り脚本（Markdown）のみ

根拠:
- リサーチ赤旗2「漫画化の現実性」が明確。Panel layout の自動生成は未成熟
- SVG/HTML 生成は Codex がコードを実装する必要があるが、1 日の MVP に不適（コード品質・デバッグコスト）
- 画像生成は character 一貫性を保証できない（毎コマ異なる見た目になる）
- テキストコマ割り脚本は Obsidian でそのまま読め、WeeklyReport との整合も取れる
- v0.2 で HTML/SVG に昇格させる設計にする（manga-scripter の出力フォーマットを変えるだけで済むよう story-final.md の構造を安定させる）

v0 の「初版方針案: B (HTML/SVG)」との違い:
- v0 はリサーチ前プランのため HTML/SVG を選んでいたが、リサーチ後は「テキスト脚本に限定」が推奨。v1 で逆転

---

## 9. オープン質問（ユーザーへのヒアリング項目）— 優先度順

### Q1（ブロッカー）: Vault の絶対パスと既存 WeeklyReport の場所
v0.1 実装前に必須。Vault パスがないと Phase 6 が書けない。WeeklyReport のサンプルファイルパスを 1 つ教えてもらえれば命名規則と構造がわかる。

### Q2（ブロッカー for v0.2）: Fieldy とは何か
製品名・API endpoint・取得可能なデータの種類。v0.1 では空欄で進むが v0.2 で必要。CLI か API か、認証が必要かも教えてほしい。

### Q3（v0.1 起動設計に影響）: スラッシュコマンドはどの repo で動かすか
`/daily-manga` コマンドの定義ファイルをこの `dailyReport` リポジトリに置くか、別の repo（Vault など）に置くか。dailyReport repo のままでよければ `.claude/commands/daily-manga.md` に配置する。

### Q4（v0.2 設計に影響）: 漫画の主人公キャラビジュアル設定はあるか
既存アバター・キャラシート・参考イラストが存在するか。v0.2 で HTML 漫画に進む際、キャラ設定を Codex のプロンプトに埋め込む必要がある。

### Q5（v1.0 設計に影響）: 画像生成 API は何を使うか（または使わないか）
DALL-E API key が使えるか、Replicate / ComfyUI など。「テキスト脚本で十分」であれば v1.0 の画像生成フェーズをドロップしてもよい。

---

## 10. Risk Register — 赤旗への具体対処

### リスク1: Codex 並列実行時の I/O 競合
- 赤旗内容: 複数 Codex job を並列投入すると queue overflow の可能性
- 対処（v1 設計に反映済み）: Codex を全て foreground (`--wait`) で逐次実行する。並列化しない。Phase 3 → Phase 5 の 2 回呼び出しも逐次。これで queue overflow のリスクはゼロ
- 残存リスク: なし（逐次化により解消）

### リスク2: 漫画化の現実性
- 赤旗内容: SVG/HTML 生成・画像生成は自動化困難。character 一貫性・panel layout が未成熟
- 対処（v1 設計に反映済み）: v0.1 をテキストコマ割り脚本に限定（Section 8 参照）。HTML/SVG は v0.2、画像生成は v1.0 に延期
- 残存リスク: v0.2 以降の画像生成における character 一貫性は引き続き未解決。v0.2 着手時に改めて設計

### リスク3: Self-review 偏り
- 赤旗内容: 同一モデルで draft → review → refine を回すと bias 強化
- 対処（v1 設計に反映済み）: Claude (Sonnet) で draft → Codex (GPT 系) で review → Claude (別 subagent) で refine、という3段モデル分化を明示。v0 の「Claude main が取り込み」を廃止して Subagent D (story-refiner) に独立させた
- 残存リスク: Claude subagent 同士（B と D）は同一モデル。ただし独立コンテキストで実行されるため bias reinforcement は限定的

### リスク4（v0 未記載）: Vault パス未確定による Phase 6 の実装不可
- 対処: Q1 をヒアリング最優先（ブロッカー）として明記。確定前は Phase 6 のみ skip して 1〜5 を先行実装可能にする

### リスク5（v0 未記載）: Fieldy アクセス不明による Phase 1 の不完全性
- 対処: v0.1 の report.md で Fieldy セクションを空欄で出力し、パイプライン全体の動作確認を優先する。Fieldy 統合は v0.2 の独立タスクに分離

---

## 11. v0 からの変更点 diff サマリ

| 変更箇所 | v0 | v1 | 理由 |
|---|---|---|---|
| 漫画化 v0.1 | HTML/SVG（方針案）+ 要決定のまま | テキスト脚本のみ（確定） | リサーチ赤旗2対処 |
| Codex 呼び出し | 要リサーチ確定 | codex:codex-rescue --wait --fresh --effort high（確定） | リサーチ結論採用 |
| Story refine 担当 | Claude main が取り込み | Subagent D (story-refiner) が自動処理 | モデル分化・サブエージェント分離 |
| データ受け渡し | ファイル vs プロンプト（迷い中） | ファイル経由のみ（確定） | リサーチ推奨採用 |
| Codex 実行モード | foreground/background 未定 | 全て foreground --wait（確定） | 赤旗1（I/O競合）対処 |
| Vault フォルダ構成 | DailyReport/YYYY-MM-DD/ | Daily/YYYY/MM/YYYY-MM-DD.md | リサーチ推奨（WeeklyReport 整合） |
| Phase 5 実行主体 | 未定義 | Subagent F (vault-writer) | 明示化 |
| MVP 定義 | Fieldy・Vault パス unknown のまま Vault に保存 | Fieldy なし・Vault パス確定済み前提・テキスト脚本のみで完走 | 実行可能な MVP に修正 |
| ヒアリング優先度 | 6 項目・優先度なし | 5 項目・ブロッカー明示（Q1: Vault パス、Q2: Fieldy） | 実装着手判断を明確化 |
| Subagent 起動仕様 | 未定義 | 全 6 agent の type/モード/入力渡し方を表で明記 | 実装可能な仕様に |
