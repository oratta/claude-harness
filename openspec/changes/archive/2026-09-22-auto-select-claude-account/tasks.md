## 1. 選択規則をテストで固定する（Red）

- [x] 1.1 `plugins/dev-workflow/tests/account-selector.bats` を追加し、2 スロットで `a < b` の週次余裕を与えると `b` の `securestorage` が stdout に出て、stderr の理由 1 行に両方の余裕の数値が出る失敗テストを書く（受け入れ条件 1）。
- [x] 1.2 age 299 秒は候補、300 秒は候補外になる境界、片方だけ古い場合、全スロットが古い場合をテストする。全スロットが古い場合は空の既定値、`reason=default-due-to-missing-usage` / `stale`、登録済み既定スロットの実 id が出ること、および既定スロット未登録なら `selected=@unregistered-default` になることを失敗テストで固定する（受け入れ条件 2・5）。
- [x] 1.3 `five_hour_pct` が 89.99 のスロットは候補、90 以上のスロットは週次余裕が最大でも候補外になる失敗テストを書く。全スロットが 90 以上なら `reason=default-due-to-five-hour-limit` となり、欠測縮退の理由と区別されることも固定する（受け入れ条件 3）。
- [x] 1.4 登録済み id の明示指定が snapshot 不在・不正でも成功し、未登録 id と引数 2 個以上が stdout 無しの exit 2 になる失敗テストを書く。未登録 id を shell function が空の成功値と誤認せず、`claude` を起動しないことも固定する（受け入れ条件 4）。
- [x] 1.5 同点の宣言順、必要値の欠測・非数値・未来の `fetched_at`、stdout/stderr 分離、空白を含む `securestorage` を追加テストで固定し、新規 bats が実装前に Red になることを記録する。

## 2. アカウント selector を実装する（Green / Refactor）

- [x] 2.1 `plugins/dev-workflow/scripts/select-account.sh` を追加し、既存レジストリ契約と schema 2 snapshot を読み、300 秒の鮮度・5 時間 90% ガード・共有枠モードと同じ週次余裕・宣言順 tie-break を実装する。
- [x] 2.2 候補なしでは登録済み既定スロットの実 id（未登録なら `@unregistered-default`）と空の `securestorage` へ縮退し、欠測と短期枠逼迫で理由を分ける。明示 id 経路、未登録 id の exit 2 を実装し、明示 id 経路が snapshot を開かないことをテストで確認する。
- [x] 2.3 stdout を `securestorage` 値 1 行、stderr を `selected=... reason=... margins=...` 1 行に分離し、`account-selector.bats` をすべて Green にする。

## 3. 起動手順と仕様を更新する

- [x] 3.1 `plugins/dev-workflow/README.md` に marketplace clone の scripts path を変数で保持する `cld` / `cld-account` zsh function を追加し、probe の best-effort 実行、Claude 引数の転送、空値の `env -u` を説明する。selector が非 0 なら function も同じ状態で終了して Claude を起動せず、未登録 id の exit 2 を空の成功値と取り違えない実装にする。
- [ ] 3.2 `cld` で実セッションを起動し、通常選択に加えて、任意の id（例: `a`）で登録した既定スロットへ全スロット古い状態から縮退する場合にも、selector の理由行で選ばれた実 id と statusline の active 表示が一致する証拠を Draft PR の動作確認へ添える（受け入れ条件 5）。
- [x] 3.3 delta spec を main の `openspec/specs/usage-account-registry/spec.md` に反映できる状態に保ち、実装完了後の archive で選択規則を正本へ統合する。
- [x] 3.4 実装工程で `plugins/dev-workflow/.claude-plugin/plugin.json` の version を 1 patch 上げ、`plugins/dev-workflow/CHANGELOG.md` に変更を記録する（仕様工程では変更しない）。

## 4. 全体検証

- [x] 4.1 `bats plugins/dev-workflow/tests/account-selector.bats` を実行し、exit 0 と受け入れ条件 1〜4 の通過件数を記録する。
- [x] 4.2 `openspec validate auto-select-claude-account --strict` を実行して exit 0 を確認する。
- [x] 4.3 `bash scripts/test.sh` を実行し、exit 0 を Draft PR に記録する（受け入れ条件 6）。
