## change-1: infra-fixes

### S1: [infra-env-file-scheme] No commented-out prod value expectation remains
- WHEN: `plugins/infra/agents/infra-phase-5-finalize.md` を grep で「コメントアウト」を検索する
- THEN: prod 値の保存形式に関する文脈での一致は 0 件
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S2: [infra-env-file-scheme] Step 2 checks both env files
- WHEN: Step 2（`.env.local` 最終検証）のセクション本文を読む
- THEN: `.env.production.local` というファイル名が明示的に検証対象として言及されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S3: [infra-env-file-scheme] Goal description matches the two-file scheme
- WHEN: ファイル冒頭の「あなたのゴール」1項目目を読む
- THEN: 「prod 側はコメントアウト状態」という記述は存在せず、`.env.production.local` の検証を指す記述に置き換わっている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S4: [infra-env-file-scheme] Cautions section updated
- WHEN: 「重要な注意事項」節を読む
- THEN: 「`.env.local` の prod系がコメントアウトで保存されている前提を崩さない」という記述は存在せず、`.env.production.local` に prod 値が分離保存されている前提の記述に置き換わっている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S5: [infra-env-file-scheme] Repository-wide acceptance check
- WHEN: `grep -n "コメントアウト" plugins/infra/agents/infra-phase-5-finalize.md` を実行する
- THEN: prod 値の保存方式に関する一致が 0 件（`.env.production.local` 方式に統一されている）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S6: [infra-secrets-consistency] Template-referenced secrets are a subset of the investment list
- WHEN: `grep -rho 'secrets\.[A-Z_]*' plugins/infra/templates/ | sort -u` を実行し、`GITHUB_TOKEN` を除いた各項目について `agents/infra-phase-4-github-actions.md` を grep する
- THEN: `NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` / `PROD_SUPABASE_URL` / `PROD_SUPABASE_ANON_KEY` / `PROD_SUPABASE_SERVICE_ROLE_KEY` / `PROD_SUPABASE_PROJECT_REF` / `PROD_SUPABASE_DB_URL` / `SUPABASE_ACCESS_TOKEN` / `VERCEL_TOKEN` / `VERCEL_ORG_ID` / `VERCEL_PROJECT_ID` の全てについて `gh secret set <NAME>` の行が Step 7 に存在する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S7: [infra-secrets-consistency] EDGE_CONFIG_ID remains explicitly documented as optional
- WHEN: `agents/infra-phase-4-github-actions.md` の `EDGE_CONFIG_ID` に関する記述を読む
- THEN: 「メンテナンスモードを使う場合のみ必要」という opt-in の位置づけと `gh secret set EDGE_CONFIG_ID` コマンド例の両方が含まれている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S8: [infra-secrets-consistency] Phase 2 extracts the service_role key alongside anon
- WHEN: `agents/infra-phase-2-supabase.md` の API Keys 取得ステップ本文を読む
- THEN: `anon` key の抽出手順に加えて `service_role` key を prod プロジェクトから抽出する手順が明記されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S9: [infra-secrets-consistency] service_role key is written only to .env.production.local
- WHEN: `agents/infra-phase-2-supabase.md` の `.env.production.local` 書き込みステップと `.env.local` 書き込みステップの両方を読む
- THEN: service_role key への言及は `.env.production.local` 側にのみ存在し、`.env.local` 側には存在しない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S10: [infra-secrets-consistency] State file does not record the raw service_role key value
- WHEN: `agents/infra-phase-2-supabase.md` の state ファイル書き込みステップ（Phase 2 セクション）を読む
- THEN: service_role key の実値がその中に書き込まれる記述は存在しない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S11: [infra-secrets-consistency] Prod secrets read from the production env file
- WHEN: Phase 4 の Step 6 または Step 7 付近で `PROD_SUPABASE_URL` / `PROD_SUPABASE_ANON_KEY` / `PROD_SUPABASE_SERVICE_ROLE_KEY` を取得するコマンドを読む
- THEN: 取得元として `.env.production.local` が明示されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S12: [infra-secrets-consistency] CI secrets read from the dev-active local env file
- WHEN: Phase 4 の Step 6 または Step 7 付近で `NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` を取得するコマンドを読む
- THEN: 取得元として `.env.local` が明示されている
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S13: [infra-actions-freshness] No stale v4 pins for checkout/setup-node remain
- WHEN: `grep -rn "actions/checkout@v4\|actions/setup-node@v4" plugins/infra/templates/workflows/` を実行する
- THEN: 一致件数は 0 件
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S14: [infra-actions-freshness] No stale v4 pin for upload-artifact remains
- WHEN: `grep -rn "actions/upload-artifact@v4" plugins/infra/templates/workflows/` を実行する
- THEN: 一致件数は 0 件
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S15: [infra-actions-freshness] No stale v7 pin for github-script remains
- WHEN: `grep -rn "actions/github-script@v7" plugins/infra/templates/workflows/` を実行する
- THEN: 一致件数は 0 件
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S16: [infra-actions-freshness] No stale v1 pin for supabase/setup-cli remains
- WHEN: `grep -rn "supabase/setup-cli@v1" plugins/infra/templates/workflows/` を実行する
- THEN: 一致件数は 0 件
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S17: [infra-actions-freshness] All five workflow templates still pass node --check equivalent (YAML parse)
- WHEN: バージョン bump 後の各 `.yml.template` を YAML としてパースする
- THEN: 5 ファイル全てがパースエラーなく成功する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S18: [infra-actions-freshness] Investigation note present in Phase 4 agent
- WHEN: `agents/infra-phase-4-github-actions.md` の Vercel Token 取得ステップ（Step 5）を読む
- THEN: CLI 化を検証し不可と判定した旨の注記が存在する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S19: [infra-actions-freshness] Investigation note present in SKILL.md
- WHEN: `skills/infra-setup/SKILL.md` の「技術メモ」節にある Vercel Token の記述を読む
- THEN: CLI 化を検証し不可と判定した旨の注記が存在する
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S20: [infra-actions-freshness] Fallback logic is unchanged
- WHEN: Step 5（自動モード / 手動モード）の分岐構造を変更前後で比較する
- THEN: 2 分岐構造・各モードの操作手順に実質的な差分がない（注記の追加のみ）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S21: [infra-doc-integrity] SKILL.md no longer claims no automatic preview deploy
- WHEN: `grep -n "自動 preview deploy は行わない\|自動 Preview deploy は行われません" plugins/infra/skills/infra-setup/SKILL.md plugins/infra/agents/infra-phase-5-finalize.md` を実行する
- THEN: 一致件数は 0 件
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S22: [infra-doc-integrity] Updated wording states Ready-for-review triggers real deploy
- WHEN: `skills/infra-setup/SKILL.md` の「ポイント」文と `agents/infra-phase-5-finalize.md` の「PR Preview について」節を読む
- THEN: 両方に「Draft 中は skip」「Ready for review で Preview deploy が実行される」という趣旨の記述が含まれる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S23: [infra-doc-integrity] README.md remains unchanged
- WHEN: 本 change 適用前後で `plugins/infra/README.md` を diff する
- THEN: Preview deploy 方針に関する行に差分がない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S24: [infra-doc-integrity] Step number references corrected
- WHEN: `agents/infra-phase-1-hearing.md` 内の「Phase 2 の手順（Step ...）」という参照文を読む
- THEN: `.env.local` 書き込みへの参照は「Step 11」、`.env.production.local` 書き込みへの参照は「Step 11.5」
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S25: [infra-doc-integrity] No stale step-number grep hits
- WHEN: `grep -n "Step 10\.5\|の Step 10）" plugins/infra/agents/infra-phase-1-hearing.md` を実行する
- THEN: 一致件数は 0 件
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S26: [infra-doc-integrity] Troubleshooting section scoped to re-link case
- WHEN: `agents/infra-phase-3-vercel.md` のトラブルシューティング節にある `vercel link` の記述を読む
- THEN: 「既存プロジェクトへの再リンク時のみ」等、新規作成フロー（Step 3）とは異なるケースであることを明示する文言が含まれる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S27: [infra-doc-integrity] No unqualified contradictory statement remains
- WHEN: Step 3 本文とトラブルシューティング節の `vercel link` 関連記述を並べて読む
- THEN: 適用ケースの違いなしに矛盾する説明が並存していない
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S28: [infra-doc-integrity] deploy-preview appears in the Phase 4 line
- WHEN: `skills/infra-setup/SKILL.md` のアーキテクチャ図内 `infra-phase-4-github-actions` の説明行を読む
- THEN: `deploy-preview` という語がその行に含まれる
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S29: [infra-doc-integrity] SKILL.md version matches plugin.json
- WHEN: `skills/infra-setup/SKILL.md` の frontmatter `version` と `plugins/infra/.claude-plugin/plugin.json` の `version` を比較する
- THEN: 両者は同一の値
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S30: [infra-doc-integrity] No personal Dropbox path remains
- WHEN: `grep -rn "/Users/oratta" plugins/infra/` を実行する
- THEN: 一致件数は 0 件
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S31: [infra-doc-integrity] plugin.json version is bumped
- WHEN: 本 change 適用前後で `plugins/infra/.claude-plugin/plugin.json` の `version` フィールドを比較する
- THEN: 適用後の値が適用前の値より大きい（semver 上位）
- [ ] テスト実装完了
- [ ] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了
