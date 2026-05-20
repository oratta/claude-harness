---
name: daily-report
description: Fieldyの音声トランスクリプト（Notion DB_FIELDY）と、Obsidian Vault内の編集ノート・LLMログ・Claude Codeセッションjsonlを横断集約し、自然言語ナラティブで日次日記を生成する。「日記作って」「昨日の振り返りを作って」「Fieldyから日記を生成」で起動。`--with-album` フラグ付きで実行すると、diary 生成後に marketing-harness の `vlog-album` スキルを呼び出して diary と同じディレクトリにトイカメラ風 Vlog アルバム画像を出力する。`--force-rebuild` フラグで中間ファイル（voice.md / dailyLLM.md）を含めて再生成する。
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, Skill
---

# Daily Report スキル — 自然言語ナラティブの日次日記（2フェーズ・パイプライン構成）

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

### 3. メイン文脈を汚さない（2フェーズ・パイプライン）

生 transcript と jsonl 本体はサブエージェントに閉じ込め、メインスレッドは中間ファイル（voice.md / dailyLLM.md）と編集ノートだけを参照する。**メインから Notion MCP をロードしない / jsonl 本体を Read しない** を厳守し、コンテキスト消費を最小化する。

## 全体構成（2 フェーズ）

```
Phase 1 (中間ファイル生成 — 並列サブエージェント):
   voice-compactor     -> voice.md
   llm-log-compactor   -> dailyLLM.md
   ↓ 単一メッセージ内で 2 つの Agent tool_use を並列起動
   ↓ STATUS line を集約してパース

Phase 2 (diary 生成 — メイン):
   voice.md + dailyLLM.md + 編集ノート -> diary.md
   ↓ (必要時のみ) 90 - LLM/ ログを部分 Read
   ↓ 90 - LLM/<TARGET_DATE_COMPACT>-*.md にスキル実行ログ
```

## 手順

### Step 0: 引数解釈と対象日決定

`$ARGUMENTS` から **日付（positional）** と **オプション（`--with-album` / `--force-rebuild` / `--cells N` / `--split A:B`）** を分離する。`--with-album` 以外は vlog-album への pass-through、`--force-rebuild` は Phase 1 制御フラグ。

```bash
# 引数を分解（順不同に対応）
WITH_ALBUM=false
FORCE_REBUILD=false
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
    --force-rebuild)
      FORCE_REBUILD=true
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

```bash
VAULT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
DIARY_DIR="$VAULT_ROOT/01 - DAILY/$TARGET_DATE"
mkdir -p "$DIARY_DIR"
VOICE_MD="$DIARY_DIR/voice.md"
DAILY_LLM_MD="$DIARY_DIR/dailyLLM.md"
```

`WITH_ALBUM=true` の場合の追加処理は Step 5（旧 Step 5、Phase 2 末尾）で実行する。`ALBUM_ARGS` が空でも `WITH_ALBUM=false` なら無視される。

---

## Phase 1 — 中間ファイル生成（並列サブエージェント）

### Step 1: 中間ファイル存在チェック

`voice.md` と `dailyLLM.md` の **両方** が既に存在し `--force-rebuild` が無ければ Phase 1 を **スキップ** する:

```bash
if [ -f "$VOICE_MD" ] && [ -f "$DAILY_LLM_MD" ] && [ "$FORCE_REBUILD" != "true" ]; then
  echo "Phase 1 skip: 中間ファイルあり（再生成は --force-rebuild）"
  PHASE1_SKIPPED=true
else
  PHASE1_SKIPPED=false
