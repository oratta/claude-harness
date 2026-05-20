---
name: daily-report
description: Fieldyの音声トランスクリプト（Notion DB_FIELDY）と、Obsidian Vault内の編集ノート・LLMログ・Claude Codeセッションjsonlを横断集約し、自然言語ナラティブで日次日記を生成する。「日記作って」「昨日の振り返りを作って」「Fieldyから日記を生成」で起動。`--with-album` フラグ付きで実行すると、diary 生成後に marketing-harness の `vlog-album` スキルを呼び出して diary と同じディレクトリにトイカメラ風 Vlog アルバム画像を出力する。
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, ToolSearch, Skill
---

# Daily Report スキル — 自然言語ナラティブの日次日記

## このスキルを起動する条件

- 「昨日の日記を作って」「日記を生成して」「<日付>の日記を作って」と依頼された
- Fieldy（ボイスレコーダー）の音声記録と、画面側（コーディング・調査・ノート編集）の両方を統合した1日の振り返りが欲しい
- Sunsama や週次レポートのように **構造化された機械的レポート** ではなく、**ナラティブな読み物としての日記** が欲しい

## このスキルの設計思想（最重要）

このスキルが生まれた経緯から得られた **3 つの原則**。手順より先にこれを内面化すること。

### 1. ナラティブ > カタログ

過去に同じ素材で 2 種類書いた:
- **v1**: 音声のみで自然言語ナラティブ → 読みやすいが画面側の作業が抜けている
- **v2**: 全情報源 + 表多用でカタログ化 → 情報密度は高いが読む気が起きない
- **v3 (採用)**: v2 の情報量を v1 のトーンで語り直し → 採用

**表は最小限。** change 名・slug・commit hash の羅列は読みづらい。「〇〇に気づいた」「腑に落ちた」「結論」のような語り口で、**読み物として腹落ちする** ことを優先する。

### 2. 推測補完しない

取得に失敗した時間帯・セグメントは「未取得」と明記する。**音声がない時間帯を「おそらく〜」で埋めない**。事実と空白を区別する誠実さがこの日記の信頼性を支える。

### 3. jsonl は最初の userメッセージだけ読む

Claude Code のセッション jsonl は数MB〜数十MB あり、全文読むとコンテキストがパンクする。**最初の user メッセージ抜粋（300字程度）だけで、そのセッションが何をやろうとしていたか** はほぼ分かる。詳細は Fieldy 音声・LLMログ・編集ノートで補う。

## 手順

### Step 0: 引数解釈と対象日決定

`$ARGUMENTS` から **日付（positional）** と **オプション（`--with-album` / `--cells N` / `--split A:B`）** を分離する。`--with-album` 以外のオプションは vlog-album への pass-through。

```bash
# 引数を分解（順不同に対応）
WITH_ALBUM=false
ALBUM_ARGS=""
TARGET_DATE=""

# $ARGUMENTS をスペース区切りでパース
set -- $ARGUMENTS
while [ $# -gt 0 ]; do
  case "$1" in
    --with-album)
      WITH_ALBUM=true
      shift
      ;;
    --cells)
      ALBUM_ARGS="$ALBUM_ARGS --cells $2"
      shift 2
      ;;
    --split)
      ALBUM_ARGS="$ALBUM_ARGS --split $2"
      shift 2
      ;;
    *)
      if [ -z "$TARGET_DATE" ]; then
        TARGET_DATE="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$TARGET_DATE" ] || [ "$TARGET_DATE" = "yesterday" ]; then
  TARGET_DATE=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d "yesterday" +%Y-%m-%d)
fi
# 派生
TARGET_DATE_COMPACT=$(echo "$TARGET_DATE" | tr -d '-')  # YYYYMMDD
NEXT_DATE=$(date -j -v+1d -f %Y-%m-%d "$TARGET_DATE" +%Y-%m-%d 2>/dev/null \
  || date -d "$TARGET_DATE + 1 day" +%Y-%m-%d)
```

Vault root を `git rev-parse --show-toplevel` で取得。Vault が git 管理されていない場合は cwd を Vault root と仮定し、ユーザーに警告。

