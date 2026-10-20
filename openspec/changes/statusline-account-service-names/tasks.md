## 1. Claude の名前

- [ ] 1.1 登録簿を読む Python 片で、切り詰めた label の前に `Claude ` を付け、結果の表示幅を 5 列目に渡す（切り詰めの上限 8 は label にだけ掛ける）。触る範囲: plugins/statusline/scripts/statusline.sh:417-470（`clip_label` の呼び出しと行の出力）
- [ ] 1.2 bats: スロット `a`（A）・`b`（B）で行頭が `Claude A` / `Claude B` になる。全角ラベル（`Claude 仕事`）で列が揃い、長い label で `Claude abcdefgh` のようにサービス名が残る。触る範囲: plugins/statusline/tests/statusline-multi-account.bats:124-134、434-480（既存の label 列のテストの期待値更新を含む）

## 2. Codex の名前

- [ ] 2.1 登録簿を読む Python 片に `codex.label` の読み取りを足す（空でない文字列・制御文字なし・表示幅 8 に切る。それ以外は `A`。登録簿が無ければ bash 側で `A`）。触る範囲: plugins/statusline/scripts/statusline.sh:417-470、476-478（既定スロットの分岐）
- [ ] 2.2 Codex の行の固定幅 5 と固定文字列 `Codex` を、`Codex <label>` とその表示幅に置き換える。Codex の行が無いときは列幅に影響させない。触る範囲: plugins/statusline/scripts/statusline.sh:526-538、779-784
- [ ] 2.3 テスト: `codex.label` 未設定で `Codex A`、`{"label":"X"}` で `Codex X`、不正値で `Codex A`、長い label で 8 桁に切れる。既存の `  Codex  off` などの期待値を新しい名前に直す（オフの行そのものは変えない）。触る範囲: plugins/statusline/tests/statusline.bats:183-232、plugins/statusline/tests/statusline-multi-account.bats（新規テストの追加）、plugins/statusline/tests/test_codex.py:233-255

## 3. 退行と文書

- [ ] 3.1 登録簿が無い・スロット 1 つで Codex の行が無いときに出力がバイト単位で変わらないことを、既存の退行ガード（`statusline.bats`）と `single:` のテストで確かめる。触る範囲: plugins/statusline/tests/statusline-multi-account.bats:319-360
- [ ] 3.2 README の表示例とフィールド表を新しい名前に直し、`codex.label` の行を足す。触る範囲: plugins/statusline/README.md:95-150、211-231
- [ ] 3.3 `bats plugins/statusline/tests/` と `python3 -m pytest plugins/statusline/tests/` が exit 0 になることを確かめる