fi
```

### Step 2: voice-compactor / llm-log-compactor を **並列起動**

`PHASE1_SKIPPED=false` の場合のみ実行。**単一メッセージ内に 2 つの Agent tool_use を並べて並列起動する**（順次起動は禁止）。

メインは以下の 2 つの Agent を **同じ assistant message に並べて** 同時起動する:

1. `Agent: voice-compactor`
   - 引数本文に `TARGET_DATE`, `NEXT_DATE`, `VAULT_ROOT`, `OUTPUT_PATH=$VOICE_MD` を含める
   - 役割: Fieldy DB から transcript を fetch して圧縮、`$VOICE_MD` に Write
2. `Agent: llm-log-compactor`
   - 引数本文に `TARGET_DATE`, `NEXT_DATE`, `VAULT_ROOT`, `OUTPUT_PATH=$DAILY_LLM_MD` を含める
   - 役割: `~/.claude/projects/*/` の jsonl から指示・最終出力・メタ統計を集計、`$DAILY_LLM_MD` に Write

両 Agent は最終 assistant message として **STATUS line 1 行のみ** を返却する。本文要約・件数詳細・抜粋は voice.md / dailyLLM.md に書かれており、メインの context には乗らない。

### Step 3: STATUS line の集約とエラー処理

両 Agent の STATUS line をパース（正規表現 `^STATUS: (ok|partial|fail)\b`）して分岐する:

| Agent | STATUS | 振る舞い |
|-------|--------|----------|
| voice-compactor | `ok` | そのまま Phase 2 へ |
| voice-compactor | `partial` | 警告ログを出して Phase 2 へ（未取得時間帯は voice.md に `- (未取得: token-limit)` 記載済み） |
| voice-compactor | `fail reason=notion-mcp-unavailable` | **既存挙動を継承**: voice.md なしで dailyLLM.md + 編集ノートのみで Phase 2 継続。diary 冒頭に「音声記録なし」と明記する |
| voice-compactor | その他の `fail` | フェーズ単位で中断、ユーザーへ報告 |
| llm-log-compactor | `ok` / `partial` | Phase 2 へ（`partial` は警告） |
| llm-log-compactor | `fail` | フェーズ単位で中断、ユーザーへ報告（jsonl は LLM ログ index 不在では diary 品質が大きく落ちるため） |

正規表現の参考:

```bash
# fail reason 抽出
reason=$(echo "$line" | sed -nE 's/^STATUS: fail reason=([a-z0-9-]+).*/\1/p')
# voice の特例フォールバック
if [ "$reason" = "notion-mcp-unavailable" ]; then
  VOICE_AVAILABLE=false
else
  # 他の fail は中断
  ...
fi
```

### Step 4: Phase 1 完了直後の sanity check（冒頭 40 行 Read）

メインは voice.md / dailyLLM.md の **冒頭 40 行だけを Read** して frontmatter + 最初の数セクションが妥当か確認する（本文全体は読まない）。

```bash
# 行数だけ wc で確認
voice_lines=$(wc -l < "$VOICE_MD" 2>/dev/null || echo 0)
llm_lines=$(wc -l < "$DAILY_LLM_MD" 2>/dev/null || echo 0)

# < 50 行なら警告（明らかに空・極端に短い）
if [ "$voice_lines" -lt 50 ] && [ "$VOICE_AVAILABLE" = "true" ]; then
  echo "WARNING: voice.md が $voice_lines 行（< 50 行）。--force-rebuild を検討してください。"
fi
if [ "$llm_lines" -lt 50 ]; then
  echo "WARNING: dailyLLM.md が $llm_lines 行（< 50 行）。--force-rebuild を検討してください。"
fi
```

行数チェックを通った後、冒頭 40 行だけ `Read(limit=40)` で確認する。本文全体は Read しない（コンテキスト効率維持）。

---

## Phase 2 — diary 生成（メインスレッド）

### Step 5: obsidian-markdown スキルをロード

```
Skill: obsidian:obsidian-markdown
```

frontmatter, callouts, wikilinks の表記規約を確認する。

### Step 6: 中間ファイルと編集ノートを入力に diary を生成

#### 6a. 編集ノートの収集

```bash
NEXT_DATETIME="${NEXT_DATE} 00:00"
find "$VAULT_ROOT" -name "*.md" \
  -newermt "${TARGET_DATE} 00:00" ! -newermt "$NEXT_DATETIME" \
  -not -path "*/.git/*" -not -path "*/.obsidian/*" \
  -not -path "*/01 - DAILY/*" -not -path "*/02 - PERIODIC/*" -not -path "*/90 - LLM/*" \
  -not -path "*/LLM/*" 2>/dev/null
