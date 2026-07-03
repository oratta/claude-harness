# Tasks: infra-fixes

## 1. Phase 5 の `.env.production.local` 方式への統一

- [x] 1.1 `plugins/infra/agents/infra-phase-5-finalize.md` の「あなたのゴール」1項目目（:13）を「`.env.local` の dev 値検証 + `.env.production.local` の prod 値検証」に書き換える
- [x] 1.2 Step 2（`.env.local` 最終検証）の grep コマンドと期待状態の記述（:39-60）を、`.env.local` は dev 値、`.env.production.local` は prod 値（active）という 2 ファイル検証に書き換える。「prod 側の `# NEXT_PUBLIC_SUPABASE_URL=...` はコメントアウトで保存されている」という記述を削除する
- [x] 1.3 「重要な注意事項」節（:225 付近）の「`.env.local` の prod系がコメントアウトで保存されている前提を崩さない」を「`.env.production.local` に prod 値が分離保存されている前提を崩さない」に書き換える
- [x] 1.4 `grep -n "コメントアウト" plugins/infra/agents/infra-phase-5-finalize.md` を実行し、prod 値保存方式に関する一致が 0 件であることを確認する（受け入れ条件 6）

## 2. Secrets 名の投入/参照一致

- [x] 2.1 `grep -rho 'secrets\.[A-Z_]*' plugins/infra/templates/ | sort -u` を実行し、現在の Phase 4 投入リストとの差分を確定する（受け入れ条件 5 の事前確認）
- [x] 2.2 `plugins/infra/agents/infra-phase-2-supabase.md` の API Keys 取得ステップ（Step 9）に、prod プロジェクトの `service_role` key 抽出コマンドを追加する
- [x] 2.3 同ファイルの `.env.production.local` 書き込みステップ（Step 11.5）に `SUPABASE_SERVICE_ROLE_KEY`（もしくは同義の変数名）を追記する。`.env.local` 側（Step 11）には追記しない
- [x] 2.4 state ファイル書き込みステップ（Step 13）に service_role key の実値が書き込まれていないことを確認する（既存の「機密情報は state に書かない」原則を踏襲するのみで変更不要な場合はそのまま）
- [x] 2.5 `plugins/infra/agents/infra-phase-4-github-actions.md` の Step 6（`.env.local`/`.env.production.local` からの値読み取り）に、`NEXT_PUBLIC_SUPABASE_URL`/`NEXT_PUBLIC_SUPABASE_ANON_KEY`（`.env.local` の dev 値）と `PROD_SUPABASE_URL`/`PROD_SUPABASE_ANON_KEY`/`PROD_SUPABASE_SERVICE_ROLE_KEY`（`.env.production.local` の値）の読み取りコマンドを追加する
- [x] 2.6 同ファイルの Step 7（`gh secret set`）に上記 5 secrets の投入コマンドを追加する
- [x] 2.7 同ファイルの Step 9（state 書き込み）の `secrets_set` リストと Step 10（完了報告）の一覧を新しい 5 secrets を含む内容に更新する
- [x] 2.8 `grep -rho 'secrets\.[A-Z_]*' plugins/infra/templates/ | sort -u` の全項目（`GITHUB_TOKEN` 除く）について `grep -q "gh secret set <NAME>"` 相当の存在確認を行い、全て PASS することを確認する（受け入れ条件 5）

## 3. GitHub Actions バージョン bump

- [x] 3.1 `gh api /repos/actions/checkout/tags --jq '.[0].name'` 等で 5 種類（`actions/checkout` / `actions/setup-node` / `actions/upload-artifact` / `actions/github-script` / `supabase/setup-cli`）の最新メジャータグを実装時点で再確認する（design.md D3 のタグ名は執筆時点のスナップショット。異なっていれば実装時点の値を採用する）
- [x] 3.2 `plugins/infra/templates/workflows/*.yml.template`（5ファイル全て）の該当 action バージョンピンを確認済み最新メジャータグへ更新する
- [x] 3.3 `grep -rn "actions/checkout@v4\|actions/setup-node@v4\|actions/upload-artifact@v4\|actions/github-script@v7\|supabase/setup-cli@v1" plugins/infra/templates/workflows/` を実行し 0 件であることを確認する
- [x] 3.4 バージョン bump 後の各テンプレートが YAML として妥当であることを確認する（`{{NODE_VERSION}}` 等のプレースホルダー行を除き構文が壊れていないか目視 + 可能なら YAML パーサで検証）

