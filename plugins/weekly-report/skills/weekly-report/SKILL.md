---
name: weekly-report
description: 週次プロジェクト実績レポートを自動生成する。各プロジェクトのGitコミット履歴・LLMセッションログ・Obsidianファイル変更・フェーズ状態を集約し、週次ノートに挿入する。
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# 週次プロジェクト実績レポートスキル

## 概要

対象週の各プロジェクトの活動を自動集約し、事実ベースの実績サマリを週次ノートに挿入する。

## 入力

- `$ARGUMENTS`: 週番号（例: `2026-W11`）。空欄なら直近の完了した週（日曜以前の週）

## 実行フロー

### Step 1: 対象週の特定

引数をパースしてISO週の月曜〜日曜の日付範囲を算出する。

```bash
# 例: 2026-W11 → monday=2026-03-09, sunday=2026-03-15, next_monday=2026-03-16
# dateコマンドまたは手動計算でISO週を日付に変換
```

引数が空の場合:
- 今日が月〜土なら前週、日曜なら当週を対象とする

週次ノート `02 - PERIODIC/Weekly/{week}.md` の存在確認:
- **存在する場合**: そのまま使用
- **存在しない場合**: テンプレート `__META/TEMPLATE/02 - WEEKLY Template.md` を参考に基本構造を作成
  - frontmatter: `created`, `type: weekly`, `week`, `cssclasses: [wide]`
  - 見出し: `# {week}（MM/DD 〜 MM/DD）`
  - テンプレートのセクション構造をコピー（Templater構文は展開済みの値に置換）

### Step 2: レジストリ読み込み

`__META/project-registry.md` のMarkdownテーブルをパースする:
- `project`: プロジェクト名
- `source_path`: ソースコードディレクトリの絶対パス（空なら省略）

加えて `12 - PROJECT/` のディレクトリ一覧を取得し、レジストリ未登録プロジェクトも含めた全プロジェクトリストを作る。

### Step 3: LLMセッションログ収集

`90 - LLM/YYYYMMDD-*.md` を対象週の各日付（月〜日）でGlob検索する。

各ログファイルについて:
- ファイル名のサマリ部分を取得
- 「作成/更新したファイル」セクションからプロジェクト名を推定（`12 - PROJECT/{name}/` パターン）
- ファイル名やタイトルからもプロジェクト名を推定（例: `Buffon購入商品選定` → Buffon）

プロジェクトごとにグルーピングする。プロジェクトに紐付かないログは「その他」として集約。

### Step 4: プロジェクト別データ収集

各プロジェクトについて以下を収集する。

#### 4a. ソースコードGit（source_pathがある場合）

```bash
cd {source_path} && git -c core.quotePath=false log \
  --since={monday} --until={next_monday} \
  --format="%h %s" --no-merges
```

- コミットメッセージをconventional commit type別に分類（feat/fix/docs/refactor/chore/test等）
- conventional commitでないものは「other」
- ファイル変更数:
  ```bash
  git -c core.quotePath=false diff --stat --shortstat {monday_commit}..{latest_commit}
  ```
  またはコミットがない場合はスキップ

#### 4b. Obsidianファイル変更

Vault git logから対象プロジェクトの変更ファイルを取得:
```bash
git -c core.quotePath=false log --since={monday} --until={next_monday} \
  --name-only --format="" --diff-filter=ACMR -- "12 - PROJECT/{name}/"
```

- `LLM/` ディレクトリは除外
- コミットがない場合はスキップ（mtimeフォールバックは行わない）
- 変更ファイルをカテゴリ分け: `context/`, `phases/`, その他

#### 4c. フェーズ状態

`12 - PROJECT/{name}/phases/` 内のファイルを読み、frontmatterで `status: active` のフェーズを取得:
- `deliverable`: 成果物
- `progress`: 進捗率（%）
- フェーズ名（ファイル名またはH1見出し）

### Step 5: レポート生成

以下の構造でMarkdownを生成する:

```markdown
## 今週の実績サマリ（自動生成）

> 生成日: YYYY-MM-DD | 対象週: GGGG-WXX（MM/DD 〜 MM/DD）

### サマリ
{2-4文の自然言語要約。主要な活動と進捗を簡潔に記述}

**アクティブプロジェクト数**: N/total | **ソースコミット数**: N | **LLMセッション数**: N

---

### [[プロジェクト名]]
**フェーズ**: [[フェーズ名]] — 成果物名 (進捗: N%)

**ソースコード活動** (Nコミット, Nファイル変更):
- feat: コミットメッセージ要約
- fix: コミットメッセージ要約

**Obsidian更新**:
- context/: 変更ファイル名
- phases/: 変更ファイル名

**LLMセッション**:
- [[ログファイル名|表示名]]

---
（プロジェクトごとに繰り返し。活動がないプロジェクトはスキップ）

### 活動なしのプロジェクト
プロジェクトA, プロジェクトB, ...
```

**レポート生成ルール:**
- 活動があったプロジェクトのみ詳細セクションを出力
- ソースコード活動がない場合はそのサブセクションを省略
- Obsidian更新がない場合はそのサブセクションを省略
- LLMセッションがない場合はそのサブセクションを省略
- 全サブセクションが空のプロジェクトは「活動なしのプロジェクト」に列挙
- プロジェクト名・フェーズ名は `[[]]` でwikilink化

### Step 6: 週次ノートへの挿入

週次ノートファイル `02 - PERIODIC/Weekly/{week}.md` を更新する:

1. `## 今週の実績サマリ（自動生成）` が既存の場合:
   - そのセクション開始から次の `## ` 見出し（同レベル以上）までを置換
2. 存在しない場合:
   - `## 週次振り返り（金曜）` の直前に挿入
   - `## 週次振り返り（金曜）` もなければファイル末尾に追加

Edit ツールで更新する。

## エラーハンドリング

| 状況 | 対応 |
|---|---|
| source_pathが未設定/空 | Obsidian活動・LLMログのみでレポート |
| source_pathのディレクトリが存在しない | スキップ＋警告メッセージをレポートに含める |
| 対象週にソースコミットなし | ソースコード活動サブセクションを省略 |
| 週次ノートが存在しない | テンプレートベースで自動作成してから挿入 |
| LLMログが対象週にない | LLMセクションを省略 |
| 活動が一切ないプロジェクト | 「活動なしのプロジェクト」に列挙 |
| 日本語ファイル名 | `git -c core.quotePath=false` を常に使用 |
| 再実行（冪等性） | 既存の「今週の実績サマリ（自動生成）」セクションを置換 |
| Gitリポジトリでない | ソースコード活動をスキップ |

## 注意事項

- **テンプレートは変更しない**: `__META/TEMPLATE/02 - WEEKLY Template.md` は読み取り専用
- **既存コンテンツを保持**: 週次ノートの他のセクション（フォーカス、振り返り等）は一切変更しない
- **Vault外のリポジトリにアクセスするため** `cd` を使ったBashコマンドが必要
- **大量コミット対策**: コミットが50件を超える場合はサマリのみ（type別件数）表示