```

ファイル数が 10 以下なら全部 Read。多い場合は head -30 だけ抽出して概要把握、本文を引用したいものだけ Read。

#### 6b. dailyLLM.md の `**参照**:` wikilink 補完（必要時のみ）

dailyLLM.md の各セッションエントリには `**参照**: [[90 - LLM/<filename>|...]] · <jsonl-path>` 形式の wikilink がある。**ナラティブで深堀りしたいセッションに限り**、対応する `90 - LLM/<filename>.md` をメインが Read で補完する。

> [!warning] 禁止
> **全セッションを Read してはならない**。コンテキスト効率維持のため、深堀り対象は最大 3〜5 セッションに留める。

#### 6c. 物語の骨格を作る

中間ファイル（voice.md / dailyLLM.md）+ 編集ノートを元に、時系列で **朝/午前/昼/午後/夕方/夜** のスロットに振り分ける:

- 朝の小ハマり（dailyLLM.md 朝イチのセッション）
- 午前〜午後の作業（dailyLLM.md の指示から "何のロングランが走っていたか" を逆引き、voice.md と突き合わせる）
- 環境トラブル（dailyLLM.md および編集ノートから拾う）
- Vault 側の編集（編集ノートから "どのプロジェクトの何を進めたか"）
- 昼の予定電話・買い物（voice.md）
- 夜の食事・飲み（voice.md）
- 帰路の出来事（voice.md）

**voice.md で語っていた抽象的な話を、dailyLLM.md の具体実装と突き合わせて "あれはこの作業だった" と紐付ける** のが、このスキルの肝。

### Step 7: 日記本文を書く

#### 7a. ファイル配置

```
$VAULT_ROOT/01 - DAILY/<TARGET_DATE>/diary.md
```

`01 - DAILY/<TARGET_DATE>/` ディレクトリが無ければ作る。同名ファイルが既にある場合は `diary-v2.md` 等の suffix を付けて衝突回避（既存日記を上書きしない）。

#### 7b. 構造テンプレート

```markdown
---
created: <生成ISO timestamp>
type: daily-diary
date: <TARGET_DATE>
source:
  - "[[voice|<TARGET_DATE> Voice Log]]"
  - "[[dailyLLM|<TARGET_DATE> LLM Log Index]]"
  - "Obsidian-edited notes (<TARGET_DATE>)"
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

#### 7c. ナラティブのトーン

- **語り口**: 「〜と気づいた」「腑に落ちた」「結論としては」「整理がついた」
- **段落構成**: 1セクションあたり 2〜4 段落、各段落は 3〜6 行
- **表は最小限**: 数値の比較（前後の Load avg 等）には使ってよい。change 一覧、ファイル一覧は段落で書く
- **wikilinks**: 技術用語・人物・場所は `[[]]` で囲む（プロジェクト名、ライブラリ、店名、サッカーチーム等）
- **callout**: `> [!quote]` で印象的な発言を引用、`> [!todo]` で翌日アクション、`> [!warning]` で当日露呈した問題
- **コードブロック**: コマンド・コミット hash・change 名は inline backtick で十分。長いブロックは避ける

#### 7d. 必須セクション

末尾には必ず以下を入れる:

```markdown
## 自分用メモ

> [!quote] 印象的だったセリフ
> <voice.md から拾った1〜2文>

> [!todo] 翌日以降のアクション
> - [ ] <dailyLLM.md やLLMログから読み取れる未完了タスク>
> - [ ] <voice.mdで言及された予定>
> - [ ] <Vault編集ノートに残っていた TODO>

## 関連

- [[voice|<TARGET_DATE> Voice Log]]
- [[dailyLLM|<TARGET_DATE> LLM Log Index]]
- [[LLM/<関連ログ>]]
- <その他関連ノート>
```

