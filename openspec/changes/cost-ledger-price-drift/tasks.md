行番号は仕様づくりの時点（origin/main の a8bf4ca8）の値。前のタスクの編集でずれるので、編集の前に該当範囲を読んで確かめる。

編集するファイルは合わせて 11 個（スクリプト 3、テスト 3、README 2、変更の記録 2、`openspec/specs` は archive で反映）。着手前の見積もりがこの数なので、ここから増えたときだけ規模超過として扱う。

## 1. テスト（Red）: statusline が記録を書く

- [x] 1.1 `plugins/statusline/tests/statusline-session-cost-record.bats` を作る。setup は `statusline-session-records.bats` と同じ形（`CLAUDE_CONFIG_DIR` を一時ディレクトリへ、`STATUSLINE_API_PACE=0`、`STATUSLINE_CODEX=0`、`date +%s` を固定）。このリポジトリの bats は途中に置いた `[[ ]]` が偽でも素通りするので、アサーションには `|| return 1` を付ける（`tests/bats-assertion-guard.bats` が検査する）。触る範囲: `plugins/statusline/tests/statusline-session-cost-record.bats`（新規）、手本は `plugins/statusline/tests/statusline-session-records.bats:1-60`
- [x] 1.2 `specs/session-cost-record/spec.md` の Scenario ごとに 1 件ずつ書く（最初の描画・値が増えた・値が同じで書き換えない・表記だけが違う同じ値（`1.5` と `1.50`）で書き換えない・値が下がった・壊れた記録・ファイル名に使えない session_id・本体の値が無い・`STATUSLINE_SESSION_COST=0` でも書く・書ける/書けないで標準出力が同じ・一時ファイルが残らない・古い記録を消すのは新しい記録を作るときだけ・値が同じ描画では古い記録に触らない）。「書き換えない」は inode か更新時刻が変わらないことで見る。触る範囲: `plugins/statusline/tests/statusline-session-cost-record.bats`（新規）

## 2. 実装（Green）: statusline が記録を書く

- [x] 2.1 `statusline.sh` に記録の書き込みを足す。置く場所は `now` が定義された後（セッションコストの表示の直前）。流れ: `session_id` の引用符を外して文字種と長さを検査 → 本体の値が数値かを検査 → 記録を組み込みの `read` で読む → 最後の観測値と文字列で同じなら抜ける（外部コマンドを起動しない） → 違えば `awk` を 1 回だけ起動して数として比べ、「等しい・小さい・大きい」の 3 通りを受け取る → 等しければ書かずに抜ける → 小さい・大きいなら一時ファイル＋`mv` で書く → 新しい記録を作ったときは必ず 400 日より古い記録を消す（それ以外の描画では消さない。400 日は固定で、設定は足さない）。どの失敗でも標準出力・標準エラー・終了コードを変えない。冒頭のコメントにある行の説明と環境変数の一覧は、表示が変わらないので足さない。触る範囲: `plugins/statusline/scripts/statusline.sh:861-878`（セッションコストの表示。この直前に足す）、`plugins/statusline/scripts/statusline.sh:41-42`（`session_id` と `session_cost_usd` の取り出し。読むだけ）、`plugins/statusline/scripts/statusline.sh:356`（`now`。読むだけ）、`plugins/statusline/scripts/statusline.sh:182-205`（一時ファイル＋`mv` の手本。読むだけ）
- [x] 2.2 `bats plugins/statusline/tests/` が通ることを確かめる（既存の出力バイト一致のテストを含む）。1 件だけ落ちたら単独で再実行して判定する（複数アカウントのテストは単発で落ちることがある）。触る範囲: なし（実行のみ）

## 3. テスト（Red）: cost-ledger が突き合わせて警告する

