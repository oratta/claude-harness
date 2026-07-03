# Design: report-plugins-update

## Context

`plugins/weekly-report/` と `plugins/daily-report/` は独立した Obsidian レポート生成プラグインだが、LLM セッションログの収集責務が重複しかつ非対称に実装されている。daily-report は `agents/llm-log-compactor.md` で native jsonl（`~/.claude/projects/*/`）を jq で直読する堅牢なロジックを既に持つ一方、weekly-report は廃止予定の obsidian-llm-session-rules（auto-save.py）が生成する `{source_path}/LLM/*.md` を読む設計のままである。change-6（plugin-retirement）は obsidian-llm-session-rules を完全削除するため、本 change（change-5）はその前提条件として weekly-report の依存を先に断ち切る。

本 change は他の変更（付録 E finding 2-5）も含めて `plugins/weekly-report/` と `plugins/daily-report/` の両プラグインを同一 worktree・同一タイミングで更新する。

## Goals / Non-Goals

**Goals:**

- weekly-report のセッションログ収集を native jsonl 直読に統一し、obsidian-llm-session-rules への参照をゼロにする（change-6 の削除で weekly-report が壊れない状態を作る）
- weekly-report / daily-report の command ファイルの参照・frontmatter バグを修正する
- 両プラグインに cron 経由の非対話実行モードを追加し、AskUserQuestion に依存しない自動実行を可能にする
- 個人パス・廃止命名（1h-cooking）を解消し、他ユーザー環境でも動作しうる記述にする

**Non-Goals:**

- weekly-report / daily-report の Sunsama タスク収集・diary 生成ロジック本体の変更（本 change のスコープ外）
- obsidian-llm-session-rules / skill-aware-workflow 自体の削除（change-6 の範囲）
- `/schedule` skill 自体の実装変更（本 change は daily-report / weekly-report 側が非対話実行に耐えるようにするだけで、`/schedule` の呼び出し経路は変更しない）

## Decisions

### D1: jq ロジックは「参照して同じパターンを書く」（コード共有ではなくパターン流用）

- **選択肢**: (a) `llm-log-compactor` agent を weekly-report からも呼び出す共有 agent 化 / (b) weekly-report の SKILL.md 本文に同等の jq ロジックをインラインで記述する
- **決定**: (b)
- **理由**: weekly-report は「対象週の複数日」を横断集計する必要があり、daily-report の agent は「対象 1 日」専用の契約（`TARGET_DATE`/`NEXT_DATE`/`OUTPUT_PATH` 引数、STATUS line 1 行の出力契約）を持つ。契約ごと共有すると週次側の集計要件（週内セッションの日付範囲フィルタ、プロジェクトマッピング）のために agent 側の契約を変更する必要が生じ、daily-report 側の安定した出力契約を壊すリスクがある。plan.md の制約（「llm-log-compactor の jq パターンを流用」であって agent 呼び出しの共有ではない）とも整合する。将来的に週次専用 agent を切り出す余地は残すが、本 change のスコープでは SKILL.md 本文への直接記述に留める

### D2: harvest セッション検索ルートは環境変数 `$WORKSPACE_ROOT`、未設定時はサブセクション省略

- **選択肢**: (a) `~/.claude/settings.json` 相当の設定ファイルを新設 / (b) 環境変数 1 個で解決し未設定時はスキップ
- **決定**: (b)
- **理由**: CLAUDE.md の `LLM_LOG_DIR` 規約（未設定ならユーザーに確認、デフォルトパスを勝手に決めない）と同じ思想を踏襲する。ただし weekly-report は非対話実行（本 change の report-noninteractive-mode）もサポートするため、「未設定ならユーザーに確認」を毎回強制すると非対話実行が止まってしまう。そのため weekly-report では未設定時は当該サブセクションを省略してレポート生成を継続するフェイルソフトを採用する（エラー・対話ブロックにしない）

### D3: 非対話モードのデフォルト値は daily=昨日、weekly=先週（plan.md 指定どおり）

- **選択肢**: (a) 当日 / 当週を対象にする / (b) 前日 / 前週を対象にする
- **決定**: (b)
- **理由**: cron 実行は通常「完了した期間の実績」を集計する用途（例: 深夜バッチで前日分の日記を確定させる）であり、当日・当週はまだ活動が完結していないため実績集計に適さない。plan.md の config.yaml rule で明示的に指定されている値でもある

### D4: 判断ログは生成物本体に埋め込む（別ログファイルを新設しない）

- **選択肢**: (a) 専用のログファイル（例: `noninteractive.log`）を新設する / (b) 生成される diary.md / 週次ノートの実績サマリ本文に判断ログを埋め込む
- **決定**: (b)
- **理由**: 非対話実行の主用途は無人 cron 実行であり、専用ログファイルは見落とされやすい。生成物本体（ユーザーが後で必ず開く diary.md / 週次ノート）に「非対話実行によりデフォルト値 X を採用した」旨を残せば、次にユーザーが手動で確認する際に自然に判断根拠が見える。既存のエラーハンドリング表（weekly-report SKILL.md の「エラーハンドリング」節）と同じ形式で追記できるため実装コストも低い

### D5: change-5 は自己完結で version bump + marketplace.json 同期を行う