#### 7e. 未取得時間帯の取り扱い

voice.md / dailyLLM.md に `(未取得)` セクションがある場合、diary.md でも対応時間帯を「未取得」と明記する。**推測補完禁止**（既存原則を継承）。

### Step 8: セッションログを残す（既存 Step 4 を維持）

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

- voice.md (Phase 1 voice-compactor 生成, <件数>ページ取得, <未取得件数>ページがトークン上限超で未取得)
- dailyLLM.md (Phase 1 llm-log-compactor 生成, <セッション数>セッション)
- <vault edited notes>

# 作成したファイル

- 作成: [[01 - DAILY/<TARGET_DATE>/diary|<TARGET_DATE> Daily Diary]]
- 作成: [[01 - DAILY/<TARGET_DATE>/voice|<TARGET_DATE> Voice Log]]
- 作成: [[01 - DAILY/<TARGET_DATE>/dailyLLM|<TARGET_DATE> LLM Log Index]]
- 作成: 本ログ
```

### Step 9: `--with-album` 指定時のみ — Vlog アルバム生成

Step 0 で `WITH_ALBUM=true` だった場合のみ実行する。`WITH_ALBUM=false` ならこの Step をスキップして Step 10 へ。

このスキルは **marketing-harness の `vlog-album` スキル** に diary パスを渡してアルバム画像を生成し、生成物を **diary.md と同じディレクトリ** に配置する。

#### 9a. vlog-album スキルを呼び出す

`vlog-album` スキルの description には「Triggered ONLY by /vlog-album slash command」というガードがあるが、これは **自然言語の auto-trigger を防ぐためのガード** であり、`--with-album` フラグでユーザーが明示的にオプトインした本ケースでは Skill ツール経由での明示的な呼び出しが許容される。

Skill ツールで呼び出す:

```
Skill: vlog-album
args: "<DIARY_ABS_PATH>${ALBUM_ARGS}"
```

- `DIARY_ABS_PATH` は Step 7a で書き出した diary の絶対パス（`$VAULT_ROOT/01 - DAILY/<TARGET_DATE>/diary.md` もしくは衝突回避で suffix が付いた版）。
- `ALBUM_ARGS` は Step 0 で組み立てた `--cells N` / `--split A:B` の pass-through 文字列（空でも可）。

vlog-album は cwd 配下に `output/<TARGET_DATE>-vlog/album.png` と `output/<TARGET_DATE>-vlog/prompt.md` を生成する。**cwd は本スキル実行時のディレクトリ**（通常は Vault root）になることに留意。

> [!warning] codex CLI セットアップ不全時
> vlog-album が codex CLI 未セットアップで失敗した場合、本スキルの責務外なので、エラーをそのままユーザーに伝えて Step 10 に進む（diary 自体は完成しているので報告で握り潰さない）。

#### 9b. 生成物を diary と同じディレクトリへ移動

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
  echo "WARNING: vlog-album が album.png を生成しなかった。Step 10 で報告に含める。"
fi
```

#### 9c. Step 8 のセッションログに追記

Step 8 で書いた `90 - LLM/` のログに、アルバム生成の事実を追記する:

```markdown
# 作成したファイル（追記）

- 作成: [[01 - DAILY/<TARGET_DATE>/album.png|<TARGET_DATE> Vlog Album]]
- 参考: <DIARY_DIR>/album-prompt.md（vlog-album が使った最終プロンプト）
```

### Step 10: 結果報告

ユーザーに以下を伝える:

