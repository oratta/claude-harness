# Verification Guide

## 環境
- 対象: CLI（Claude Code セッション内）。Web UI なし
- テスト: `find plugins -name '*.bats' -print0 | xargs -0 bats`
- 構文検証: `node --check`（workflow テンプレ・.mjs）/ JSON parse（全 *.json）
- 参照ゼロ検証: plan.md 受け入れ条件 5-16 の grep / ls コマンド一式
- worktree: ~/.superset/worktrees/plugin-review-fixes（branch: longrun/plugin-review-fixes, Draft PR #8）

## change-1: infra-fixes

### S1: [infra-env-file-scheme] No commented-out prod value expectation remains
- WHEN: `plugins/infra/agents/infra-phase-5-finalize.md` を grep で「コメントアウト」を検索する
- THEN: prod 値の保存形式に関する文脈での一致は 0 件
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S2: [infra-env-file-scheme] Step 2 checks both env files
- WHEN: Step 2（`.env.local` 最終検証）のセクション本文を読む
- THEN: `.env.production.local` というファイル名が明示的に検証対象として言及されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S3: [infra-env-file-scheme] Goal description matches the two-file scheme
- WHEN: ファイル冒頭の「あなたのゴール」1項目目を読む
- THEN: 「prod 側はコメントアウト状態」という記述は存在せず、`.env.production.local` の検証を指す記述に置き換わっている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S4: [infra-env-file-scheme] Cautions section updated
- WHEN: 「重要な注意事項」節を読む
- THEN: 「`.env.local` の prod系がコメントアウトで保存されている前提を崩さない」という記述は存在せず、`.env.production.local` に prod 値が分離保存されている前提の記述に置き換わっている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S5: [infra-env-file-scheme] Repository-wide acceptance check
- WHEN: `grep -n "コメントアウト" plugins/infra/agents/infra-phase-5-finalize.md` を実行する
- THEN: prod 値の保存方式に関する一致が 0 件（`.env.production.local` 方式に統一されている）
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S6: [infra-secrets-consistency] Template-referenced secrets are a subset of the investment list
- WHEN: `grep -rho 'secrets\.[A-Z_]*' plugins/infra/templates/ | sort -u` を実行し、`GITHUB_TOKEN` を除いた各項目について `agents/infra-phase-4-github-actions.md` を grep する
- THEN: `NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` / `PROD_SUPABASE_URL` / `PROD_SUPABASE_ANON_KEY` / `PROD_SUPABASE_SERVICE_ROLE_KEY` / `PROD_SUPABASE_PROJECT_REF` / `PROD_SUPABASE_DB_URL` / `SUPABASE_ACCESS_TOKEN` / `VERCEL_TOKEN` / `VERCEL_ORG_ID` / `VERCEL_PROJECT_ID` の全てについて `gh secret set <NAME>` の行が Step 7 に存在する
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S7: [infra-secrets-consistency] EDGE_CONFIG_ID remains explicitly documented as optional
- WHEN: `agents/infra-phase-4-github-actions.md` の `EDGE_CONFIG_ID` に関する記述を読む
- THEN: 「メンテナンスモードを使う場合のみ必要」という opt-in の位置づけと `gh secret set EDGE_CONFIG_ID` コマンド例の両方が含まれている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S8: [infra-secrets-consistency] Phase 2 extracts the service_role key alongside anon
- WHEN: `agents/infra-phase-2-supabase.md` の API Keys 取得ステップ本文を読む
- THEN: `anon` key の抽出手順に加えて `service_role` key を prod プロジェクトから抽出する手順が明記されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S9: [infra-secrets-consistency] service_role key is written only to .env.production.local
- WHEN: `agents/infra-phase-2-supabase.md` の `.env.production.local` 書き込みステップと `.env.local` 書き込みステップの両方を読む
- THEN: service_role key への言及は `.env.production.local` 側にのみ存在し、`.env.local` 側には存在しない
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S10: [infra-secrets-consistency] State file does not record the raw service_role key value
- WHEN: `agents/infra-phase-2-supabase.md` の state ファイル書き込みステップ（Phase 2 セクション）を読む
- THEN: service_role key の実値がその中に書き込まれる記述は存在しない
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S11: [infra-secrets-consistency] Prod secrets read from the production env file
- WHEN: Phase 4 の Step 6 または Step 7 付近で `PROD_SUPABASE_URL` / `PROD_SUPABASE_ANON_KEY` / `PROD_SUPABASE_SERVICE_ROLE_KEY` を取得するコマンドを読む
- THEN: 取得元として `.env.production.local` が明示されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S12: [infra-secrets-consistency] CI secrets read from the dev-active local env file
- WHEN: Phase 4 の Step 6 または Step 7 付近で `NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` を取得するコマンドを読む
- THEN: 取得元として `.env.local` が明示されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S13: [infra-actions-freshness] No stale v4 pins for checkout/setup-node remain
- WHEN: `grep -rn "actions/checkout@v4\|actions/setup-node@v4" plugins/infra/templates/workflows/` を実行する
- THEN: 一致件数は 0 件
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S14: [infra-actions-freshness] No stale v4 pin for upload-artifact remains
- WHEN: `grep -rn "actions/upload-artifact@v4" plugins/infra/templates/workflows/` を実行する
- THEN: 一致件数は 0 件
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S15: [infra-actions-freshness] No stale v7 pin for github-script remains
- WHEN: `grep -rn "actions/github-script@v7" plugins/infra/templates/workflows/` を実行する
- THEN: 一致件数は 0 件
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S16: [infra-actions-freshness] No stale v1 pin for supabase/setup-cli remains
- WHEN: `grep -rn "supabase/setup-cli@v1" plugins/infra/templates/workflows/` を実行する
- THEN: 一致件数は 0 件
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S17: [infra-actions-freshness] All five workflow templates still pass node --check equivalent (YAML parse)
- WHEN: バージョン bump 後の各 `.yml.template` を YAML としてパースする
- THEN: 5 ファイル全てがパースエラーなく成功する
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S18: [infra-actions-freshness] Investigation note present in Phase 4 agent
- WHEN: `agents/infra-phase-4-github-actions.md` の Vercel Token 取得ステップ（Step 5）を読む
- THEN: CLI 化を検証し不可と判定した旨の注記が存在する
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S19: [infra-actions-freshness] Investigation note present in SKILL.md
- WHEN: `skills/infra-setup/SKILL.md` の「技術メモ」節にある Vercel Token の記述を読む
- THEN: CLI 化を検証し不可と判定した旨の注記が存在する
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S20: [infra-actions-freshness] Fallback logic is unchanged
- WHEN: Step 5（自動モード / 手動モード）の分岐構造を変更前後で比較する
- THEN: 2 分岐構造・各モードの操作手順に実質的な差分がない（注記の追加のみ）
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S21: [infra-doc-integrity] SKILL.md no longer claims no automatic preview deploy
- WHEN: `grep -n "自動 preview deploy は行わない\|自動 Preview deploy は行われません" plugins/infra/skills/infra-setup/SKILL.md plugins/infra/agents/infra-phase-5-finalize.md` を実行する
- THEN: 一致件数は 0 件
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S22: [infra-doc-integrity] Updated wording states Ready-for-review triggers real deploy
- WHEN: `skills/infra-setup/SKILL.md` の「ポイント」文と `agents/infra-phase-5-finalize.md` の「PR Preview について」節を読む
- THEN: 両方に「Draft 中は skip」「Ready for review で Preview deploy が実行される」という趣旨の記述が含まれる
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S23: [infra-doc-integrity] README.md remains unchanged
- WHEN: 本 change 適用前後で `plugins/infra/README.md` を diff する
- THEN: Preview deploy 方針に関する行に差分がない
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S24: [infra-doc-integrity] Step number references corrected
- WHEN: `agents/infra-phase-1-hearing.md` 内の「Phase 2 の手順（Step ...）」という参照文を読む
- THEN: `.env.local` 書き込みへの参照は「Step 11」、`.env.production.local` 書き込みへの参照は「Step 11.5」
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S25: [infra-doc-integrity] No stale step-number grep hits
- WHEN: `grep -n "Step 10\.5\|の Step 10）" plugins/infra/agents/infra-phase-1-hearing.md` を実行する
- THEN: 一致件数は 0 件
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S26: [infra-doc-integrity] Troubleshooting section scoped to re-link case
- WHEN: `agents/infra-phase-3-vercel.md` のトラブルシューティング節にある `vercel link` の記述を読む
- THEN: 「既存プロジェクトへの再リンク時のみ」等、新規作成フロー（Step 3）とは異なるケースであることを明示する文言が含まれる
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S27: [infra-doc-integrity] No unqualified contradictory statement remains
- WHEN: Step 3 本文とトラブルシューティング節の `vercel link` 関連記述を並べて読む
- THEN: 適用ケースの違いなしに矛盾する説明が並存していない
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S28: [infra-doc-integrity] deploy-preview appears in the Phase 4 line
- WHEN: `skills/infra-setup/SKILL.md` のアーキテクチャ図内 `infra-phase-4-github-actions` の説明行を読む
- THEN: `deploy-preview` という語がその行に含まれる
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S29: [infra-doc-integrity] SKILL.md version matches plugin.json
- WHEN: `skills/infra-setup/SKILL.md` の frontmatter `version` と `plugins/infra/.claude-plugin/plugin.json` の `version` を比較する
- THEN: 両者は同一の値
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S30: [infra-doc-integrity] No personal Dropbox path remains
- WHEN: `grep -rn "/Users/oratta" plugins/infra/` を実行する
- THEN: 一致件数は 0 件
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S31: [infra-doc-integrity] plugin.json version is bumped
- WHEN: 本 change 適用前後で `plugins/infra/.claude-plugin/plugin.json` の `version` フィールドを比較する
- THEN: 適用後の値が適用前の値より大きい（semver 上位）
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

