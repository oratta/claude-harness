## 1. spec delta

- [x] 1.1 `wt-clean-target-selection` delta: REMOVED「引数なし時は対象選択 UI で TARGETS を選ばせる」、ADDED「引数なし時は全 worktree をデフォルト対象にする（対象選択 UI なし）」、MODIFIED「引数なし時は遅延診断で worktree をリストアップする」（文言調整）

## 2. SKILL.md 改訂（正本）

- [x] 2.1 frontmatter description / version（3.0.0 → 3.1.0）更新
- [x] 2.2 「設計の核」とフロー図から対話ポイント①（Step A 対象選択）を削除し、Pass 2 を唯一の対話ポイントに
- [x] 2.3 オプション節に「位置引数なし = 全件確定なしで対象」を明記
- [x] 2.4 Step A-2 を「対象選択 UI で選ばせる」から「全 worktree を確認なしで TARGETS に」へ書き換え（AskUserQuestion 廃止・SHALL NOT 明記）
- [x] 2.5 Step C レポート例の「選択: 全て」を「全件・確認なし」に更新

## 3. 周辺同期

- [x] 3.1 `commands/wt-clean.md` の frontmatter description を同期
- [x] 3.2 `plugin.json` version 2.3.0 → 2.4.0、description 更新

## 4. デプロイ後（マージ後の運用）

- [ ] 4.1 change を archive し `openspec/specs/` に delta を sync する
