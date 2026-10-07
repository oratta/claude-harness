## 1. 閉じた PR の問い合わせ

- [ ] 1.1 `fetch_closing_prs(where, number)` を足す。`gh api graphql` を 1 回（`issue(number) { _CLOSING_FIELDS }` と `nameWithOwner`、`{owner}` `{repo}` の置換で変数を渡す）、`_closing_refs()` で絞る。失敗・形の崩れ・100 件超は `EpicError` を呼び元で受けて `None`（読めなかった）を返す。0 件は `[]`。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:367-427`（`_CLOSING_FIELDS`・`_closing_refs()` の直後に新規関数）
- [ ] 1.2 `cmd_cost` の「子 issue を持たない issue」の分岐（`kind == "issue"`）で `fetch_closing_prs` を呼び、結果を `cmd_issue` に渡す（`closing_pr` の引数に `番号:ブランチ` の列を組む、または `Namespace` に `closing_prs` と `closing_prs_error` を足す）。PR・エピック・番号なしの経路では呼ばない。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:2307-2320`（`cmd_cost`）
- [ ] 1.3 `cmd_issue` で読めなかったときの 1 行（`  閉じた PR を読めなかったため、PR の分は合計に入っていません。`）を、合計の行を出さない位置（`対象:` の行の前）に足し、`--json` は標準出力を JSON だけに保ち、読めなかった行を混ぜずに `closing_prs_error`（読めたら `false`、0 件でも `false`）を足す。通常出力の 0 件時は 1 文字も変えない。`cost_ledger.py issue` の直接呼び（`--closing-pr` あり・なし）の出力は変えない。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:2642-2700`（`cmd_issue`）

## 2. テスト（偽の `gh` で。GraphQL の呼び出し回数も数える）

- [ ] 2.1 閉じた PR が 1 件の issue で、`/cost` の出力に合計・PR の額・PR 外の額が出て終了コード 0、1 行目が `--closing-pr` なしと同じ。触る範囲: `plugins/cost-ledger/tests/cost-command.bats`、`plugins/cost-ledger/tests/helper.bash:70-77`（`cl_fake_gh`）
- [ ] 2.2 閉じた PR が 0 件の issue で、出力が `cost_ledger.py issue` と完全に同じ。GraphQL 1 回。触る範囲: 同上
- [ ] 2.3 問い合わせの失敗・形の崩れ・`hasNextPage` 真で、終了コード 0・区間の分のまま・読めなかった旨の 1 行・合計の行なし。`--json` の `closing_prs_error`。触る範囲: 同上
- [ ] 2.6 `--json` の標準出力が失敗時も JSON として読めること、0 件時の `--json` の `closing_prs_error` が `false` で通常出力は従来と同一であること。触る範囲: `plugins/cost-ledger/tests/cost-command.bats`
- [ ] 2.4 別リポジトリ・フォークの PR を数えない。PR 番号・エピック・番号なしの経路で閉じた PR の問い合わせ（専用の GraphQL）が走らない。触る範囲: 同上
- [ ] 2.5 既存の bats（`cost-command.bats` の「子 issue の数が応答に無い」で GraphQL 0 回を見ているものなど）を新しい回数に直す。触る範囲: `plugins/cost-ledger/tests/cost-command.bats`

## 3. 文書と記録

- [ ] 3.1 `commands/cost.md` の呼び方の表の `/cost <issue番号>` の行に、閉じた PR があれば合計が 2 行目に出ること・要ネットワークを足す。触る範囲: `plugins/cost-ledger/commands/cost.md:35-42`
- [ ] 3.1b `commands/cost.md` の「出力の扱い」で、1 行目に続けて合計の行と読めなかった旨の行も利用者に見せる指示に直す（PR に貼るのは 1 行目だけのまま）。確認項目: 該当の文が「1 行目だけ見せる」のままになっていないこと。触る範囲: `plugins/cost-ledger/commands/cost.md:49-53`
- [ ] 3.1c `README.md` の「`/cost <子の番号>` は今までどおり区間だけの額」の説明（58 行付近）と、区間だけの累計に関する他の記述（19・60・292-295 行付近）を、今回の動作（子の番号でも閉じた PR があれば 2 行目に合計が出る。1 行目は区間のまま）に合わせて直す。触る範囲: `plugins/cost-ledger/README.md:19-60`、`:290-296`
- [ ] 3.2 変更の記録 `plugins/cost-ledger/changes/736.md` を書く（利用者に見える変化と、`/cost <issue番号>` の GraphQL が 1 回増えること）。触る範囲: `plugins/cost-ledger/changes/736.md`（新規）
- [ ] 3.3 変更前後の `/cost <issue番号>` 1 回の所要時間と `gh` の呼び出し回数を実測し、PR 本文に書く（変更前は main、変更後はこのブランチ。実測の手順はテストに入れずに手で実行する）
