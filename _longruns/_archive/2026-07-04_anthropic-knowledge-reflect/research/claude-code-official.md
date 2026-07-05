# Claude Code 公式ナレッジ 設計資料（2026-07 時点）

調査日: 2026-07-04（research-claude-code エージェントによる調査結果）
Anthropic 公式ドキュメント（code.claude.com/docs、platform.claude.com/docs）と Anthropic Engineering 記事を横断調査。各トピックは「公式推奨/アンチパターン」と「marketplace リポジトリ運用者がすべきこと」の2部構成。

## 信頼度について
- Skills / Subagents / Hooks / Plugins / Memory / settings / SDK の各仕様、および engineering 記事のうち harnesses / writing-tools の2本は **公式ページを直接 WebFetch して確認済み**。
- changelog 上の細かいバージョン対応は裏取りが甘いため本資料では丸めている。

---

## 1. Agent Skills（SKILL.md）

### 公式推奨パターン
- **3層のprogressive disclosure**を意識する。
  - 層1: frontmatter の `description` → 常時コンテキストに載る（skill listing）。
  - 層2: SKILL.md 本体 → skill 起動時に一度だけロードされ、そのターンの間だけ standing instruction として保持。
  - 層3: 参照ファイル（`reference.md` / `examples.md` / `scripts/*`）→ 本文からリンクし、必要になった時だけ読ませる。
- **SKILL.md 本体は 500 行以下**を目安に。詳細は supporting file へ逃がす。
- **description は「主要ユースケースを先頭に」「トリガー句（Use when… / Use proactively after…）を明示」**。キーワード密度が高いほど自動起動精度が上がる。description と `when_to_use` の合算で長さ上限があり、超過すると切り詰められる。
- 配置スコープの優先度: managed(組織) > `~/.claude/skills/`(個人) > `.claude/skills/`(プロジェクト) > plugin 同梱。ネストした `.claude/skills/` も自動発見（モノレポ対応）。同名衝突はディレクトリ修飾名で区別。
- 副作用のある skill（deploy 等）は `disable-model-invocation: true` で自動起動を禁止し手動のみに。背景知識だけの skill は `user-invocable: false` で `/` メニューから隠す。
- `allowed-tools` で権限プロンプトなしに使えるツールを **具体的に**限定。`context: fork` で subagent 隔離実行、`model` / `effort` で skill 中のモデル・努力度を上書き可能。

### アンチパターン
- SKILL.md を数百行に肥大化させる。
- description が曖昧（トリガー条件がない）。
- `allowed-tools: Bash(*)` のような広すぎる許可。
- `disable-model-invocation: true` と `user-invocable: false` の同時指定（誰も起動できなくなる）。
- 純粋な参照 skill に `context: fork` を付ける。

### marketplace 運用者がすべきこと
- SKILL.md の description を **先頭にユースケース+トリガー句** の型へ揃える。
- 長い手順書 skill は本体を薄くして `references/` に分割し、progressive disclosure に寄せる。
- plugin 同梱 skill は最下位スコープなので、ユーザーの `~/.claude/skills/` に同名を置くと上書きされる点を README で警告（plugin-editing.md のルールと整合）。
- 破壊系 skill には `disable-model-invocation: true` を検討。

---

## 2. Subagents（.claude/agents/）

### 公式推奨パターン
- 定義は frontmatter（`name` 必須・lowercase+hyphen、`description` 必須）+ Markdown 本文（= system prompt）。
- `description` に**委譲トリガー**を書く（「Expert code reviewer. Use proactively after code changes.」）。範囲は狭く具体的に。
- `tools`（allowlist）/ `disallowedTools`（denylist、`mcp__*` でMCP一括除去可）でツール権限を絞る。`Agent(worker, researcher)` で spawn できる子を限定。
- `model`: `sonnet`/`opus`/`haiku`/`fable`/フルID/`inherit`。既定は `inherit`。
- コンテキスト分離: subagent は**本文（system prompt）+ 委譲タスク + CLAUDE.md + 親開始時のgit status + preload skills** で起動する fresh context。
- `isolation: worktree` で git worktree 上の隔離コピーを与えられる。
- `skills:` で必要な知識を preload、`memory:`（user/project/local）で知識を永続蓄積（**project スコープ推奨** = VCS 管理可）。
- 配置優先度: managed > `--agents` CLI > `.claude/agents/`(プロジェクト) > `~/.claude/agents/`(個人) > plugin 同梱。

