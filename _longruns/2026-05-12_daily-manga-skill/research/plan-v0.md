# Daily Manga Pipeline — Plan v0 (main session, pre-research)

> 作者: Claude (main session)
> 目的: 1日の終わりに、その日の活動データを元に「ドラマの主人公」視点の物語を生成し、2ページの漫画にして Vault に保存する自動パイプラインを設計する。
> 役割分担（user 指示）:
> - 情報収集: Claude
> - 物語作成: Claude
> - 物語添削: Codex
> - 漫画作成: Codex

## 1. 全体像

```
[Claude]情報収集 → DailyReport.md
   ↓
[Claude]物語化 → story-draft.md
   ↓
[Codex]添削 → story-review.md (修正パッチ or リライト)
   ↓
[Claude]添削取り込み → story-final.md
   ↓
[Codex]漫画化 → manga.{md|svg|html|png} (2ページ分)
   ↓
Vault に保存・index 更新
```

## 2. 各フェーズ詳細

### Phase 0: 起動・準備
- トリガー: 当面は手動コマンド `/daily-manga [YYYY-MM-DD]`（デフォルト today）
- 出力先: `<Vault>/DailyReport/YYYY-MM-DD/`
  - `report.md` — 構造化された活動ログ
  - `story-draft.md` / `story-final.md` — 物語
  - `manga.md` (+ assets) — 漫画
- 状態管理: 各フェーズの成果物がファイルとして残るので、再開可能（idempotent）

### Phase 1: 情報収集 (Claude subagent: collector)
**Inputs:**
- 日付 (YYYY-MM-DD)
- Vault パス（要ヒアリング）
- Fieldy アクセス情報（要ヒアリング — Fieldy が何かまず確認）

**Sources to gather:**
1. Claude Code セッションログ: `~/.claude/projects/*/<日付近辺>.jsonl`
2. Git commits: 主要 repo の `git log --since=<date> --until=<date+1>`
3. Fieldy データ: 当日分（仕様 unknown — 要確認）
4. Vault 内更新ファイル: `find <Vault> -newer ... -mtime -1`
5. Obsidian の WeeklyReport テンプレ参照（フォーマット流用のため）

**Output: `report.md`**
```markdown
# Daily Report — YYYY-MM-DD
## 活動サマリー
- 主要トピック / 感情曲線 / 注目イベント
## Claude Code セッション
- プロジェクト別の作業内容
## Git activity
## Fieldy
## Vault updates
## Tomorrow's hint
```

### Phase 2: 物語化 (Claude subagent: storyteller)
**Inputs:** `report.md` + 物語スタイルガイド
**処理:**
- 1日を「ドラマの主人公」視点で再構成
- 起承転結 or 3幕構成、2ページ漫画に収まる尺（目安 6〜8コマ）
- 主人公の内面モノローグ＋外的アクション
- 感情の起伏を山場1つに集約

**Output: `story-draft.md`**
```markdown
# Story — YYYY-MM-DD
## ログライン
## 登場人物
## あらすじ
## シーン1〜N（コマ単位の下書き）
- ト書き / セリフ / モノローグ
```

### Phase 3: 物語添削 (Codex subagent: story-critic)
**呼び出し方式:** Claude Code の codex:codex-rescue agent 経由（要リサーチ確定）
**Inputs:** `story-draft.md`
**Codex に渡すプロンプト方針:**
- ドラマ性（葛藤・転機・解決）
- キャラクター性（主人公の声に一貫性）
- 漫画への翻訳容易性（ビジュアル化しやすいか）
- 2ページ尺の妥当性

**Output: `story-review.md`** — 指摘 + 推奨リライト
**取り込み:** Claude main が review を読み `story-final.md` を確定

### Phase 4: 漫画化 (Codex subagent: manga-maker)
**Inputs:** `story-final.md`
**Output 候補（要リサーチ・要決定）:**
- A) Markdown コマ割り脚本のみ（テキスト漫画）
- B) HTML/SVG で簡易ビジュアル
- C) 画像生成 (DALL-E / Stable Diffusion / Pencil MCP) で各コマを画像化
- D) Stitch / frontend-design スキルで HTML 漫画

**初版方針案:** B (HTML/SVG) — テキスト+簡易絵で2ページレイアウト。後で C にアップグレード可能な構造にする。

### Phase 5: Vault 統合
- `<Vault>/DailyReport/YYYY-MM-DD/` に全成果物を保存
- `<Vault>/DailyReport/index.md` に当日エントリを追記
- WeeklyReport との連携（週次で daily を集約する仕組みは後続）

## 3. 技術選定（暫定）

| 要素 | 候補 | 備考 |
|---|---|---|
| サブエージェント分離 | Claude Code Agent tool | claude / general-purpose / codex:codex-rescue |
| Codex 呼び出し | codex:codex-rescue agent + codex:setup skill | リサーチで詳細確定 |
| Vault 操作 | 通常の Read/Write/Edit | パスは要ヒアリング |
| Fieldy 取得 | 不明 | 要ヒアリング |
| 漫画ビジュアル | HTML/SVG 暫定 → 画像生成は v2 | |
| パイプライン定義 | スラッシュコマンド `/daily-manga` | 単一エントリポイント |
| 中間ファイル管理 | `<Vault>/DailyReport/<date>/` 配下にすべて集約 | 再実行可能 |

## 4. リスク・オープンクエスチョン

1. **Fieldy** が何か未確定。API か CLI かファイル出力か？
2. **Vault** の正確なパス、WeeklyReport のテンプレ場所
3. **Codex 呼び出し方法** の現状ベストプラクティス（リサーチで確定）
4. **漫画生成** をどこまでやるか（テキスト脚本 / HTML / 画像）
5. **サブエージェント間のデータ受け渡し**：ファイル経由 vs プロンプト直接埋め込み（長文リスク）
6. **Codex の context 制約**：物語+レビュー+漫画化と段階的に渡すならファイル参照ベースが安全
7. **失敗時の冪等性**：各 phase が独立して再実行可能か
8. **メイン session での自画自賛回避**：レビュー（Phase 3）は別 agent で確定 — これは仕様通り
9. **コスト**：Codex 2回 + Claude subagent 複数の運用コスト感
10. **保存頻度・自動化**：当面は手動。cron 化は v2

## 5. MVP スコープ（v0.1 想定）

- [ ] Phase 1〜2 を Claude subagent 2 つで動かす（収集→物語）
- [ ] Phase 3 を Codex で動かす（添削）
- [ ] Phase 4 は MVP では Markdown 脚本のみ（HTML/画像は v0.2）
- [ ] Vault に保存
- [ ] スラッシュコマンド `/daily-manga` で起動

## 6. 不明点ヒアリング（実装着手前に user に聞きたい）

1. Fieldy とは？（製品名 / API endpoint / どんなデータが取れるか）
2. Vault の絶対パス
3. 既存 WeeklyReport のサンプルファイル位置
4. 漫画はどのレベルまで欲しいか（テキスト脚本で十分 / 画像欲しい / レイアウトHTML）
5. 自動化トリガー（毎日 N 時に走らせたいか / 手動でいいか）
6. 主人公キャラのビジュアル設定はあるか（既存アバター？）