## change-2: longrun-browser-verify-restore

### S1: [longrun-browser-verify-step] Verify フェーズが静的とブラウザの両 verifier を起動する
- WHEN: レンダリング済みの build-verify workflow の Verify フェーズが 1 周実行される
- THEN: browser-verifier 埋め込みポイント（既定 longrun:longrun-browser-verifier）を agentType とする agent() 呼び出しと、静的 verifier（既定 longrun:longrun-verifier）を agentType とする agent() 呼び出しが同じ Verify フェーズ内に存在する
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S2: [longrun-browser-verify-step] 総合 verdict は両 verifier の論理積である
- WHEN: 静的 verifier または browser verifier のいずれかが FAIL を返す／両方が PASS を返す
- THEN: いずれか FAIL の周は総合 FAIL で builder への修正依頼へ進み、両方 PASS のとき Verify ループは stopReason=PASS で停止する
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S3: [longrun-browser-verify-step] workflow のしきい値が schema の description と一致する
- WHEN: build-verify workflow のしきい値記述（functionality=100 / quality=100 / completeness>=80 / ux>=70）と verifier-score.schema.json の各軸 description のしきい値を突き合わせる
- THEN: 4 軸すべてでしきい値が一致する
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S4: [longrun-browser-verify-step] schema が外部ファイルを唯一のソースとする GATE が維持される
- WHEN: レンダリング前のテンプレート（build-verify.workflow.js）と verifier-score.schema.json を確認する
- THEN: schema 本体（プロパティ定義）はテンプレートに直書きされておらず、__VERIFIER_SCHEMA__ 等の埋め込みポイント経由で外部ファイルから注入されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S5: [longrun-browser-verify-step] BROWSER_VERIFIER_MODEL 未指定でも render が落ちない
- WHEN: BROWSER_VERIFIER_MODEL を含まない params.json で render-workflow.mjs に build-verify テンプレートを渡す
- THEN: render はエラー終了せず、__BROWSER_VERIFIER_MODEL__ が null に置換された出力を生成する
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S6: [longrun-browser-verify-step] BROWSER_VERIFIER_MODEL が null のとき model キーを出力しない
- WHEN: BROWSER_VERIFIER_MODEL が null でレンダリングされた build-verify workflow の browser-verifier の agent() 呼び出しを確認する
- THEN: その opts に model キーが含まれていない
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S7: [longrun-browser-verify-step] exec.md の params 表に browser-verifier 埋め込みポイントが記載されている
- WHEN: commands/exec.md の Step 2 params 表を確認する
- THEN: BROWSER_VERIFIER_AGENT_TYPE（既定 longrun:longrun-browser-verifier）と BROWSER_VERIFIER_MODEL の行が存在する
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S8: [longrun-browser-verify-step] レンダリング済み build-verify workflow が node --check PASS する
- WHEN: render-workflow.mjs で build-verify テンプレートをレンダリングし、生成された .js に node --check を実行する
- THEN: 構文エラーなく終了コード 0 で完了する
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S9: [longrun-browser-verify-step] 4 軸が漏れなく重複なく 2 verifier に割り当てられている
- WHEN: longrun-verifier.md / longrun-browser-verifier.md の担当宣言と workflow の各 verifier 呼び出しの採点対象軸を突き合わせる
- THEN: quality / completeness は静的 verifier のみ、functionality / ux は browser verifier のみが担当し、4 軸すべてがちょうど一方に割り当てられている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S10: [longrun-workflow-reference-bundle] reference が references ディレクトリ配下に存在する
- WHEN: plugins/longrun/references/workflow-tool-reference.md の有無を確認する
- THEN: ファイルが存在し、Workflow ツールのシグネチャ・制約の記述を含む
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S11: [longrun-workflow-reference-bundle] plugins 配下に _longruns/2026-06-12 参照が残っていない
- WHEN: grep -rn "_longruns/2026-06-12" plugins/ を実行する
- THEN: 一致行が 0 件である
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S12: [longrun-workflow-reference-bundle] 参照元 3 箇所が配布物内パスを指す
- WHEN: commands/exec.md / build-verify.workflow.js / review.workflow.js の一次ソース参照記述を確認する
- THEN: 3 箇所すべてが ${CLAUDE_PLUGIN_ROOT}/references/（またはテンプレートコメントの plugins/longrun/references/）配下の workflow-tool-reference.md を指し、_longruns/2026-06-12 を含まない
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S13: [longrun-workflow-reference-bundle] 元パスに移動先を示すスタブが残る
- WHEN: 移動後に _longruns/2026-06-12_harness-workflow-overhaul/workflow-tool-reference.md を確認する
- THEN: ファイルが存在し、移動先 plugins/longrun/references/workflow-tool-reference.md へのポインタ（移動済みである旨と新パス）が記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