### アンチパターン
- 「Helper agent」のような曖昧 description。
- 必要ツールを `tools` に入れ忘れる権限不足。
- `permissionMode: bypassPermissions` の常用。
- plugin 同梱 subagent は `hooks` / `mcpServers` / `permissionMode` を持てない点を無視する（必要なら `.claude/agents/` にコピーして override）。

### marketplace 運用者がすべきこと
- 各 subagent 定義を **description の委譲トリガー明確化**の観点で棚卸し。
- plugin 同梱 agent が `hooks`/`permissionMode` 非対応な制約に触れないか確認。
- 重い調査系は `isolation: worktree` や `memory: project` の活用余地を検討。

---

## 3. Hooks

### 公式推奨パターン
- イベント（大文字小文字厳密）: `SessionStart` / `SessionEnd` / `UserPromptSubmit` / `PreToolUse` / `PostToolUse` / `PermissionRequest` / `Stop` / `StopFailure` / `SubagentStop` / `PreCompact` / `Notification` など。
- 定義は settings.json（または plugin の `hooks/hooks.json`）で `matcher` + `hooks[]`。type は `command` / `http` / `mcp_tool` / `prompt`(LLM yes-no) / `agent`(実験的)。
- 入出力: stdin に JSON。**exit 0 のときだけ stdout の JSON を解釈**、exit 2 は stderr をエラーとしてブロック、その他は非ブロックエラー。
- フロー制御 JSON: `continue` / `systemMessage` / `additionalContext` / `hookSpecificOutput.permissionDecision`（allow/deny/ask/defer）等。
- パス変数: `${CLAUDE_PROJECT_DIR}` / `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_PLUGIN_DATA}`。
- 用途: 決定的ゲート（Stop hook で lint/test を強制）、危険コマンドのブロック、コンテキスト注入、フォーマッタ自動実行。

### アンチパターン
- stdin を複数回読む。`/dev/tty` へ直接書く。
- matcher に複雑条件を詰める（`if` フィールドで Bash 条件を書く）。
- 出力の各文字列フィールドは上限あり（約1万字）。
- **セキュリティ**: hook は任意コマンドを実行する。信頼できない plugin の hook をそのまま有効化しない。

### marketplace 運用者がすべきこと
- 「毎回○○して」系のユーザー要望は memory ではなく **hook で実装**するのが公式の考え方。
- plugin が hook を同梱する場合、`${CLAUDE_PLUGIN_ROOT}` でスクリプトを参照し、plugin 外の相対パス（`../`）に依存しない。
- longrun の検証フェーズを Stop hook による決定的ゲート化できないか検討（「check を出せないなら ship しない」= 公式の検証哲学）。

---

## 4. Plugins と marketplace

### 公式推奨パターン
- `plugin.json` は `.claude-plugin/` 配下に置き、**必須は `name`（kebab-case）のみ**。推奨で `version` / `description` / `author`。
- **コンポーネントは plugin ルート直下**に置く: `skills/<name>/SKILL.md`、`commands/*.md`、`agents/*.md`、`hooks/hooks.json`、`.mcp.json`、`.lsp.json`、`bin/`。`.claude-plugin/` にはマニフェストのみ。
- **バージョン戦略の二択**:
  - `version` を明示 → SemVer を bump した時だけユーザーに更新が届く（公開 plugin 向け、推奨）。
  - `version` 省略 → git commit SHA が自動採用（開発中向け）。
  - **plugin.json と marketplace.json の両方に version を書くと plugin.json が無警告で優先**（片方だけにする）。
