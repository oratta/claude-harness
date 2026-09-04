## 1. 目印の描画

- [ ] 1.1 目印のテストを書く（Red）: 2 スロットで active スロットの 2 行が `▸ ` で始まり、非 active スロットの 2 行が半角スペース 2 つで始まる
- [ ] 1.2 二重符号化のテストを書く（Red）: ANSI エスケープを剥がした出力でも `▸ ` で active を判別できる / active スロットの `label` に `DIM` が適用されておらず、非 active スロットの `label` には適用されている
- [ ] 1.3 目印が active に追随するテストを書く（Red）: `CLAUDE_SECURESTORAGE_CONFIG_DIR` を 2 番目のスロットに向けると `▸ ` が 2 番目の行に移る
- [ ] 1.4 active スロットが欠測のときのテストを書く（Red）: `▸ ` で始まる行が 1 行も出ず、非 active スロットの行は半角スペース 2 つで始まる
- [ ] 1.5 列揃えのテストを書く（Red）: 目印の有無にかかわらず全行で `5h` / `7d All` の開始位置（表示幅）が一致する。全角ラベル（`仕事`）でも一致する
- [ ] 1.6 1 スロット時の退行ガードを確認する（Red のうちに）: 既存の `git show origin/main:...` との実出力 diff 2 本と、`multi=0` 時に目印が出ないことを検証するケース
- [ ] 1.7 `prefix` の組み立てに目印の列を足す（Green）。active は `▸ ` + 通常の明るさの label、非 active は半角スペース 2 つ + `DIM` の label。`multi=0` の短絡経路には触らない
- [ ] 1.8 `active_idx` をそのまま使い、描画側で判定を作り直していないことを確認する（Refactor）

## 2. ドキュメントとバージョン

- [ ] 2.1 `plugins/statusline/README.md` の複数アカウント表示のサンプルを目印付きに更新し、記号と明るさの二重符号化であること（色が落ちても記号が残る）を「表示の読み方」に追記する
- [ ] 2.2 `plugins/statusline/.claude-plugin/plugin.json` のバージョンを上げ、ルートの `.claude-plugin/marketplace.json` も同時に更新する（`plugins/` 配下の変更はバージョン同期ガード S131 の対象）

## 3. 検証

- [ ] 3.1 `bats plugins/statusline/tests/statusline-multi-account.bats plugins/statusline/tests/statusline.bats` を実行し exit code と出力を記録する
- [ ] 3.2 `bash scripts/lint.sh` を実行し exit code を記録する（shellcheck。`scripts/test.sh` は bats しか回さない）
- [ ] 3.3 `bash scripts/test.sh` を実行し exit code を記録する
- [ ] 3.4 レジストリ不在の状態で `origin/main` 版と出力を diff し、差分が空であることを確認する
- [ ] 3.5 主の実測値（A = 5h 29% / 7d 93%（日程 90%）/ Fable 94%、B = 5h 0% / 7d 0%）のフィクスチャで目印付きのレイアウトを目視確認する
- [ ] 3.6 ANSI エスケープを剥がした出力でも active / 非 active が判別できることを目視確認する
