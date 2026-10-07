行番号は仕様づくりの時点（d284e35a）の値。前のタスクの編集でずれるので、編集の前に該当範囲を読む。

## 1. 着手前の確認

- [ ] 1.1 `git fetch origin` して PR #744（ブランチ `oratta/issue-691`）が main に入ったかを確かめる。入っていれば origin/main を取り込み（merge。rebase と force push はしない）、`gate_report.py` の `stack()`・`README.md`・`openspec/specs/cost-ledger-timeline/spec.md` の現状を読み直す。入っていなければそのまま進める。どちらだったかを PR の本文に書く。触る範囲: なし（確認だけ）
- [ ] 1.2 変更前の実測を取る（測り方は 6.1）。変更後の作業ツリーでは測り直せないので、実装の前に `git show d284e35a:plugins/cost-ledger/scripts/gate-report.sh` と `gate_report.py` を一時ディレクトリへ書き出して測り、数字を控える。触る範囲: なし（リポジトリにファイルを足さない）

## 2. テストを先に書く（落ちることを確かめる）

- [ ] 2.1 stub の `gh` が `created_at` を返せるようにする。既定の PR の応答に「いま」の `created_at` を入れ、`$FIX/pull.<N>.json` で上書きできるようにする。`pulls?head=<owner>:<ブランチ>&state=all` の問い合わせで、渡されたブランチ名をログから確かめられるようにする。触る範囲: `plugins/cost-ledger/tests/gate-report.bats`:83-272（`write_stub_gh`）
- [ ] 2.2 fast path のテストを直す・足す: 文字列は 10 個（`gh pr create`・`gh pr reopen` を足す）／`gh api` の読み取り 3 形では `python3` が起動しない／`/issues/` も `/pulls/` も含まない `gh api` の書き込みでは起動しない／`gh api` の書き込み 4 形と `gh pr create`・`gh pr reopen` では起動する。既存の「対象外」の一覧から `gh pr create --title x` と `gh pr reopen 300` を外す。触る範囲: `plugins/cost-ledger/tests/gate-report.bats`:401-423
- [ ] 2.3 受け入れ条件の 1 つ目のテストを足す: `gh pr create`・`gh api .../issues/300/comments -f body=x`・`gh api -X PATCH .../pulls/300 -f state=closed`・`gh pr reopen 300`・`gh api -X PUT .../pulls/300/merge` を順に流すと、POST は最初の 1 回だけで、流すたびに行が 1 行ずつ増え、きっかけが `PR 作成,PR コメント,PR クローズ,PR 再オープン,マージ` になる。PR でない issue #12 への 3 形（コメント・`state=closed`・`state=open`）も足す。既存の「表に無いコマンドでは積まない」のテストから `gh pr create` と `gh pr reopen` を外す。触る範囲: `plugins/cost-ledger/tests/gate-report.bats`:816-851
- [ ] 2.4 受け入れ条件の 2 つ目のテストを足す: `gh api .../issues/300/comments -f body=x` を 1 回流すと、新規作成 1 回・書き換え 0 回・表の行 1 行／`gh api -X PATCH repos/acme/cwd-repo/issues/comments/900 --input -` を流しても `gh` は 1 回も呼ばれない。触る範囲: `plugins/cost-ledger/tests/gate-report.bats`:853-860 の後ろ
- [ ] 2.5 受け入れ条件の 3 つ目のテストを足す: `gh api` の GET 3 形（2.2 と同じ）で `python3` が起動しない／`gh api -X GET .../issues/300/comments -f per_page=100`（fast path は通る）で `gh` が 1 回も呼ばれない／`state` を変えない PATCH（`-f title=x`・`--input body.json`）で `gh` が 1 回も呼ばれない。触る範囲: `plugins/cost-ledger/tests/gate-report.bats`:853-860 の後ろ
- [ ] 2.6 「`gh api` の呼び出しの読み方」のテストを足す: メソッド省略＋フィールドは POST／`--input` だけでも POST／`--input` の値のパスを拾わない（#5 だけが対象で #300 は問い合わせない）／`--jq`・`-H` の値を endpoint と読まない／`-XPATCH`・`-fstate=closed`・`--method=PATCH`・`--raw-field=state=closed`／`-f body='state=closed'` と `--jq state=closed` は積まない／代入の展開／`--jq 'labels[]=agent-review:passed'` は付与と見ない／`gh api repos/{owner}/{repo}/issues/300/labels -f 'labels[]=agent-review:passed'` は `cwd` のリポジトリの #300 への付与と見て、前置きの `GH_REPO=oratta/other` があれば oratta/other の #300 を対象にする／メソッドが解決できない `-X "$M"`（`M` の代入がコマンドに無い）の呼び出しは飛ばし、`gh` を呼ばない。触る範囲: `plugins/cost-ledger/tests/gate-report.bats`:628-638 の後ろ
- [ ] 2.7 対象の解決と状態の確認のテストを足す・直す: `gh pr create --head feat/x` はそのブランチで問い合わせる／`gh pr create -Hfeat/x`（短いオプションに値を続けた形）も `--head feat/x` と同じブランチで問い合わせる／`--head someone:feat/x`・`--dry-run`・`--web` は `gh` を呼ばない／`{owner}/{repo}` の endpoint／別リポジトリの endpoint は確かめるが書かない／完全な URL の endpoint とコマンド置換を含む endpoint は `gh` を呼ばない／`--hostname ghe.example` の `gh api` のコメント投稿は `gh` を呼ばない／issue 向けの endpoint に PR の番号（`PR コメント`・`PR クローズ`・`PR 再オープン`）／`gh issue reopen 300`（PR）は `PR 再オープン` として積む（既存の「積まない」のテストを書き換える）／`gh api` のマージ・クローズが失敗していたら積まない／`gh pr reopen` で `state` が closed なら積まない／`created_at` が 1 時間前の PR には `PR 作成` を積まない／ブランチの PR が無ければ積まない。触る範囲: `plugins/cost-ledger/tests/gate-report.bats`:901-929、1009-1076
- [ ] 2.8 `gh` の呼び出し回数のテストを足す: `gh pr create`・`gh pr reopen 300`・`gh api -X PATCH .../pulls/300 -f state=closed`・`gh api -X PUT .../pulls/300/merge` は各 3 回／`gh api .../issues/12/comments -f body=x`（issue）は 3 回、`.../issues/300/comments`（PR）は 4 回／`gh api -X PATCH .../issues/12 -f state=closed` は 4 回。触る範囲: `plugins/cost-ledger/tests/gate-report.bats`:1185-1215
- [ ] 2.9 `bats plugins/cost-ledger/tests/gate-report.bats` を流し、2.2〜2.8 で足したテストが落ち、それ以外が通ることを確かめる。触る範囲: なし

