---
name: weekly-report
description: 週次プロジェクト実績レポートを自動生成する。各プロジェクトのGitコミット履歴・Sunsamaタスク・LLMセッションログ・フェーズ状態を集約し、週次ノートに挿入する。
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, mcp__sunsama__read_resource
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
- `sunsama_channel`: Sunsamaのチャンネル名（プロジェクトとのマッピング用）

加えて `12 - PROJECT/` のディレクトリ一覧を取得し、レジストリ未登録プロジェクトも含めた全プロジェクトリストを作る。

### Step 3: Sunsamaタスク収集

#### 3-0. Deferred Tool スキーマのロード（必須）

Claude Code 環境では MCP ツールが "deferred tools" として登録されており、初期状態ではスキーマがロードされていない。`mcp__sunsama__read_resource` を直接呼ぶと `InputValidationError` となり「MCP未接続」と誤判定してしまうため、**呼び出し前に必ず ToolSearch でスキーマをロードする**:

```
ToolSearch(query="select:mcp__sunsama__read_resource", max_results=1)
```

ロードに失敗した場合（`claude mcp list` で `sunsama: ... ✗` 等）にのみ、本ステップ全体をスキップしてレポートに `⚠️ Sunsama MCP が未接続` と記載する。ロード成功時は通常通り続行する。

#### 3-1. タスク収集

対象週の月〜日（7日間）について `sunsama://tasks/{YYYY-MM-DD}` リソースを読み取る。

各タスクについて:
- `completed: true` かつ `completedOnDate` が対象週内のもののみ抽出
- **ルーチン除外**: `recurrenceRule` に `FREQ=DAILY` を含むタスクは除外（デイリールーチン、Daily Long Run等）
- **Daily planning除外**: channel が `Sintrepreneur` でタイトルが `Daily planning` のものは除外
- `channel` でプロジェクトにマッピング（レジストリの `sunsama_channel` 列を参照）
- マッピングできないタスクで `isPersonal: true` のものは「個人タスク」セクションに集約
- `timeEstimate` を分に変換して集計（計画時間）

**サブタスク展開ルール:**
- タスクに `subtasks` がある場合、完了済みサブタスク（`completed: true`）を個別の行として展開する
- 表記: `親タスク名: サブタスク名 (計画時間)` — 親タスク名は短縮してよい
- サブタスクがないタスクはそのまま `タスク名 (計画時間)` で表示
- task(N) の N は展開後のサブタスク数を含めた完了項目数

プロジェクト別・個人別にグルーピングし、計画時間の合計を算出する。

### Step 4: LLMセッションログ収集

#### 3a. VaultレベルLLMログ（`90 - LLM/`）

`90 - LLM/YYYYMMDD-*.md` を対象週の各日付（月〜日）でGlob検索する。

各ログファイルについて:
- ファイル名のサマリ部分を取得
- 「作成/更新したファイル」セクションからプロジェクト名を推定（`12 - PROJECT/{name}/` パターン）
- ファイル名やタイトルからもプロジェクト名を推定（例: `Buffon購入商品選定` → Buffon）

プロジェクトごとにグルーピングする。プロジェクトに紐付かないログは「その他」として集約。

#### 3b. ソースリポジトリ Claude Code セッション（native jsonl 直読）

> 流用元: `plugins/daily-report/agents/llm-log-compactor.md:33-100` の jq ロジック（初回 user メッセージ抽出・メタ統計集計）を、週次（複数日横断）集計向けに適用したもの。廃止済み hook が生成していた旧形式の劣化コピー（ソースリポジトリ配下の `LLM/` ディレクトリの markdown）は参照しない。

レジストリの各プロジェクトについて、`source_path` を Claude Code の `~/.claude/projects/` エンコード規則（`/` を `-` に置換）で変換し、対応するセッション jsonl を対象週の日付範囲（月曜 00:00 〜 翌月曜 00:00）でフィルタして直読する:

```bash
encoded_path=$(echo "{source_path}" | sed 's#/#-#g')
project_dir="$HOME/.claude/projects/${encoded_path}"

# 対象週の月曜 00:00 〜 翌月曜 00:00 の範囲で作成された jsonl のみを対象にする
find "$project_dir" -maxdepth 1 -name "*.jsonl" \
  -newermt "{monday} 00:00" ! -newermt "{next_monday} 00:00" 2>/dev/null
```

各 jsonl ファイル = 1 セッション。各セッションについて `plugins/daily-report/agents/llm-log-compactor.md` の 2a ロジックと同じパターンで初回 user メッセージを抽出する（`head -5` 制限は撤廃し、先頭から順次スキャン。sidechain は除外）:

```bash
jq -r -c 'select(.type == "user" and .message.role == "user")' "$f" \
  | head -1 \
  | jq -r 'if (.message.content | type) == "string" then .message.content
           else (.message.content[] | select(.type=="text") | .text) end' \
  | head -c 300
```