- [x] 3.1 `plugins/cost-ledger/tests/drift.bats` を作る。合成ログは `helper.bash` の `cl_row`（モデルは haiku 固定で `input_tokens=1000000` が $1.00）と `cl_write_log` で組み、記録は `$CLAUDE_CONFIG_DIR/.session-cost/<セッション ID>` に直接書く。単価の無いモデルの行は `cl_mini_log` の形（モデル名を渡せる）を使うか、`drift.bats` の中に小さな組み立て関数を置く。setup で `export LC_ALL=C.UTF-8`。アサーションには `|| return 1` を付ける（既存の cost-ledger の bats と同じ）。触る範囲: `plugins/cost-ledger/tests/drift.bats`（新規）、手本は `plugins/cost-ledger/tests/helper.bash:8-22`（`cl_setup`）、`plugins/cost-ledger/tests/helper.bash:52-64`（`cl_mini_log`）、`plugins/cost-ledger/tests/helper.bash:77-106`（`cl_write_log`・`cl_row`）
- [x] 3.2 `specs/cost-ledger-pricing/spec.md` の Scenario ごとに 1 件ずつ書く。受け入れ条件に対応するのは次の 2 組: 「差が両方の閾値を超える」で警告が出て「差が閾値以内」「割合は超えるが差額が小さい」「差額は超えるが割合が小さい」で出ない／「単価の無いモデルの行が区間にある」で警告が出る。残りの Scenario（別ブランチの行・区間の外の行・記録が無い・壊れた記録・台帳から読むとき・自前の計算の方が大きい・ずれありが複数でも 1 行・トークンの無い未知モデル・1 行目が同じ・`--no-drift-check`・JSON の `price_drift`）も書く。読み直しの打ち切りの Scenario 5 件（`COST_LEDGER_DRIFT_BUDGET_SECONDS=0` で `未確認` の行が 1 行だけ出て 1 行目と終了コードが変わらない・`inf` で最後まで突き合わせる・台帳から読むときも打ち切る・記録が無ければ `未確認` の行が出ない・読めない値 `abc` で既定を使う）も書く。打ち切りは `0` で起こし、テストを実際の経過時間に頼らせない。触る範囲: `plugins/cost-ledger/tests/drift.bats`（新規）
- [x] 3.3 `gh` の呼び出しが増えないことを固定する。`cl_fake_gh` で呼び出しを数える `gh` を置き、記録のある状態で番号なしの `cost` を実行して 0 回であることを見る。触る範囲: `plugins/cost-ledger/tests/drift.bats`（新規）、手本は `plugins/cost-ledger/tests/helper.bash:66-75`（`cl_fake_gh`）
- [x] 3.4 `gate-report.bats` に、hook が `cost_ledger.py` を呼ぶ引数に `--no-drift-check` が含まれることを見る 1 件を足す。既存の「cost is asked with GH_REPO set to the labelled repository」と同じ仕掛けで引数を捕まえる。触る範囲: `plugins/cost-ledger/tests/gate-report.bats:385-392`（手本にするテスト。この近くに足す）

## 4. 実装（Green）: cost-ledger が突き合わせて警告する

- [x] 4.1 `cost_ledger.py` に、記録の場所の解決（`log_root()` と同じ設定ディレクトリの `.session-cost`）と、1 セッション分の記録の読み取り（形が違う・読めない・`t1` が `t0` と同じなら「対象外」を返す）を足す。閾値の定数 2 つ（差額 0.50、割合 0.10）と、読み直しの上限の定数（既定 1 秒）・上限を変える環境変数の名前（`COST_LEDGER_DRIFT_BUDGET_SECONDS`）をファイルの上の定数の並びに置く。環境変数は 0 以上の秒数か `inf` を受け付け、未設定・数として読めない値・負の値は既定に倒す。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:34-61`（定数の並び）、`plugins/cost-ledger/scripts/cost_ledger.py:210-212`（`log_root`。隣に足す）
- [x] 4.2 対象のセッション ID の行を、ブランチで絞らずに集める入口を足す。台帳を使うときは台帳を生の行のセッション ID で絞って読み、`ledger_sync` はやり直さない。使わないときは、更新時刻が対象の記録の `t0` の最小値より前の会話ログを開かず、開いたファイルは生の行で絞る。既存の `branch` の絞り込み（生の行で弾いてからパースする）と同じ形にする。この入口は読み直しの上限を受け取り、始めた時点からの経過時間を `time.monotonic()` で測って、ファイルを 1 つ開く前ごとと、1 つのファイルの中で生の行を 5,000 行読むごとに確かめる。上限に達したら読むのをやめ、「打ち切った」ことを呼び出し側に返す（読めた分の行は返さない）。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:285-334`（`facts_from_lines`・`iter_facts`）、`plugins/cost-ledger/scripts/cost_ledger.py:560-603`（`iter_ledger_facts`・`load_facts`）
- [x] 4.3 突き合わせの関数を足す。入力は対象のセッション ID の集まりと単価表、出力は「突き合わせた数・ずれありの数・差額が最大のセッションの値・単価の無いモデルを含むセッションの数と合計とモデル名」。会話ログの時刻（ISO 形式・ミリ秒・末尾 `Z`）を epoch 秒に直して `[t0 + 1, t1 + 1)` で絞る。時刻を読めない行は区間の外として扱う。単価の無いモデルは、トークン 5 種のいずれかが 1 以上の行だけ数える。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:97-105`（`Pricing.cost`。読むだけ）、`plugins/cost-ledger/scripts/cost_ledger.py:610-631`（`summarise`。この近くに足す）
- [x] 4.4 警告行を作る関数を足し、`cmd_branch` と `cmd_issue` の出力の最後（内訳と既存の注記のうしろ）で呼ぶ。1 行目は触らない。`cmd_issue` は最初から全行を読んでいるので、読み直さずにその行を渡してよい。JSON の出力には `price_drift`（警告が無ければ `null`）を足す。読み直しが打ち切られたときは、どのセッションも判定せず、閾値超えの行と単価の無いモデルの行の代わりに `単価表のずれ: 未確認` で始まる行を 1 行だけ出す（打ち切ったこと・対象だったセッションの数・上限の秒数・`COST_LEDGER_DRIFT_BUDGET_SECONDS=inf` で最後まで突き合わせられること）。`cmd_issue` は読み直さないので打ち切りは起きない。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:747-768`（`render_breakdown`。この近くに警告行の関数を足す）、`plugins/cost-ledger/scripts/cost_ledger.py:789-823`（`cmd_branch`）、`plugins/cost-ledger/scripts/cost_ledger.py:941-987`（`cmd_issue`）
- [x] 4.5 `cost` サブコマンドに `--no-drift-check` を足し、`cmd_cost` が `cmd_branch`・`cmd_issue` に渡す `Namespace` に載せる。`branch`・`issue` を直接呼ぶ経路は引数を持たず、常に突き合わせる。触る範囲: `plugins/cost-ledger/scripts/cost_ledger.py:826-868`（`cmd_cost`）、`plugins/cost-ledger/scripts/cost_ledger.py:1036-1045`（`cost` の引数の定義）
- [x] 4.6 `gate-report.sh` の `cost` の呼び出しに `--no-drift-check` を足す。触る範囲: `plugins/cost-ledger/scripts/gate-report.sh:401-403`
- [x] 4.7 `bats plugins/cost-ledger/tests/` が通ることを確かめる。触る範囲: なし（実行のみ）

