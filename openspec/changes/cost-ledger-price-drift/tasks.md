行番号は仕様づくりの時点（origin/main の a8bf4ca8）の値。前のタスクの編集でずれるので、編集の前に該当範囲を読んで確かめる。

編集するファイルは合わせて 11 個（スクリプト 3、テスト 3、README 2、変更の記録 2、`openspec/specs` は archive で反映）。着手前の見積もりがこの数なので、ここから増えたときだけ規模超過として扱う。

## 1. テスト（Red）: statusline が記録を書く

- [ ] 1.1 `plugins/statusline/tests/statusline-session-cost-record.bats` を作る。setup は `statusline-session-records.bats` と同じ形（`CLAUDE_CONFIG_DIR` を一時ディレクトリへ、`STATUSLINE_API_PACE=0`、`STATUSLINE_CODEX=0`、`date +%s` を固定）。このリポジトリの bats は途中に置いた `[[ ]]` が偽でも素通りするので、アサーションには `|| return 1` を付ける（`tests/bats-assertion-guard.bats` が検査する）。触る範囲: `plugins/statusline/tests/statusline-session-cost-record.bats`（新規）、手本は `plugins/statusline/tests/statusline-session-records.bats:1-60`
- [ ] 1.2 `specs/session-cost-record/spec.md` の Scenario ごとに 1 件ずつ書く（最初の描画・値が増えた・値が同じで書き換えない・値が下がった・壊れた記録・ファイル名に使えない session_id・本体の値が無い・`STATUSLINE_SESSION_COST=0` でも書く・書ける/書けないで標準出力が同じ・一時ファイルが残らない・古い記録を消すのは新しい記録を作るときだけ・値が同じ描画では古い記録に触らない）。「書き換えない」は inode か更新時刻が変わらないことで見る。触る範囲: `plugins/statusline/tests/statusline-session-cost-record.bats`（新規）

## 2. 実装（Green）: statusline が記録を書く

- [ ] 2.1 `statusline.sh` に記録の書き込みを足す。置く場所は `now` が定義された後（セッションコストの表示の直前）。流れ: `session_id` の引用符を外して文字種と長さを検査 → 本体の値が数値かを検査 → 記録を組み込みの `read` で読む → 最後の観測値と文字列で同じなら抜ける → 違えば `awk` で大小を比べ、一時ファイル＋`mv` で書く → 新しい記録を作ったときだけ 400 日より古い記録を消す。どの失敗でも標準出力・標準エラー・終了コードを変えない。冒頭のコメントにある行の説明と環境変数の一覧は、表示が変わらないので足さない。触る範囲: `plugins/statusline/scripts/statusline.sh:861-878`（セッションコストの表示。この直前に足す）、`plugins/statusline/scripts/statusline.sh:41-42`（`session_id` と `session_cost_usd` の取り出し。読むだけ）、`plugins/statusline/scripts/statusline.sh:356`（`now`。読むだけ）、`plugins/statusline/scripts/statusline.sh:182-205`（一時ファイル＋`mv` の手本。読むだけ）
- [ ] 2.2 `bats plugins/statusline/tests/` が通ることを確かめる（既存の出力バイト一致のテストを含む）。1 件だけ落ちたら単独で再実行して判定する（複数アカウントのテストは単発で落ちることがある）。触る範囲: なし（実行のみ）

## 3. テスト（Red）: cost-ledger が突き合わせて警告する