## 3. fast path

- [ ] 3.1 `case` に `gh pr create`・`gh pr reopen` と、`gh api` の 3 条件（`gh api` を含む・`/issues/` か `/pulls/` を含む・空白に続く `-X`・`--method`・`-f`・`-F`・`--field`・`--raw-field`・`--input` のどれかを含む）を足す。先頭のコメントのきっかけの一覧と fast path の説明も直す。`jq` も `python3` も起動しない `case` だけで書く。触る範囲: `plugins/cost-ledger/scripts/gate-report.sh`:6-18、26-31

## 4. きっかけの判定（`gate_report.py` の同期部分）

- [ ] 4.1 `gh api` の語の並びを endpoint・メソッド・フィールドに分ける関数を作る（値を取るオプションの表、`--name=値`、短いオプションに値を続けた形、メソッドの既定）。`api_targets()` をこの関数の上に作り直し、ラベルの付与は endpoint が `issues/<番号>/labels` でフィールドに `labels[]=agent-review:passed` があるときだけにする。付与の endpoint の `{owner}/{repo}` は、4.2 のきっかけと同じ規則（前置きの `GH_REPO`、無ければ `cwd` のリポジトリ。`repo_values()` を使う）で置き換えて付与と見る（`LABELS_PATH_RE` が `{owner}/{repo}` を受けるようにし、`find_triggers()` から前置きの `GH_REPO` を渡す）。メソッドが解決できない呼び出し（`-X "$M"`）は飛ばす。触る範囲: `plugins/cost-ledger/scripts/gate_report.py`:27-38（定数）、260-287（`api_targets()`）
- [ ] 4.2 `gh api` のきっかけ（`issues/<番号>/comments` の POST・`pulls/<番号>` と `issues/<番号>` の PATCH の `state`・`pulls/<番号>/merge` の PUT）を取り出す関数を足し、`find_triggers()` の `args[0] == "api"` の枝から呼ぶ。`{owner}/{repo}` は前置きの `GH_REPO`、無ければ `cwd` のリポジトリ（`repo_values()` を使う）。触る範囲: `plugins/cost-ledger/scripts/gate_report.py`:260-287 の後ろ、393-447（`find_triggers()`）
- [ ] 4.3 `TRIGGERS` に `("pr", "create")`（`PR 作成`）と `("pr", "reopen")`（`PR 再オープン`）を足す。`trigger_targets()` で `gh pr create` の値を取るオプション・`--dry-run`・`-w` / `--web`・`-H` / `--head`（`--head=値` と、短いオプションに値を続けた `-Hfeat/x` を含む）を扱い、ヘッドブランチの指定を対象に持たせる。`build_job()` の対象の鍵と裏へ渡す JSON にヘッドブランチを足す。触る範囲: `plugins/cost-ledger/scripts/gate_report.py`:40-58（`TRIGGERS`・`AS_PR`）、338-378（`trigger_targets()`）、459-475（`build_job()`）
- [ ] 4.4 ファイル先頭の説明（きっかけの一覧）を直す。触る範囲: `plugins/cost-ledger/scripts/gate_report.py`:1-17

## 5. 対象の確認（`gate_report.py` の裏の処理。`stack()` は触らない）

