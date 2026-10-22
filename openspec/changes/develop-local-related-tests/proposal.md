## Why

develop の作業者の指示書 `plugins/dev-workflow/skills/develop/references/roles/worker/implement.md` の「全経路共通の大原則」は、対象リポジトリの CI の検査コマンドをすべて手元で実行するよう求めている。claude-harness ではこれが `scripts/test.sh`（直列で 1 回 40 分ほど）の全体実行になり、実装・仕上げ・指摘の修正のたびに 40 分待つ。#1177（PR #1208）では開始から CI の決着まで約 2 時間 20 分のうち約 2 時間が全体のテストの待ちで、作業者が 3 回、レビュアー・ゲートの担当・本体が各 1 回回していた。同じ中身を CI は 4 つの組に分けて 5 分ほどで回しており、ゲートの合格後に本体が CI を見張って落ちたら直しに回る仕組み（`plugins/dev-workflow/references/ci-watch.md`）も既にある（issue #1211）。

## What Changes

- 作業者が手元で回す検査を「変えたファイルに関係するテスト・lint などの静的検査・仕様の検査」に絞る。テストの全体実行（CI の test ジョブがテストランナーをファイルで絞らずに起動するもの）とビルドは手元で回さず CI に任せる。CI の定義から検査を拾う規則と、コマンド名をリポジトリ固有の値に固定しない規則は残す。対象リポジトリに PR・push で全体のテストを回す CI が無いときだけ、手元で全体を回す（design D1・D2）
- 作業者の (3a) の return に、関係するテストの選び方（探したコマンド）と、手元で回さず CI に任せた検査（CI のジョブ名）を書かせる
- レビュアーは、テスト・lint を報告を信用せず自分で再実行する姿勢を保ったまま、再実行を関係するテストと lint に限り、全体のテストは回さない。全体のテストの結果は作業者の return か CI の結果を証拠にし、どちらも無いときは全体のテストの証拠が無いことを要約に書く（design D3）
- ゲートの担当は動作確認（pr-review-gate 手順 4）で全体のテストを手元で回さず、対象 HEAD の CI の結果を証拠にする。CI の結論がまだ無いときや既に落ちているときは、その状態（run の URL）と、合格後の CI の見張りで確かめる・直しに回す旨を書いて進め、成功とは書かない。auto-merge 未配備のリポジトリでは、合格処理の後に残す「マージは人間の操作待ち」の 1 行に、CI が失敗か未決着ならその状態と、見張りが結論を出すまでマージしない旨を添える（design D4）
- `scripts/test.sh` の並列化は行わない（design D5）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 要件「W の (3) は 2 回の return に分かれる」のうち、CI の検査コマンドをすべて手元で実行する義務を、関係するテスト・静的検査・仕様の検査を手元で回し、全体のテストを CI に任せる義務に置き換え、return に書く項目を合わせる
- `dev-workflow-pr-review-gate`: レビュアーとゲートの担当が全体のテストを手元で回さず、作業者の結果か CI の結果を証拠にする要件を足す

## Impact

- `plugins/dev-workflow/skills/develop/references/roles/worker/implement.md`（「全経路共通の大原則」の検査の段落と守備範囲の段落、(3a) の return に書くこと）
- `plugins/dev-workflow/skills/pr-review-gate/stages/reviewer-brief.md`（2-1 の姿勢の文）
- `plugins/dev-workflow/skills/pr-review-gate/stages/pass.md`（手順 4 の動作確認）
- テスト: `tests/develop-worker-ci-checks.bats`（文面の固定を新しい規則に合わせる）、レビュアーとゲートの担当の指示を固定するテストを足す
- 変更の記録 `plugins/dev-workflow/changes/1211.md`
- 他のリポジトリで develop を使うときも、全体のテストの待ちが CI 側に移る。PR・push で全体のテストを回す CI を持たないリポジトリでは、今までどおり手元で全体を回す
