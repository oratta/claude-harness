## 1. スクリプトのテストを先に直す（bats）

- [x] 1.1 既存の「許可リスト外 → exit 1」系 5 件を、終了コード 3・`CARRYOVER=if-rereviewed`・`RESOLVED_OUTSIDE_ALLOWLIST=<ファイル>` の行あり・`NG:` 行なしの期待に直す（テスト名も `-> exit 3` に直す）。対象: 許可リスト外のファイルでの衝突解消、衝突していないファイルへの手入れ、plugin.json の版以外の行、CHANGELOG の新しい文、ほかの JSON。触る範囲: plugins/dev-workflow/tests/risk-carryover-check.bats:128-185
- [x] 1.2 受け入れ条件 1 の再現を足す: `openspec/specs/x/spec.md` の衝突を解いた取り込みで、根拠ファイルの diff が空なら終了コード 3 と `RESOLVED_OUTSIDE_ALLOWLIST=openspec/specs/x/spec.md` を出す。触る範囲: plugins/dev-workflow/tests/risk-carryover-check.bats:128-185 の後ろ（「other JSON files」テストの直後）
- [x] 1.3 受け入れ条件 2 を足す: 許可リスト外の衝突解消と根拠ファイルの変更が同じ取り込みで重なると終了コード 1・`CARRYOVER=no`・根拠ファイルを示す `NG:` 行。触る範囲: 1.2 と同じ位置
- [x] 1.4 #480 を足す: merge commit の中で許可リスト外のファイルを消し、よく似た中身のファイルを別名で作ると、消したファイルが `RESOLVED_FILES` と `RESOLVED_OUTSIDE_ALLOWLIST=` に出る。触る範囲: 1.2 と同じ位置
- [x] 1.5 #478 を足す: `evidence path that exists at neither HEAD -> exit 2`（`no-such-file.txt`）と、サブディレクトリを cwd にして呼んでも根拠ファイルの変更を拾う（終了コード 1）テスト。触る範囲: plugins/dev-workflow/tests/risk-carryover-check.bats:195-208 の近く（exit 2 系のテストの並び）
- [x] 1.6 先頭コメントの spec 参照に #694 を足す。触る範囲: plugins/dev-workflow/tests/risk-carryover-check.bats:1-5

## 2. スクリプトを直す

- [x] 2.1 SHA の解決の前に `cd "$(git rev-parse --show-toplevel)"` を入れ、pathspec をルート相対に固定する（#478）。触る範囲: plugins/dev-workflow/scripts/risk-carryover-check.sh:47-52
- [x] 2.2 衝突解消ファイルの列挙を `git diff --no-renames --name-only` にする（#480）。触る範囲: plugins/dev-workflow/scripts/risk-carryover-check.sh:121-127
- [x] 2.3 `allowed` が偽のファイルを `ng` に積まず、別の配列（許可リストの条件を満たさないファイル）に積む。触る範囲: plugins/dev-workflow/scripts/risk-carryover-check.sh:54-56（配列の宣言）、:121-127（列挙のループ）
- [x] 2.4 根拠ファイルごとに `git cat-file -e <前>:<f>` / `<新>:<f>` のどちらかが通ることを確かめ、どちらにも無ければ標準エラーに出して終了コード 2（#478）。触る範囲: plugins/dev-workflow/scripts/risk-carryover-check.sh:131-140
- [x] 2.5 出力と終了コードを直す: `NG:` があれば `CARRYOVER=no`・終了 1、無くて許可リストの条件を満たさないファイルがあれば `CARRYOVER=if-rereviewed`・終了 3、どちらも無ければ `CARRYOVER=yes`・終了 0。`RESOLVED_OUTSIDE_ALLOWLIST=<ファイル>` を重複なしでファイルごとに 1 行出す（終了 1 のときも出す）。Bash 3.2 で空配列の展開は `${arr[@]+"${arr[@]}"}` 形を使う。触る範囲: plugins/dev-workflow/scripts/risk-carryover-check.sh:142-152
- [x] 2.6 冒頭コメントの判定・出力・終了コードの説明を直し、「許可リストの条件を満たさない」の定義（ファイル名と中身の両方、衝突していないファイルへの手入れを含む）と、終了コード 3 の確認は G が 3-c で行うことを書く。触る範囲: plugins/dev-workflow/scripts/risk-carryover-check.sh:1-21
- [x] 2.7 `bats plugins/dev-workflow/tests/risk-carryover-check.bats` が全件 ok。`/bin/bash`（3.2）での実行テストも通る