## 4. Vercel Token CLI 化検証の反映

- [x] 4.1 `vercel help` / `vercel tokens --help` で `tokens`/`token` サブコマンドの有無を実装時点で再確認する（design.md D4 は 48.12.0 時点の結果。CLI がアップデートされ `tokens` サブコマンドが追加されていれば config.yaml rule に従い CLI 化を検討し直す。存在しなければ以下を進める）
- [x] 4.2 `plugins/infra/agents/infra-phase-4-github-actions.md` Step 5 に CLI 化検証結果（不可と判定した場合はその旨、可能であれば CLI 化を実施）の注記を追加する
- [x] 4.3 `plugins/infra/skills/infra-setup/SKILL.md` の「技術メモ」節の Vercel Token 記述に同様の注記を追加する

## 5. 文書整合性の解消

- [x] 5.1 `plugins/infra/skills/infra-setup/SKILL.md:40` の「PR時は CI のみで自動 preview deploy は行わない（個人開発前提）」を「Draft 中は CI・Preview deploy を skip し、Ready for review で Preview deploy が実行される」という趣旨に書き換える
- [x] 5.2 `plugins/infra/agents/infra-phase-5-finalize.md:179` の「自動 Preview deploy は行われません」を同様に書き換える
- [x] 5.3 `grep -n "自動 preview deploy は行わない\|自動 Preview deploy は行われません" plugins/infra/skills/infra-setup/SKILL.md plugins/infra/agents/infra-phase-5-finalize.md` が 0 件であることを確認する
- [x] 5.4 `plugins/infra/README.md` を本 change 適用前後で diff し、Preview deploy 方針に関する行に差分がないことを確認する（変更対象外の再確認）
- [x] 5.5 `plugins/infra/agents/infra-phase-1-hearing.md` の「Phase 2 の Step 10」「Step 10.5」という参照を「Step 11」「Step 11.5」に修正する
- [x] 5.6 `grep -n "Step 10\.5\|の Step 10）" plugins/infra/agents/infra-phase-1-hearing.md` が 0 件であることを確認する
- [x] 5.7 `plugins/infra/agents/infra-phase-3-vercel.md` のトラブルシューティング節の `vercel link` 案内冒頭に「（既存プロジェクトへの再リンク時のみ。新規作成は Step 3 の対話フローに従うこと）」を追記する
- [x] 5.8 `plugins/infra/skills/infra-setup/SKILL.md` のアーキテクチャ図 `infra-phase-4-github-actions` の説明行に `deploy-preview` を追加する
- [x] 5.9 `plugins/infra/skills/infra-setup/SKILL.md` frontmatter の `version: 0.1.0` を、タスク 6 で bump 後の `plugin.json` バージョンと一致させる
- [x] 5.10 `plugins/infra/skills/infra-setup/SKILL.md:261` の `/Users/oratta/Dropbox/...` 個人パス参照行を削除する
- [x] 5.11 `grep -rn "/Users/oratta" plugins/infra/` が 0 件であることを確認する

## 6. バージョン同期

- [x] 6.1 `plugins/infra/.claude-plugin/plugin.json` の `version`（現行 `0.2.0`）を本 change の内容量に応じて bump する（marketplace.json 側の同期は change-7 が担当。ここでは plugin.json のみ）
- [x] 6.2 タスク 5.9 の SKILL.md frontmatter version が 6.1 の bump 後の値と一致していることを再確認する

## 7. 統合検証

- [x] 7.1 受け入れ条件 5: `grep -rho 'secrets\.[A-Z_]*' plugins/infra/templates/ | sort -u` の全項目（`GITHUB_TOKEN` 除く）が Phase 4 の `gh secret set` 投入リストに存在することを確認する
- [x] 7.2 受け入れ条件 6: `agents/infra-phase-5-finalize.md` に「コメントアウトで prod 値を保存」する旧方式の記述が残っていないことを確認する
- [x] 7.3 `find plugins/infra -name '*.bats'` があれば実行する（infra プラグインに既存 bats テストがなければ skip し、その旨を記録する）
- [x] 7.4 変更した全 `.md` / `.yml.template` / `plugin.json` について、意図しない差分（特に README.md・実装ロジックが変わっていないか）を `git diff` で目視確認する