## change-3: longrun-v5-cleanup

### S1: [longrun-orphan-cleanup] longrun-verifier context restoration step
- WHEN: a reader opens `plugins/longrun/agents/longrun-verifier.md` and reads its "コンテキスト復元" step (current line ~37)
- THEN: the step MUST list `{longrun-dir}/plan.md` and `{longrun-dir}/decisions.md` as the primary sources of current state, and MUST NOT state that `checkpoint.md` is read to "把握" current status as the first/primary action
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S2: [longrun-orphan-cleanup] longrun-verifier FAIL escalation step
- WHEN: a reader opens `plugins/longrun/agents/longrun-verifier.md` and reads its "FAILの場合" step (current line ~98)
- THEN: the step MUST NOT contain "orchestratorに修正を依頼" and MUST describe returning a structured FAIL result that the generated Workflow script uses to re-invoke `longrun-builder`
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S3: [longrun-orphan-cleanup] longrun-browser-verifier context restoration step
- WHEN: a reader opens `plugins/longrun/agents/longrun-browser-verifier.md` and reads its "コンテキスト復元" step (current line ~101)
- THEN: the step MUST list `{longrun-dir}/plan.md` and `{longrun-dir}/decisions.md` as primary sources, MUST NOT prioritize checkpoint.md
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S4: [longrun-orphan-cleanup] longrun-browser-verifier verification-guide.md provenance note
- WHEN: a reader opens `plugins/longrun/agents/longrun-browser-verifier.md` and reads the note about who generates `verification-guide.md` (current line ~151)
- THEN: the note MUST NOT attribute generation to "orchestrator"; MUST attribute it to the Build phase / `longrun-builder`
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S5: [longrun-orphan-cleanup] longrun-browser-verifier FAIL escalation step
- WHEN: a reader opens `plugins/longrun/agents/longrun-browser-verifier.md` and reads its "FAILの場合" step (current line ~187)
- THEN: the step MUST NOT contain "orchestratorに修正を依頼"; MUST describe Workflow re-invoking `longrun-builder`
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S6: [longrun-orphan-cleanup] longrun-builder description accuracy
- WHEN: a reader reads the `description` field in `plugins/longrun/agents/longrun-builder.md` frontmatter
- THEN: MUST NOT claim "checkpoint.mdを更新する"; MUST describe the TDD implementation + `builder-report` schema contract
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S7: [longrun-orphan-cleanup] exec.md historical note rewritten without the literal compound
- WHEN: a reader greps `plugins/longrun/commands/exec.md` for the exact string `longrun-orchestrator`
- THEN: MUST be zero matches, while the sentence still accurately describes what v6.0.0 removed
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S8: [longrun-orphan-cleanup] dead script removed
- WHEN: a reader checks for the existence of `plugins/longrun/scripts/update-checkpoint.sh`
- THEN: the file MUST NOT exist
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S9: [longrun-orphan-cleanup] no orphaned call sites remain after removal
- WHEN: a reader runs `grep -rn "update-checkpoint.sh" plugins/` after the deletion
- THEN: MUST be zero matches
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S10: [longrun-orphan-cleanup] GATE block removed, full mode starts directly at Step 1
- WHEN: a reader opens `plugins/longrun/skills/longrun-plan/SKILL.md`
- THEN: MUST NOT contain a `--mode=mvp` interception GATE; document begins directly with the full-mode flow
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S11: [longrun-orphan-cleanup] full-mode regression — unaffected behavior
- WHEN: a reader diffs the full-mode body (Step 1〜8, template loading, `longrun-reviewer` invocation) before and after this change
- THEN: MUST be no content differences beyond the GATE removal itself
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S12: [longrun-orphan-cleanup] unrecognized --mode=mvp argument no longer triggers a migration notice
- WHEN: a user runs `/longrun:plan --mode=mvp <任意の引数>` after this change
- THEN: MUST run full-mode flow treating the flag as unrecognized/ignored; MUST NOT print a migration notice or exit early
- [ ] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S13: [longrun-orphan-cleanup] migration description removed, passthrough contract intact (lr p.md)
- WHEN: a reader opens `plugins/lr/commands/p.md`
- THEN: MUST NOT contain the string `mode=mvp`; MUST still forward `$ARGUMENTS` and forbid the Agent tool
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S14: [longrun-orphan-cleanup] plan.md wrapper stays shim-free
- WHEN: a reader greps `plugins/longrun/commands/plan.md` for `mode=mvp`
- THEN: MUST be zero matches; MUST still instruct Skill-tool delegation with `$ARGUMENTS`
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S15: [longrun-orphan-cleanup] mvp.md wrapper stays shim-free
- WHEN: a reader greps `plugins/longrun/commands/mvp.md` for `mode=mvp`
- THEN: MUST be zero matches; MUST still instruct Skill-tool delegation with `$ARGUMENTS`
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S16: [longrun-orphan-cleanup] scoped-zero for "longrun-orchestrator"
- WHEN: a reader runs `grep -rln "longrun-orchestrator" plugins/ | grep -v '/tests/'`
- THEN: output MUST be empty
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S17: [longrun-orphan-cleanup] scoped-zero for "mode=mvp"
- WHEN: a reader runs `grep -rln "mode=mvp" plugins/longrun/ plugins/lr/ | grep -v '/tests/'`
- THEN: output MUST be empty
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S18: [longrun-orphan-cleanup] residual test-file occurrences are documented, not silently ignored
- WHEN: a reader reads the run's `decisions.md` after this change lands
- THEN: MUST contain a note explaining the unscoped grep still matches only `plugins/longrun/tests/*.bats`, and that this is intended/reviewed
- [ ] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S19: [longrun-docs-restructure] CHANGELOG.md exists and contains full historical record
- WHEN: a reader opens `plugins/longrun/CHANGELOG.md`
- THEN: MUST exist with entries for at least v4.0 through the version immediately preceding this change's own bump
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S20: [longrun-docs-restructure] README.md no longer contains version-history blocks
- WHEN: a reader greps `plugins/longrun/README.md` for `^## v[0-9]+\.[0-9]+ 変更点`
- THEN: MUST be zero matches
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S21: [longrun-docs-restructure] README.md links to CHANGELOG.md
- WHEN: a reader reads the top of `plugins/longrun/README.md`
- THEN: MUST contain a reference pointing to `CHANGELOG.md`
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S22: [longrun-docs-restructure] current-feature sections survive the restructure unchanged in substance
- WHEN: a reader compares コマンド表/アーキテクチャ/命名規則/MVPプランモード(minus deprecation subsection)/OpenSpec縮退モード before and after
- THEN: substantive content MUST be unchanged; only position/surrounding content differs
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S23: [longrun-docs-restructure] deprecation subsection removed from README's current MVP section
- WHEN: a reader reads the "MVP プランモード（/longrun:mvp）" section of `README.md` after this change
- THEN: MUST NOT contain a `--mode=mvp` deprecation subsection or the literal string `mode=mvp`
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S24: [longrun-docs-restructure] longrun plugin.json description is compressed
- WHEN: a reader reads `.description` from `plugins/longrun/.claude-plugin/plugin.json` via `jq -r .description`
- THEN: at most 2 occurrences of `。`, at most 200 characters, still mentions autonomous execution harness
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S25: [longrun-docs-restructure] lr plugin.json description is compressed while preserving shortcut-command discoverability
- WHEN: a reader reads `.description` from `plugins/lr/.claude-plugin/plugin.json`
- THEN: at most 2 occurrences of `。`, at most 200 characters, still mentions `/lr:m`
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S26: [longrun-docs-restructure] checkpoint.md reframed as optional/foldable
- WHEN: a reader reads the checkpoint.md section of `plugins/longrun/commands/exec.md` after this change
- THEN: MUST state checkpoint.md is optional and MAY be integrated into decisions.md; MUST NOT imply every run requires a standalone checkpoint.md
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S27: [longrun-docs-restructure] no-machine-parse prohibition preserved
- WHEN: a reader greps `plugins/longrun/commands/exec.md` for `checkpoint.md を grep/sed` or `パースして制御フロー`
- THEN: at least one match MUST exist
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S28: [longrun-docs-restructure] workflow-runs.jsonl / resumeFromRunId flow is untouched
- WHEN: a reader diffs exec.md's Step 4 (runId 記録) and Step 5 (中断→再開) sections before and after this change
- THEN: MUST be zero content differences
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S29: [longrun-test-suite-alignment] migration-notice assertions replaced with absence assertions
- WHEN: a reader reads the former `"plan: SKILL.md handles --mode=mvp with migration notice to /longrun:mvp"` test in `mvp-plan-split.bats`
- THEN: MUST be replaced by a test asserting zero `mode=mvp` occurrences in `longrun-plan/SKILL.md`; companion migration-instruction test replaced/removed to match
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S30: [longrun-test-suite-alignment] residual scan test upgraded to strict scoped-zero
- WHEN: a reader reads the former `"residual: --mode=mvp only appears as deprecation/migration prose"` test
- THEN: MUST be replaced by an assertion that `grep -rln "mode=mvp" plugins/longrun/ plugins/lr/ | grep -v '/tests/'` is empty
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S31: [longrun-test-suite-alignment] version assertions match this change's final version (mvp-plan-split.bats)
- WHEN: a reader reads the version-sync tests in `mvp-plan-split.bats`
- THEN: hardcoded literals MUST match this change's final version; marketplace.json parity assertions removed or relaxed
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S32: [longrun-test-suite-alignment] README-section assertions still pass after the CHANGELOG split
- WHEN: a reader re-runs the pre-existing README assertions in `mvp-plan-split.bats`
- THEN: MUST still pass against restructured README.md; deprecation-subsection-dependent assertions updated
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S33: [longrun-test-suite-alignment] plugin.json version assertion updated (release-and-readme.bats)
- WHEN: a reader reads `"plugin.json: longrun version is 6.2.0"` in `release-and-readme.bats`
- THEN: hardcoded `"6.2.0"` MUST be replaced with this change's final version
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S34: [longrun-test-suite-alignment] marketplace.json parity assertion deferred, not silently broken
- WHEN: a reader reads the marketplace.json parity assertions in `release-and-readme.bats`
- THEN: MUST be removed with explanatory comment, or rewritten to not assert version equality
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S35: [longrun-test-suite-alignment] degraded-mode documentation assertions remain valid
- WHEN: a reader re-runs the degraded-mode README assertions in `release-and-readme.bats`
- THEN: MUST still pass unchanged
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S36: [longrun-test-suite-alignment] legacy-removal.bats version literals updated
- WHEN: a reader reads the longrun/lr version-sync tests in `legacy-removal.bats`
- THEN: hardcoded literals MUST match this change's final versions; marketplace parity handled per S34's policy
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S37: [longrun-test-suite-alignment] description-content assertion still passes against the compressed description
- WHEN: `"legacy: longrun plugin.json description has no orchestrator / status / decisions refs"` is re-run against the compressed description
- THEN: MUST still pass
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S38: [longrun-test-suite-alignment] full bats run is clean
- WHEN: a reader runs `find plugins/longrun plugins/lr -name '*.bats' -print0 | xargs -0 bats` after this change
- THEN: all tests MUST report PASS
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S39: [longrun-test-suite-alignment] unmodified test files require no edits, or edits are justified
- WHEN: a reader diffs `exec-workflow.bats` / `exec-step0.bats` / `verify-loop.bats` before and after this change
- THEN: zero diff, or a diff justified by a decisions.md note
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

