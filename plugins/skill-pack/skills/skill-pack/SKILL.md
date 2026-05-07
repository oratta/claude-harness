---
name: skill-pack
description: プロジェクトごとに skillOverrides と enabledPlugins を対話的に編集し、必要なスキル/プラグインだけ ON にする。「このプロジェクトで使うスキルを絞りたい」「ユーザーレベルのスキルが多すぎる」「skillOverrides を設定」「プロジェクトのスキル整理」「不要なプラグインを無効化」で起動する。Claude Code 公式の skillOverrides / enabledPlugins 仕様に準拠し、コピーや symlink ではなく設定ファイル編集で実現する。
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion
---

# skill-pack — プロジェクト別スキル ON/OFF 管理

Claude Code の `skillOverrides` と `enabledPlugins` を対話的に編集し、プロジェクトごとに必要なスキル/プラグインだけを ON に絞り込むスキル。

## 背景: なぜこのスキルが必要か

`~/.claude/skills/` に多数のスキルを置くと、すべてのプロジェクトで全スキルが読み込まれ、コンテキストを圧迫する（`/doctor` 警告の主因）。Claude Code 公式は以下の仕組みでプロジェクトごとに ON/OFF できる:

- **個人スキル** (`~/.claude/skills/`): `skillOverrides` で個別に `"on" / "off" / "name-only" / "user-invocable-only"` を指定
- **プラグインのスキル群**: `enabledPlugins` で plugin 単位に `true / false`
- **設定ファイル優先度**: Local > Project > User
  - `.claude/settings.json` (チーム共有, commit 対象)
  - `.claude/settings.local.json` (個人専用, gitignore 標準)

このスキルはその仕組みを対話 UI でラップするもの。

## サブコマンド

引数 `$ARGUMENTS` の最初のトークンで動作分岐。

| 引数 | 動作 |
|---|---|
| (なし) または `init` | 全 user-level skills + 全 plugins を一覧表示 → ユーザーが ON にしておくものを選択 → 残りを OFF にして設定ファイルに書き込む |
| `list` | 現在の skillOverrides / enabledPlugins の状態を一覧表示 |
| `on <name>` | 指定スキルを ON に変更（設定から削除 or `"on"`） |
| `off <name>` | 指定スキルを OFF に変更（`"off"` を書き込み） |
| `suggest` | プロジェクトの状況（package.json 等）から推奨スキルセットを提示 |

引数: `$ARGUMENTS`

## 前提条件

- カレントディレクトリがプロジェクトルート（`.claude/` の親）であること
- `~/.claude/skills/` または marketplace plugins が存在すること

## 共通: 設定ファイルのスコープ判定

設定書き込み先は **チーム共有 / 個人** の2択:

| スコープ | 配置先 | git追跡 | 用途 |
|---|---|---|---|
| **チーム共有** | `.claude/settings.json` | commit 対象 | プロジェクト全員に強制したい設定 |
| **個人専用** | `.claude/settings.local.json` | gitignore 標準 | このユーザーだけ適用、メンバー間で違っても良い |

`init` または個別変更時、AskUserQuestion でスコープを尋ねる。デフォルトは **個人専用** （`.claude/settings.local.json`）— 公式が「プロジェクトごとの個別制御」として推奨する形。

ただし、`.claude/settings.json` が既に存在し当該キーを持つ場合はそちらを優先（チーム規約として尊重）。

## 実行フロー

### Step 0: スコープと現状の確認

1. カレントディレクトリで `.claude/` の存在を確認。なければ `mkdir -p .claude` で作成。
2. `.claude/settings.json` と `.claude/settings.local.json` を読む（存在しないなら空 JSON `{}` 扱い）。
3. 既存の `skillOverrides` / `enabledPlugins` を解析。

### Step 1: 全スキル/プラグインの一覧取得

以下のソースから「現在ロード可能な skill/plugin」を列挙:

