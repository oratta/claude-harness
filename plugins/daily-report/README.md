# Daily Report Plugin

Fieldy（ボイスレコーダー）の音声トランスクリプトと、Obsidian Vault・LLMログ・Claude Codeセッションを横断集約して、**自然言語ナラティブの日次日記**を生成する Claude Code プラグイン。

## このプラグインが解くもの

1日を振り返るとき、情報源は複数ある:

- **Fieldy** に録音された音声（独り言・会話・電話）
- **Vault の編集ノート**（プロジェクトの context 更新、リサーチノート）
- **Vault の LLM ログ**（Claude Code との対話の保存）
- **Claude Code のセッション jsonl**（worktree 単位の作業履歴）

これらを 1 つずつ手で読むのは現実的でないが、機械的に要約しても読み物にならない。`weekly-report` の縦集約とは別で、**読み物として腹落ちする日記** を作ることが本プラグインの目的。

## weekly-report との違い

| | weekly-report | daily-report |
|---|---|---|
| 粒度 | 週次 | 日次 |
| 情報源 | Git + Sunsama + LLM logs + Phase | Fieldy + LLM logs + 編集ノート + Claude Code jsonl |
| 出力 | 機械集約レポート（表中心） | 自然言語ナラティブ（段落中心） |
| 音声 | なし | Fieldy / Notion DB_FIELDY |

## 前提条件

### 必須

- Obsidian Vault が手元にあり、git 管理されている
- 以下のディレクトリ構造（[Vault basic ルール](https://github.com/oratta) 準拠）:
  ```
  vault/
  ├── 01 - DAILY/<YYYY-MM-DD>/diary.md   # 出力先
  ├── 90 - LLM/<YYYYMMDD>-*.md                    # 任意、あれば取り込む
  ├── LLM/<YYYY-MM-DD>_<hash>.md                  # 任意、あれば取り込む
  ├── 12 - PROJECT/.../LLM/*.md                   # 任意
  └── (各種編集ノート)
  ```

### 推奨

- **Fieldy** + **Notion `DB_FIELDY`** データベース（1 時間単位の音声トランスクリプト）
  - 無くてもプラグインは動くが、Fieldy 由来のセグメントが空になる
- **Claude Code MCP** で Notion 接続済み
  - 接続未完了の場合は手動 markdown export からの読み込みに切り替える必要がある（未実装）

## 使い方

```bash
/daily-report                                   # 昨日の日記を生成
/daily-report 2026-05-13                        # 指定日の日記を生成
/daily-report yesterday                         # 明示的に「昨日」
/daily-report --with-album                      # 昨日の日記 + Vlog アルバム
/daily-report 2026-05-13 --with-album --cells 16 --split 10:6
                                                # 指定日 + 4×4 アルバム + 配分
```

出力先:

- 日記: `<vault>/01 - DAILY/<date>/diary.md`
- アルバム（`--with-album` 指定時）: `<vault>/01 - DAILY/<date>/album.png` および同ディレクトリの `album-prompt.md`（再生成用）

既存の `diary.md` / `album.png` がある場合は `diary-v2.md` / `album-v2.png` ... と suffix を付けて衝突回避する。

### `--with-album` の挙動

- marketing-harness の `vlog-album` スキルに diary パスを渡してトイカメラ風コンタクトシートを生成する
- `--cells 9|16`（デフォルト `9`、3×3）/ `--split office:private`（デフォルト `2:1`）/ `--gene female|male`（デフォルト `female`）は vlog-album に pass-through
- `--gene` のデフォルト `female` は「Gene を mid-20s 女性として描き、Netta / Pikke と並んで女子 3 人の startup 友達」になる版。`--gene male` で旧デフォルトの男性 Gene 版に切り替え
- 画像生成は Codex CLI built-in（サブスク枠）。`OPENAI_API_KEY` は vlog-album 側で明示的に unset される
- vlog-album が失敗しても diary 本体は壊れない（Step 6 で「diary は OK / album は失敗」を別個に報告）

## 設計思想

詳細は `skills/daily-report/SKILL.md` を参照。要点:

1. **ナラティブ > カタログ**: 表や箇条書きを増やすより、段落で語る
2. **推測補完しない**: 取得失敗は「未取得」と明記、空白で残す
3. **jsonl は最初の user メッセージだけ読む**: 全文読むとコンテキストパンク
4. **Fieldy の抽象 ↔ jsonl の具体** を突き合わせる: 「結果論プロンプトを skill 化したい」 ↔ `final-prompts-synthesis` sub-agent のように、抽象的な発言を具体実装に紐付けると一段深くなる

## 既知の制約

- **20 KB を超える Notion ページ** はトークン上限で取得失敗する。該当時間帯は「未取得」として記録される。
- Notion MCP が未接続の場合、Fieldy パートが完全に欠落する。本スキルは LLM ログ・編集ノート・jsonl だけでも動作するが、夜の生活パートは Fieldy 依存。
- 音声トランスクリプトの **話者識別が不完全**（Speaker Unknown が多い）。ナラティブ化の際に「自分」と「相手」を文脈推測で振り分けている。

## バージョン

- 0.3.0 (2026-05-28): `--gene female|male` オプションを追加し、vlog-album へ pass-through。デフォルトを `female`（3 人とも女性版）に変更。
- 0.2.0 (2026-05-16): `--with-album` オプションを追加。marketing-harness の `vlog-album` を連鎖呼び出しし、diary と同じディレクトリに `album.png` を出力する。
- 0.1.0 (2026-05-14): 初版。`/e2s:distill` で蒸留して生成。
