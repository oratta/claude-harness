# Decisions — 2026-05-13 e2s-skill-llm-logs

## Plan Review Round 1（longrun-reviewer, 2026-05-13）

Status: REQUEST_CHANGES → 6 件の指摘を受領。全て技術的根拠あり（嗜好レベルなし）として採用。

### 指摘 1: jsonl ディレクトリ名エンコーディング規約の誤定義（BLOCKER）

- **判定**: 採用（事実誤認）
- **理由**: plan の「`/` → `-` 置換」は不完全。実例 `/Users/oratta/.claude-mem` → `-Users-oratta--claude-mem` のように `.` も `-` に置換され、連続ハイフンが発生する
- **対応**: データモデル節を修正 + change-A の config.yaml rules に逆引き検証ルール追加

### 指摘 2: PII サニタイズ流用元喪失リスク（SHOULD_FIX）

- **判定**: 採用
- **理由**: 旧 e2s-reflect / e2s-distill 削除と新サニタイズ実装が同一 change 内なので、builder が削除を先に行うと流用元を失う
- **対応**: config.yaml rules に「削除前にサニタイズロジックを新ファイルへコピー」を明記

### 指摘 3: グローバルルール書き換えタイミング曖昧（SHOULD_FIX）

- **判定**: 採用
- **理由**: `~/.claude/rules/git-commit-policy.md` は worktree 外のユーザーグローバルファイル。worktree マージ前に書き換えると、本番セッションで `/e2s:commit` が消える前にルールが消える不整合期間が発生する
- **対応**: change-B スコープ冒頭に「change-A の worktree が main にマージされた後に実施」を明記。decisions.md に変更日時 + マージコミット SHA を記録

### 指摘 4: 旧コマンド参照の grep 0 件担保が弱い（SHOULD_FIX）

- **判定**: 採用
- **理由**: 単純な文字列 grep では空白混入や半角/全角差を取りこぼす可能性
- **対応**: 受け入れ条件 6 を 3 サブ条件に分割（コマンド grep + ファイル名 grep + plugin.json 検査）

### 指摘 5: jsonl スキャンのパフォーマンス上限未定義（NOTE）

- **判定**: 採用
- **理由**: 防衛策として安い（日付→サイズ→grep の順序ルール）。最適化を後回しにする方針は変えないが、最低限の順序は決めておく
- **対応**: change-A の config.yaml rules に追加

### 指摘 6: Bats テスト範囲（fixture jsonl）（NOTE）

- **判定**: 採用
- **理由**: 「実環境の jsonl」依存だと再現性がない。サニタイズ済み fixture を 1 件 commit するのは妥当
- **対応**: 受け入れ条件 9 に fixture jsonl コミット要件を追記

## Setup フェーズ判断（2026-05-13）

### 決定 7: OpenSpec カスタムスキーマ `longrun-tdd` のセットアップを本 longrun ではスキップ

- **エビデンス**: `ls openspec/schemas/` → `No such file or directory`
- **状況**: orchestrator SKILL.md は「`openspec/schemas/longrun-tdd/` が存在しなければ `openspec schema fork spec-driven longrun-tdd` を実行」と規定
- **判断**: 本 longrun ではセットアップを実施せず、builder agent には plan.md + 標準 OpenSpec スキーマで TDD を進めさせる
- **理由**:
  1. 本リファクタは規模が小さく（plugin 1 個の作り直し）、TDD 強制ハーネスが必須ではない
  2. plan.md でテストフレームワーク (Bats) と受け入れ条件 (テスト全 PASS) が明示されており、builder agent は plan.md を参照すれば TDD で進められる
  3. カスタムスキーマセットアップのコンテキスト消費を回避し、本来の実装に集中する
- **代替担保**: builder agent への指示文に「テスト先行（Red） → 最小実装（Green） → リファクタ」の TDD サイクルを plan.md の受け入れ条件 2 に基づいて遵守すること、を明記する
- **将来の方針**: 大規模 longrun ではカスタムスキーマセットアップを別途 Setup の必須項目として組み込む

### 決定 8: 既存 OpenSpec change `experience-to-skill-plugin` の進捗扱い

- **エビデンス**: `openspec/changes/experience-to-skill-plugin/tasks.md` は 5.x (Documentation) と 6.1 / 7.1-7.3 が完了。残り [  ] は Manual Test (6.2-6.10) と End-to-end Install (7.4)
- **状況**: 旧 e2s 実装は既にコードベースに反映済みだが、Manual Test は未実施で tasks 半完了状態のまま放置
- **判断**: 本 longrun の change-B で旧 change を archive 扱いとする。Manual Test 未完了タスクは「旧設計の不採用により無効」として archive 時に注釈を付ける。新 e2s 実装は新規 change として `openspec/changes/experience-to-skill-jsonl-refocus/` を作成
- **理由**:
  1. 旧 change の Manual Test を完了させる意味がない（その実装を新設計で完全に置き換えるため）
  2. 新 capability 構造（旧 3 capability → 新 1 capability）は新規 change として記述する方が clean
- **archive 時のラベル候補**: `2026-05-13-experience-to-skill-plugin-superseded`