`WITH_ALBUM=true` の場合の追加処理は Step 5 で実行する（diary 生成完了後）。`ALBUM_ARGS` が空でも `WITH_ALBUM=false` なら無視される（誤指定時はユーザーに警告するのみ）。

### Step 1: 情報源を集める（並列）

1a〜1d は独立しているので、可能な限り並列で投げる。

#### 1a. Fieldy 音声トランスクリプト（Notion）

Notion MCP のツールはデフォルトで未ロード。**必ず ToolSearch でロードしてから使う**:

```
ToolSearch(query="select:mcp__claude_ai_Notion__notion-search,mcp__claude_ai_Notion__notion-fetch", max_results=2)
```

その後の流れ:

1. `notion-search` で `DB_FIELDY` を query="DB_FIELDY" / filters={} / page_size=5 で検索 → database id を取得
2. `notion-fetch` で database id を fetch → `<data-source url="collection://...">` を抜き出す
3. `notion-search` を再度呼ぶ。`data_source_url=collection://...`, `filters.created_date_range={start_date: TARGET_DATE, end_date: NEXT_DATE}`, page_size=25, max_highlight_length=0 でページ一覧を取得
4. 取得したページ ID 群を、`notion-fetch(include_transcript=true)` で **5 並列ずつ** 取得（同時5ツール呼び出し）
5. **トークン上限エラー（~50K characters 超）が返ったページは "未取得" として記録**。`Error: result (NNN characters) exceeds maximum allowed tokens` の場合、そのページのファイルは Read で取れるが、本日記の趣旨上は無理に読まず注釈で「20:00–20:59 はトークン上限で未取得」と明記する

> [!warning] DB_FIELDY が無い / Notion MCP 未接続の場合
> 1a を完全にスキップして、1b〜1d だけで進める。日記冒頭に「音声記録なし」と明記。

#### 1b. Vault の LLM ログ

```bash
VAULT_ROOT="<取得済み>"
ls "$VAULT_ROOT/90 - LLM/" | grep "^$TARGET_DATE_COMPACT"
# 例: 20260513-Wikiリンク自動ディレクトリ設定.md
# あれば全文 Read。複数あれば全部読む
```

加えて、Vault 内に **タイムスタンプ命名 + ハッシュ** 形式のログがある場合があるので、そちらも探す:

```bash
find "$VAULT_ROOT/LLM" -name "${TARGET_DATE}_*.md" 2>/dev/null
# 例: LLM/2026-05-13_0a7f36bd.md
```

プロジェクト別 LLM/ にも対象日のログがあれば取り込む:

```bash
find "$VAULT_ROOT/12 - PROJECT" -path "*/LLM/${TARGET_DATE}*" -name "*.md" 2>/dev/null
find "$VAULT_ROOT/12 - PROJECT" -path "*/LLM/${TARGET_DATE_COMPACT}*" -name "*.md" 2>/dev/null
```

#### 1c. Vault の編集ノート

```bash
NEXT_DATETIME="${NEXT_DATE} 00:00"
find "$VAULT_ROOT" -name "*.md" \
  -newermt "${TARGET_DATE} 00:00" ! -newermt "$NEXT_DATETIME" \
  -not -path "*/.git/*" -not -path "*/.obsidian/*" \
  -not -path "*/01 - DAILY/*" -not -path "*/02 - PERIODIC/*" -not -path "*/90 - LLM/*" \
  -not -path "*/LLM/*" 2>/dev/null
```

ファイル数が 10 以下なら全部 Read。多い場合は head -30 だけ抽出して概要把握、本文を引用したいものだけ Read。

#### 1d. Claude Code セッション jsonl の概要

cwd が Vault root の場合、jsonl ディレクトリは:

```bash
ENCODED_CWD=$(echo "$VAULT_ROOT" | sed 's|/|-|g')
JSONL_DIR="$HOME/.claude/projects/$ENCODED_CWD"
```

しかし、**並行作業（worktree）も同じ日に走っていることが多い**ので、`~/.claude/projects/` 配下を横断検索:

```bash
find ~/.claude/projects -maxdepth 1 -type d | while read d; do
  count=$(find "$d" -name "*.jsonl" \
    -newermt "${TARGET_DATE} 00:00" ! -newermt "$NEXT_DATETIME" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$count" -gt 0 ]; then
    echo "$count $(basename $d)"
  fi
done
```

