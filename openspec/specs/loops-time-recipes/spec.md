# loops-time-recipes Specification (Delta)

## ADDED Requirements

### Requirement: time レシピ 3 本が存在し固定見出し規約に準拠する

`plugins/loops/recipes/` 配下に `loop-pr-babysit.md`・`cron-daily-report.md`・`cron-weekly-report.md` の 3 ファイルが存在しなければならない (MUST)。各ファイルは change-1 のレシピ形式規約に従い、固定見出し（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）の 7 見出しを全て含まなければならない (MUST)。ループ型の節には 4 分類のうち「タイムベース」であることを明記すること。

#### Scenario: time レシピ 3 ファイルが存在する

- **WHEN** `plugins/loops/recipes/` を一覧する
- **THEN** `loop-pr-babysit.md`・`cron-daily-report.md`・`cron-weekly-report.md` の 3 ファイルが全て存在する

#### Scenario: 固定見出しが grep で確認できる

- **WHEN** 各 time レシピに対して固定見出し 7 種（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）をそれぞれ grep する
- **THEN** 3 ファイル全てで 7 見出し全てがヒットする（欠落 0 件）

#### Scenario: ループ型がタイムベースと明記されている

- **WHEN** 各 time レシピのループ型の節を grep する
- **THEN** 3 ファイル全てに「タイムベース」の記載がある

### Requirement: loop-pr-babysit は Draft PR 運用向けの保守的な /loop レシピである

`loop-pr-babysit.md` の起動コマンドは、公式例に準拠した `/loop` コマンド文字列（PR のチェック・レビューコメント対応・CI 失敗修正）でなければならず (MUST)、実行間隔のデフォルトは 5〜10 分の保守的な値とし、間隔の変更方法（コマンド文字列中の該当箇所）を併記すること。発火時の作業指示はこのリポジトリの Draft PR 運用（CLAUDE.md）に合わせ、feature branch への push と Draft PR の更新までを許可し、マージ・Ready for Review 切り替え・main への push を行ってはならない (MUST NOT) 旨をエスカレーション条件と併せて明記すること。停止基準として、PR のマージまたはクローズを検知した時点でループを終了（/loop のキャンセル）することを含めなければならない (MUST)。

#### Scenario: /loop 起動コマンドと保守的な間隔デフォルトがある

- **WHEN** `loop-pr-babysit.md` の起動コマンドの節を読む
- **THEN** `/loop` で始まるコピペ可能なコマンド文字列が存在し、間隔のデフォルトが 5〜10 分の範囲で指定され、間隔の変更方法が併記されている

#### Scenario: 非破壊制約とエスカレーションが明記されている

- **WHEN** `loop-pr-babysit.md` の本文を読む
- **THEN** マージ・Ready for Review 切り替え・main への直接 push を行わないこと、およびそれらが必要になった場合は人間へエスカレーションすることが明記されている

#### Scenario: PR 終了時の停止基準がある

- **WHEN** `loop-pr-babysit.md` の停止基準の節を読む
- **THEN** 対象 PR のマージまたはクローズを検知したらループを終了する条件が明記されている

### Requirement: cron レシピは既存レポートスキルの非対話モードを実行方法非依存で定義する

`cron-daily-report.md` と `cron-weekly-report.md` は、既存の daily-report / weekly-report スキルの非対話モードを定期実行するためのレシピとして、(1) 発火時に投入するプロンプト（コピペ可能なコマンド文字列）、(2) 推奨頻度（daily-report は日次、weekly-report は週次の保守的デフォルトと変更方法）、(3) 停止基準、(4) 実行環境の制約（Obsidian Vault・`~/.claude/projects/` のセッション jsonl などローカルデータを読むためローカル実行が必須であること）の 4 点を定義しなければならない (MUST)。スケジューラへの登録手順・セッション運用・課金選択には踏み込んではならず (MUST NOT)、登録は呼び出し側の責務であることをレシピ内に明記すること。

#### Scenario: 発火時プロンプトと推奨頻度が定義されている

- **WHEN** `cron-daily-report.md` と `cron-weekly-report.md` の起動コマンドの節を読む
- **THEN** 両ファイルに発火時に投入するコピペ可能なプロンプト（非対話モードでのスキル起動文字列）が存在し、推奨頻度がそれぞれ日次 / 週次のデフォルトと変更方法つきで記載されている

#### Scenario: ローカル実行必須の制約が明記されている

- **WHEN** 両 cron レシピの前提の節を読む
- **THEN** ローカルデータ（Vault・セッション jsonl）を読むためローカル実行が必須である旨の制約が両ファイルに明記されている

#### Scenario: スケジューラ登録が呼び出し側の責務と明記されている

- **WHEN** 両 cron レシピの本文を読む
- **THEN** スケジューラへの登録・セッション運用は呼び出し側の責務でありレシピのスコープ外であることが明記され、特定のスケジューラ（セッション内 cron / launchd / `claude -p` 配線等）への登録手順が含まれていない

#### Scenario: 既存レポートプラグインの本文が変更されていない

- **WHEN** 本 change の実装後に `plugins/daily-report/` と `plugins/weekly-report/` の diff を確認する
- **THEN** 両プラグイン配下のファイルに変更が 0 件である（レシピは登録・運用手順のみで既存スキル本文に触れない）

### Requirement: 全 time レシピは停止基準とトークン管理項目を含む

全ての time レシピは停止基準の節に、ループを終了・解除する条件（対象イベントの完了検知・最大継続期間・手動キャンセルの手順のいずれか複数）を具体的に記述しなければならない (MUST)。停止基準の無い time レシピが存在してはならない (MUST NOT)。また各レシピのコスト注意の節には、公式トークン管理 6 項目のうち該当するもの（少なくとも「実行頻度を必要最小限にする」を含み、該当する場合「決定論的作業のスクリプト化」「大規模実行前のパイロット実行」）を明記しなければならない (MUST)。

#### Scenario: 停止基準の無い time レシピが 0 件である

- **WHEN** `plugins/loops/recipes/loop-*.md` と `plugins/loops/recipes/cron-*.md` の全ファイルについて停止基準の節を検査する
- **THEN** 全ファイルに具体的な終了・解除条件が記述されており、停止基準が空または欠落しているレシピは 0 件である

#### Scenario: コスト注意にトークン管理該当項目がある

- **WHEN** 3 本の time レシピのコスト注意の節をそれぞれ読む
- **THEN** 全ファイルに「実行頻度を必要最小限にする」観点の記述があり、決定論的作業のスクリプト化またはパイロット実行のうちそのレシピに該当する項目が明記されている

#### Scenario: 独自ランタイム・モデル ID への参照が無い

- **WHEN** `plugins/loops/recipes/` 配下の time レシピ 3 ファイルに対して独自スクリプト起動（例: `bash .*loop.*\.sh`）と `claude-` で始まるモデル ID を grep する
- **THEN** いずれも 0 件であり、起動コマンドは全てネイティブプリミティブ（/loop・/schedule・skill 起動文字列）である
