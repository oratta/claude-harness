## change-7: repo-cleanup-final

### S1: [openspec-dedup-resolution] 生成元調査の実施と根拠の記録
- WHEN: builder が OpenSpec 4 系統の生成元調査を行う
- THEN: `.claude/skills/openspec-*/SKILL.md` の CLI 生成マーカー（author: openspec / generatedBy / compatibility）、`.agents/skills/source-command-opsx-*` の「migrated source command」表記、`which openspec`/`openspec --version` を確認し、結果を file 単位の根拠付きで decisions.md に記録する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S2: [openspec-dedup-resolution] 調査結論が decisions.md に文書化される
- WHEN: 調査が完了する
- THEN: `openspec/changes/repo-cleanup-final/decisions.md` が存在し、(a) CLI 管理/手動管理/判断不能のいずれか、(b) 採用分岐（CLI 抑制/`.claude/` 側残置削除/現状維持縮退）とその理由、の両方が記載されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S3: [openspec-dedup-resolution] 分岐 A — CLI 抑制が可能な場合
- WHEN: 4 系統が CLI 生成物であり CLI 設定で出力系統を単一化できると確認された
- THEN: 設定変更で重複が 1 系統に抑制され、設定変更内容と再現手順が decisions.md に記録される
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S4: [openspec-dedup-resolution] 分岐 B — 手動管理と確認された場合
- WHEN: 4 系統が手動管理（CLI 再生成の対象でない）と確認された
- THEN: `.claude/skills/openspec-*` と `.claude/commands/opsx/` の 2 系統は残り、`.agents/skills/openspec-*/` と `.agents/skills/source-command-opsx-*/` は git rm で削除され復元可能
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S5: [openspec-dedup-resolution] 分岐 C — 判断不能時の現状維持縮退
- WHEN: CLI 管理の疑いが残り削除が `openspec update` 等で再生成されて無効化される恐れがある
- THEN: 4 系統は削除されず現状維持され、decisions.md に「現状維持の理由」と「将来 CLI 設定で抑制する手順」が記録される
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S6: [openspec-dedup-resolution] 削除は常に git tracked で可逆
- WHEN: いずれかの系統を削除する分岐を採る
- THEN: 削除対象は削除前に git tracked であり `git rm` 相当で削除され commit 履歴から復元可能（untracked ファイルの物理削除はしない）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S7: [repo-root-cleanup] 参照ゼロの再確認
- WHEN: builder が `templates/rules/` の削除に着手する
- THEN: `grep -rn "templates/rules" plugins/ .claude-plugin/ README.md docs/`（archive・_longruns 除く）が 0 件であることを確認してから削除する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S8: [repo-root-cleanup] templates/rules ディレクトリの不存在
- WHEN: 削除完了後に `templates/rules/` の存在を確認する
- THEN: `templates/rules/` ディレクトリおよび配下 4 ファイルが存在しない（受け入れ条件 14 前半）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S9: [repo-root-cleanup] docs/cooking-mvp-mode-plan.md の削除
- WHEN: 削除完了後に `docs/cooking-mvp-mode-plan.md` の存在を確認する
- THEN: `docs/cooking-mvp-mode-plan.md` が存在しない（受け入れ条件 14 後半）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S10: [repo-root-cleanup] .gitignore の cooking コメント更新
- WHEN: `.gitignore` を読む
- THEN: 「1h-cooking session output」という旧命名コメントが残らず harvest 命名に更新されている（`grep -n "1h-cooking" .gitignore` が 0 件）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S11: [repo-root-cleanup] skill-pack SKILL.md の cooking 言及掃除
- WHEN: `plugins/skill-pack/skills/skill-pack/SKILL.md` を読む
- THEN: cooking 例示・言及が現行実態に即した表現へ更新され、`1h-cooking` / `cooking@1h-cooking` の旧命名残骸が実例説明として残っていない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S12: [repo-root-cleanup] skillOverrides 適用範囲の明記
- WHEN: `plugins/skill-pack/skills/skill-pack/SKILL.md` を読む
- THEN: `skillOverrides` が個人スキル（`~/.claude/skills/`）対象で plugin skill を制御しないこと、plugin スキルは `enabledPlugins` で plugin 単位に ON/OFF する旨が `on`/`off` 説明付近に明記されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S13: [repo-root-cleanup] realpath "$0" の除去と CLAUDE_PLUGIN_ROOT 化
- WHEN: `plugins/experience-to-skill/commands/e2s-distill.md` を読む
- THEN: `realpath "$0"` を用いた PLUGIN_ROOT 導出が存在せず、plugin ルート解決が `${CLAUDE_PLUGIN_ROOT}` を基点に行われている（`grep -n 'realpath "\$0"' plugins/experience-to-skill/commands/e2s-distill.md` が 0 件）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S14: [marketplace-final-sync] skill-pack / experience-to-skill の version bump
- WHEN: 本 change が skill-pack と experience-to-skill を編集した後に両者の plugin.json を読む
- THEN: 両 plugin.json の version が編集前より bump されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S15: [marketplace-final-sync] 他 change 編集分の version bump 確認
- WHEN: infra / longrun / lr / worktree / daily-report / weekly-report の plugin.json を読む
- THEN: 各 version が本 run の編集に対応して bump されている（未 bump は本 change で補完）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S16: [marketplace-final-sync] version の完全一致
- WHEN: marketplace.json の各エントリ version と対応 plugin.json の version を比較する
- THEN: 8 プラグイン（infra/longrun/lr/worktree/daily-report/weekly-report/skill-pack/experience-to-skill）全てで両者が完全一致する（受け入れ条件 15）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S17: [marketplace-final-sync] description の同期
- WHEN: marketplace.json の各エントリ description と対応 plugin.json の description を比較する
- THEN: 各プラグインで両者が一致する（plugin.json 側を正）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S18: [marketplace-final-sync] 廃止 2 プラグインのエントリに触れない
- WHEN: 本 change が marketplace.json を編集する
- THEN: obsidian-llm-session-rules / skill-aware-workflow のエントリ除去は change-6 の責務であり本 change はそれらの version/description を触らない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S19: [marketplace-final-sync] change-7 固有条件（14/15）の検証
- WHEN: 統合検証を実行する
- THEN: `templates/rules/` 不存在・`docs/cooking-mvp-mode-plan.md` 不存在（条件 14）、全編集プラグインで plugin.json version == marketplace.json version（条件 15）が確認される
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S20: [marketplace-final-sync] 他 change 由来条件（5-13, 16）の横断検証
- WHEN: 統合検証を実行する
- THEN: 条件 5/6/7/8/9/10/11/12/13/16 の各 grep/ls が期待値になり、逸脱があれば該当 change 担当へ差し戻す
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S21: [marketplace-final-sync] 全 *.json の parse 検証
- WHEN: 統合検証の一部として全 JSON の構文を確認する
- THEN: marketplace.json を含む全 `*.json` が JSON として parse 可能である（受け入れ条件 3 の一部）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了