- [ ] 3.1 `plugins/cost-ledger/tests/drift.bats` を作る。合成ログは `helper.bash` の `cl_row`（モデルは haiku 固定で `input_tokens=1000000` が $1.00）と `cl_write_log` で組み、記録は `$CLAUDE_CONFIG_DIR/.session-cost/<セッション ID>` に直接書く。単価の無いモデルの行は `cl_mini_log` の形（モデル名を渡せる）を使うか、`drift.bats` の中に小さな組み立て関数を置く。setup で `export LC_ALL=C.UTF-8`。アサーションには `|| return 1` を付ける（既存の cost-ledger の bats と同じ）。触る範囲: `plugins/cost-ledger/tests/drift.bats`（新規）、手本は `plugins/cost-ledger/tests/helper.bash:8-22`（`cl_setup`）、`plugins/cost-ledger/tests/helper.bash:52-64`（`cl_mini_log`）、`plugins/cost-ledger/tests/helper.bash:77-106`（`cl_write_log`・`cl_row`）
- [ ] 3.2 `specs/cost-ledger-pricing/spec.md` の Scenario ごとに 1 件ずつ書く。受け入れ条件に対応するのは次の 2 組: 「差が両方の閾値を超える」で警告が出て「差が閾値以内」「割合は超えるが差額が小さい」「差額は超えるが割合が小さい」で出ない／「単価の無いモデルの行が区間にある」で警告が出る。残りの Scenario（別ブランチの行・区間の外の行・記録が無い・壊れた記録・台帳から読むとき・自前の計算の方が大きい・ずれありが複数でも 1 行・トークンの無い未知モデル・1 行目が同じ・`--no-drift-check`・JSON の `price_drift`）も書く。触る範囲: `plugins/cost-ledger/tests/drift.bats`（新規）
- [ ] 3.3 `gh` の呼び出しが増えないことを固定する。`cl_fake_gh` で呼び出しを数える `gh` を置き、記録のある状態で番号なしの `cost` を実行して 0 回であることを見る。触る範囲: `plugins/cost-ledger/tests/drift.bats`（新規）、手本は `plugins/cost-ledger/tests/helper.bash:66-75`（`cl_fake_gh`）
- [ ] 3.4 `gate-report.bats` に、hook が `cost_ledger.py` を呼ぶ引数に `--no-drift-check` が含まれることを見る 1 件を足す。既存の「cost is asked with GH_REPO set to the labelled repository」と同じ仕掛けで引数を捕まえる。触る範囲: `plugins/cost-ledger/tests/gate-report.bats:385-392`（手本にするテスト。この近くに足す）

## 4. 実装（Green）: cost-ledger が突き合わせて警告する