- 日記の保存先パス（および voice.md / dailyLLM.md の同居パス）
- Phase 1 が実行されたかスキップされたか（`PHASE1_SKIPPED` 参照）
- 取得できた情報源の件数（voice.md の pages_fetched / pages_missing、dailyLLM.md の sessions 数、編集ノート何件）
- 推測補完できなかった時間帯（音声未取得など）
- 日記の総文字数の目安
- **`--with-album` 指定時のみ**: アルバム画像のパス（`<DIARY_DIR>/album.png`）、セル数 / グリッド / 配分、保存済み `album-prompt.md` のパス。vlog-album が失敗した場合はその旨と diary 自体は完成している事実を併せて報告

---

# DEPRECATED: removed in change-5

以下の旧経路コードは **change-4 では一時的に残置** され、**change-5 で完全削除** される。
メインスレッドから Notion MCP をロードする経路 / jsonl 本体を直接 Read する経路は新パイプラインでは使用しない。
新経路は Phase 1（サブエージェント）が中間ファイルに圧縮し、Phase 2 はそれを Read するのみ。

旧 Step 1a (Notion MCP load) / 旧 Step 1d (jsonl head -5 Read) は本ファイルから削除済み。
本ブロックは change-5 完了時に「以下旧経路は完全に削除されました」を明示するためのアンカーとして残し、change-5 commit で本ブロック自体も削除する。

---

## 注意事項（試行錯誤から得た教訓）

> [!warning] やってはいけない
> 1. **change 名や slug の羅列を表にする** — カタログ化して読まれない（v2 で失敗済）
> 2. **音声がない時間帯を推測で埋める** — 信頼性を失う、「未取得」と明記
> 3. **メインから jsonl の本文を Read する** — コンテキストパンク、必ず llm-log-compactor サブエージェントに閉じる
> 4. **メインから Notion MCP をロードする** — voice-compactor サブエージェントに閉じる、メインは voice.md だけ Read
> 5. **Phase 1 を順次起動する** — 必ず単一メッセージ内に 2 つの Agent tool_use を並べて並列起動する
> 6. **既存の diary.md を黙って上書きする** — 必ず suffix 付与で衝突回避
> 7. **`--with-album` 指定時に vlog-album 失敗を握り潰す** — diary 本体は完成しているので、必ず Step 10 で「diary は OK / album は失敗」を別個に報告する
> 8. **`--with-album` なしで `--cells` / `--split` を渡されたまま album 生成に走る** — Step 0 で `WITH_ALBUM=false` なら ALBUM_ARGS は完全に無視（誤指定の旨を Step 10 で軽く触れる程度に留める）
> 9. **dailyLLM.md の `**参照**:` 全セッションをメインで Read する** — 深堀り対象 3〜5 セッションに限る

> [!tip] うまくいくコツ
> - サブエージェント並列起動は **単一の assistant message に 2 つの Agent tool_use を並べる**
> - voice-compactor の `fail reason=notion-mcp-unavailable` だけは Phase 2 継続のフォールバックとして特別扱い
> - jsonl は worktree 横断で見る（`~/.superset/worktrees/*` 系も対象に） — これは llm-log-compactor 側で処理される
> - voice.md で抽象的に語っていた内容を dailyLLM.md の change 名で具体化すると、読み物として一段深くなる
> - 夜の飲み会パートは voice.md が強い領域なので、音声のニュアンスを残して書く
> - 朝〜午後の画面作業パートは voice.md が弱い領域なので、dailyLLM.md + 編集ノートで補う

## 出力例

実際の出力例: `01 - DAILY/2026-05-13/diary.md`（v3 として採用された版）。

このスキルはその v3 を蒸留して作られているので、生成物の参考にするとよい。

## Source

蒸留元 jsonl: `~/.claude/projects/-Users-oratta-Dropbox-Application-Obsidian-oratta2025/82b8ae4c-c934-422a-8133-63ab00d90d58.jsonl`
蒸留日時: 2026-05-14
2フェーズ・パイプライン化: 2026-05-20 (change-1〜5)