## change-4: worktree-command-dedup

### S1: [worktree-command-wrapper] wt-clean コマンドが SKILL.md を Read してインライン実行する
- WHEN: ユーザーが `plugins/worktree/commands/wt-clean.md` を開く
- THEN: `skills/wt-clean/SKILL.md`（`${CLAUDE_PLUGIN_ROOT}/skills/wt-clean/SKILL.md` を含むパス）を Read tool で読み込みインライン実行する旨の指示が本文に含まれている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S2: [worktree-command-wrapper] wt-clean コマンドに診断分類表の重複コピーが無い
- WHEN: `plugins/worktree/commands/wt-clean.md` 内で診断分類表（`🟢 Safe` / `🟡 Recoverable` / `🔴 Active` の Markdown 表・分類条件本文）を grep する
- THEN: 分類表・分類条件本文が 1 件も存在しない（分類の正は SKILL.md 側のみ）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S3: [worktree-command-wrapper] wt-clean コマンドに squash 検出ロジックの重複コピーが無い
- WHEN: `plugins/worktree/commands/wt-clean.md` 内で squash 検出手順本文（`検証A`/`検証B`/`検証C`・`git cherry`・`TREE_DIFF`・`SQUASHED`）を grep する
- THEN: これらの手順本文が command に存在しない（squash 検出の正は SKILL.md 側のみ）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S4: [worktree-command-wrapper] wt-setup コマンドが SKILL.md を Read してインライン実行する
- WHEN: ユーザーが `plugins/worktree/commands/wt-setup.md` を開く
- THEN: `skills/wt-setup/SKILL.md`（`${CLAUDE_PLUGIN_ROOT}/skills/wt-setup/SKILL.md` を含むパス）を Read tool で読み込みインライン実行する旨の指示が本文に含まれている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S5: [worktree-command-wrapper] wt-setup コマンドにセットアップ手順本文の重複コピーが無い
- WHEN: `plugins/worktree/commands/wt-setup.md` 内でセットアップ手順本文（`wt-setup.sh` 呼び出しブロック・`.worktreeinclude` 生成の分類ルール本文・`gh pr create --draft` の Draft PR 手順）を grep する
- THEN: これらの手順本文が command に存在しない（Step 1-6 の正は SKILL.md 側のみ）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S6: [worktree-command-wrapper] wt-clean の frontmatter が allowed-tools を維持する
- WHEN: `plugins/worktree/commands/wt-clean.md` の frontmatter を読む
- THEN: `allowed-tools` に `AskUserQuestion`・`Read`・`Bash` を含む（診断フロー実行に必要なツールが欠落していない）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S7: [worktree-command-wrapper] wt-setup の frontmatter が allowed-tools と argument-hint を維持する
- WHEN: `plugins/worktree/commands/wt-setup.md` の frontmatter を読む
- THEN: `allowed-tools` が保持され、かつ `argument-hint`（`[--with-pr] ...` 相当）が存在する
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S8: [worktree-command-wrapper] 引数が SKILL.md の実行に透過される
- WHEN: ユーザーが `/wt-clean ~/wt/foo --no-sync` や `/wt-setup --with-pr ログイン画面のバグ修正` のように引数付きで起動する
- THEN: ラッパーは `$ARGUMENTS` を SKILL.md の実行にそのまま渡す旨を明記しており、位置引数・フラグ・後続作業指示が SKILL.md 側フローに欠落なく届く
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S9: [worktree-command-wrapper] squash 検出 A/B/C が SKILL.md に一言一句残っている
- WHEN: `plugins/worktree/skills/wt-clean/SKILL.md` を読む
- THEN: 検証 A（実ツリー差分空）・検証 B（`git cherry`）・検証 C（`gh pr` MERGED）の 3 検証、「実ツリー差分を優先」、`SQUASHED` 非空を 🟢/🟡 とし `AHEAD_COUNT>0` でも 🔴 にしない旨がすべて残っている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S10: [worktree-command-wrapper] AskUserQuestion 別ターン実行の絶対禁則が SKILL.md に残っている
- WHEN: `plugins/worktree/skills/wt-clean/SKILL.md` を読む
- THEN: 「AskUserQuestion ツール呼び出しと削除 Bash を同一ターンの並列ツール呼び出しに含めてはならない」「回答を受け取った後の別のアシスタントターンで実行する」旨の絶対禁則（最重要）が残っている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S11: [worktree-command-wrapper] command 経由と skill 経由で同一の診断フローになる
- WHEN: `/wt-clean` を command として起動した場合と、wt-clean skill を起動した場合を比較する
- THEN: command は独立フロー定義を持たず SKILL.md を Read して実行するため、両経路とも `skills/wt-clean/SKILL.md` の同一手順（Step 0→A→B→C, squash 検出込み）を実行し、command 側に旧分類表など別フローが存在しない
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S12: [worktree-setup-script-integrity] find -path グロブの挙動が検証され意図がコメント化されている
- WHEN: `plugins/worktree/scripts/wt-setup.sh` の `.worktreeinclude` 展開ループ（`find -path "./$pattern"` を含む箇所）を読む
- THEN: `find -path` のグロブ展開挙動（1 階層パターンとサブディレクトリ一致の差異）についての確認結果コメントが存在する、または挙動を是正する修正が入っている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S13: [worktree-setup-script-integrity] settings.local.json の symlink 是非が判断・文書化されている
- WHEN: `plugins/worktree/scripts/wt-setup.sh` の `.claude/` 配下ファイルを symlink するループ（`settings.json` / `settings.local.json` 対象箇所）を読む
- THEN: `settings.local.json` を worktree に symlink する／しないの判断理由コメントが存在する、または是正する修正が入っている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S14: [worktree-setup-script-integrity] スクリプトの構文検証が通る
- WHEN: `bash -n plugins/worktree/scripts/wt-setup.sh` を実行する
- THEN: 構文エラーなく終了する（exit 0）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