- marketplace は `.claude-plugin/marketplace.json`（必須: `name` / `owner.name` / `plugins[]`）。
- `strict: true`(既定)で plugin.json が権威、marketplace entry は追加定義のみ。
- キャッシュ: install 時に `~/.claude/plugins/cache/` にコピー。plugin 外ファイルは参照不可 → `${CLAUDE_PLUGIN_ROOT}` を使い、永続データは `${CLAUDE_PLUGIN_DATA}`。

### アンチパターン
- skills/commands/agents を `.claude-plugin/` 内に置く。
- version を bump せず内容だけ変える（キャッシュのため他プロジェクトに反映されない）。
- plugin 外の共有ディレクトリを相対パス参照。
- Anthropic 予約名の marketplace 名を使う。

### marketplace 運用者がすべきこと（このリポジトリ最重要）
- **公式仕様は現行運用ルールを追認**: 「marketplace 版のみ編集」「version を必ず bump」「ローカルコピー禁止」は全て公式のキャッシュ挙動から導かれる正しい対策。
- version bump の機械的徹底（CI で「変更あるのに version 据え置き」を検出する余地あり）。
- plugin 内スクリプトは `${CLAUDE_PLUGIN_ROOT}` 参照に統一し、`../` 参照が残っていないか棚卸し。
- 永続キャッシュや状態は `${CLAUDE_PLUGIN_DATA}` を使う（plugin update で消えない領域）。

---

## 5. Memory と CLAUDE.md

### 公式推奨パターン
- 階層と優先度（広→狭で連結）: managed policy > user `~/.claude/CLAUDE.md` > project `./CLAUDE.md` > local `./CLAUDE.local.md`。
- `@path` import（相対=参照元基準、最大4段再帰、コードブロック内は無効）。
- **CLAUDE.md は 200 行以下を目標**。大きくなったら `.claude/rules/` に分割。
- 役割分担: CLAUDE.md = 毎回必要な事実 / auto memory = 発見された学び / skills = 再利用可能な手順。
- 具体的に書く。モノレポは `claudeMdExcludes` で無関係な CLAUDE.md を除外。

### アンチパターン
- 200 行超で肥大化 → 重要ルールごと無視される。
- 標準規約や頻繁に変わる情報を書く。
- auto memory を CLAUDE.md の代替に使う。
- CLAUDE.md を強制力（enforcement）と誤解する → 強制は hook で実装。

### marketplace 運用者がすべきこと
- 本リポジトリの CLAUDE.md は既に公式推奨に沿う。200 行を超えたら rules へ切り出す運用を維持。
- plugin が配布する「使い方ルール」は CLAUDE.md ではなく **skill（progressive disclosure）** に寄せる。

---

## 6. settings.json

### 公式推奨パターン
- 階層(高→低): managed > CLI 引数 > `.claude/settings.local.json` > `.claude/settings.json` > `~/.claude/settings.json`。スカラーは上位勝ち、配列/オブジェクトは deep merge。
- **deny が allow より優先**。allow は `Bash(npm run test *)` のように具体的に。
- 反映タイミング: permissions/hooks/env はリアルタイム、model/outputStyle は再起動要。
- `.claude/settings.json` の allow と additionalDirectories は **workspace trust 承認後のみ有効**。

### アンチパターン
- settings に API キーを平文で書く。
- settings.local.json を commit する。
- 広すぎる allow を local に置いて CI へ流す。

### marketplace 運用者がすべきこと
- plugin テスト用 CI では `--bare` + `--permission-mode dontAsk` + 具体的 allowlist で決定的に。

---

## 7. Headless / Agent SDK（ハーネス設計の核）

### 公式推奨パターン
- `claude -p` で非対話実行。`--output-format json|stream-json`、`--json-schema` で構造化出力、`--allowedTools`、`--permission-mode`、`--continue`/`--resume`。
- **`--bare`**: hooks/skills/plugins/MCP/auto memory/CLAUDE.md を読み込まず、明示 flag のみで動く。CI/スクリプトで決定的にしたい時に推奨。
- permission mode 6種: `default` / `acceptEdits` / `plan` / `auto` / `dontAsk` / `bypassPermissions`(隔離コンテナ専用)。