- [ ] 5.1 `pr_checks()` に `PR 再オープン`（`state` が open）と `PR 作成`（`state` が open で `created_at` がきっかけの時刻の前後 300 秒以内）を足す。`PR 作成` の判定にきっかけの時刻が要るので、`resolve()` に `at` を渡す。`AS_PR` に `issue 再オープン` → `PR 再オープン` を足す。触る範囲: `plugins/cost-ledger/scripts/gate_report.py`:57（`AS_PR`）、550-557（`pr_checks()`）、568-605（`resolve()`）、724-738（`work()` の `resolve()` の呼び出し。`stack()` の呼び出しの行は変えない）
- [ ] 5.2 `resolve()` の番号を省いた PR の問い合わせで、対象がヘッドブランチの指定を持つときは `{branch}` の代わりにそのブランチを使う。触る範囲: `plugins/cost-ledger/scripts/gate_report.py`:590-593
- [ ] 5.3 `bats plugins/cost-ledger/tests/gate-report.bats` と `bats plugins/cost-ledger/tests/` の全部が exit 0 になることを確かめる。触る範囲: なし

## 6. 実測（エピック #272 の「全体の制約」。PR の本文に書く）

- [ ] 6.1 hook 1 回の同期部分の所要時間を、変更の前（d284e35a）と後で測る。測り方: `gh` を「何もせず成功を返す」stub に差し替えた PATH と、一時ディレクトリの `cwd`・`TMPDIR` で、`COST_LEDGER_HOOK_FOREGROUND` を付けずに（裏のプロセスは切り離される）`gate-report.sh` へ hook JSON を stdin で渡し、起動から終了までの壁時計時間を 20 回測って中央値を取る。場合は 5 つ: きっかけに無関係の Bash（`ls -la`）／`gh api` の読み取り（`gh api repos/o/r/issues/300/comments`）／`gh api` のコメント投稿（`gh api repos/o/r/issues/300/comments -f body=x`）／`gh pr create --title x --body y`／`gh pr comment 300 --body x`（変更前からあるきっかけ。比較用）。合否に使うのは「測って書いたこと」と「どの場合も 1 秒未満」だけで、前後の差の大きさは記録にとどめる。触る範囲: なし（測るコマンドは PR の本文に書き、リポジトリにファイルを足さない）
- [ ] 6.2 `gh` の呼び出し回数を、`COST_LEDGER_HOOK_FOREGROUND=1` と呼び出しを数える stub の `gh` で測る（bats の `gh_calls` と同じ数え方）。新しいきっかけ 5 つ（`gh pr create`・`gh pr reopen 300`・`gh api` のコメント投稿（PR の番号）・`gh api` の PATCH `state=closed`・`gh api` の PUT merge）と、`gh api` の読み取り（0 回）を表にして PR の本文に書く。同期部分で `gh` が 0 回であることも書く。触る範囲: なし

## 7. 文書と記録

- [ ] 7.1 README のきっかけの表に `gh pr create`・`gh pr reopen`・`gh api` の 4 形を足し、「`gh api` の直叩きでの投稿・状態変更、`gh pr create`、`gh pr reopen` でも積まない」の文を、今の振る舞い（積む。`gh api graphql` と `--input` の中の `state` は見ない）に直す。この文は PR #744 も書き換えているので、1.1 の結果に合わせて、#744 の文があればそれを土台に直す。触る範囲: `plugins/cost-ledger/README.md`:148-166、199-202
- [ ] 7.2 変更の記録を書く（何が変わるか・積まないもの・実測の表・反映に `/reload-plugins` が要らないこと）。「PR でない issue への `gh api` のコメント投稿・クローズ・再オープンは、行は積まれるが累計が 0 か実際より小さく出ることがある（issue への帰属は `cost_ledger.py` の `ISSUE_RE` で決まり、`gh api .../issues/<番号>/...` は帰属の鍵にならない。この変更では直さない）」も書く。触る範囲: `plugins/cost-ledger/changes/697.md`（新規）
- [ ] 7.3 archive の前に、もう一度 `git fetch origin` して PR #744 が main に入ったかを確かめる。入っていれば origin/main を取り込み、この change の差分 `specs/cost-ledger-timeline/spec.md` の「行を積むきっかけ」の守備範囲の最後の文（「Bash ツール以外…で行われた投稿や状態変更は」で始まる文）を、main の文（後追い `cost-ledger-backfill` への言及を含む）に合わせてから archive する。触る範囲: `openspec/changes/cost-ledger-api-triggers/specs/cost-ledger-timeline/spec.md`（「行を積むきっかけ」の守備範囲の段落）
- [ ] 7.4 PR の本文に次の 2 つを書く（(3b) で PR を作るとき）: PR でない issue への `gh api` の投稿・クローズ・再オープンは、行は積まれるが累計が 0 か実際より小さく出ることがあり、この PR では直さないこと（7.2 と同じ内容。`cost_ledger.py` には触らない）／受け入れ条件「hook 自身の書き込みでは行が積まれない」を、「裏のプロセスの書き込みは再発火しない」「hook の書き換え（PATCH）と同じ形の Bash コマンドは積まない」「hook の新規作成と同じ形の POST（`issues/<番号>/comments`）を Bash で実行した場合は、コメントの投稿として積む」と読んだこと。触る範囲: なし（PR の本文）