セッション数が多い（10超）ディレクトリだけ深掘りする。各 jsonl の最初の user メッセージを抽出:

```bash
for f in $(find "$dir" -name "*.jsonl" \
  -newermt "${TARGET_DATE} 00:00" ! -newermt "$NEXT_DATETIME"); do
  head -5 "$f" | python3 -c "
import json,sys
for line in sys.stdin:
    try:
        d = json.loads(line)
        if d.get('type') == 'user' and d.get('message',{}).get('role') == 'user':
            content = d['message'].get('content','')
            if isinstance(content, list):
                content = next((c.get('text','') for c in content
                              if isinstance(c,dict) and c.get('type')=='text'), '')
            print('FIRST_USER:', str(content)[:300].replace(chr(10),' '))
            break
    except: pass
" 2>/dev/null
done
```

**重要**: ここで取れる「最初のユーザーメッセージ」だけで、そのセッションが何の change / どの worktree / どのフェーズだったか判別できる。原則として **jsonl 本体は読まない**。

### Step 2: 統合の前段準備

#### 2a. obsidian-markdown スキルをロード

```
Skill: obsidian:obsidian-markdown
```

frontmatter, callouts, wikilinks の表記規約を確認する。

#### 2b. 物語の骨格を作る

集めた情報を時系列で並べ、**朝/午前/昼/午後/夕方/夜** のスロットに振り分ける:

- 朝の小ハマり（LLMログ・jsonl 朝イチの会話）
- 午前〜午後の作業（jsonl の userメッセージから "何のロングランが走っていたか" を逆引き、Fieldy 音声と突き合わせる）
- 環境トラブル（PC 暴走など、LLMログから拾う）
- Vault 側の編集（編集ノートから "どのプロジェクトの何を進めたか"）
- 昼の予定電話・買い物（Fieldy 音声）
- 夜の食事・飲み（Fieldy 音声）
- 帰路の出来事（Fieldy 音声）

**Fieldy で語っていた抽象的な話を、jsonl の具体実装と突き合わせて "あれはこの作業だった" と紐付ける** のが、このスキルの肝。例:

- Fieldy 「結果論プロンプトを skill 化したい」 ↔ jsonl `final-prompts-synthesis` sub-agent
- Fieldy 「ワークツリー単位で from-worktree を作りたい」 ↔ jsonl `add-cooking-from-worktree` capability
- Fieldy 「Codex に実装エージェントだけ渡してみた」 ↔ jsonl `codex-build-agent-poc` change

### Step 3: 日記本文を書く（ここが本番）

#### 3a. ファイル配置

```
$VAULT_ROOT/01 - DAILY/<TARGET_DATE>/diary.md
```

`01 - DAILY/<TARGET_DATE>/` ディレクトリが無ければ作る。同名ファイルが既にある場合は `diary-v2.md` 等の suffix を付けて衝突回避（既存日記を上書きしない）。

#### 3b. 構造テンプレート

```markdown
---
created: <生成ISO timestamp>
type: daily-diary
date: <TARGET_DATE>
source:
  - Fieldy / DB_FIELDY
  - "90 - LLM/ + project LLM logs"
  - Claude Code session jsonl (`~/.claude/projects/`)
  - Obsidian-edited notes (<TARGET_DATE>)
tags:
  - diary
  - fieldy
cssclasses:
  - wide
---

# Diary: <TARGET_DATE>（<曜日>）

## ひとことで

<1〜2文で1日を要約。出来事ベース、エモいまとめは不要>

## <時間帯ごとのセクション>

<以下、自然言語ナラティブで時系列に書く>
```

#### 3c. ナラティブのトーン

- **語り口**: 「〜と気づいた」「腑に落ちた」「結論としては」「整理がついた」
- **段落構成**: 1セクションあたり 2〜4 段落、各段落は 3〜6 行
- **表は最小限**: 数値の比較（前後の Load avg 等）には使ってよい。change 一覧、ファイル一覧は段落で書く
- **wikilinks**: 技術用語・人物・場所は `[[]]` で囲む（プロジェクト名、ライブラリ、店名、サッカーチーム等）
- **callout**: `> [!quote]` で印象的な発言を引用、`> [!todo]` で翌日アクション、`> [!warning]` で当日露呈した問題
- **コードブロック**: コマンド・コミット hash・change 名は inline backtick で十分。長いブロックは避ける

