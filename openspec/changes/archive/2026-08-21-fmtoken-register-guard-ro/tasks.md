## 1. テスト先行（Red）

- [x] 1.1 `fmtoken.bats` のスタブ `op` を拡張（`item list` が `FMTOKEN_TEST_REGISTERED` の title を返す /
  `item create` の SA 照合を `FMTOKEN_TEST_EXPECT_SA_CREATE` で経路別化）し、
  「rw で read 失敗でも同名 title は exit 47・create なし」「同名なしは create・exit 0」
  「ro 未解決は exit 48・create なし」「item list 失敗は exit 48・create なし」を追加する

## 2. 実装（Green）

- [x] 2.1 `fmtoken.sh` の `--register` 存在判定を ro SA + `op item list` の title 完全一致に置換。
  `resolve_ro_token --optional` を追加し、判定不能時は exit 48（fail-closed）
- [x] 2.2 `bats plugins/capability-registry/tests/fmtoken.bats` 全 34 件 green を確認

## 3. 追随

- [x] 3.1 `1password.md` に「二重登録ガードは ro SA の read で判定する」を前提として追記
- [x] 3.2 `plugin.json` / `marketplace.json` の version bump（並走 PR の番号を確認して取る）
- [x] 3.3 `openspec validate fmtoken-register-guard-ro --strict` を通し、archive して PR に含める
