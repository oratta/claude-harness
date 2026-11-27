## 1. review-hit-set.py の行単位違反を蓄積に変える

- [x] 1.1 失敗するテストを先に書く（Red）: `plugins/dev-workflow/tests/review-hit-set.bats` に次のケースを追加する。「補助表に複数種類の違反が同時にある」（2 つの `contract:` 行がそれぞれの `<ファイル>:<行>` 付きで出て exit 1）、「主表の扱い欄違反と補助表の違反が混在する」、「契約違反があるときは第 2 段の差分（`unmatched:` 等）を出さない」、「表の構造エラーは引き続き即時停止する」（見出し欠落・列数不一致を含む入力）。既存の単発違反テスト（`a rewritten-rows entry pointing at a fixed row is a contract violation` 等 4 件）は出力先・行数の期待を変えず、そのまま pass することを確認する
- [x] 1.2 `parse_rewritten`（review-hit-set.py:144-166 付近）を、補助表の 3 条件（対応先が扱い「該当しない」の行をちょうど 1 つ指さない・重複・書き換え無し）で即時 `raise ContractError` する代わりに、違反を `violations` リストへ蓄積して全行の検査を続けるよう書き換える。違反した行（対応先不正・書き換え無し）は `rewritten` マップに採用しない。重複（同じ `(path, line)` を指す 2 件目以降）は最初に見つかった行の値だけを `rewritten` の候補として残し、2 件目以降を違反として記録する。戻り値を `(rewritten, violations)` のタプルに変える
- [x] 1.3 `main`（review-hit-set.py:297-302 付近）の `--head` 検査ループを、扱い欄の値チェックで即時 `raise ContractError` する代わりに違反を `report` に蓄積し、残りの行の検査を続けるよう書き換える。`parse_rewritten` から返る `violations` も `report` に連結する。**`violations` が 1 件でもあれば `second_stage` を呼ばない**（出力は第 1 段の `missing:` / `extra:` と `contract:` 行だけにする）。`violations` が 0 件のときだけ従来どおり `second_stage` を実行する
- [x] 1.4 蓄積した違反の出力形式を `contract: <理由>: <path>:<line>` に統一する（既存の `ContractError` のメッセージ文言はすでに末尾が `<path>:<line>` で終わるので、そのまま `contract: ` プレフィックスを付けて使う。二重に `<path>:<line>` を付け足さない）。表の構造エラー（見出し欠落・列数不一致・必須フィールド欠落・SHA 形式不正・検索コマンド構文違反・補助表の行の path/行番号不正・本文の escape 違反・`--repo` 不正・`git grep` 失敗）は `ContractError` の即時 raise・stderr 出力のまま変えない
- [x] 1.5 テストを通す最小実装にする（Green）。`plugins/dev-workflow/tests/review-hit-set.bats` をこのファイル単体で実行し、全件 pass することを確認する
- [x] 1.6 リファクタ（Refactor）: `parse_rewritten` と `main` の検査ループの重複があれば整理する。振る舞いは変えない

## 2. 仕様の同期と全体検証

- [x] 2.1 `openspec/specs/dev-workflow-pr-review-gate/spec.md` に本 change の delta spec（`specs/dev-workflow-pr-review-gate/spec.md`）を反映する（archive 時点で行う。ここでは delta の内容が実装と一致していることだけ確認する）
- [x] 2.2 `plugins/dev-workflow/changes/406.md` に変更の記録を書く（`plugins/dev-workflow/changes/447.md` の書式に合わせる。見出し `# <変更の要約>（#406）`、続けて背景を 1 段落、変更点の箇条書き）。`plugin.json` / `.claude-plugin/marketplace.json` の `version` は上げず、`CHANGELOG.md` にも追記しない
- [x] 2.3 `scripts/test.sh` を push 前にフルで実行し、exit code と失敗件数をターン内に表示する
