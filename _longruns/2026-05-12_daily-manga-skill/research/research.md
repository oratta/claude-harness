# Daily Manga Research

## 1. Codex from Claude Code — 結論

**推奨方式**: `codex:codex-rescue` agent（subagent）を使用

Codex プラグイン v1.0.4 時点で、Claude Code から Codex を呼ぶ正式な方法は `codex:codex-rescue` subagent を経由することである。これは以下の利点を持つ：

- **Shared Runtime 経由**: Bash で `node "${CLAUDE_PLUGIN_ROOT}/scripts/codex-companion.mjs"` を実行。各エージェント呼び出しが独立した Codex タスクランとなる
- **前景 vs 背景選択**: 単純な修正は `--wait`（前景）、複雑な実装は `--background` で背景実行可能
- **Resume 対応**: 前回の Codex 実行を `--resume-last` で継続可能。新規タスクは明示的に `--fresh` で分岐

**制約と注意点**:
- Bash で直接 `codex-companion.mjs` を叩く場合、subagent が自動で prompt 成形する機能は使えない
- `codex-rescue` は「Codex にタスクを投げる」だけの forwarding wrapper。独自の処理逻輯を持たない
- モデル指定（`--model gpt-5.4-mini` など）はランタイム制御。task text に含めない
- `--effort` の指定は可能。Opus 4.7 なら `--effort xhigh` が多段階推論に最適

**代替案と trade-off**:
- CLI 直叩き（`codex review --wait`）: subagent 経由より低レイテンシだが、複数 Codex 並列実行時のコンテキスト分離が弱い
- 自前 Agent Tool（見直し agent）: Codex 代わりに Claude Sonnet で実装可能だが、深いコード理解・アーキテクチャ分析能力で劣る

