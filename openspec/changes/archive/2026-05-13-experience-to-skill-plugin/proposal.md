## Why

Claude Code セッションで生成される膨大な作業履歴（コミット差分 + セッション jsonl）は、本来「プロジェクト固有のスキルを蒸留する素材」として再利用できるはずだが、現状は使い捨てで消えている。既存プラグイン（Aider / claude-mem / affaan-m の skill-create）はそれぞれ「自動コミット」「セッション記録」「git履歴からのスキル生成」を個別に実装しているが、**コミットと会話履歴を突き合わせて体験からスキルを抽出する統合ワークフロー**が存在しない。さらにマルチセッションでの安全なコミット分離、試行錯誤と検証済み状態の区別といった LLM 時代特有の課題も未解決のまま残っている。

## What Changes

- 新プラグイン `experience-to-skill` を追加し、LLM駆動で都度コミット → verified タグで検証点を記録 → 区間から skill を蒸留する一貫ワークフローを提供
- **LLM駆動の自動コミットスキル**（Stop hook ではなく skill 方式）: 作業完了を示すフレーズや archive 系コマンド完了時に auto-trigger し、自セッションが編集したファイルのみを `git add` → Intent / Result / Prompted-by 構造化 body 付きで commit
- **verified タグ管理**: `/e2s:ok` で検証済みコミットにタグ付与（`verified/YYYYMMDD-HHMMSS-<label>`）、`/e2s:rewind` で backup タグ付きの安全な巻き戻し
- **skill 蒸留機構**: `/e2s:reflect` で verified タグ間の commit 群と session jsonl を突き合わせて skill 候補提示、`/e2s:distill` で SKILL.md 生成
- **secret filter**: `.env*` / `*.key` / credentials 系の混入防止、プロンプトに紛れる secret の正規表現スキャン
- **BREAKING**: ユーザーのグローバルルール `~/.claude/rules/git-commit-policy.md` を書き換え、「明示承認なしのコミット絶対禁止」を撤廃し、作業完了単位の自動コミット許可に変更（push は引き続き明示承認必須）

## Capabilities

### New Capabilities

- `experience-to-skill-commit`: LLM駆動の都度コミット機構。auto-trigger スキル、secret filter、Conventional Commits + Intent/Result/Prompted-by ハイブリッドフォーマット、マルチセッション安全な自編集ファイルのみステージング戦略を規定する。
- `experience-to-skill-verified-tags`: verified タグによる検証済み状態管理。タグ命名規則、`/e2s:ok` による付与フロー、`/e2s:rewind` による backup タグ付き安全巻き戻し、マルチセッション競合回避を規定する。
- `experience-to-skill-distillation`: verified タグ区間からの skill 蒸留。commit body と session jsonl の突き合わせによる素材統合、`/e2s:reflect` での skill 候補抽出、`/e2s:distill` での SKILL.md 生成、本家 skill-creator との住み分けを規定する。

### Modified Capabilities

（なし。`git-commit-policy.md` はユーザーのグローバルルールであり openspec spec ではないため、書き換えは Impact として記載）

## Impact

- **新規ファイル**:
  - `plugins/experience-to-skill/.claude-plugin/plugin.json`
  - `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md`（auto-trigger メインスキル）
  - `plugins/experience-to-skill/commands/e2s-ok.md`
  - `plugins/experience-to-skill/commands/e2s-rewind.md`
  - `plugins/experience-to-skill/commands/e2s-reflect.md`
  - `plugins/experience-to-skill/commands/e2s-distill.md`
  - `plugins/experience-to-skill/README.md`
- **変更ファイル**:
  - `.claude-plugin/marketplace.json`: `experience-to-skill` プラグイン登録
  - `~/.claude/rules/git-commit-policy.md`: 自動コミット許可ポリシーに書き換え（BREAKING）
- **依存なし**: 外部ライブラリ・MCP サーバ不要。shell と git のみで完結
- **Claude Code 本体の挙動**: 変更なし。スキルと slash command のみで動作
- **他プラグインへの影響**: 
  - `longrun:archive` / `openspec:archive` 完了時に auto-trigger 候補となるため、これらのコマンド動作は変わらないが、完了後に tag 提案フローが走る
  - 本家 `skill-creator` とはネーミング分離済み（蒸留 vs 新規作成）
- **セキュリティ影響**: secret filter 実装が甘いと credentials が commit に混入するリスクがある。設計で明示的な除外パターンと LLM による二重チェックを規定
- **マルチセッション影響**: LLM が自セッション context から編集ファイルを特定するため、同リポジトリで並行 Claude セッションを走らせても commit が混線しない
