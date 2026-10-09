## 1. 検査とテスト

- [x] 1.1 `check_third_party_pins` の `find` を、シンボリックリンクは名前を問わず列挙する形にする
- [x] 1.2 ディレクトリへのリンクの下に違反テンプレートがある形のテスト S16a-27 を足す（直す前の `find` では落ちる）
- [x] 1.3 #240 で足したテスト 2 件の ID を S16a-25・S16a-26 に振り直し、`plugins/infra/changes/240.md` を揃える

## 2. spec

- [x] 2.1 Scenario に、列挙の失敗で fail する条件と、シンボリックリンクを違反にする条件を足す（既存の行は変えない）

## 3. 確認

- [x] 3.1 `bats plugins/infra/tests/infra-fixes.bats` が通る
- [x] 3.2 `openspec validate --specs --strict` と `tests/openspec-specs-format.bats` が通る