## 3. 3-c の文面と書式を直す（hold.md は 3-c だけ）

- [x] 3.1 スクリプトの呼び方のブロックの出力・終了コードの説明に `CARRYOVER=if-rereviewed`・`RESOLVED_OUTSIDE_ALLOWLIST=`・終了コード 3 を足す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:23-27（#### 3-c. の bash ブロック）
- [x] 3.2 条件 1 を「終了コード 0、または終了コード 3 で、最新の `レビュー重量:` コメントの `固定 HEAD:` が新しい HEAD と一致し、その周が PR 全体を見たレビュー（ゲートの開始・CI の見張りのあとの取り直し・方式の書き換え後の全体レビュー）である。W の修正後の差分限定の再レビューと、順 3 だけでレビューをせずに閉じた周は当たらない。周の種類を前の段の Gate Result と PR のコメントから読めなければ満たさない」に直す。理由（衝突解消の結果は base との差分に現れ、全体レビューで読まれる）を 1 文添える。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:29-31（引き継げる条件の 1）
- [x] 3.3 追記 4 行の書式ブロックの 3 行目を `引き継ぎの根拠: risk-carryover-check.sh 終了コード <0 または 3> — main の取り込み <件数> 件、衝突解消 <none またはファイル>、許可リスト外 <none またはファイル>、根拠ファイルの diff は空、取り直しのレビュー <終了コード 3: 固定 HEAD <40 桁フル SHA>（<周の種類>） <レビュー重量コメントのリンク>／終了コード 0: 不要>` の形に直す（4 行のまま）。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:36-43
- [x] 3.4 引き継げないときの段落に、終了コード 3 で全体レビューを経ていないときは `RESOLVED_OUTSIDE_ALLOWLIST=` の行とその理由を質問に添えることを足す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:45（「1 つでも満たさなければ」の段落）
- [x] 3.5 3-c 以外の節（手順 6・復帰の表）を変えていないことを `git diff` で確かめる（兄弟 #721 との衝突を避ける）。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md 全体（確認のみ）
- [x] 3.6 設計の Open Question を確かめる: CI の見張りのあとの取り直しの周がそれと分かる記録（前の段の Gate Result の `段:`、PR のコメント）が残るかを読む。残らなければ R1 に報告する（3-c は「読めなければ引き継がない」に倒れる）。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/prepare.md:110-120（この段で起こされたときの入力）、plugins/dev-workflow/skills/pr-review-gate/stages/pass.md:175-185（読むだけ）
- [x] 3.7 `gate-runner.md` が 3-c を正本として参照するだけで、条件や書式を写していないことを確かめる（写していなければ変えない）。触る範囲: plugins/dev-workflow/skills/develop/references/roles/gate-runner.md:95-110（読むだけ）

## 4. 文面検査の bats を直す

- [x] 4.1 3-c の条件の検査に、終了コード 3 と「PR 全体を見た」「差分限定」の文が条件 1 にあることを足す（`終了コード 0` の検査は残す）。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:934-943
- [x] 4.2 追記 4 行の書式の検査を、`^引き継ぎの根拠: risk-carryover-check.sh 終了コード ` で始まり、`許可リスト外` と `取り直しのレビュー` と `固定 HEAD` を含む形に直す（4 行のままの検査は残す）。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:970-979
- [x] 4.3 `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` が全件 ok（ロケール依存の既知の失敗が出たら #662 の扱いに従って切り分ける）

## 5. 記録と全体テスト

- [x] 5.1 変更の記録 `plugins/dev-workflow/changes/694.md` を書く（何を変えたか・終了コード 3 の意味・#478/#480 を含めた理由・BREAKING の読み方）。触る範囲: plugins/dev-workflow/changes/694.md（新規）
- [x] 5.2 `bash scripts/test.sh` が exit 0（#478・#480 の受け入れ条件 3）
- [x] 5.3 `openspec validate risk-carryover-rereviewed-resolution --strict` が valid
