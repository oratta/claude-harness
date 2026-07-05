# Tasks: goal-time-recipes

## 1. テスト先行（bats）

- [x] 1.1 change-1 の成果物（レシピ形式規約・固定見出しの正確な文字列・`plugins/loops/recipes/` の置き場所）を読み、grep 対象の見出しパターンを確定する
- [x] 1.2 `plugins/loops/tests/recipes-seed.bats` を新設し、goal レシピ 3 ファイル（goal-tests-green / goal-acceptance-pass / goal-lighthouse）の存在と固定見出し 7 種（ループ型 / 目的 / 起動コマンド / 停止基準 / 前提 / コスト注意 / エスカレーション）の grep 検証を書く
- [x] 1.3 同 bats に、goal レシピの停止基準が検証コマンド + 期待値 + 最大試行数（具体的な数値デフォルト）を含むことの grep 検証を書く（goal-tests-green は bats 実行コマンド、goal-lighthouse はスコア閾値 90 と最大 5 回、goal-acceptance-pass は最大試行数の数値デフォルトと「受け入れ条件」「全て PASS」相当の固定トークン）
- [x] 1.4 同 bats に、time レシピ 3 ファイル（loop-pr-babysit / cron-daily-report / cron-weekly-report）の存在と固定見出し 7 種の grep 検証、および停止基準節が空でないこと、loop-pr-babysit に非破壊制約の固定文言（merge 禁止・Ready for Review 切替禁止・main 直 push 禁止に相当するトークン）が存在することの検証を書く
- [x] 1.5 同 bats に、全 6 レシピの起動コマンドがネイティブプリミティブ（/goal・/loop・/schedule・skill 起動文字列）であること、独自スクリプト起動への参照が無いこと、`claude-` で始まるモデル ID が 0 件であること、停止基準節に主観語デナイリスト（「良くなったら」「十分に」「改善したら」「きれいに」等）のヒットが 0 件であることの grep 検証を書く
- [x] 1.6 `bats plugins/loops/tests/recipes-seed.bats` を実行し、レシピ未作成の時点で全テストが FAIL（RED）することを確認する

## 2. goal レシピ実装

- [x] 2.1 `plugins/loops/recipes/goal-tests-green.md` を作成する（ループ型: ゴールベース / 成功基準: `find plugins -name '*.bats' -print0 | xargs -0 bats` が exit 0 / 最大試行数デフォルト 5 回と変更箇所の併記 / コピペ可能な /goal 起動コマンド / コスト注意: パイロット実行・決定論部分のスクリプト化）
- [x] 2.2 `plugins/loops/recipes/goal-acceptance-pass.md` を作成する（成功基準: 対象 longrun plan.md の受け入れ条件に列挙された機械検証コマンドが全て PASS / 受け入れ条件をコマンド + 期待値として読み取る手順 / 最大試行数デフォルトと変更箇所 / エスカレーション: 2 連続同一失敗で人間へ）
- [x] 2.3 `plugins/loops/recipes/goal-lighthouse.md` を作成する（公式例 `/goal get the homepage Lighthouse score to 90 or above, stop after 5 tries` の忠実な移植 / 閾値 90 デフォルト / 前提: Web プロジェクト・Lighthouse 実行手段 / 公式例由来である旨の記載）
- [x] 2.4 `bats plugins/loops/tests/recipes-seed.bats` で goal レシピ分のテストが GREEN になることを確認する

## 3. time レシピ実装

- [x] 3.1 `plugins/loops/recipes/loop-pr-babysit.md` を作成する（公式例 `/loop 5m check my PR, address review comments, and fix failing CI` の Draft PR 運用向け調整版 / 間隔デフォルト 5〜10 分と変更方法 / 非破壊制約: merge・Ready for Review 切り替え・main 直 push 禁止 / 停止基準: PR マージ・クローズ検知で終了 / コスト注意: パイロット実行）
- [x] 3.2 `plugins/loops/recipes/cron-daily-report.md` を作成する（発火時プロンプト: daily-report 非対話モードの起動文字列 / 推奨頻度: 日次デフォルトと変更方法 / 停止基準 / 前提: Vault・セッション jsonl のローカルデータ依存によるローカル実行必須 / スケジューラ登録は呼び出し側の責務と明記）
- [x] 3.3 `plugins/loops/recipes/cron-weekly-report.md` を作成する（発火時プロンプト: weekly-report 非対話モードの起動文字列 / 推奨頻度: 週次デフォルトと変更方法 / 停止基準 / ローカル実行必須の制約 / スケジューラ登録は呼び出し側の責務と明記）
- [x] 3.4 全 6 レシピのコスト注意節に公式トークン管理の該当項目（頻度最小化を必須、該当に応じて決定論スクリプト化・パイロット実行）が明記されていることを確認し、`bats plugins/loops/tests/recipes-seed.bats` の全 PASS（GREEN）を確認する

## 4. 検証・統合

- [x] 4.1 `find plugins -name '*.bats' -print0 | xargs -0 bats` を実行し、既存テストを含め全 PASS することを確認する
- [x] 4.2 受け入れ条件 6 の grep 検証: `plugins/loops/recipes/*.md` の全レシピが固定見出し 7 種を持ち、停止基準の無いレシピが 0 件であることを確認する
- [x] 4.3 受け入れ条件 7 の検証: `plugins/loops/` に常駐スクリプト・カスタム driver が存在せず、全レシピの起動コマンドがネイティブプリミティブであることを確認する
- [x] 4.4 受け入れ条件 9 の検証: goal レシピ 3 本・time レシピ 3 本が存在し、goal レシピの成功基準が全て機械検証可能（コマンド + 期待値）であることを確認する
- [x] 4.5 goal デモ（plan 動作確認手順 3）: `goal-tests-green.md` の起動コマンドをこのリポジトリで実行し、全 bats PASS で停止することを確認してログを `{longrun-dir}` に残す。/goal の最大試行数指定構文が想定と異なればレシピを実測に合わせて修正する
- [x] 4.6 `git diff --stat` で `plugins/daily-report/` と `plugins/weekly-report/` に変更が 0 件であることを確認する（config.yaml rule: 既存プラグイン本文は変更しない）