1. **User-level skills**: `~/.claude/skills/*/SKILL.md` を Glob で取得し、各 SKILL.md の frontmatter から `name` を抽出
2. **Plugin skills**: `~/.claude/plugins/cache/<marketplace>/<plugin>/.claude-plugin/plugin.json` を読み、`name` フィールドから plugin 名を取得（または system-reminder で提供されている skill 一覧から `<plugin>:<skill>` 形式のものを集める）

注: 自動取得が難しい場合は、Claude Code セッションが起動時に表示する skill 一覧（system-reminder の "available skills" セクション）をそのまま参照してよい。

### Step 2: サブコマンドに応じた処理

#### `init` (引数なしの場合)

1. Step 1 で取得した全 skills/plugins を、AskUserQuestion または対話で提示
   - 数が多い場合は **カテゴリ別** にグルーピングして提示（例: workflow, design, ai-stack, framework-specific...）
2. ユーザーに「このプロジェクトで ON にしておくもの」を選択してもらう（multiSelect）
3. 選択されなかったスキルは:
   - User skill → `skillOverrides[<name>] = "off"`
   - Plugin → `enabledPlugins[<plugin>@<marketplace>] = false`
4. スコープ（team / personal）を尋ねる
5. 該当の settings ファイルを Edit/Write で更新

#### `list`

両 settings ファイルを読み、現状を表形式で出力:

```
=== ~/.claude/skills/ ===
  ✅ tool-selection-guide          (default ON)
  ❌ liff-development              (off in .claude/settings.local.json)
  📛 corporate-branding            (name-only)

=== Plugins ===
  ✅ longrun@oratta-claude-harness
  ❌ cooking@1h-cooking            (disabled in .claude/settings.local.json)
```

#### `on <name>` / `off <name>`

1. `<name>` が user skill か plugin か判定
2. 既存の settings ファイルから対応エントリを書き換え
   - `on`: `skillOverrides` から削除 or `"on"` をセット
   - `off`: `"off"` を追加
3. plugin の場合は `enabledPlugins` を編集
4. スコープが不明な場合は尋ねる

#### `suggest`

1. プロジェクトのファイル群を Glob/Grep で軽く調査:
   - `package.json` が存在 → 含まれる依存から推奨を判定
     - `next` → nextjs 系スキル / plugin を推奨
     - `@supabase/supabase-js` → supabase 系
     - `@vercel/ai` → vercel-ai-sdk
     - `@line/liff` → liff-development
     - `n8n` 関連 → n8n 系
   - `.pen` ファイルが存在 → pencil 系
   - `infra/` ディレクトリ → infra plugin
2. 推奨リストを提示し、ユーザー承認後に `init` 同等の処理で settings に反映

## 設定ファイル編集の注意

- JSON は手動編集ではなく、**Read → 解析 → Write** の流れで処理する
- 既存のキー（permissions, hooks 等）を絶対に壊さない
- `skillOverrides` / `enabledPlugins` キーが存在しない場合は新規追加
- 値が空オブジェクトになる場合は、キー自体を削除しても良い

### settings.local.json のサンプル形

```json
{
  "skillOverrides": {
    "liff-development": "off",
    "n8n-mcp-dev": "off",
    "pencil-mcp-workaround": "off"
  },
  "enabledPlugins": {
    "cooking@1h-cooking": false,
    "obsidian-llm-session-rules@oratta-claude-harness": false
  }
}
```

## 完了レポート

実行後、以下を表示:

1. 編集した設定ファイル（path）
2. 変更前後の skillOverrides / enabledPlugins 件数
3. **変更を反映するには Claude Code の再起動が必要** な旨の注意（skill ロードはセッション開始時のため）

## エラーハンドリング

- `.claude/` 配下に書き込み権限がない → エラー報告
- settings JSON が壊れている → ユーザーに確認を取り、修正を促す（自動上書きしない）
- skill 名が見つからない → 候補をfuzzy一致で提示