- **選択肢**: (a) plan.md の change-7 依存関係に change-5 が含まれていないため sync を change-7 に委ねる（本 change は sync しない） / (b) 本 change 内で weekly-report / daily-report の version bump と marketplace.json 同期を完結させる
- **決定**: (b)
- **理由**: plan.md 付録の受け入れ条件 15（「編集した全プラグインで version bump + marketplace.json 一致」）と技術要件の制約（`~/.claude/rules/plugin-editing.md` 準拠を全編集プラグインに適用）は change 単位で除外を明記していない。change-7 の依存関係リストに change-5 が挙がっていないのは「他 change の marketplace.json 同時編集による競合を避ける直列化」が目的であり（change-1/3/4/6 は change-7 と同一ファイルを触るため直列化が必要）、change-5 は独立して自己完結できる範囲（weekly-report・daily-report の 2 エントリのみ）なので先に確定させてよい。change-7 が最終統合で version drift を再検査する際もこの事前同期は矛盾しない

### D6: 週次の per-project jsonl 特定は `source_path` → `~/.claude/projects/` エンコードパスの直接変換

- **選択肢**: (a) `~/.claude/projects/` 配下を全走査して jsonl 内の cwd フィールドとレジストリの `source_path` を突き合わせる / (b) `source_path` を Claude Code のディレクトリエンコード規則（`/` → `-`）でそのまま変換し、対象ディレクトリを直接特定する
- **決定**: (b)
- **理由**: (a) は cwd を確認するためにどのみち各 jsonl を jq で開く必要があり、全プロジェクト分の jsonl を都度スキャンする O(N) コストがかかる。(b) はパス変換のみで対象ディレクトリを O(1) 特定でき、daily-report の `llm-log-compactor`（全プロジェクト横断で 1 日分を集計する設計）が持たないロジックを週次側で素直に追加できる。`project_dir` が存在しない場合は当該プロジェクトの LLM セッションサブセクションを省略するフェイルソフトとする

### D7: 非対話モードの判断ログの具体的な埋め込み位置は各プラグインの既存記法に合わせる

- **選択肢**: (a) 両プラグイン共通の書式（例: 固定の HTML コメント）を新設する / (b) 各プラグインの既存の記法慣習（weekly-report: blockquote 行、daily-report: `> [!info]` callout）に合わせて個別に定義する
- **決定**: (b)
- **理由**: D4 は「生成物本体に埋め込む」までを決定しており、書式は未確定だった。daily-report は既に `> [!warning]` / `> [!todo]` callout 記法を多用しており、判断ログだけ異質な書式にすると読み物としてのトーン（設計思想「ナラティブ > カタログ」）を損なう。weekly-report は表・blockquote ベースの機械的レポートであり、既存の「エラーハンドリング」節と同じ「状況→対応」的な簡潔な blockquote が自然。対話実行時（デフォルト値未使用時）はこの行/callout を出力しないことで既存 Scenario への影響をゼロに保つ

### D8: `report-noninteractive-mode` の共通 Scenario（S13-S15）は daily-report / weekly-report 双方の `tests/` に重複実装する

- **選択肢**: (a) 共通 Scenario 用の bats ファイルをどちらかのプラグイン配下にのみ置く / (b) 両プラグインの `tests/noninteractive-mode.bats` にそれぞれ同等のアサーションを実装する
- **決定**: (b)
- **理由**: spec 上は 1 つの Requirement/Scenario 群だが、実装は SKILL.md 2 本（daily-report・weekly-report）に分かれており、どちらか一方の bats ファイルに寄せると検証対象外のプラグインの regression を検知できなくなる。tests/ ディレクトリはプラグイン単位（`plugins/<name>/tests/`）で完結させる既存の bats-core 運用（daily-report の既存 tests/ 構成）とも整合する

## Risks / Trade-offs

- [SKILL.md 本文への jq インライン記述（D1）が daily-report 側の将来のロジック改善に追随しない] → コメントで `plugins/daily-report/agents/llm-log-compactor.md` を一次ソースとして明記し、将来の同期ズレをレビューで検知できるようにする
- [`$WORKSPACE_ROOT` 未設定時のフェイルソフト（D2）が「本当は集計してほしかった」ケースを静かにスキップしてしまう] → レポート生成時に「harvest セッション: 環境変数未設定のためスキップ」という注記を出力し、ユーザーが気づけるようにする
- [非対話モードのデフォルト値（D3）と判断ログ埋め込み（D4）が既存の対話フローの出力フォーマットに影響を与える] → 既存の対話実行時の出力フォーマットは変更せず、非対話時のみ追加セクションとして判断ログを付記する（既存 Scenario への影響なし）
- [change-7 との version bump 二重編集（D5）] → change-7 は「全編集プラグインの version・description 最終同期」を再確認する設計であり、既に一致していれば diff が発生しないため衝突しない

## Migration Plan

1. weekly-report の Step 3b/4d 書き換え（native jsonl 直読 + 環境変数化 + harvest 命名更新）→ command パス修正 → daily-report command frontmatter 修正 → 両 SKILL.md の非対話モード節追加 → bats テスト新設・実行 → version bump + marketplace.json 同期、の順で実装する
2. **後方互換**: 既存のユーザー向け動作（対話実行時のレポート生成フロー）は変更しない。非対話モードは追加的な分岐であり、対話実行の既存 Scenario には影響しない
3. **ロールバック**: 本 change は追加的な書き換え（同一ファイル内での記述置換）のみで新規プラグイン・新規ファイル追加は tests/ のみ。問題が出た場合は該当ファイルの diff を revert すれば旧動作に戻る
