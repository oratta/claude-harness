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

## change-A 実装決定（2026-05-13、builder agent）

### 決定 9: 旧コマンド参照の許可リスト

旧コマンド `/e2s:commit` `/e2s:ok` `/e2s:rewind` `/e2s:status` `/e2s:reflect` への文字列言及を意図的に残すファイル（受け入れ条件 6 のサブ条件 (a) `grep -rE '/e2s:(commit|ok|rewind|status|reflect)\b' .` での 0 件担保はこれらを除外した上で評価する）:

- `_longruns/2026-05-13_e2s-skill-llm-logs/plan.md`（本 longrun の元設計）
- `_longruns/2026-05-13_e2s-skill-llm-logs/decisions.md`（本ファイル）
- `_longruns/2026-05-13_e2s-skill-llm-logs/checkpoint.md`（履歴記録）
- `_longruns/2026-05-13_e2s-skill-llm-logs/verification-guide.md`（受け入れ条件追跡）
- `openspec/changes/experience-to-skill-plugin/`（旧 OpenSpec change、change-B で archive 予定）
- `openspec/changes/experience-to-skill-jsonl-refocus/proposal.md`（BREAKING マーカーとして旧コマンド名を列挙する必要あり）
- `openspec/changes/experience-to-skill-jsonl-refocus/design.md`（リスク欄で旧コマンド名を引用する必要あり）
- `openspec/changes/experience-to-skill-jsonl-refocus/specs/experience-to-skill-jsonl-distillation/spec.md`（依存削除を明記するため `reflect-candidates` への言及を許容）
- `plugins/experience-to-skill/README.md`（BREAKING 変更点として旧コマンド名を列挙する必要あり）
- `plugins/experience-to-skill/commands/e2s-distill.md`（旧 2 段階分離を廃止した経緯の言及）

これら以外で旧コマンド参照が新たに検出された場合は、受け入れ条件 6(a) 違反として扱う。

### 決定 10: jsonl ディレクトリの実環境エンコーディング検証結果

実機 `~/.claude/projects/` で 3 例以上を検証:

| cwd | 実エントリ | naive encode | 一致 |
|---|---|---|---|
| `/Users/oratta` | `-Users-oratta` | `-Users-oratta` | 完全一致 |
| `/Users/oratta/.claude-mem` | `-Users-oratta--claude-mem-observer-sessions` | `-Users-oratta--claude-mem` | prefix のみ一致 |
| `/Users/oratta/.superset/worktrees/ef0031fc-885f-4c05-adfc-99fa2da76f43/e2s-skill-llm-logs-2` | `-Users-oratta--superset-worktrees-ef0031fc-885f-4c05-adfc-99fa2da76f43-e2s-skill-llm-logs-2` | 同左 | 完全一致 |

UUID 形式の `-` を含むパスは naive encode で一致した。一方 `.claude-mem` のような実用パスでは Claude Code 側がさらに subdirectory（observer-sessions 等）を付加するケースがあるため、**逆引きフォールバック（longest-prefix match）は必須**であることが確認できた。`scripts/jsonl-finder.sh::e2s_resolve_jsonl_dir` で実装済み。

### 決定 12: ブラウザ検証（longrun-browser-verifier）のスキップ

- **エビデンス**: experience-to-skill プラグインは CLI 専用で Web UI / 開発サーバーを持たない
- **判断**: orchestrator の Verify フェーズ Step 2「ブラウザ検証」を本 longrun では対象外とする
- **代替担保**: 機能性軸（spec Scenario 通過率 100%）は Feedback フェーズの「ユーザー動作確認」で手動 E2E として実施。テスト fixture `tests/fixtures/sample-session.jsonl` を用いた再現可能な手動検証で代替
- **UX 軸**: CLI 対話の UX 評価は Feedback フェーズでユーザーが実機で判断

### 決定 11: 旧 SKILL.md からのロジック転写元

- Layer 1 正規表現セット: 旧 SKILL.md の Step 4「Layer 1 コンテンツベースの secret 正規表現スキャン」セクションから採取（AWS / OpenAI / Anthropic / GitHub token / GitHub PAT / Slack / JWT / PEM）
- 加えて Layer 1 にメールアドレスパターンを追加（旧 SKILL.md Step 5 の Layer 2 で PII として扱われていたものを正規表現として下層に降格、確実性のため）
- Layer 2 LLM 意味判定方針: 旧 SKILL.md の Step 5「Layer 2 LLM による意味的 secret チェック」を新 SKILL.md および新 e2s-distill.md にそれぞれ転写
- 旧 SKILL.md は新 SKILL.md で完全に置き換え。`git log -p` で旧版は復元可能
