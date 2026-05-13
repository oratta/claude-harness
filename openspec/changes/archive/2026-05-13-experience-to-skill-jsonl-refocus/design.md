# Design: experience-to-skill-jsonl-refocus

## Context

旧 e2s プラグインの実装は本リポジトリに 4 時間前に完成したが、利用実績ゼロ。理由は「コミット境界に紐付けた事前準備（verified タグ付与、commit 整形）が必要で、後付けでスキル化したい自然な欲求に追随できない」点。一方 Claude Code 自身が `~/.claude/projects/<cwd-encoded>/*.jsonl` にセッション履歴を網羅的に書き出しており、これは「事後にスキル化したい」要求の素材として理想的。本変更は旧 e2s を全廃し、jsonl 起点・対話完結 1 コマンドのスキル蒸留専門ツールに作り直す。

## Goals

- 旧 e2s 群（6 commands + 1 auto-commit skill）の完全削除
- jsonl ログを素材にした「自然言語起動・対話完結」のスキル蒸留体験
- マルチセッション運用や verified タグといった事前準備を完全に不要にする
- PII / secret サニタイズの確実な実装（旧 e2s-reflect の Layer 1 / 2 ロジックを流用）
- 補助スクリプトを Bats でユニットテスト可能にする

## Non-Goals

- jsonl の長期保存ポリシーや専用 DB の構築（都度スキャンで十分軽量）
- claude-mem MCP 連携（別関心事、別 longrun で検討）
- 旧コードのアーカイブ保持（git 履歴から復元可能）
- グローバルルール `~/.claude/rules/git-commit-policy.md` の書き換え（change-B で実施）
- 既存 OpenSpec change `experience-to-skill-plugin` の archive（change-B で実施）

## Decisions

### Decision 1: cwd → jsonl ディレクトリ名のエンコーディング規約

- **What**: cwd の絶対パスを `~/.claude/projects/` 配下のディレクトリ名に変換するロジック
- **Choice**: `/` および `.` を `-` に置換する。連続ハイフン（`.claude-mem` → `--claude-mem`）はそのまま保持
- **Why**:
  - 実例 3 件（`-Users-oratta`、`-Users-oratta--claude-mem-observer-sessions`、`-Users-oratta--superset-worktrees-...`）で連続ハイフンを確認済み
  - 公式仕様文書がないため、規約未知の文字に備えて逆引きフォールバック（cwd の prefix が一致するエントリを優先順位付きで返す）を併設する
- **Alternatives**:
  - URL encode 風（`/` → `%2F`）: Claude Code 実装と不一致のため却下
  - cwd hash（md5 等）: 実装と不一致のため却下

### Decision 2: jsonl スキャン順序

- **What**: 大量の jsonl から候補を効率良く絞り込むスキャン順序
- **Choice**: (1) ディレクトリ存在確認 → (2) mtime による日付範囲フィルタ → (3) ファイルサイズ上限フィルタ（デフォルト 50MB） → (4) キーワード grep
- **Why**: 安価なメタデータフィルタを先に走らせて、高コストな grep の対象を最小化する防衛策。最適化は実利用してから

### Decision 3: 削除前にサニタイズロジックを新ファイルへ先行コピー

- **What**: 旧 e2s の Layer 1 正規表現セット（旧 SKILL.md Step 4）と Layer 2 LLM 意味判定方針（旧 SKILL.md Step 5）を、旧ファイル削除前に新ファイルへ転写する
- **Why**: 同一 change 内で削除と新規実装が同時実行されるため、削除を先行させると流用元を失う。コピー完了を確認してから旧ファイル削除に進む
- **Implementation**: `plugins/experience-to-skill/scripts/sanitize.sh`（Layer 1）+ 新 SKILL.md 内（Layer 2 プロンプト）に転写

### Decision 4: PII / secret サニタイズの 2 層構造