出典: [codex-rescue.md](file:///Users/oratta/.claude/plugins/cache/openai-codex/codex/1.0.4/agents/codex-rescue.md)

---

## 2. Multi-subagent Best Practice — 結論

**並列実行の定石**:
1. **独立タスク単位で並列化**: 情報収集、物語作成、添削、漫画化を 4 つの subagent で実行
2. **2～4 agent が実績値**: 費用（トークン）と効果のバランス。5 個以上は調整不可の複雑性増加
3. **ファイル経由でのデータ受け渡し推奨**: stdin/stdout でなく、`.tmp/` や `work/` に JSON 吐き出し。各 agent が独立して参照可能

**「創作 → 添削 → 修正」の往復パターン**:
- API 側の定石は「draft 生成 → review agent で評価 → refine で修正」の 3 API call cycle（各ステップで logging・branch 可能）
- Claude Code では **別々の subagent として実装**が推奨。同一 agent での自己レビューは perspective 均一化で品質低下
- 実装例: `agent-writer` (draft) → `agent-reviewer` (feedback JSON) → `agent-reviser` (apply feedback)

**並列実行時の留意点**:
- 各 subagent は独立コンテキストなので、共有 state が必要なら **ファイルベースの state machine** で管理
- 並列度が高い（3+ agent）場合、token overhead は単一 agent の 3 倍～。逐次実行より時間短縮がコスト正当化するか検討必須
- Self-review の罠: 同一 LLM（Claude 4.7）で創作と批評を同じコンテキストで行うと、bias reinforcement。Sonnet など別モデルで review するか、ファイル経由の遅延レビューで perspective リセット

出典: [Claude Code Sub-Agents Best Practices](https://claudefa.st/blog/guide/agents/sub-agent-best-practices), [Claude Code Subagents Documentation](https://code.claude.com/docs/en/sub-agents)

---

## 3. Text-to-Manga Tooling — 結論

**2025-2026 の現状**: 専用 CLI ツール不在。以下の組み合わせが現実解

**Image Generation Models**:
- **FLUX.1 シリーズ**: Kontext Pro / Kontext Max が character consistency と narrative visual storytelling に最適（OSS）
- **Stable Diffusion**: Anifusion が LoRA fine-tuning で manga style を実現
- **DALL-E API** または Replicate 経由の Stable Diffusion inference

**Commercial SaaS / API**:
- **LlamaGen Comic API**: Text → printable comic。API-first で自動 panel layout。CSV upload 対応
- **Anifusion**: Text + character description で AI 漫画生成。LLM + image generation hybrid
- **KomikoAI**: anime character gen だが、manga panel layout 機能もあり

**Claude Code での実装パターン**:
1. Claude で脚本（narrative + dialog）を JSON で生成 → `script.json`
2. Codex で SVG generator（Python / Node）を実装 → panel layout + text placement
3. Image model（FLUX など）に prompt 投げて各 panel の画像生成
4. SVG or PDF に composite

**短期 MVP**: SVG + HTML Canvas で手書き風コマ割りを JavaScript で動的生成。画像は DALL-E API に投げる

出典: [Best Open Source Models for Comics and Manga in 2026](https://www.siliconflow.com/articles/en/best-open-source-models-for-comics-and-manga), [LlamaGen Comic API](https://llamagen.ai/comic-api), [Anifusion](https://anifusion.ai/)

---

## 4. Obsidian Vault Layout — 結論

**推奨フォルダ構成**:
```
/
├── 📅 Daily/
│   ├── 2026/
│   │   ├── 05/
│   │   │   ├── 2026-05-12.md  (WeeklyReport との相互参照)
│   │   │   └── ...
│   │   └── ...
│   └── _index.md  (dataview で daily 一覧自動生成)
├── 📝 Projects/
│   └── DailyManga/
│       ├── spec.md
│       ├── logs/  (脚本・添削・画像生成ログ)
│       └── ...
├── 📊 WeeklyReport/
│   └── 2026-W19.md  (既存)
└── 🏷️ Tags/  (dataview で tag ベース検索可能)
```

**重要な設計方針**:
- **YYYY-MM-DD で日付統一**: 自動 sort と cross-reference 可能化
- **Daily は時系列フォルダ**: `/Daily/2026/05/` のように year/month で階層化。Dataview で月単位 query 可能
- **Project フォルダとの相互参照**: Daily ノートから DailyManga/spec へ wiki-link。back-reference で dependency 可視化
- **Templater/Dataview**: Daily note 作成時に前日 link 自動挿入。Monthly review ページは `dataview TABLE` で動的一覧

**WeeklyReport との整合**:
- Weekly は `/WeeklyReport/2026-W{week-num}.md`
- Daily から Weekly へ uplink: `[[2026-W19]]` で関連付け
- Weekly から Daily へ downlink: dataview で該当週の Daily 一覧自動取得

出典: [How I Organize my Obsidian Vault](https://www.excellentphysician.com/post/how-i-organize-my-obsidian-vault), [Obsidian Folder Structures Best Practices](https://hannahswainlovik.eu/2025/06/02/obsidian-folder-structures-or-how-i-locate-notes/), [Auto Organization with Plugins](https://www.xda-developers.com/set-up-obsidian-vault-to-organize-itself-havent-touched-folder-structure-in-weeks/)

---

## 5. プラン v0 への注意点（赤旗 3 つ）

### 🚩 1. Codex 並列実行時の I/O 競合
Codex は背景実行で複数 job を queue する。同時実行数上限が不明確で、5+ job 投げると queue overflow の可能性あり。Codex status で job count を監視し、逐次実行との trade-off 判断が必須。

### 🚩 2. 漫画化の現実性
「テキスト脚本 → SVG → 画像」の 3 段階は概念上は simple だが、実装では：
- Character 一貫性（同じキャラが毎回同じ容姿）の確保が困難
- Panel layout アルゴリズムが複雑（コマ割り自動生成は未成熟）
- FLUX + LlamaGen API 代替が都度ユーザー操作必須（自動化不可）

短期 MVP は「脚本 + static SVG」（手書きコマ割り）に限定し、画像生成は **sample output 展示程度**に留めるべき。

### 🚩 3. Self-review 偏り
Codex で添削・修正を自動化する場合、同じ Codex モデル（gpt-5.4）で「創作 → 添削 → 修正」を3 loop すると、loop 毎に bias が強化される可能性。「Claude 4.7 で draft → Codex で review → Claude で refine」など **モデル分化** で perspective を維持すること。

---

## 調査上の限界

- **Codex CLI runtime** の詳細（queue size、concurrent job limit）は公開情報不足。実装時に `codex status` で検証必要
- **Manga generation state of art** は SaaS/API 中心で、完全自動化可能な OSS ツール chain が 2025 時点では未確立
- **Obsidian Vault 統合** は plugin (Templater / Dataview) 依存。claude-mem MCP や obs-cli との連携パターンは未調査

