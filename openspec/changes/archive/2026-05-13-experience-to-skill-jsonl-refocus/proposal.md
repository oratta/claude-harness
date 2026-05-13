## Why

旧 `experience-to-skill` プラグイン（commit / verified タグ / 巻き戻し / reflect / distill の 6 コマンド + auto-commit skill）は実用に至らなかった。コミット境界に紐付いた事前準備が必須で、後から「あの作業をスキル化したかった」という自然な発想に追随できない構造だったため。一方で Claude Code は `~/.claude/projects/<encoded-cwd>/*.jsonl` にセッションの全履歴を網羅的に書き出しており、これを素材に「自然言語の依頼」で SKILL.md を蒸留する方が、コミット運用に依存せず後付けで動かせる。本変更で旧 e2s 群を全廃し、**jsonl 起点・対話完結 1 コマンドのスキル蒸留専門ツール**に作り直す。

## What Changes

- **BREAKING**: 旧スキル `experience-to-skill`（auto-commit）を削除。コミット運用関連の機能（commit / ok / rewind / status / reflect）を全廃止する
- **BREAKING**: 旧 slash command `/e2s:commit` `/e2s:ok` `/e2s:rewind` `/e2s:status` `/e2s:reflect` `/e2s:distill` を全削除
- 新 skill `experience-to-skill` を導入し、auto-trigger は「スキル化依頼の自然言語フレーズ」（例: 「〜スキル化して」「過去の作業からスキルを作って」）のみに限定する。コミット完了等では起動しない
- 新 slash command `/e2s:distill` を導入。1 コマンドで対話完結（jsonl 探索 → 候補絞り込み → サニタイズ → SKILL.md 書き出し）する
- jsonl 探索の補助スクリプト `plugins/experience-to-skill/scripts/jsonl-finder.sh` を実装（cwd → encoded path 正規化 + 逆引きフォールバック + 4 段スキャン順序）
- PII / secret サニタイズ `plugins/experience-to-skill/scripts/sanitize.sh` を実装（Layer 1 正規表現） + 新 skill 内に Layer 2 LLM 意味判定方針を明記
- Bats による補助スクリプトのユニットテストを追加（`plugins/experience-to-skill/tests/`）
- `plugins/experience-to-skill/README.md` を新設計で全面書き直し
- `.claude-plugin/marketplace.json` および `plugins/experience-to-skill/.claude-plugin/plugin.json` の version を minor bump、commands 配列を `e2s-distill` のみに

## Capabilities

### New Capabilities

- `experience-to-skill-jsonl-distillation`: Claude Code セッションの jsonl ログを素材に、自然言語の依頼で SKILL.md を蒸留する機構。jsonl 探索（cwd → encoded path 正規化 + 逆引きフォールバック + 4 段スキャン順序）、対話完結 1 コマンドフロー、PII / secret 2 層サニタイズ、SKILL.md の `e2s-` / `distilled-` prefix 命名、出力配置先選択（プロジェクトローカル / ユーザーグローバル）を規定する。

### Modified Capabilities

（旧 3 capability は本 change の delta では参照しない。旧 OpenSpec change `experience-to-skill-plugin` は archive 対象として change-B で扱うため、本 change-A の specs 配下には REMOVED delta を作らない。）

## Impact

- **削除されるファイル**:
  - `plugins/experience-to-skill/commands/e2s-commit.md`
  - `plugins/experience-to-skill/commands/e2s-ok.md`
  - `plugins/experience-to-skill/commands/e2s-rewind.md`
  - `plugins/experience-to-skill/commands/e2s-status.md`
  - `plugins/experience-to-skill/commands/e2s-reflect.md`
  - `plugins/experience-to-skill/commands/e2s-distill.md`（旧版。新版で置き換え）
  - 旧 `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md`（auto-commit 仕様）
- **新規ファイル**:
  - `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md`（新 auto-trigger）
  - `plugins/experience-to-skill/commands/e2s-distill.md`（対話完結 1 コマンド）
  - `plugins/experience-to-skill/scripts/jsonl-finder.sh`
  - `plugins/experience-to-skill/scripts/sanitize.sh`
  - `plugins/experience-to-skill/tests/jsonl-finder.bats`
  - `plugins/experience-to-skill/tests/sanitize.bats`
  - `plugins/experience-to-skill/tests/fixtures/sample-session.jsonl`
- **変更ファイル**:
  - `plugins/experience-to-skill/.claude-plugin/plugin.json`（commands 配列縮小 + version minor bump）
  - `plugins/experience-to-skill/README.md`（全面書き直し）
  - `.claude-plugin/marketplace.json`（experience-to-skill エントリの description / keywords / version 同期）
- **依存なし**: 外部ライブラリ・MCP サーバ不要。Bash + `jq` / `python3` のみで完結
- **マルチプラットフォーム参照修正**: リポジトリ内の `/e2s:(commit|ok|rewind|status|reflect)` 参照を grep し削除 or 言い換え（許可リストは decisions.md に明示）
- **本 change-A では触らない**:
  - `~/.claude/rules/git-commit-policy.md` の auto-commit 許可記述（change-B でマージ後に対応）
  - 既存 OpenSpec change `openspec/changes/experience-to-skill-plugin/` の archive（change-B で対応）