- **Layer 1**: `scripts/sanitize.sh` の正規表現セット（AWS / OpenAI / Anthropic / GitHub / Slack / JWT / PEM / 汎用 hex / メールアドレス / 電話番号）を入力 jsonl 抜粋に対して走らせ、マッチを `[REDACTED:<kind>]` に置換
- **Layer 2**: 新 SKILL.md の手順に従い、LLM が抽出済みテキストを自然言語レベルで再レビューし、独自形式トークン・PII・URL embedded credentials を抽象化または削除する
- **Why**: 旧 e2s で確立された方針。jsonl 原文は credentials を含み得るため二重で防衛する

### Decision 5: SKILL.md の name prefix 規約

- **Choice**: 生成される SKILL.md の frontmatter `name:` には `e2s-` または `distilled-` prefix を必ず付与する
- **Why**: 本家 skill-creator との衝突回避 + 蒸留由来であることを明示。デフォルトは `e2s-` prefix

### Decision 6: 1 コマンド対話完結 vs 複数コマンドフロー

- **Choice**: 1 コマンド `/e2s:distill` で jsonl 探索 → 候補提示 → 選択 → 生成まで対話完結
- **Why**: 旧 e2s は `reflect` → `distill` の 2 段階分離だったが「使われなかった」反省を踏まえ、ユーザー操作を最短化する。シンプルさ最優先

### Decision 7: 既存 OpenSpec change の取り扱い

- **What**: 旧 `openspec/changes/experience-to-skill-plugin/` の delta を本 change-A 内で REMOVED 扱いにするか
- **Choice**: しない。本 change-A の specs/ 配下には新 capability の ADDED delta のみを置き、旧 change は change-B で archive する
- **Why**: 旧 change は本リポジトリで未 archive のまま `/openspec/specs/` には未昇格。capability ファイルは存在しないため REMOVED 対象がない。delta の整合性は新規 ADDED のみで保つのが clean

### Decision 8: auto-trigger description のフレーズ限定

- **Choice**: 新 skill の auto-trigger description には「スキル化依頼」フレーズ（例: 「スキルにして」「スキル化して」「過去の作業からスキルを作って」「振り返ってスキル抽出して」）のみを列挙し、コミット完了・archive 完了等の言及は明示的に除外する
- **Why**: 旧 e2s が常駐し全コミット境界で起動してコンテキストを浪費した反省を踏まえ、起動条件を最小化する

## Risks / Trade-offs

- **リスク**: jsonl ディレクトリの命名規約が Claude Code 本体のアップデートで変わる可能性
  - **緩和**: 逆引きフォールバック（cwd prefix マッチ）で吸収。実装関数を Bats でユニットテスト
- **リスク**: LLM が jsonl を読んで判断する部分はユニットテスト不能
  - **緩和**: Bats テストは shell 補助関数（正規化、grep、サニタイズ regex）に限定し、メインフローは fixture jsonl による手動 E2E で担保
- **リスク**: 旧コマンド `/e2s:commit` 等への外部参照が漏れて検出されない
  - **緩和**: 受け入れ条件 6 で 3 サブ条件（コマンド grep + ファイル名 find + plugin.json 検査）を強制

## Migration Plan

1. 旧 e2s の Layer 1 正規表現セット + Layer 2 LLM 方針を、削除前に新 `scripts/sanitize.sh` および新 SKILL.md にコピー完了する
2. 旧 6 コマンド + 旧 SKILL.md を削除
3. 新 SKILL.md, `/e2s:distill`, `scripts/jsonl-finder.sh`, `scripts/sanitize.sh`, Bats テスト, fixture を新規作成
4. plugin.json / marketplace.json / README を更新
5. リポジトリ内の旧コマンド参照を grep して削除 or 言い換え
6. Bats テストが全 PASS することを確認
7. `~/.claude/rules/git-commit-policy.md` および旧 OpenSpec change archive は change-B で実施
