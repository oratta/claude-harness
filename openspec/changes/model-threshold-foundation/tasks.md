# Tasks

実装対象は proposal.md の 5 ファイルだけ。各範囲は仕様作成時の案内で、編集前に読み直す。既存の 3 スクリプト・そのテスト・pr-token-budget.md は編集しない。

## 1. 根拠付きしきい値の共通部品と利用手順

- [x] 1.1 `test_token_thresholds.py` に unittest を先に書く。両固定 ID と 4 指標の値・各値の根拠、未知/不明/可変別名、既知行でも根拠モデルが違う場合、3 種 env の優先/空白/0/不正値、上書き時の診断維持、権限値を累計へ自動適用しないこと、破損/欠損/必須根拠欠落の表、追加フィールドの許容、import/CLI の同一結果・stdout/stderr・終了コード・repo 外 cwd をケースにする。表の差し替えは unittest.mock と repo 外の一時領域だけで行い、本番の差し替え用 env は作らない。検証: 下記 unittest コマンドで未実装による失敗を確認し、1.3 の実装後に全ケースが通る。触る範囲: `plugins/dev-workflow/tests/test_token_thresholds.py`（新規）
- [x] 1.2 `token-thresholds.json` に schema_version、両 5.5 固定 ID、fallback、4 指標と各値の根拠を追加する。#1799 結論の対象から ID を決め、値・判断日・出典と混在標本/品質未測定の限界を各レコードに添える。検証: 1.1 の表に関するテストで両 ID/fallback の 4 値と根拠を照合する。触る範囲: `plugins/dev-workflow/references/token-thresholds.json`（新規）
- [x] 1.3 `token_thresholds.py` に同梱表の読み込み、`resolve_thresholds(model_id, environ=None)` と CLI を実装する。design.md の結果契約とエラー契約、完全一致、env 優先、再検証診断を守り、GitHub 投稿や状態ファイルを作らない。同時に `token-thresholds.md` に CLI の実行例・結果の読み方・API の値/診断/例外・env と `--cap` の境界・未配線の説明を記す。検証: `python3 -m unittest discover -s plugins/dev-workflow/tests -p 'test_token_thresholds.py'` が exit 0、文書の CLI 例で未知モデルのフォールバック/再検証通知が出る。触る範囲: `plugins/dev-workflow/scripts/token_thresholds.py`（新規）、`plugins/dev-workflow/skills/develop/references/token-thresholds.md`（新規）
- [x] 1.4 同じ `token-thresholds.md` に design.md の再検証手順 1〜8 を再実行の段取りとして書く。原スクリプト/実行条件の取得、基準と新標本、ログと gh 材料、集計順、固定分/消費見積もり/手渡しの釣り合い、総消費と上限対象の分離、検算・欠測・品質未測定、値の変更ごとの結果コメントと出典更新、repo 外作業領域と LLM_LOG_DIR の規則を含める。検証: delta spec の「同じ集計を再実行する手順と更新記録を一か所に持つ」の全 Scenario と文書を照合する。再調査や原スクリプトの取得・実行そのものは今回の完了条件にしない。触る範囲: `plugins/dev-workflow/skills/develop/references/token-thresholds.md`（新規）
- [x] 1.5 decision-criteria.md の文脈上限節の「数値と環境変数名はこの節にだけ置く」を、共通部品の JSON 表・解決処理・利用手順を許容する配置規則に直す。同節の表は未配線期間の既存経路の既定値・環境変数・停止動作の説明、新しい JSON 表は後続の配線で利用するモデル別既定値と根拠であると区別し、表と手順へのリンク、既存 3 スクリプトへ未配線の注記を追加する。検証: 2 つの相対リンク先が実在し、`dev-workflow-develop` の MODIFIED delta の配置・未配線 Scenario と照合でき、既存の数値/停止/権限/fail-open の説明と return-declaration.md・他の面への再掲禁止が変わっていないことを diff で確認する。触る範囲: `plugins/dev-workflow/skills/develop/references/decision-criteria.md:32-46`（コンテキスト上限の入口）

## 2. change 1 の境界と仕様の確認

- [x] 2.1 unittest と `openspec validate model-threshold-foundation --type change --strict`、`git diff --check` を通す。`git diff --name-only fd904b8ff8359965aba8a84bac6b203cff5de2f7 -- plugins/dev-workflow` が上記 5 ファイル以内で、既存 3 スクリプト・それらのテスト・pr-token-budget.md に差分が無いことを確認する。文書からの CLI 例、配置規則、未配線の注記を両 capability の delta spec と照合する。触る範囲: `plugins/dev-workflow/tests/test_token_thresholds.py`（新規・実行のみ）、`plugins/dev-workflow/skills/develop/references/token-thresholds.md`（新規・照合のみ）、`plugins/dev-workflow/skills/develop/references/decision-criteria.md:32-46`（照合のみ）

## Workflow follow-up

- 本体の仕様レビューを経て実装へ進む。この spec 工程ではコードを実装せず、strict validate 後に仕様を commit・push して本体へ返す。PR はまだ作らない。
- 実装後のレビュー・archive・変更記録・PR は本体の指定する後工程で扱い、merge / auto-merge はこの worker から行わない。
- change 2（文脈上限）/ change 3（累計上限）はこの change のマージ後、main から開始する。共通 API の結果・診断を各呼出元の契約に合わせて接続する。