## change-5: report-plugins-update

### S1: [weekly-report-jsonl-direct] Step 3b が LLM/*.md への参照を持たない
- WHEN: `plugins/weekly-report/skills/weekly-report/SKILL.md` 内で `{source_path}/LLM` を grep する
- THEN: 該当行は 0 件である
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S2: [weekly-report-jsonl-direct] Step 3b が native jsonl を参照する
- WHEN: `plugins/weekly-report/skills/weekly-report/SKILL.md` の Step 3b を読む
- THEN: `~/.claude/projects` への参照と jq ベースのセッション抽出手順が記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S3: [weekly-report-jsonl-direct] llm-log-compactor のロジックを流用している旨が明記されている
- WHEN: ユーザーが Step 3b の説明文を読む
- THEN: `plugins/daily-report/agents/llm-log-compactor.md` の jq ロジックを流用・参照している旨が記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S4: [weekly-report-jsonl-direct] 個人パスのハードコードが無い
- WHEN: `plugins/weekly-report/skills/weekly-report/SKILL.md` 内で `/Users/oratta/Dropbox/WorkSpace` を grep する
- THEN: 該当行は 0 件である
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S5: [weekly-report-jsonl-direct] 環境変数未設定時にフェイルソフトする
- WHEN: harvest セッション検索用の環境変数（`$WORKSPACE_ROOT`）が未設定の状態でレポート生成が実行される
- THEN: 該当サブセクション（harvest セッション集計）は省略され、レポート生成の他のセクションは通常どおり出力される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S6: [weekly-report-jsonl-direct] 1h-cooking 言及が残っていない
- WHEN: `plugins/weekly-report/skills/weekly-report/SKILL.md` 内で大文字小文字を無視して `1h-cooking` を grep する
- THEN: 該当行は 0 件である
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S7: [weekly-report-jsonl-direct] harvest の実態に沿った検索パターンが記載されている
- WHEN: ユーザーが更新後の該当サブセクション（旧 Step 4d）を読む
- THEN: `data/sessions/<slug>.jsonl` という作業 repo cwd 直下分散のパターンでセッション jsonl を検索する旨が記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S8: [report-command-hygiene] 存在しない旧パスへの参照が無い
- WHEN: `plugins/weekly-report/commands/weekly-report.md` 内で `.claude/skills/weekly-report/SKILL.md` を grep する
- THEN: 該当行は 0 件である
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S9: [report-command-hygiene] plugin-relative パスで SKILL.md を参照している
- WHEN: `plugins/weekly-report/commands/weekly-report.md` の本文を読む
- THEN: `skills/weekly-report/SKILL.md` という plugin-relative なパスで SKILL.md の手順に従う旨が記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S10: [report-command-hygiene] allowed-tools に Agent が含まれる
- WHEN: `plugins/daily-report/commands/daily-report.md` の frontmatter `allowed-tools` 行を読む
- THEN: `Agent` がツール一覧に含まれている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S11: [report-noninteractive-mode] daily-report SKILL.md に非対話モード節が存在する
- WHEN: `plugins/daily-report/skills/daily-report/SKILL.md` を読む
- THEN: cron / 非対話実行時にデフォルト対象日「昨日」で続行する旨を記載した節が存在する
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S12: [report-noninteractive-mode] weekly-report SKILL.md に非対話モード節が存在する
- WHEN: `plugins/weekly-report/skills/weekly-report/SKILL.md` を読む
- THEN: cron / 非対話実行時にデフォルト対象週「先週」で続行する旨を記載した節が存在する
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S13: [report-noninteractive-mode] AskUserQuestion 不可時はデフォルト値で続行する
- WHEN: 非対話実行コンテキスト（cron 経由等）で AskUserQuestion が使用できない状態でスキルが起動される
- THEN: 質問をスキップしデフォルト値（daily=昨日、weekly=先週）で処理が続行される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S14: [report-noninteractive-mode] 対話依存ステップがファイル出力に代替される
- WHEN: 非対話実行時に対話依存ステップ（口頭報告等のユーザー入力前提の箇所）に到達する
- THEN: 当該ステップはファイル出力（空セクション・プレースホルダー等）へ代替される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S15: [report-noninteractive-mode] 判断ログが出力に残る
- WHEN: 非対話実行によりデフォルト値の適用や対話ステップのスキップが発生する
- THEN: その判断内容が生成物の出力（レポート本文またはログ）に判断ログとして記録される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

