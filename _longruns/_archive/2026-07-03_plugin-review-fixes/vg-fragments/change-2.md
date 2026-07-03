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
