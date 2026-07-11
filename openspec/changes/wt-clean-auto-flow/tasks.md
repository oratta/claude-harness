## 1. spec delta

- [x] 1.1 `wt-clean-target-selection` delta: 逐次処理要件を Pass 1（自動）+ Pass 2（判断バッチ）に MODIFIED。🟢/🟡 確認要件の削除、診断根拠表示・退避検証の要件化
- [x] 1.2 `wt-clean-merge-active` delta: 🔴 確認タイミングを判断バッチに MODIFIED。選択肢内容・マージ実行・競合・サニティ要件は維持

## 2. SKILL.md 改訂（正本）

- [x] 2.1 frontmatter description / version（2.0.0 → 3.0.0）更新
- [x] 2.2 「設計の核」のフロー図を 2 パス構成に更新
- [x] 2.3 絶対禁則 1 を改訂（自動実行可能な操作と AskUserQuestion 必須操作の区分）、禁則 4 に退避検証を明文化
- [x] 2.4 Step B を Pass 1 / Pass 2 に再構成（🟢 自動削除・🟡 退避検証→自動削除・DEFERRED キュー・判断バッチ UI・マージ/競合/サニティ移設）
- [x] 2.5 Step C レポート例を新フローに合わせて更新
- [x] 2.6 自己検証節に「退避検証」「診断根拠表示」を反映

## 3. 周辺同期

- [x] 3.1 `commands/wt-clean.md` の frontmatter description を同期
- [x] 3.2 `plugin.json` version 2.2.1 → 2.3.0、description 更新
- [x] 3.3 `references/wt-clean-verification.md` の evidence 項目を新フローに合わせて更新

## 4. デプロイ後（マージ後の運用）

- [ ] 4.1 change を archive し `openspec/specs/` に delta を sync する