- **セッションIDでグルーピング**: jsonl のファイル名（`.jsonl` を除いた basename）をそのまま session ID として使う（native jsonl は 1 セッション 1 ファイルのため、旧形式のような日付跨ぎのファイル分割は発生しない）
- **セッション要約の抽出**: 上記 jq で取得した初回 user メッセージから、ユーザーの最初のリクエストを1行に要約する
  - コマンド呼び出し（`<command-name>` タグ）がある場合はコマンド名を記載
  - 通常のテキストの場合は最初の1文を要約
- **セッション数をカウント**: 対象週内で `find` が列挙した jsonl 件数 = セッション数
- `jq` が利用できない、または `project_dir` が存在しない場合はそのプロジェクトの LLM セッションセクションを省略する（フェイルソフト、エラー扱いにしない）

### Step 5: プロジェクト別データ収集

各プロジェクトについて以下を収集する。

#### 4a. ソースコードGit（source_pathがある場合）

```bash
cd {source_path} && git -c core.quotePath=false log \
  --since={monday} --until={next_monday} \
  --format="%h %s" --no-merges
```

- コミットメッセージをconventional commit type別に分類（feat/fix/docs/refactor/chore/test等）
- conventional commitでないものは「other」
- コード変更量（追加行数＋削除行数の合計）:
  ```bash
  cd {source_path} && git log --since={monday} --until={next_monday} --no-merges --shortstat --format="" | awk '
    /files? changed/ {
      for (i=1; i<=NF; i++) {
        if ($i ~ /insertion/) ins += $(i-1)
        if ($i ~ /deletion/) del += $(i-1)
      }
    }
    END { print ins + del }
  '
  ```
  - 変更量 = insertions + deletions（追加も削除も「対応した量」として合算）
  - コミットがない場合はスキップ

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

#### 4d. harvest セッション

harvest plugin（`/harvest:*` slash command 群）はツール本体を marketplace dir に置き、コンテンツ（slug データ）を各作業 repo の cwd 直下 `data/sessions/<slug>.jsonl` に分散させる責務分離モデルで運用されている（`~/.claude/rules/harvest-usage.md` 参照）。検索ルートは環境変数 `$WORKSPACE_ROOT` で解決する。

```bash
if [ -z "$WORKSPACE_ROOT" ]; then
  # 未設定時はフェイルソフト: 本サブセクションを省略してレポート生成を継続する
  echo "WORKSPACE_ROOT 未設定のため harvest セッション集計をスキップ"
else
  find "$WORKSPACE_ROOT" -type f -path "*/data/sessions/*.jsonl" \
    -not -path "*/node_modules/*" \
    -not -path "*/venv/*" \
    -not -path "*/.venv/*" \
    -not -path "*/site-packages/*" \
    -not -path "*/storage/framework/sessions/*"
fi
```

各 jsonl について:
- ファイル名（`.jsonl` を除いた basename）が **slug**
- 各行をJSONパースし、`time` フィールドが対象週内のイベントを抽出
- イベント種別: `session_start`, `session_finish`, `plan_done`, `retrospect_start`, `retrospect_done` 等
- `session_finish` イベントの `work_minutes` フィールドがあれば作業時間として記録（未取得の場合は空）

**プロジェクトへのマッピング:**
- jsonl の親 repo path（`*/data/sessions/` の手前）を取得
- レジストリの `source_path` と前方一致でマッチ → プロジェクト名を解決
- マッチしない場合は、path のディレクトリ名から推測（例: `00_IndieDev/genetta-inc/` → Genetta-inc）
- どのプロジェクトにも紐付かない場合は「個人タスク」セクションに集約

**集計:**
- slug ごとに session_start / session_finish の有無、合計 work_minutes、最新イベント時刻を記録
- session_start のみ（session_finish なし）は「進行中」として扱う

### Step 6: レポート生成

以下の構造でMarkdownを生成する:

