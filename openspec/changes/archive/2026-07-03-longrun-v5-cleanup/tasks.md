# Tasks: longrun-v5-cleanup

## 1. orchestrator 残骸の除去

- [x] 1.1 `plugins/longrun/agents/longrun-verifier.md` の「コンテキスト復元」ステップ（現 :37）を `{longrun-dir}/checkpoint.md` から把握 → `{longrun-dir}/plan.md` と `{longrun-dir}/decisions.md` から把握、に書き換える
- [x] 1.2 同ファイルの「FAILの場合」ステップ（現 :98）の「orchestratorに修正を依頼」を、Workflow が構造化 FAIL 結果を受けて `longrun-builder` を再呼び出しする旨の記述に書き換える
- [x] 1.3 `plugins/longrun/agents/longrun-browser-verifier.md` の「コンテキスト復元」ステップ（現 :101）を 1.1 と同様に書き換える
- [x] 1.4 同ファイルの verification-guide.md 生成元の注記（現 :151「orchestrator の Build前半で既に生成されている」）を Build フェーズ / `longrun-builder` 起点の記述に書き換える
- [x] 1.5 同ファイルの「FAILの場合」ステップ（現 :187）を 1.2 と同様に書き換える
- [x] 1.6 `plugins/longrun/agents/longrun-builder.md` frontmatter の `description`（現 :3）から「checkpoint.mdを更新する」を削除し、`builder-report` schema による完了レポートの記述に置き換える
- [x] 1.7 `plugins/longrun/commands/exec.md` の historical 注記（現 :9）から複合語 `longrun-orchestrator` を除去する（「旧 orchestrator スキル」等に言い換え、情報は保持）
- [x] 1.8 `grep -rln "longrun-orchestrator" plugins/ | grep -v '/tests/'` が空になることを確認する

## 2. dead code 削除

- [x] 2.1 `grep -rn "update-checkpoint.sh" plugins/` を再実行し、呼び出し元がスクリプト自身のコメントのみであることを最終確認する
- [x] 2.2 `plugins/longrun/scripts/update-checkpoint.sh` を `git rm` で削除する
- [x] 2.3 削除後に `grep -rn "update-checkpoint.sh" plugins/" が空になることを確認する（scoped: `| grep -v '/tests/'`。理由は decisions.md D-change3-1 参照）

## 3. `--mode=mvp` シムの完全撤去

- [x] 3.1 `plugins/longrun/skills/longrun-plan/SKILL.md` 冒頭の GATE ブロック（現 :8-35、「起動前チェック: 廃止された `--mode=mvp` フラグの移行案内」節全体）を削除する。ファイルの実行指示は既存の `# Run Plan — plan.md 作成スキル` 見出し（Step 1）から直接始まるようにする
- [x] 3.2 `git diff` で Step 1〜Step 8 本体・テンプレ読み込み・`longrun-reviewer` 起動指示に意図しない差分がないことを確認する
- [x] 3.3 `plugins/lr/commands/p.md` の :11（旧フラグの移行案内説明）を削除する。`$ARGUMENTS` 透過転送と Agent tool 禁止の記述は維持する
- [x] 3.4 `plugins/longrun/commands/plan.md` / `plugins/longrun/commands/mvp.md` を確認し、`mode=mvp` 言及がゼロであることを再確認する（現状ゼロ確認済みのため通常は無変更）
- [x] 3.5 `grep -rln "mode=mvp" plugins/longrun/ plugins/lr/ | grep -v '/tests/'` が空になることを確認する

## 4. README → CHANGELOG.md 分離

- [x] 4.1 `plugins/longrun/README.md` の版履歴ブロック（現 :5-85、`## v6.2 変更点` 〜 `## v4.0 変更点（旧 longrun → run 時代）` の全セクション）を新規 `plugins/longrun/CHANGELOG.md` に移設する。歴史的記述内で `longrun-orchestrator` / `mode=mvp` の複合語 literal を使わない言い回しに調整する（design.md D1/D2）
- [x] 4.2 `README.md` の冒頭にタイトル・1 行概要 + `CHANGELOG.md` への参照リンクを配置する
- [x] 4.3 `README.md` の「MVP プランモード（/longrun:mvp）」セクション内の `### --mode=mvp は廃止（deprecation）` サブセクション（現 :144-146）を削除する
- [x] 4.4 `README.md` の残存セクション（コマンド表・アーキテクチャ・命名規則・MVP プランモード・OpenSpec 縮退モード）を通読し、版履歴移設によるリンク切れ・見出しズレがないことを確認する

## 5. plugin.json description 圧縮