#### 3d. 必須セクション

末尾には必ず以下を入れる:

```markdown
## 自分用メモ

> [!quote] 印象的だったセリフ
> <Fieldy 音声から拾った1〜2文>

> [!todo] 翌日以降のアクション
> - [ ] <jsonl やLLMログから読み取れる未完了タスク>
> - [ ] <Fieldyで言及された予定>
> - [ ] <Vault編集ノートに残っていた TODO>

## 関連

- [[LLM/<関連ログ>]]
- [[2026-XX-XX/report|XX月XX日 Daily Report]] — 機械集約版（あれば）
- <その他関連ノート>
```

### Step 4: セッションログを残す

`90 - LLM/<TARGET_DATE_COMPACT_TODAY>-<タイトル>.md` に、本スキル実行のログを記録する。Vault の basic.md ルールに従う:

```markdown
---
created: <ISO timestamp>
type: llm-log
tags:
  - daily-report
  - fieldy
  - diary
---

# ユーザー依頼

[日時: ...]

> /daily-report <TARGET_DATE>

# 参照した情報

- DB_FIELDY (<件数>ページ取得, <未取得件数>ページがトークン上限超で未取得)
- <vault LLM logs>
- <vault edited notes>
- Claude Code sessions: <jsonl ディレクトリ別の件数>

# 作成したファイル

- 作成: [[01 - DAILY/<TARGET_DATE>/diary|<TARGET_DATE> Daily Diary]]
- 作成: 本ログ
```

### Step 5: `--with-album` 指定時のみ — Vlog アルバム生成

Step 0 で `WITH_ALBUM=true` だった場合のみ実行する。`WITH_ALBUM=false` ならこの Step をスキップして Step 6 へ。

このスキルは **marketing-harness の `vlog-album` スキル** に diary パスを渡してアルバム画像を生成し、生成物を **diary.md と同じディレクトリ** に配置する。

#### 5a. vlog-album スキルを呼び出す

`vlog-album` スキルの description には「Triggered ONLY by /vlog-album slash command」というガードがあるが、これは **自然言語の auto-trigger を防ぐためのガード** であり、`--with-album` フラグでユーザーが明示的にオプトインした本ケースでは Skill ツール経由での明示的な呼び出しが許容される。

Skill ツールで呼び出す:

```
Skill: vlog-album
args: "<DIARY_ABS_PATH>${ALBUM_ARGS}"
```

- `DIARY_ABS_PATH` は Step 3a で書き出した diary の絶対パス（`$VAULT_ROOT/01 - DAILY/<TARGET_DATE>/diary.md` もしくは衝突回避で suffix が付いた版）。
- `ALBUM_ARGS` は Step 0 で組み立てた `--cells N` / `--split A:B` の pass-through 文字列（空でも可）。

vlog-album は cwd 配下に `output/<TARGET_DATE>-vlog/album.png` と `output/<TARGET_DATE>-vlog/prompt.md` を生成する。**cwd は本スキル実行時のディレクトリ**（通常は Vault root）になることに留意。

> [!warning] codex CLI セットアップ不全時
> vlog-album が codex CLI 未セットアップで失敗した場合、本スキルの責務外なので、エラーをそのままユーザーに伝えて Step 6 に進む（diary 自体は完成しているので報告で握り潰さない）。

#### 5b. 生成物を diary と同じディレクトリへ移動