## 5. 文書

- [ ] 5.1 `plugins/cost-ledger/README.md` の「料金表と円換算」の未知モデルの説明のうしろに、ずれの警告（何と何を比べるか、閾値、statusline の記録が要ること、警告が出たら `pricing.json` を直すこと、読み直しは既定 1 秒で打ち切られて `未確認` の行が出ること、`COST_LEDGER_DRIFT_BUDGET_SECONDS` で上限を変えられること）を書く。触る範囲: `plugins/cost-ledger/README.md:32-50`（「料金表と円換算」の節）
- [ ] 5.2 `plugins/statusline/README.md` に、本体のセッションコストを `.session-cost/` に書き残すこと、cost-ledger が読むこと、`/statusline:setup` を再実行すると記録が始まることを書く。触る範囲: `plugins/statusline/README.md:48-56`（`/statusline:setup` の説明）、テストの一覧 `plugins/statusline/README.md:163-167`
- [ ] 5.3 変更の記録を 2 つ書く。版は上げない。触る範囲: `plugins/cost-ledger/changes/692.md`（新規）、`plugins/statusline/changes/692.md`（新規）、書式の手本は `plugins/cost-ledger/changes/285.md:1-7`
- [ ] 5.4 `commands/cost.md`・`plugin.json` の `description`・`rules/`・`CLAUDE.md` を変えていないことを `git diff --stat origin/main` で確かめる（常時注入の予算を動かさない）。触る範囲: なし（確認のみ）

## 6. 実測（PR に書く）

