## change-5: report-plugins-update

### S1: [weekly-report-jsonl-direct] Step 3b が LLM/*.md への参照を持たない
- WHEN: `plugins/weekly-report/skills/weekly-report/SKILL.md` 内で `{source_path}/LLM` を grep する
- THEN: 該当行は 0 件である
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S2: [weekly-report-jsonl-direct] Step 3b が native jsonl を参照する
- WHEN: `plugins/weekly-report/skills/weekly-report/SKILL.md` の Step 3b を読む
- THEN: `~/.claude/projects` への参照と jq ベースのセッション抽出手順が記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S3: [weekly-report-jsonl-direct] llm-log-compactor のロジックを流用している旨が明記されている
- WHEN: ユーザーが Step 3b の説明文を読む
- THEN: `plugins/daily-report/agents/llm-log-compactor.md` の jq ロジックを流用・参照している旨が記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S4: [weekly-report-jsonl-direct] 個人パスのハードコードが無い
- WHEN: `plugins/weekly-report/skills/weekly-report/SKILL.md` 内で `/Users/oratta/Dropbox/WorkSpace` を grep する
- THEN: 該当行は 0 件である
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S5: [weekly-report-jsonl-direct] 環境変数未設定時にフェイルソフトする
- WHEN: harvest セッション検索用の環境変数（`$WORKSPACE_ROOT`）が未設定の状態でレポート生成が実行される
- THEN: 該当サブセクション（harvest セッション集計）は省略され、レポート生成の他のセクションは通常どおり出力される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S6: [weekly-report-jsonl-direct] 1h-cooking 言及が残っていない
- WHEN: `plugins/weekly-report/skills/weekly-report/SKILL.md` 内で大文字小文字を無視して `1h-cooking` を grep する
- THEN: 該当行は 0 件である
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S7: [weekly-report-jsonl-direct] harvest の実態に沿った検索パターンが記載されている
- WHEN: ユーザーが更新後の該当サブセクション（旧 Step 4d）を読む
- THEN: `data/sessions/<slug>.jsonl` という作業 repo cwd 直下分散のパターンでセッション jsonl を検索する旨が記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S8: [report-command-hygiene] 存在しない旧パスへの参照が無い
- WHEN: `plugins/weekly-report/commands/weekly-report.md` 内で `.claude/skills/weekly-report/SKILL.md` を grep する
- THEN: 該当行は 0 件である
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S9: [report-command-hygiene] plugin-relative パスで SKILL.md を参照している
- WHEN: `plugins/weekly-report/commands/weekly-report.md` の本文を読む
- THEN: `skills/weekly-report/SKILL.md` という plugin-relative なパスで SKILL.md の手順に従う旨が記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S10: [report-command-hygiene] allowed-tools に Agent が含まれる
- WHEN: `plugins/daily-report/commands/daily-report.md` の frontmatter `allowed-tools` 行を読む
- THEN: `Agent` がツール一覧に含まれている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S11: [report-noninteractive-mode] daily-report SKILL.md に非対話モード節が存在する
- WHEN: `plugins/daily-report/skills/daily-report/SKILL.md` を読む
- THEN: cron / 非対話実行時にデフォルト対象日「昨日」で続行する旨を記載した節が存在する
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S12: [report-noninteractive-mode] weekly-report SKILL.md に非対話モード節が存在する
- WHEN: `plugins/weekly-report/skills/weekly-report/SKILL.md` を読む
- THEN: cron / 非対話実行時にデフォルト対象週「先週」で続行する旨を記載した節が存在する
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S13: [report-noninteractive-mode] AskUserQuestion 不可時はデフォルト値で続行する
- WHEN: 非対話実行コンテキスト（cron 経由等）で AskUserQuestion が使用できない状態でスキルが起動される
- THEN: 質問をスキップしデフォルト値（daily=昨日、weekly=先週）で処理が続行される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S14: [report-noninteractive-mode] 対話依存ステップがファイル出力に代替される
- WHEN: 非対話実行時に対話依存ステップ（口頭報告等のユーザー入力前提の箇所）に到達する
- THEN: 当該ステップはファイル出力（空セクション・プレースホルダー等）へ代替される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S15: [report-noninteractive-mode] 判断ログが出力に残る
- WHEN: 非対話実行によりデフォルト値の適用や対話ステップのスキップが発生する
- THEN: その判断内容が生成物の出力（レポート本文またはログ）に判断ログとして記録される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了
