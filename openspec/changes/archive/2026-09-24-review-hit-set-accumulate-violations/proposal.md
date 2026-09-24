## Why

`plugins/dev-workflow/scripts/review-hit-set.py` の `parse_rewritten` と `main` の `--head` 検査ループは、順 3（一覧の一致で閉じる）の補助表・扱い欄を検査するとき、行単位の契約違反（扱い欄の値が `直した` / `該当しない: <理由>` のどちらかちょうどでない、補助表の行が扱い「該当しない」の行をちょうど 1 つ指さない、重複、書き換え無し）を見つけた最初の 1 件で `ContractError` を raise してプロセスを止める。補助表に複数種の違反があると、W には 1 件ずつしか返らず、修正して出し直すたびに次の違反が新たに見つかる。順 3 の差し戻しは 1 回までという上限があるため、2 回目の出し直しでも別の違反が残っていると、機械的に順 6（決める役の裁定）に落ちる。これは実装の都合による事故（全違反を検査し切らずに停止する）が招く落ち込みであり、W が一度に直せる情報を渡せば避けられる。

## What Changes

- `review-hit-set.py` の行単位の内容違反（扱い欄の値、補助表の対応先、重複、書き換え無し）を `ContractError` の即時 raise から、`report` リストへの蓄積に変える。全行を検査し終えてから蓄積した違反をまとめて標準出力に出し（各行 `contract: <理由>: <path>:<line>` 形式）、exit 1 にする。
- 違反した行は書き換えマップに採用せず、違反が 1 件でもあれば HEAD との差分計算（第 2 段: `unmatched:` / `not-removed:`）を実行しない。違反がある実行の出力は第 1 段の差分（`missing:` / `extra:`）と `contract:` 行だけにする（前提の表が信頼できない状態で差分を計算しても意味が無いため）。
- 表の構造エラー（見出し欠落、列数不一致、必須フィールド欠落、SHA 形式不正、検索コマンドの構文違反など、個々の行を検査する前提が成立しない種類のエラー）は、引き続き `ContractError` を即時 raise して止める（部分的な検査結果を返しても意味がないため）。
- `openspec/specs/dev-workflow-pr-review-gate/spec.md` の既存 Requirement（`--head` 付きの呼び出しでの契約違反の扱い）を、行単位の違反を全件検査してまとめて報告する契約に更新する。

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-pr-review-gate`: `review-hit-set.py --head` の契約違反検査を、最初の 1 件で停止する仕様から、行単位の内容違反（扱い欄の値・補助表の対応先・重複・書き換え無し）を全件検査してまとめて報告する仕様に変える。表の構造エラー（見出し欠落・列数不一致等）は従来どおり即時停止のままとする区別を明記する。

## Impact

- `plugins/dev-workflow/scripts/review-hit-set.py`（`parse_rewritten` 関数、`main` の `--head` 検査ループ、出力フォーマット）
- `plugins/dev-workflow/tests/review-hit-set.bats`（review-hit-set.py の既存テスト。複数違反を含む入力での挙動を追加検証する）
- `openspec/specs/dev-workflow-pr-review-gate/spec.md`（902 行付近の Requirement）
- pr-review-gate の順 3 運用（W・G のやり取り）に直接の手順変更はないが、差し戻し 1 回で複数違反をまとめて直せるようになる分、順 6 への落ち込みが減る