```bash
DIARY_DIR="$VAULT_ROOT/01 - DAILY/$TARGET_DATE"
ALBUM_SRC_DIR="$(pwd)/output/${TARGET_DATE}-vlog"

if [ -f "$ALBUM_SRC_DIR/album.png" ]; then
  # 衝突回避: 既存ファイルがあれば suffix
  ALBUM_DST="$DIARY_DIR/album.png"
  if [ -f "$ALBUM_DST" ]; then
    n=2
    while [ -f "$DIARY_DIR/album-v${n}.png" ]; do n=$((n+1)); done
    ALBUM_DST="$DIARY_DIR/album-v${n}.png"
    PROMPT_DST="$DIARY_DIR/album-v${n}-prompt.md"
  else
    PROMPT_DST="$DIARY_DIR/album-prompt.md"
  fi

  mv "$ALBUM_SRC_DIR/album.png" "$ALBUM_DST"
  # prompt.md は再生成・微調整用に残す（任意。無ければ無視）
  if [ -f "$ALBUM_SRC_DIR/prompt.md" ]; then
    mv "$ALBUM_SRC_DIR/prompt.md" "$PROMPT_DST"
  fi
  # 空になった一時ディレクトリを掃除（codex.log は残しておく方が debug 用に便利）
  rmdir "$ALBUM_SRC_DIR" 2>/dev/null || true
else
  echo "WARNING: vlog-album が album.png を生成しなかった。Step 6 で報告に含める。"
fi
```

#### 5c. Step 4 のセッションログに追記

Step 4 で書いた `90 - LLM/` のログに、アルバム生成の事実を追記する:

```markdown
# 作成したファイル（追記）

- 作成: [[01 - DAILY/<TARGET_DATE>/album.png|<TARGET_DATE> Vlog Album]]
- 参考: <DIARY_DIR>/album-prompt.md（vlog-album が使った最終プロンプト）
```

### Step 6: 結果報告

ユーザーに以下を伝える:

- 日記の保存先パス
- 取得できた情報源の件数（Fieldy何ページ、未取得何ページ、jsonl 何セッション、編集ノート何件）
- 推測補完できなかった時間帯（音声未取得など）
- 日記の総文字数の目安
- **`--with-album` 指定時のみ**: アルバム画像のパス（`<DIARY_DIR>/album.png`）、セル数 / グリッド / 配分、保存済み `album-prompt.md` のパス。vlog-album が失敗した場合はその旨と diary 自体は完成している事実を併せて報告

## 注意事項（試行錯誤から得た教訓）

> [!warning] やってはいけない
> 1. **change 名や slug の羅列を表にする** — カタログ化して読まれない（v2 で失敗済）
> 2. **音声がない時間帯を推測で埋める** — 信頼性を失う、「未取得」と明記
> 3. **jsonl の本文を全文読む** — コンテキストパンク、最初の user メッセージで十分
> 4. **Notion MCP をロードせずに呼ぶ** — `InputValidationError` で全プロセスが詰まる
> 5. **`mcp__claude_ai_Notion__notion-fetch` を 10 並列以上で投げる** — トークン上限の累積で1つでも巨大ページが混じると全体失敗
> 6. **既存の diary.md を黙って上書きする** — 必ず suffix 付与で衝突回避
> 7. **`--with-album` 指定時に vlog-album 失敗を握り潰す** — diary 本体は完成しているので、必ず Step 6 で「diary は OK / album は失敗」を別個に報告する
> 8. **`--with-album` なしで `--cells` / `--split` を渡されたまま album 生成に走る** — Step 0 で `WITH_ALBUM=false` なら ALBUM_ARGS は完全に無視（誤指定の旨を Step 6 で軽く触れる程度に留める）

> [!tip] うまくいくコツ
> - notion-fetch は **5 並列まで**
> - jsonl は worktree 横断で見る（`~/.superset/worktrees/*` 系も対象に）
> - Fieldy で抽象的に語っていた内容を jsonl の change 名で具体化すると、読み物として一段深くなる
> - 夜の飲み会パートは Fieldy が強い領域なので、音声のニュアンスを残して書く
> - 朝〜午後の画面作業パートは Fieldy が弱い領域なので、LLMログ・jsonl・編集ノートで補う

## 出力例

実際の出力例: `01 - DAILY/2026-05-13/diary.md`（v3 として採用された版）。

このスキルはその v3 を蒸留して作られているので、生成物の参考にするとよい。

## Source

蒸留元 jsonl: `~/.claude/projects/-Users-oratta-Dropbox-Application-Obsidian-oratta2025/82b8ae4c-c934-422a-8133-63ab00d90d58.jsonl`
蒸留日時: 2026-05-14
蒸留コマンド: `/e2s:distill ここでのやったことをもとに、oratta/claude-harnessにdaily-reportスキルを作成してほしい。`
