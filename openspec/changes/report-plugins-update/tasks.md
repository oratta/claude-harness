# Tasks: report-plugins-update

## 1. weekly-report のセッションログ収集を native jsonl 直読に移行

- [ ] 1.1 `plugins/daily-report/agents/llm-log-compactor.md:33-100` の jq ロジック（初回 user メッセージ抽出・最終 assistant 抽出・メタ統計 6 項目の集計クエリ）を確認し、週次（複数日横断）集計に必要な変更点（対象週の日付範囲フィルタ、日別ではなくセッション単位のグルーピング）を洗い出す
- [ ] 1.2 `plugins/weekly-report/skills/weekly-report/SKILL.md` の Step 3b（旧「ソースリポジトリ LLM セッション」節）を、`{source_path}/LLM/*.md` 読み込みから `~/.claude/projects/*/` の native jsonl 直読（jq ベース）に書き換える。対象週の月〜日の範囲で `find ~/.claude/projects -maxdepth 2 -name "*.jsonl" -newermt ... ! -newermt ...` 相当のフィルタを使う
- [ ] 1.3 書き換えた Step 3b の説明文に、`plugins/daily-report/agents/llm-log-compactor.md` のロジックを流用した旨を明記する（design.md D1 の一次ソース明記方針）
- [ ] 1.4 Step 6（レポート生成）と Step 7（週次ノートへの挿入）内の「LLMセッション」表示部分が、新しい抽出結果（セッションID・要約）の形式と整合していることを確認し、必要なら文言を調整する

## 2. weekly-report の個人パス・廃止命名を解消

- [ ] 2.1 `plugins/weekly-report/skills/weekly-report/SKILL.md` の旧 Step 4d（1h-cooking セッション収集）を、`/Users/oratta/Dropbox/WorkSpace` ハードコードから環境変数 `$WORKSPACE_ROOT` ベースの検索に書き換える（design.md D2: 未設定時は当該サブセクションを省略してレポート生成は継続）
- [ ] 2.2 同サブセクション内の「1h-cooking」言及を harvest plugin の現行命名・実態（`data/sessions/<slug>.jsonl`、作業 repo cwd 直下に分散）に更新する
- [ ] 2.3 Step 6（レポート生成テンプレート）内の「1h-cooking セッション」表示ラベルも harvest 命名に更新する（テンプレート内の見出し・変数名を含む）

## 3. command ファイルの参照・frontmatter バグ修正

- [ ] 3.1 `plugins/weekly-report/commands/weekly-report.md` の SKILL.md 参照を、存在しない `.claude/skills/weekly-report/SKILL.md` から plugin-relative な `skills/weekly-report/SKILL.md`（daily-report の `commands/daily-report.md` と同方式）に修正する
- [ ] 3.2 `plugins/daily-report/commands/daily-report.md` の frontmatter `allowed-tools` に `Agent` を追加する（SKILL.md Phase 1 の Agent tool_use 並列起動の実挙動に合わせる）

## 4. 非対話（/schedule cron）モードの追加

- [ ] 4.1 `plugins/daily-report/skills/daily-report/SKILL.md` に非対話実行モードの節を追加する。AskUserQuestion 不可時はデフォルト対象日「昨日」で続行し、対話依存ステップ（口頭報告関連等）はファイル出力へ代替、判断内容を diary.md の出力に判断ログとして残す
- [ ] 4.2 `plugins/weekly-report/skills/weekly-report/SKILL.md` に非対話実行モードの節を追加する。AskUserQuestion 不可時はデフォルト対象週「先週」で続行し、対話依存ステップは代替、判断内容を週次ノートの実績サマリに判断ログとして残す
- [ ] 4.3 両 SKILL.md の既存「エラーハンドリング」節の形式に合わせて判断ログの記載箇所・書式を統一する（design.md D4）

## 5. テスト新設・実行

- [ ] 5.1 `plugins/weekly-report/tests/` ディレクトリを新設し、`plugins/daily-report/tests/helper.bash` を参考にした共有 bats ヘルパーを作成する
- [ ] 5.2 bats テスト: `plugins/weekly-report/skills/weekly-report/SKILL.md` に `{source_path}/LLM`・`/Users/oratta/Dropbox/WorkSpace`・`1h-cooking`（大文字小文字無視）のいずれも出現しないことを grep で検証する
- [ ] 5.3 bats テスト: `plugins/weekly-report/skills/weekly-report/SKILL.md` に `~/.claude/projects` への参照と `$WORKSPACE_ROOT` 環境変数の使用が存在することを grep で検証する
- [ ] 5.4 bats テスト: `plugins/weekly-report/commands/weekly-report.md` が `.claude/skills/weekly-report/SKILL.md` を参照せず `skills/weekly-report/SKILL.md` を参照することを grep で検証する
- [ ] 5.5 bats テスト: `plugins/daily-report/commands/daily-report.md` の frontmatter `allowed-tools` に `Agent` が含まれることを検証する
- [ ] 5.6 bats テスト: `plugins/daily-report/skills/daily-report/SKILL.md` と `plugins/weekly-report/skills/weekly-report/SKILL.md` の両方に非対話モード節（デフォルト値・判断ログの言及）が存在することを grep で検証する
- [ ] 5.7 `find plugins -name '*.bats' -print0 | xargs -0 bats` を実行し、新設分を含め全 PASS することを確認する

## 6. バージョン同期・統合確認

- [ ] 6.1 `plugins/weekly-report/.claude-plugin/plugin.json` の version を bump する（1.0.2 → 1.1.0 目安。破壊的変更ではない機能追加のため minor）
- [ ] 6.2 `plugins/daily-report/.claude-plugin/plugin.json` の version を bump する（0.3.0 → 0.3.1 目安。frontmatter バグ修正 + 非対話モード追加）
- [ ] 6.3 `.claude-plugin/marketplace.json` の weekly-report / daily-report エントリの version を 6.1/6.2 と一致させ、description も変更内容に応じて更新する（design.md D5: 本 change 内で自己完結して同期する）
- [ ] 6.4 `jq . plugins/weekly-report/.claude-plugin/plugin.json`・`jq . plugins/daily-report/.claude-plugin/plugin.json`・`jq . .claude-plugin/marketplace.json` の構文検証を実行する
- [ ] 6.5 受け入れ条件 11（weekly-report SKILL.md に `{source_path}/LLM/` 参照が無い）・16（daily/weekly 両 SKILL.md に非対話モード節が存在する）に該当する grep コマンドを実行し、期待値どおりであることを確認する