## change-6: plugin-retirement

### S1: [llm-log-relocation] Snapshot recorded before the first move
- WHEN: 退避直前、`LLM/*` のファイル数・ファイル名一覧をスナップショットとして記録する
- THEN: 最初の `mv` 実行前にスナップショットが永続化されており、後続の照合はこのスナップショット件数を基準にする
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S2: [llm-log-relocation] Every snapshotted filename is accounted for
- WHEN: 退避処理が完了する
- THEN: スナップショットに記録された各ファイル名は `$LLM_LOG_DIR` へ移動済みか、衝突スキップとしてリポジトリ直下 `LLM/` に残置されているかのいずれかであり、両方から消失しているファイルがあれば失敗として扱われる
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S3: [llm-log-relocation] Collision detected and skipped
- WHEN: スナップショット済みのファイル名が `$LLM_LOG_DIR` に既に存在する
- THEN: そのファイルの `mv` はスキップされ、移動先ファイルは変更されず、元ファイルはリポジトリ直下 `LLM/` に残置され、ファイル名が衝突リストに追加される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S4: [llm-log-relocation] Snapshot-based arithmetic passes despite hook activity
- WHEN: 全 `mv` 完了後の照合時に、リポジトリ直下 `LLM/` にスナップショット外のファイル（`auto-save.py` hook による退避作業中の新規発生分）が存在する
- THEN: 照合算式（移動成功件数 + 衝突スキップ件数 = スナップショット件数）はスナップショット済みファイルのみで成立し、スナップショット外の新規ファイルはこの算式から除外され hook 起因として別記される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S5: [llm-log-relocation] Reconciliation fails loudly on genuine loss
- WHEN: スナップショットに記録されたファイル名が `$LLM_LOG_DIR` にもリポジトリ直下 `LLM/` にも存在せず、衝突スキップとしても記録されていない
- THEN: 照合は失敗として報告され、解決されるまで退避完了とはみなされない
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S6: [llm-log-relocation] post-merge-steps.md documents the evacuation outcome
- WHEN: 退避と照合が完了する
- THEN: `{longrun-dir}/post-merge-steps.md` に衝突スキップされた全ファイル名（または「衝突ゼロ」の明記）と、hook 起因のスナップショット外新規ファイル（または「発生なし」の明記）が記録される
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S7: [llm-log-relocation] Zero-collision case leaves LLM/ empty or absent
- WHEN: 退避が衝突ゼロで完了する
- THEN: リポジトリ直下 `LLM/` は空または不存在になる
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S8: [llm-log-relocation] Collision case leaves only the collided files
- WHEN: 退避が1件以上の衝突を伴って完了する
- THEN: リポジトリ直下 `LLM/` には衝突スキップされたファイル名のみが残っており、移動成功したファイルも衝突リスト外のファイルも残っていない
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S9: [plugin-retirement-cleanup] Plugin directories are absent
- WHEN: `plugins/` を一覧する
- THEN: `plugins/obsidian-llm-session-rules/` と `plugins/skill-aware-workflow/` が存在しない
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S10: [plugin-retirement-cleanup] Deletion is git-tracked
- WHEN: `git log --diff-filter=D -- plugins/obsidian-llm-session-rules plugins/skill-aware-workflow` を実行する
- THEN: 両ディレクトリの内容削除が tracked commit として履歴に現れる
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S11: [plugin-retirement-cleanup] plugins[] array excludes both entries
- WHEN: `.claude-plugin/marketplace.json` の `plugins[]` をパースする
- THEN: `name: "obsidian-llm-session-rules"` または `name: "skill-aware-workflow"` のエントリが存在しない
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S12: [plugin-retirement-cleanup] "all" bundle no longer lists retired plugins
- WHEN: `.claude-plugin/marketplace.json` の `bundles[]` 内 `"all"` エントリをパースする
- THEN: その `plugins[]` リストに `"obsidian-llm-session-rules"` または `"skill-aware-workflow"` が含まれない
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S13: [plugin-retirement-cleanup] Only entry removal appears in the diff
- WHEN: `.claude-plugin/marketplace.json` の変更前後を diff する
- THEN: 差分は両プラグインの `plugins[]` エントリと `bundles[].all.plugins[]` 名の除去のみであり、top-level `version` と残存プラグインの `version`/`description` は変更前と同一である
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S14: [plugin-retirement-cleanup] Zero plugin-name references outside archive/_longruns
- WHEN: `grep -rln "obsidian-llm-session-rules\|skill-aware-workflow" plugins/ README.md docs/` をリポジトリルートから実行する
- THEN: 結果が0件である
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S15: [plugin-retirement-cleanup] Zero skill-name references outside archive/_longruns/this-change
- WHEN: 旧 Skill 名9個の grep（`session-logger|context-reader|research-workflow|pre-task-orchestrator|task-analyzer|skill-inventory|skill-finder|execution-tracker|skill-proposer`）を `openspec/changes/archive/`・`_longruns/`・`openspec/changes/plugin-retirement/` を除いてリポジトリ全体に実行する
- THEN: 結果が0件である
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S16: [plugin-retirement-cleanup] Illustrative examples use generic names
- WHEN: `CONTRIBUTING.md` の「NGパターン」例示を読む
- THEN: 例示名は旧 Skill 名9個のいずれも含まず、実在した/現存するスキルに紐付かない汎用架空名になっている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S17: [plugin-retirement-cleanup] Quickstart install commands cleaned
- WHEN: `README.md` の `## クイックスタート` 節を読む
- THEN: `/plugin install skill-aware-workflow@oratta-claude-harness` も `/plugin install obsidian-llm-session-rules@oratta-claude-harness` も含まれない
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S18: [plugin-retirement-cleanup] Plugin catalog sections removed
- WHEN: `README.md` の `## プラグイン一覧` 節を読む
- THEN: `### skill-aware-workflow` も `### obsidian-llm-session-rules` サブセクションも存在しない
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S19: [plugin-retirement-cleanup] Local development examples cleaned
- WHEN: `README.md` の `## ローカル開発` 節を読む
- THEN: `/plugin add ./plugins/skill-aware-workflow` も `/plugin add ./plugins/obsidian-llm-session-rules` も含まれない
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S20: [retirement-handoff-docs] Section is resolved, not left dangling
- WHEN: 本 change 適用後に `openspec/backlog.md` を読む
- THEN: `## Skill 命名規則リファクタリング` 節が完全に不存在であるか、旧 Skill 名9個を個別に列挙しない単一行の解消済みノートに縮小されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S21: [retirement-handoff-docs] No orphaned rename-target table remains
- WHEN: 本 change 適用後に `openspec/backlog.md` を読む
- THEN: 旧 Skill 名9個をリネーム先候補にマッピングする対象表が存在しない
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S22: [retirement-handoff-docs] Uninstall and reload commands present
- WHEN: `{longrun-dir}/post-merge-steps.md` を開く
- THEN: `/plugin uninstall obsidian-llm-session-rules@oratta-claude-harness`、`/plugin uninstall skill-aware-workflow@oratta-claude-harness`、`/reload-plugins` の3コマンドが記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S23: [retirement-handoff-docs] enabledPlugins cleanup guidance present
- WHEN: `{longrun-dir}/post-merge-steps.md` を開く
- THEN: 各プロジェクトの `settings.local.json` の `enabledPlugins` から `obsidian-llm-session-rules@oratta-claude-harness` と `skill-aware-workflow@oratta-claude-harness` の両キーを削除する手順が記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