- [ ] 6.1 statusline の描画時間を、足す前と後で測る。足す前のスクリプトは `git show origin/main:plugins/statusline/scripts/statusline.sh` を一時ディレクトリに書き出して使う（作業ツリーを戻す操作はしない）。条件は 2 つ: 本体の値が前回と同じ入力を 50 回、本体の値が毎回増える入力を 50 回。`CLAUDE_CONFIG_DIR` を一時ディレクトリに向け、`STATUSLINE_API_PACE=0`・`STATUSLINE_CODEX=0` で測る。4 つの中央値（足す前/後 × 同じ値/増える値）を PR に書く。触る範囲: なし（計測のみ）
- [ ] 6.2 `/cost` の所要時間を、足す前と後で測る。対象はこの change のブランチ。条件は 2 つ: 台帳を使わない（`env -u COST_LEDGER_PATH`、実環境の会話ログは読み取りのみ）、台帳を使う（一時ディレクトリの台帳。利用者の台帳には書かない）。記録が無いときと有るときの両方を測る（各 5 回の中央値）。記録が有るときは、上限が既定（1 秒）の場合と `COST_LEDGER_DRIFT_BUDGET_SECONDS=inf` の場合の両方を測り、既定で `未確認` の行が出たかどうかを控える。PR には、足す前・足した後（記録なし）・足した後（記録あり・既定）・足した後（記録あり・`inf`）の所要時間と、読み直しで増えた分（記録あり − 記録なし）を、台帳あり・なしのそれぞれについて書く。既定の上限で増えた分が 2 秒以上になったら、打ち切りが効いていないので、確かめる位置を直してから測り直す。この Mac で既定のまま毎回打ち切られる（`未確認` の行が毎回出る）ことが分かったら、上限を手元で動かさずに、測った値を添えて return で報告する。触る範囲: なし（計測のみ）
- [ ] 6.3 `gh` の呼び出し回数と、pr-review-gate 通過時の hook（`gate-report.sh`）の所要時間を、変更の前と後で実測して PR に書く。引数を確かめるテスト（3.4）は実測の代わりにしない。(a) statusline の書き込みと `/cost` の突き合わせ: 呼び出しを 1 回 1 行でログに書いてから本物の `gh` に渡す包みの `gh` を PATH の先頭に置き、6.1 の描画と、6.2 の番号なしの `cost`（記録あり）を実行して、ログの行数を足す前と後で比べる。(b) hook: 足す前の `plugins/cost-ledger` は `git archive origin/main plugins/cost-ledger | tar -x -C <一時ディレクトリ>` で取り出す（作業ツリーを戻す操作はしない）。足す前と後の `gate-report.sh` に、同じ入力（`agent-review:passed` が付いているマージ済みの PR 1 件に対する合格ラベル付与の PostToolUse の JSON。入力の形は `plugins/cost-ledger/tests/gate-report.bats` の `run_hook` に合わせる）を流す。条件は前後で揃える: 同じ PR、同じ `--repo`、`env -u COST_LEDGER_PATH`（利用者の台帳に書かない）、`CLAUDE_CONFIG_DIR` は 6.4 と同じ作り（`projects` が実環境の会話ログへのシンボリックリンクで、`.session-cost` にその PR の答えに含まれるセッションの記録が 1 つ以上ある一時ディレクトリ）。`gh` は (a) と同じ包みを使い、読み取りの呼び出しは本物の `gh` に渡し、コメントの投稿と更新（`-X POST`・`-X PATCH`）は本物に渡さずログに書いて成功を返す（実在の PR にコメントを書かない）。足す前と後をそれぞれ 5 回実行し、所要時間の中央値と、1 回あたりの `gh` の呼び出し回数を PR に書く。後の回数が前より多い、または後の所要時間の中央値が前より 1 秒以上長ければ、`--no-drift-check` が効いていないので直してから測り直す。触る範囲: なし（計測と PR 本文）。読むのは `plugins/cost-ledger/tests/gate-report.bats:1-130`（hook の入力の形と `gh` の差し替え方）
- [ ] 6.4 実機の 1 セッションで、本体の値と自前の計算の差を測って PR に書く。手順の例: 一時ディレクトリを `CLAUDE_CONFIG_DIR` にし、その `projects` を実環境の会話ログへのシンボリックリンクにする → セッション ID を決めて `claude -p --session-id <UUID> --output-format json '<短い作業>'` を実行し、返ってきた `total_cost_usd` を本体の値とする → 実行の前（値 0）と後（返ってきた値）の 2 回、statusline のスクリプトにその `session_id` と `cost.total_cost_usd` を持つ入力を流して記録を作る → `cost_ledger.py branch <ブランチ>` を実行して警告の有無を見る。PR には、本体の値・自前の計算・差額・割合・使ったモデルを書く。画面のある通常のセッションでの確認が要るかどうかは return の `画面確認:` 行で本体に伝える。触る範囲: なし（計測のみ）
- [ ] 6.5 6.4 で、単価表が正しいはずのセッションの差が閾値（差額 $0.50 かつ 10%）を超えたら、閾値を手元で動かさずに止めて、測った値と考えられる原因を return で報告する。触る範囲: なし

## 7. 確認

- [ ] 7.1 `bash scripts/test.sh`（常時注入の予算 `tests/injection-budget.bats` を含む）。触る範囲: なし（実行のみ）
- [ ] 7.2 `openspec validate cost-ledger-price-drift --strict`。触る範囲: なし（実行のみ）