- [ ] 4.1 `cost_ledger.py` に、記録の場所の解決（`log_root()` と同じ設定ディレクトリの `.session-cost`）と、1 セッション分の記録の読み取り（形が違う・読めない・`t1` が `t0` と同じなら「対象外」を返す）を足す。閾値の定数 2 つ（差額 0.50、割合 0.10）をファイルの上の定数の並びに置く。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:34-61`（定数の並び）、`plugins/cost-ledger/scripts/cost_ledger.py:210-212`（`log_root`。隣に足す）
- [ ] 4.2 対象のセッション ID の行を、ブランチで絞らずに集める入口を足す。台帳を使うときは台帳を生の行のセッション ID で絞って読み、`ledger_sync` はやり直さない。使わないときは、更新時刻が対象の記録の `t0` の最小値より前の会話ログを開かず、開いたファイルは生の行で絞る。既存の `branch` の絞り込み（生の行で弾いてからパースする）と同じ形にする。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:285-334`（`facts_from_lines`・`iter_facts`）、`plugins/cost-ledger/scripts/cost_ledger.py:560-603`（`iter_ledger_facts`・`load_facts`）
- [ ] 4.3 突き合わせの関数を足す。入力は対象のセッション ID の集まりと単価表、出力は「突き合わせた数・ずれありの数・差額が最大のセッションの値・単価の無いモデルを含むセッションの数と合計とモデル名」。会話ログの時刻（ISO 形式・ミリ秒・末尾 `Z`）を epoch 秒に直して `[t0 + 1, t1 + 1)` で絞る。時刻を読めない行は区間の外として扱う。単価の無いモデルは、トークン 5 種のいずれかが 1 以上の行だけ数える。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:97-105`（`Pricing.cost`。読むだけ）、`plugins/cost-ledger/scripts/cost_ledger.py:610-631`（`summarise`。この近くに足す）
- [ ] 4.4 警告行を作る関数を足し、`cmd_branch` と `cmd_issue` の出力の最後（内訳と既存の注記のうしろ）で呼ぶ。1 行目は触らない。`cmd_issue` は最初から全行を読んでいるので、読み直さずにその行を渡してよい。JSON の出力には `price_drift`（警告が無ければ `null`）を足す。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:747-768`（`render_breakdown`。この近くに警告行の関数を足す）、`plugins/cost-ledger/scripts/cost_ledger.py:789-823`（`cmd_branch`）、`plugins/cost-ledger/scripts/cost_ledger.py:941-987`（`cmd_issue`）
- [ ] 4.5 `cost` サブコマンドに `--no-drift-check` を足し、`cmd_cost` が `cmd_branch`・`cmd_issue` に渡す `Namespace` に載せる。`branch`・`issue` を直接呼ぶ経路は引数を持たず、常に突き合わせる。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:826-868`（`cmd_cost`）、`plugins/cost-ledger/scripts/cost_ledger.py:1036-1045`（`cost` の引数の定義）
- [ ] 4.6 `gate-report.sh` の `cost` の呼び出しに `--no-drift-check` を足す。触る範囲: `plugins/cost-ledger/scripts/gate-report.sh:401-403`
- [ ] 4.7 `bats plugins/cost-ledger/tests/` が通ることを確かめる。触る範囲: なし（実行のみ）

## 5. 文書

- [ ] 5.1 `plugins/cost-ledger/README.md` の「料金表と円換算」の未知モデルの説明のうしろに、ずれの警告（何と何を比べるか、閾値、statusline の記録が要ること、警告が出たら `pricing.json` を直すこと）を書く。触る範囲: `plugins/cost-ledger/README.md:32-50`（「料金表と円換算」の節）
- [ ] 5.2 `plugins/statusline/README.md` に、本体のセッションコストを `.session-cost/` に書き残すこと、cost-ledger が読むこと、`/statusline:setup` を再実行すると記録が始まることを書く。触る範囲: `plugins/statusline/README.md:48-56`（`/statusline:setup` の説明）、テストの一覧 `plugins/statusline/README.md:163-167`
- [ ] 5.3 変更の記録を 2 つ書く。版は上げない。触る範囲: `plugins/cost-ledger/changes/692.md`（新規）、`plugins/statusline/changes/692.md`（新規）、書式の手本は `plugins/cost-ledger/changes/285.md:1-7`
- [ ] 5.4 `commands/cost.md`・`plugin.json` の `description`・`rules/`・`CLAUDE.md` を変えていないことを `git diff --stat origin/main` で確かめる（常時注入の予算を動かさない）。触る範囲: なし（確認のみ）

## 6. 実測（PR に書く）

- [ ] 6.1 statusline の描画時間を、足す前と後で測る。足す前のスクリプトは `git show origin/main:plugins/statusline/scripts/statusline.sh` を一時ディレクトリに書き出して使う（作業ツリーを戻す操作はしない）。条件は 2 つ: 本体の値が前回と同じ入力を 50 回、本体の値が毎回増える入力を 50 回。`CLAUDE_CONFIG_DIR` を一時ディレクトリに向け、`STATUSLINE_API_PACE=0`・`STATUSLINE_CODEX=0` で測る。4 つの中央値（足す前/後 × 同じ値/増える値）を PR に書く。触る範囲: なし（計測のみ）
- [ ] 6.2 `/cost` の所要時間を、足す前と後で測る。対象はこの change のブランチ。条件は 2 つ: 台帳を使わない（`env -u COST_LEDGER_PATH`、実環境の会話ログは読み取りのみ）、台帳を使う（一時ディレクトリの台帳。利用者の台帳には書かない）。記録が無いときと有るときの両方を測る。触る範囲: なし（計測のみ）
- [ ] 6.3 `gh` の呼び出し回数を PR に書く。statusline の書き込みは 0 回、突き合わせは 0 回（3.3 のテストが根拠）。pr-review-gate 通過時の hook は `--no-drift-check` で突き合わせを行わないので、hook 1 回の `gh` の回数と所要時間は変わらない（3.4 のテストが根拠）。触る範囲: なし（PR 本文）
- [ ] 6.4 実機の 1 セッションで、本体の値と自前の計算の差を測って PR に書く。手順の例: 一時ディレクトリを `CLAUDE_CONFIG_DIR` にし、その `projects` を実環境の会話ログへのシンボリックリンクにする → セッション ID を決めて `claude -p --session-id <UUID> --output-format json '<短い作業>'` を実行し、返ってきた `total_cost_usd` を本体の値とする → 実行の前（値 0）と後（返ってきた値）の 2 回、statusline のスクリプトにその `session_id` と `cost.total_cost_usd` を持つ入力を流して記録を作る → `cost_ledger.py branch <ブランチ>` を実行して警告の有無を見る。PR には、本体の値・自前の計算・差額・割合・使ったモデルを書く。画面のある通常のセッションでの確認が要るかどうかは return の `画面確認:` 行で本体に伝える。触る範囲: なし（計測のみ）
- [ ] 6.5 6.4 で、単価表が正しいはずのセッションの差が閾値（差額 $0.50 かつ 10%）を超えたら、閾値を手元で動かさずに止めて、測った値と考えられる原因を return で報告する。触る範囲: なし

## 7. 確認

- [ ] 7.1 `bash scripts/test.sh`（常時注入の予算 `tests/injection-budget.bats` を含む）。触る範囲: なし（実行のみ）
- [ ] 7.2 `openspec validate cost-ledger-price-drift --strict`。触る範囲: なし（実行のみ）
