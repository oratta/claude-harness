## 1. 回帰テスト（Red）

- [ ] 1.1 `develop-adapter-review-routing.bats` に #390 の G 入力一覧（`レビュー経路:`、再開時 executor / model・dispatch URL）を検査するアサーションを追加し、変更前に失敗することを確認する
- [ ] 1.2 同テストに #392 の経路別 model 決定元（従来経路は G の推奨、adapter 経路は adapter の値＋残量上限）を検査するアサーションを追加し、変更前に失敗することを確認する
- [ ] 1.3 同テストに #393 の PR コメント雛形 5 欄すべてが `未実行（adapter 経路）` を選べることを検査するアサーションを追加し、変更前に失敗することを確認する
- [ ] 1.4 同テストに #394 の行無し従来経路が Claude G と Codex G を書き分け、旧文言が残らないことを検査するアサーションを追加し、変更前に失敗することを確認する
- [ ] 1.5 同テストに #395 の欠陥探索が adapter 経路のレビュアーと従来経路の Codex を含むことを検査するアサーションを追加し、変更前に失敗することを確認する
- [ ] 1.6 同テストに #396 の `needs-reviewer` 前の同一 PR/HEAD 着手確認を検査するアサーションを追加し、変更前に失敗することを確認する

## 2. レビュー経路契約の文言整合（Green）

- [ ] 2.1 `gate-runner.md` の本体入力一覧へ `レビュー経路:` と adapter 再開情報を追加し、adapter 行へ同一 PR/HEAD の重複着手確認を追加する
- [ ] 2.2 develop `SKILL.md` の model 表へ経路別の model 決定元を追加し、(4) 冒頭の欠陥探索の説明を従来経路の Codex を含む形へ統一する
- [ ] 2.3 pr-review-gate `SKILL.md` のコメント雛形にある証拠 5 欄すべてへ `未実行（adapter 経路）` を追加する
- [ ] 2.4 `codex-develop.md` の行無し従来経路を、Claude G は Codex を直接呼び、Codex G は prompt の禁止により呼ばない形へ書き分ける

## 3. 配布メタデータと検証

- [ ] 3.1 dev-workflow の `plugin.json` と marketplace metadata の version を同じ値へ更新し、CHANGELOG に #425 のレビュー経路契約整合を追記する
- [ ] 3.2 `bats plugins/dev-workflow/tests/develop-adapter-review-routing.bats` を実行し、6 件の回帰テストを含めて exit 0 を確認する
- [ ] 3.3 `git grep -n '行が無ければ従来経路として Codex を直接呼ぶ' -- plugins` が 0 件、かつ `未実行（adapter 経路）` が pr-review-gate の雛形 5 欄でヒットすることを確認する
- [ ] 3.4 `openspec validate align-develop-review-route-contract --strict` と `openspec validate --all --strict --no-interactive` を実行し、どちらも exit 0 を確認する
- [ ] 3.5 `bash scripts/test.sh` を実行し exit 0 を確認する。`statusline-multi-account.bats` の単発 1 件だけが失敗した場合は、そのテストを単独で再実行して exit 0 を確認する
- [ ] 3.6 PR 本文の issue 参照は最初に `Closes #425`、続いて `Closes #390`、`Closes #392`、`Closes #393`、`Closes #394`、`Closes #395`、`Closes #396` を並べ、最初の参照先が #425 であることを確認する