- [x] 5.1 `plugins/longrun/.claude-plugin/plugin.json` の `description`（現 :4、約 600 字）を 2 文以内・200 字以内に圧縮する。自律実行ハーネスであることを明記し、スキーマ強制・budget ガード等の実装詳細は README に譲る
- [x] 5.2 `plugins/lr/.claude-plugin/plugin.json` の `description` を 2 文以内・200 字以内に圧縮する。`/lr:m` への言及は維持する（`mvp-plan-split.bats` の既存アサーション互換のため）
- [x] 5.3 圧縮後の両 description に対し `。` の出現回数が 2 以下であることを確認する

## 6. checkpoint.md 節の格下げ

- [x] 6.1 `plugins/longrun/commands/exec.md` の `## checkpoint.md（人間向け監査ログ）` 節（現 :262-271）を、checkpoint.md は任意であり decisions.md に統合してよい人間向けメモである旨の記述に書き換える
- [x] 6.2 「checkpoint.md を grep/sed/正規表現でパースして制御フローを決めてはならない」という禁止文言（現 :243-244, :265-267 相当）を一言一句またはほぼ同一の形で維持する
- [x] 6.3 `git diff` で Step 4「runId 記録」節（現 :218-225）と Step 5「中断 → 再開」節（現 :241-259）に差分がないことを確認する

## 7. バージョン同期（plugin.json のみ、marketplace.json は change-7）

- [x] 7.1 着手時点の `jq -r .version plugins/longrun/.claude-plugin/plugin.json` を確認し、minor（3 桁目）を 1 つ上げた値を `plugins/longrun/.claude-plugin/plugin.json` に適用する（6.2.0 → 6.3.0）
- [x] 7.2 `plugins/lr/.claude-plugin/plugin.json` の version も同様に 1 つ上げる（6.1.0 → 6.2.0。`commands/p.md` を編集するため）
- [x] 7.3 `.claude-plugin/marketplace.json` は編集しない（change-7 が同期する。plan.md の change-7 依存関係節参照）

## 8. 既存 bats の新仕様への更新

- [x] 8.1 `plugins/longrun/tests/mvp-plan-split.bats` の `"plan: SKILL.md handles --mode=mvp with migration notice to /longrun:mvp"` と `"plan: migration notice instructs no Step 1-8 and no plan.md generation"` を、GATE 不在を検証するテストに置き換える
- [x] 8.2 同ファイルの `"residual: --mode=mvp only appears as deprecation/migration prose"`（現 :394-406）を、`grep -rln "mode=mvp" plugins/longrun/ plugins/lr/ | grep -v '/tests/'` が空であることを検証する厳密版に置き換える
- [x] 8.3 同ファイルのバージョン同期テスト（現 :276-303 付近）のハードコード値を 7.1/7.2 で決めた新バージョンに更新し、marketplace.json パリティを要求する assertion は削除または「JSON として parse でき longrun/lr エントリが存在する」程度に緩和する
- [x] 8.4 同ファイルの README アサーション（`/longrun:mvp` 言及・汎用性記述など）が CHANGELOG 分離後も通ることを確認し、`--mode=mvp` deprecation サブセクションに依存するアサーションがあれば更新する
- [x] 8.5 `plugins/longrun/tests/release-and-readme.bats` のバージョンアサーション（現 :34-46）を新バージョンに更新し、marketplace.json パリティ assertion を 8.3 と同じ方針で処理する
- [x] 8.6 同ファイルの縮退モードドキュメント assertion（degraded-mode 関連）が無変更で通ることを確認する
- [x] 8.7 `plugins/longrun/tests/legacy-removal.bats` のバージョンアサーション（現 :93-105）を新バージョンに更新する
- [x] 8.8 同ファイルの description-content assertion（現 :52-55）が圧縮後の description に対して通ることを確認する

## 9. 検証

- [x] 9.1 `find plugins/longrun plugins/lr -name '*.bats' -print0 | xargs -0 bats` を実行し全 PASS を確認する（275 tests, 0 failures）
- [x] 9.2 `plugins/longrun/tests/exec-workflow.bats` / `exec-step0.bats` / `verify-loop.bats` に diff が出ていないことを確認する（`git diff --stat` で確認済み。差分ゼロ）
- [x] 9.3 `jq empty plugins/longrun/.claude-plugin/plugin.json plugins/lr/.claude-plugin/plugin.json` で JSON 構文を確認する
- [x] 9.4 `grep -rn "longrun-orchestrator" plugins/` と `grep -rn "mode=mvp" plugins/longrun/ plugins/lr/` を（`/tests/` 除外なしで）実行し、ヒットが `plugins/longrun/tests/*.bats` のみに収まっていることを目視確認し、run ディレクトリの `decisions.md` にその旨を記録する（design.md D1/D2, 受け入れ条件 9 の解釈メモ）
- [x] 9.5 `plugins/longrun/scripts/update-checkpoint.sh` が不存在であることを確認する
- [x] 9.6 `plugins/longrun/README.md` に `## v[0-9]+\.[0-9]+ 変更点` 形式の見出しが残っていないことを確認する