### ツール設計（writing-tools-for-agents の要点、直接確認済み）
- **ツールは多ければ良くない**。関連操作は1つに統合。
- **命名は名前空間化**で曖昧さを排除。
- **description が最重要**。新人に説明するつもりで、何をする/いつ使う・使わない/各パラメータ/注意点/戻り値の制限まで書く。曖昧語を排除。小さな description 改善が大きな精度改善を生む。
- **レスポンスは high-signal に**。意味のある semantic ID、不要フィールドを削る、`response_format` で詳細/簡潔を切替。truncation 時はエージェント向け指示メッセージを添える。
- **エラーメッセージは実行可能に**（どう直すかを返す）。
- **eval 駆動で改善**: 現実的シナリオで評価タスクを作り、推論ログから混乱点を特定 → 改善。

### 長時間エージェントのハーネス（effective-harnesses-for-long-running-agents の要点、直接確認済み）
- **compaction だけでは不十分**。セッションをまたぐ一貫性は、外部状態ファイル + git で担保する。
- パターン: **init エージェント**（初回のみ環境セットアップ）と**coding エージェント**（以降、段階的に前進）を分ける。
- **状態の外部化**: 機能リストファイル（JSON で `passes:false` 列挙）、`init.sh`、`claude-progress.txt`、初期 git commit。
- **1セッション1機能**に限定して過剰実装を防ぐ。セッション末に説明的な git commit。
- **検証は人間と同じ E2E で**（ブラウザ自動化 MCP）。丁寧なテスト後にのみ `passing` を立てる。セッション開始時に基本機能の動作確認。

### marketplace 運用者がすべきこと
- **longrun プラグインはこのハーネス論文の設計とほぼ同型**。論文の「1セッション1機能」「compaction 不十分」「外部状態ファイル + git で一貫性」を longrun のドキュメント/デフォルトに明文化する価値が高い。
- longrun-browser-verifier の E2E 設計は論文の「人間と同じ方法で検証」に合致。verifier を「テスト後にのみ pass」ゲートとして強めると論文準拠度が上がる。
- 各 plugin のツール/コマンド定義を **writing-tools-for-agents の観点で監査**。

---

## 8. 参照した実在 URL

公式ドキュメント（code.claude.com、直接確認済み）:
- https://code.claude.com/docs/en/skills.md
- https://code.claude.com/docs/en/sub-agents.md
- https://code.claude.com/docs/en/hooks-guide.md
- https://code.claude.com/docs/en/hooks.md
- https://code.claude.com/docs/en/plugins.md
- https://code.claude.com/docs/en/plugins-reference.md
- https://code.claude.com/docs/en/plugin-marketplaces.md
- https://code.claude.com/docs/en/memory.md
- https://code.claude.com/docs/en/configuration.md
- https://code.claude.com/docs/en/permissions.md
- https://code.claude.com/docs/en/permission-modes.md
- https://code.claude.com/docs/en/headless.md

Claude API / SDK（platform.claude.com）:
- https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools.md
- https://platform.claude.com/docs/en/managed-agents/overview.md

Anthropic Engineering:
- https://www.anthropic.com/engineering/claude-code-best-practices
- https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents （直接確認済み）
- https://www.anthropic.com/engineering/writing-tools-for-agents （直接確認済み）
- https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
- https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- https://www.anthropic.com/engineering/building-agents-with-the-claude-agent-sdk

## このリポジトリへの含意（要約）
- 現行の運用ルール（marketplace 版のみ編集・version 必須 bump・ローカルコピー禁止・CLAUDE.md を rules 分割）は **公式仕様で追認される正しい設計**。変更不要。
- 追加で効くのは3点: (1) longrun を「長時間エージェントのハーネス」論文の語彙（外部状態+git、1セッション1機能、検証ゲート）で明文化、(2) 自作ツール/コマンドの description・レスポンスを writing-tools 基準で監査、(3) plugin の永続データを `${CLAUDE_PLUGIN_DATA}` に寄せて update 消失を回避。
