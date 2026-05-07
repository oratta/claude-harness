## 1. ディレクトリリネーム

- [x] 1.1 `git mv plugins/longrun/skills/longrun-planner plugins/longrun/skills/longrun-plan` で履歴を保持してリネーム
- [x] 1.2 `plugins/longrun/skills/longrun-plan/SKILL.md` の `name:` フィールドを `longrun-planner` → `longrun-plan` に更新
- [x] 1.3 SKILL.md 内に旧名称 `longrun-planner` の自己参照が残っていないことを `grep -n "longrun-planner" plugins/longrun/skills/longrun-plan/SKILL.md` で確認

## 2. plugin.json 更新

- [x] 2.1 `plugins/longrun/.claude-plugin/plugin.json` の skills 配列を `./skills/longrun-planner` → `./skills/longrun-plan` に変更
- [x] 2.2 同ファイルの `version` を `5.0.0` → `5.1.0` に更新
- [x] 2.3 `description` フィールドに本変更（命名統一・Skill tool 明示・バイアス緩和）の要旨を追記

## 3. コマンド整合

- [x] 3.1 `plugins/longrun/commands/plan.md` を `lr/commands/p.md` と同形式に書き換える: 「Skill tool を使って `longrun:longrun-plan` を `$ARGUMENTS` で呼び出す。Agent tool は使わない（longrun-plan は Skill であり Agent ではない）」を明記
- [x] 3.2 `plan.md` 内に元々あった「ディレクトリ構造ルール」「実行手順」要約は維持または削除可。Skill 本体に同内容があるため重複は削除推奨 → 削除済み
- [x] 3.3 `plugins/lr/commands/p.md` の skill 名参照を `longrun:plan` から `longrun:longrun-plan` に統一（短縮 alias を経由しない直接呼び出しに）。ただし既に `longrun:plan` が短縮 alias として動作している場合は据え置き、commands/plan.md 経由のほうを Skill 直呼び出しに変更する方針を選ぶ。実装時に挙動確認した上で決定する → Skill 直呼び出しに統一（`longrun:longrun-plan`）

## 4. orchestrator 参照追従＋バイアス緩和

- [x] 4.1 `plugins/longrun/skills/longrun-orchestrator/SKILL.md` の `longrun-planner` 参照を `longrun-plan` に置換（grep -n "longrun-planner" で対象行を全列挙して反映）
- [x] 4.2 同ファイルの「reviewer のレビュー結果を受領するフェーズ」の記述に、design.md の Decision 4 で定義したバイアス緩和プロンプトを 50 行以内で挿入（22 行で収まったため SKILL.md 直書き）
- [x] 4.3 50 行を超える場合は `plugins/longrun/skills/longrun-orchestrator/references/bias-guard.md` を新設してそこへ切り出し、SKILL.md からは「詳細は references/bias-guard.md 参照」と書く → 不要（22 行で収まったため切り出さず）

## 5. README 追従

- [x] 5.1 `plugins/longrun/README.md` の図とテキストで `longrun-planner` を `longrun-plan` に更新
- [x] 5.2 命名規則（Skill = 動詞・名詞、Agent = -er/-or の役割名）の説明を README に1ブロック追記

## 6. 残存参照の確認

- [x] 6.1 `grep -rn "longrun-planner" plugins/` の結果が機能参照では0件であることを確認（残2件はREADME変更点と plugin.json description の歴史的記述で意図的に残置）
- [x] 6.2 `grep -rn "longrun-planner" .claude/` を worktree 内で実行し、機能参照が残っていないことを確認（worktree内 .claude/ には残存なし）

## 7. 動作確認（コミット&push後にユーザーが手動実施）

- [ ] 7.1 `/plugin uninstall longrun@oratta-claude-harness` → `/reload-plugins` → `/plugin install longrun@oratta-claude-harness` → `/reload-plugins` でローカルキャッシュをクリア
- [ ] 7.2 `/longrun:plan "テスト用 brain dump"` を実行し、Skill tool 経由で `longrun-plan` が起動することを確認（Agent type not found エラーが出ないこと）
- [ ] 7.3 `/lr:p "テスト用 brain dump"` を実行し、同様に Skill tool 経由で正しく起動することを確認
- [ ] 7.4 plan.md が `_longruns/<date>_<slug>/plan.md` のサブディレクトリ配下に作成されることを確認

## 8. コミット & デプロイ

- [ ] 8.1 変更内容を Conventional Commits 形式でコミット（subject 例: `refactor(longrun): rename longrun-planner skill to longrun-plan`）
- [ ] 8.2 `~/.claude/plugins/known_marketplaces.json` でリポジトリ URL を確認し push
- [ ] 8.3 別プロジェクトで `/plugin update longrun@oratta-claude-harness` または再インストールを行い、version 5.1.0 が反映されて Agent 誤起動が再発しないことをサンプル確認