```markdown
## 今週の実績サマリ（自動生成）

> 生成日: YYYY-MM-DD | 対象週: GGGG-WXX（MM/DD 〜 MM/DD）

### サマリ
{2-4文の全体俯瞰。プロジェクト別ではなく、ユーザーの1週間の活動全体を評価する。
例: 開発の主軸がどこだったか、新しいワークフローの導入、全体の密度感、特筆すべき変化など}

- **アクティブプロジェクト数**: N/total
- **ソースコミット数**: N
- **コード変更量**: N行
- **Sunsamaタスク完了**: N件（計画 Nh — 仕事 Nh + 個人 Nh）
- **LLMセッション数**: N（Vault: N + ソースリポジトリ: N）
- **harvest セッション**: N件（完了 N + 進行中 N）

---

### [[プロジェクト名]]
**フェーズ**: [[フェーズ名]] — 成果物名 (進捗: N%)

**今週の目標**: {週次ノートの「プロジェクト別の今週の進め方」セクションから「ここまで進めたい:」の内容を転記}

{1-2文のプロジェクト別サマリ。今週このプロジェクトで何が起きたかを簡潔に}

**目標評価**: {目標に対して実際の成果がどうだったかを1-2文で評価。達成/部分達成/未達を明示}

**完了作業** — 計画 Nh / Nコミット / N行変更
- task(N):
	- 親タスク名: サブタスク名 (計画時間)
	- サブタスクなしタスク名 (計画時間)
- feat(N):
	- 機能A
	- 機能B
- fix(N):
	- 修正A
	- 修正B

**Obsidian更新**:
- context/: 変更ファイル名
- phases/: 変更ファイル名

**LLMセッション** (Nセッション):
- [[ログファイル名|表示名]]（Vaultログ）
- セッション要約テキスト（ソースリポジトリ、sessionID: XXXXXXXX）

**harvest** (Nセッション / 計 Nmin):
- slug-a (60min, ✅完了)
- slug-b (進行中)

### レビュー
- {ユーザーが自由入力するための空セクション}

---
（プロジェクトごとに繰り返し。活動がないプロジェクトはスキップ）

### 個人タスク（プロジェクト外）
計画 Nh / Nタスク完了
- タスク名 (計画時間)
- ...
（Sunsamaでプロジェクトに紐付かない個人タスク。ルーチン除外済み）

### 活動なしのプロジェクト
プロジェクトA, プロジェクトB, ...
```

**レポート生成ルール:**
- 活動があったプロジェクトのみ詳細セクションを出力
- 「完了作業」ヘッダー: Sunsamaタスクがあれば `計画 Nh /` を先頭に、なければコミット数から始める
- `task(N)` はSunsamaタスク。feat/fix等のGitコミットと同列に並べる
- Sunsamaタスクもコミットもない場合は「完了作業」サブセクションを省略
- Obsidian更新がない場合はそのサブセクションを省略
- LLMセッションがない場合はそのサブセクションを省略
- harvestセッションがない場合はそのサブセクションを省略
- 全サブセクションが空のプロジェクトは「活動なしのプロジェクト」に列挙
- プロジェクト名・フェーズ名は `[[]]` でwikilink化
- 個人タスクはルーチン除外後に「個人タスク（プロジェクト外）」セクションに集約

### Step 7: 週次ノートへの挿入

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
| harvest jsonl が破損/不正JSON | 該当行をスキップして次の行を処理 |
| harvest session の project マッピング不可 | 「個人タスク」セクションに集約 |
| WORKSPACE_ROOT 未設定 | harvest セッション集計サブセクションを省略しレポート生成は継続（フェイルソフト） |
| ソースリポジトリの ~/.claude/projects ディレクトリが存在しない | そのプロジェクトの LLM セッションサブセクションを省略 |

## 非対話実行モード（`/schedule` cron 対応）

`/schedule` 等の cron 経由で本スキルが非対話コンテキストから起動され、`AskUserQuestion` が使用できない場合は以下のルールで続行する:

- **対象週のデフォルト**: `$ARGUMENTS` が空、かつ AskUserQuestion が使用できない場合はデフォルト対象週「先週」（直近の完了した週）を採用して処理を続行する。質問はスキップする
- **対話依存ステップの代替**: 本スキルは元々 Sunsama/Git/LLM ログの機械集計が中心で対話ステップをほとんど持たないが、`Step 5` の「### レビュー」セクション（ユーザーが自由入力するための空セクション）は非対話時もそのままプレースホルダー（`- {ユーザーが自由入力するための空セクション}`）として出力し、対話で埋めようとしない
- **判断ログ**: 非対話実行によりデフォルト値（先週）を採用した場合、Step 6 で生成する「## 今週の実績サマリ（自動生成）」の冒頭（`> 生成日: ...` 行の直後）に判断ログを1行追記する:
  ```markdown
  > 判断ログ: 非対話実行（cron）のためデフォルト対象週「先週」を採用
  ```
  対話実行時（`$ARGUMENTS` で週が明示された、または AskUserQuestion が利用可能な通常フロー）はこの行を出力しない。既存のエラーハンドリング表と同じ「状況→対応」の粒度で判断内容を残す

## 注意事項

- **テンプレートは変更しない**: `__META/TEMPLATE/02 - WEEKLY Template.md` は読み取り専用
- **既存コンテンツを保持**: 週次ノートの他のセクション（フォーカス、振り返り等）は一切変更しない
- **Vault外のリポジトリにアクセスするため** `cd` を使ったBashコマンドが必要
- **大量コミット対策**: コミットが50件を超える場合はサマリのみ（type別件数）表示