### S24: [retirement-handoff-docs] Evacuation report and uninstall instructions share one file
- WHEN: `{longrun-dir}/post-merge-steps.md` を開く
- THEN: 同一ファイル内に `/plugin uninstall` 手順と LLM/ 退避の衝突レポート（または「衝突ゼロ」の明記）の両方が含まれている
- [x] テスト実装完了
- [x] ロジック実装完了
- [ ] 動作確認完了
- [ ] ユーザー確認完了

## change-7: repo-cleanup-final

### S1: [openspec-dedup-resolution] 生成元調査の実施と根拠の記録
- WHEN: builder が OpenSpec 4 系統の生成元調査を行う
- THEN: `.claude/skills/openspec-*/SKILL.md` の CLI 生成マーカー（author: openspec / generatedBy / compatibility）、`.agents/skills/source-command-opsx-*` の「migrated source command」表記、`which openspec`/`openspec --version` を確認し、結果を file 単位の根拠付きで decisions.md に記録する
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S2: [openspec-dedup-resolution] 調査結論が decisions.md に文書化される
- WHEN: 調査が完了する
- THEN: `openspec/changes/repo-cleanup-final/decisions.md` が存在し、(a) CLI 管理/手動管理/判断不能のいずれか、(b) 採用分岐（CLI 抑制/`.claude/` 側残置削除/現状維持縮退）とその理由、の両方が記載されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S3: [openspec-dedup-resolution] 分岐 A — CLI 抑制が可能な場合
- WHEN: 4 系統が CLI 生成物であり CLI 設定で出力系統を単一化できると確認された
- THEN: 設定変更で重複が 1 系統に抑制され、設定変更内容と再現手順が decisions.md に記録される
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S4: [openspec-dedup-resolution] 分岐 B — 手動管理と確認された場合
- WHEN: 4 系統が手動管理（CLI 再生成の対象でない）と確認された
- THEN: `.claude/skills/openspec-*` と `.claude/commands/opsx/` の 2 系統は残り、`.agents/skills/openspec-*/` と `.agents/skills/source-command-opsx-*/` は git rm で削除され復元可能
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S5: [openspec-dedup-resolution] 分岐 C — 判断不能時の現状維持縮退
- WHEN: CLI 管理の疑いが残り削除が `openspec update` 等で再生成されて無効化される恐れがある
- THEN: 4 系統は削除されず現状維持され、decisions.md に「現状維持の理由」と「将来 CLI 設定で抑制する手順」が記録される
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S6: [openspec-dedup-resolution] 削除は常に git tracked で可逆
- WHEN: いずれかの系統を削除する分岐を採る
- THEN: 削除対象は削除前に git tracked であり `git rm` 相当で削除され commit 履歴から復元可能（untracked ファイルの物理削除はしない）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S7: [repo-root-cleanup] 参照ゼロの再確認
- WHEN: builder が `templates/rules/` の削除に着手する
- THEN: `grep -rn "templates/rules" plugins/ .claude-plugin/ README.md docs/`（archive・_longruns 除く）が 0 件であることを確認してから削除する
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S8: [repo-root-cleanup] templates/rules ディレクトリの不存在
- WHEN: 削除完了後に `templates/rules/` の存在を確認する
- THEN: `templates/rules/` ディレクトリおよび配下 4 ファイルが存在しない（受け入れ条件 14 前半）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S9: [repo-root-cleanup] docs/cooking-mvp-mode-plan.md の削除
- WHEN: 削除完了後に `docs/cooking-mvp-mode-plan.md` の存在を確認する
- THEN: `docs/cooking-mvp-mode-plan.md` が存在しない（受け入れ条件 14 後半）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S10: [repo-root-cleanup] .gitignore の cooking コメント更新
- WHEN: `.gitignore` を読む
- THEN: 「1h-cooking session output」という旧命名コメントが残らず harvest 命名に更新されている（`grep -n "1h-cooking" .gitignore` が 0 件）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S11: [repo-root-cleanup] skill-pack SKILL.md の cooking 言及掃除
- WHEN: `plugins/skill-pack/skills/skill-pack/SKILL.md` を読む
- THEN: cooking 例示・言及が現行実態に即した表現へ更新され、`1h-cooking` / `cooking@1h-cooking` の旧命名残骸が実例説明として残っていない
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S12: [repo-root-cleanup] skillOverrides 適用範囲の明記
- WHEN: `plugins/skill-pack/skills/skill-pack/SKILL.md` を読む
- THEN: `skillOverrides` が個人スキル（`~/.claude/skills/`）対象で plugin skill を制御しないこと、plugin スキルは `enabledPlugins` で plugin 単位に ON/OFF する旨が `on`/`off` 説明付近に明記されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S13: [repo-root-cleanup] realpath "$0" の除去と CLAUDE_PLUGIN_ROOT 化
- WHEN: `plugins/experience-to-skill/commands/e2s-distill.md` を読む
- THEN: `realpath "$0"` を用いた PLUGIN_ROOT 導出が存在せず、plugin ルート解決が `${CLAUDE_PLUGIN_ROOT}` を基点に行われている（`grep -n 'realpath "\$0"' plugins/experience-to-skill/commands/e2s-distill.md` が 0 件）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S14: [marketplace-final-sync] skill-pack / experience-to-skill の version bump
- WHEN: 本 change が skill-pack と experience-to-skill を編集した後に両者の plugin.json を読む
- THEN: 両 plugin.json の version が編集前より bump されている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S15: [marketplace-final-sync] 他 change 編集分の version bump 確認
- WHEN: infra / longrun / lr / worktree / daily-report / weekly-report の plugin.json を読む
- THEN: 各 version が本 run の編集に対応して bump されている（未 bump は本 change で補完）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S16: [marketplace-final-sync] version の完全一致
- WHEN: marketplace.json の各エントリ version と対応 plugin.json の version を比較する
- THEN: 8 プラグイン（infra/longrun/lr/worktree/daily-report/weekly-report/skill-pack/experience-to-skill）全てで両者が完全一致する（受け入れ条件 15）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S17: [marketplace-final-sync] description の同期
- WHEN: marketplace.json の各エントリ description と対応 plugin.json の description を比較する
- THEN: 各プラグインで両者が一致する（plugin.json 側を正）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S18: [marketplace-final-sync] 廃止 2 プラグインのエントリに触れない
- WHEN: 本 change が marketplace.json を編集する
- THEN: obsidian-llm-session-rules / skill-aware-workflow のエントリ除去は change-6 の責務であり本 change はそれらの version/description を触らない
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S19: [marketplace-final-sync] change-7 固有条件（14/15）の検証
- WHEN: 統合検証を実行する
- THEN: `templates/rules/` 不存在・`docs/cooking-mvp-mode-plan.md` 不存在（条件 14）、全編集プラグインで plugin.json version == marketplace.json version（条件 15）が確認される
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S20: [marketplace-final-sync] 他 change 由来条件（5-13, 16）の横断検証
- WHEN: 統合検証を実行する
- THEN: 条件 5/6/7/8/9/10/11/12/13/16 の各 grep/ls が期待値になり、逸脱があれば該当 change 担当へ差し戻す
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S21: [marketplace-final-sync] 全 *.json の parse 検証
- WHEN: 統合検証の一部として全 JSON の構文を確認する
- THEN: marketplace.json を含む全 `*.json` が JSON として parse 可能である（受け入れ条件 3 の一部）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

