## 1. 現状の確認

- [x] 1.1 `plugins/dev-workflow/scripts/codex-worker.py` の `clean_env()`・`Rpc.__init__`・`runtime_home()`・turn の `sandboxPolicy` 生成箇所を読み、Git 共通ディレクトリの値が既にどこで取れているかを確認する
- [x] 1.2 `plugins/dev-workflow/tests/test_codex_worker.py` の fake App Server が `thread/start` / `turn/start` のパラメータと子環境をどう捕まえているかを確認し、追加テストの置き場を決める

## 2. 失敗するテストを先に書く（Red）

- [x] 2.1 implement / spec-write の turn policy が `networkAccess: True` で、`writableRoots` が cwd・job 専用一時領域・cwd の Git 共通ディレクトリの 3 つであることを検査するテストを追加する
- [x] 2.2 review / spec-review / impl-review の turn policy が `{'type':'readOnly','networkAccess':True}`、decider が `{'type':'readOnly','networkAccess':False}` であり、どの read-only role にも `writableRoots` が付かないことを検査するテストを追加する
- [x] 2.3 子プロセスの環境が親の環境を引き継ぎ、`CODEX_HOME` は runtime のパスで上書きされ、落とす変数（`TMPDIR`・`TMPPREFIX`・`OPENAI_API_KEY`・`CODEX_API_KEY`・`OPENAI_BASE_URL`・`CODEX_AUTH_JSON`・`OPENAI_ORGANIZATION`・`OPENAI_PROJECT`・`GIT_DIR`・`GIT_WORK_TREE`・`GIT_COMMON_DIR`・`GIT_INDEX_FILE`）が子に現れないことを検査するテストを追加する。`GH_TOKEN` と無関係な目印変数は届くことも見る（テストは実装側の定数を参照せず、変数名を直書きして検査する）
- [x] 2.4 read-only role の子環境に `TMPDIR` / `TMPPREFIX` が現れないことを、親に両方が設定された状態で検査するテストを追加する（既存の同趣旨のテストが環境引き継ぎで壊れないための回帰）
- [x] 2.5 `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_worker.py -v` を実行し、追加分が落ちること（Red）と件数・exit code を記録する

## 3. 第 1 段の実装（workspace-write + network + Git 共通ディレクトリ）

- [x] 3.1 Git 共通ディレクトリの絶対パスを 1 か所で算出する形に整え、`writableRoots` に加える
- [x] 3.2 workspace-write の turn policy を `networkAccess: True` にする。`excludeSlashTmp` / `excludeTmpdirEnvVar` / `approvalPolicy: never` は変えない
- [x] 3.3 read-only の turn policy を role ごとに分け、review / spec-review / impl-review を `networkAccess: True`、decider を `False` にする
- [x] 3.4 子へ渡す環境を「親を引き継ぎ、落とすものだけ落とす」形にする。落とす変数は design.md の一覧を 1 つの定数に置く（`CODEX_HOME`・`TMPDIR`・`TMPPREFIX`・認証と接続先をすり替える 6 個・`GIT_*` の 4 個）。`Rpc.__init__` の TMPDIR / TMPPREFIX の扱い（read-only には渡さない）を保つ
- [x] 3.5 worker 自身の `git` 呼び出し（`validate_request` / `runtime_home` / `JobTmp.validate_location`）は従来どおり最小環境（現行 `clean_env()` 相当）で実行し続ける形にし、子へ渡す環境と worker 自身が使う環境を別の関数として分ける。既存テスト `test_git_environment_cannot_redirect_validation` が通り続けることを確認する
- [x] 3.6 fake テストを通す（Green）。`PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_worker.py -v` の件数と exit code を記録する

## 4. 実 Codex での実測（第 1 段）

- [x] 4.1 **先に環境変数の引き継ぎを確認する。** この worktree を cwd にして implement role の job を投げ、worker の中で目印変数・`GH_TOKEN` の有無と、落とすべき変数が落ちていることを出力して確認する。Codex 側のポリシーで絞られていれば runtime `config.toml` に引き継ぎ設定を足し、絞られていなければ足さない。この結果が 4.3〜4.5 の失敗の原因切り分け（砂場の拒否か、環境変数の不達か）の根拠になる
- [x] 4.2 worker の中で `python3 -m http.server <空きポート>` 等でループバックに待ち受けを立て、`curl -sS http://127.0.0.1:<port>/` が応答することを実測する。ポートは `lsof -i :<port>` で空きを確認してから選び、使ったポートを記録する（他プロジェクトのプロセスを止めてポートを空けない）。コマンド・出力・exit code を記録する
- [x] 4.3 worker の中で、**まず使い捨て branch を作ってから** commit する。手順は（a）`git switch -c codex-probe-<日付>`（`switch` は破壊的操作ではない）、（b）`git commit --allow-empty` を実行して linked worktree で成立することを確認する、の順。本番 PR が載る `oratta/codex-worker-claude` にプローブ commit を積まない（積むと `git reset` の承認が要る事態になる）。失敗したら出力と exit code を記録し、4.1 の結果と照らして原因が砂場の拒否かどうかを判定する。**結果**: `git switch -c` は `HEAD.lock`、`git commit --allow-empty` は `index.lock` の作成が `Operation not permitted` で拒否され、どちらも exit 128。境界を 1 か所ずつ測ると、Git 共通ディレクトリ直下・`refs/`・`worktrees/` 直下への書き込みは通り、`worktrees/<この worktree>/`（cwd の `.git` ファイルが指す `$GIT_DIR`）だけが拒否される。Codex の workspace-write 砂場が cwd のリポジトリの `$GIT_DIR` を `writableRoots` より強く読み取り専用にしており、`WorkspaceWriteSandboxPolicy` にこれを解く項目は無い（`writableRoots` / `networkAccess` / `excludeSlashTmp` / `excludeTmpdirEnvVar` の 4 つだけ。`turn/start` に `permissionProfile` も無い）。砂場の拒否である
- [x] 4.4 4.3 で作った使い捨て branch のまま、worker の中で `git push -u origin codex-probe-<日付>`・`gh pr create --draft --head codex-probe-<日付> --base main`（`--head` を明示する。省略すると現在のローカル branch が head になり、本番 PR がある branch では `already exists` で落ちる）・`gh issue comment 334` を実測する。後始末の規則: Draft PR は実測後に `gh pr close` で閉じる、コメント先は記録先の issue に固定する、**最後に `git switch oratta/codex-worker-claude` で元の branch に戻ってから job を終える**。**remote branch の削除やその他の破壊的 git 操作は行わず、必要になったら実行せず主の承認を得る**。各操作のコマンド・出力・exit code と作成物の URL を記録する
- [x] 4.5 flatmate のテストスクリプトは**別 job** として、flatmate の linked worktree（実際に使ったのは `/Users/oratta/orca/workspaces/flatmate/boot-trust-784`、ブランチ `oratta/boot-trust-784`、対象 HEAD `b8661a7`）を cwd にして submit する。**この worktree を選んだ理由**: 候補 4 つのうち `workers/task-store/node_modules/.bin/wrangler` が導入済みなのはここだけで（`699` / `759-profile-render` / `mvp-2-2026-09-11` は未導入なのでスクリプトが `npm ci --include=dev` を要求して落ちる）、当初候補の `716-run-history` は別セッションのジョブが cwd を押さえていて投入できず、この worktree はロックされておらず作業ツリーもクリーンだった。**結果**: 完走しなかった（`PASS=0 FAIL=1` / `test_exit=1`）。スクリプト 62 行目の素の `mktemp -d` が macOS では `TMPDIR` を読まず呼び出し元の Darwin ユーザー一時ディレクトリを掴むため、許可外として拒否された。実行前後とも作業ツリーの差分は 0 件（commit も後片付けもしていない）（claude-harness を cwd にすると flatmate 側への書き込みが `writableRoots` の外になる）。`scripts/test-task-store-worker.sh` を worker の中で完走させ、成功件数・exit code・対象 HEAD と使ったポートを記録する。**この worktree は別プロジェクトなので、実測で生じた差分を commit せず、破壊的な後片付けもしない**（必要になったら実行せず主に聞く）
- [x] 4.6 許可外への書き込みプローブ（`/tmp/<一意名>` と呼び出し元 `TMPDIR/<一意名>`）が拒否されること、専用領域が 0700 で終了後に消えていることを実環境で確認する

## 5. 第 2 段（第 1 段で足りなかった role だけ）

- [x] 5.1 第 1 段で完了できなかった操作があれば、role ごとに（a）失敗したコマンド・出力・exit code と、（b）**その失敗が砂場の拒否によるものだと判定した根拠**を change の記録先へ記録する。（b）は 4.1 の環境変数の引き継ぎ確認の結果と照らして書き、環境変数の不達・テストスクリプト自体の不具合・一時的な通信失敗のどれでもないと言える理由を示す。（a）と（b）が揃わない状態で 5.2 に進まない。原因が砂場の拒否ではなかった場合は 5.2 を飛ばし、その原因を直して第 1 段で再実測する（4.2〜4.5 に戻る）
- [ ] 5.2 **主の承認待ちで保留。** 仕様の条件（失敗したコマンド・出力・exit code の記録と、それが砂場の拒否だという確認）は 5.1 で両方満たしたが、第 2 段は砂場の撤去そのもの＝権限設定の緩和なので、承認を得るまで実装しない。足りない role だけ `thread/start` の `sandbox` を `danger-full-access`、turn の `sandboxPolicy` を `{'type':'dangerFullAccess'}` にし、その role を第 2 段にした理由を記録する。**第 2 段にしてよいのは workspace-write role（implement / spec-write）だけで、read-only role（review / spec-review / impl-review / decider）は readOnly policy を維持する。** 判断は role ごとに独立に行い、ある role の不足を理由に他の role を緩めない
- [ ] 5.3 第 2 段にした role で 4.1〜4.5 のうち失敗していた操作を再実測し、結果を記録する
- [ ] 5.4 第 2 段でも完了できない操作が残った場合、項目ごとに「試したこと・失敗の出力・揃えられない理由」を記録先と `plugins/dev-workflow/scripts/CODEX-WORKER.md` に書く

## 6. ドキュメントの整合

- [ ] 6.1 `plugins/dev-workflow/scripts/CODEX-WORKER.md` の砂場と環境変数の記述を実際の範囲に直す（role ごとの段・`networkAccess` の値・`writableRoots` の 3 か所・落とす環境変数・残った代理実行の項目）。あわせて、実測は implement role で行い `spec-write` は policy が implement と同一なので同じ結果が当てはまる、と一言書く（後で「spec-write は未実測」と読まれないため）
- [ ] 6.2 `plugins/dev-workflow/references/codex-develop.md` から、ネットワーク無効と commit 拒否を理由にした本体の代理実行の記述を削る。5.4 で残った項目があればその項目だけを残す。**`plugins/dev-workflow/references/codex-develop.md:46` の「read-only reviewerはGitHubコメントを書かない。本体が既存正本の書式で結果を代理投稿する」という記述は削らずに残す**（read-only role は readOnly policy を維持し、レビュー結果の代理投稿は design.md の Risks / Trade-offs で残すと決めた項目。ここを消すと投稿の担い手が不在になる）
- [ ] 6.3 `plugins/dev-workflow/docs/codex-develop.md` の同趣旨の段落を同じ方針で直す（read-only reviewer のレビュー結果を本体が代理投稿する記述は同様に残す）
- [x] 6.4 `openspec/specs/codex-worker/spec.md` の Purpose が `TBD - created by archiving change isolate-codex-worker-job-tmp.` のままなので、archive 時に埋める内容を決めておく。あわせて、`openspec/specs/codex-worker-concurrency/spec.md:14` が参照する Requirement「アカウントと作業ディレクトリを排他的に所有する」が現在の `openspec/specs/codex-worker/spec.md` に存在しない（参照切れ）ことを記録する。**この参照切れを直すのはこの change の対象外**（アカウント排他の要件は今回触らない）が、Purpose を書くときに capability の範囲を見渡すので、そのとき気づけるようにここに残す
- [ ] 6.5 `openspec/specs/codex-develop-continuation/spec.md` の Requirement「coordinator と担当者の責務境界を守る」が、archive で delta（`openspec/changes/align-codex-worker-permissions/specs/codex-develop-continuation/spec.md`）の全文に置き換わることを確認する。置き換え後の本文が「GitHub 操作と commit/push は workspace-write role の担当者が worker の中で自分で完了する」「代理は揃えられなかった項目として記録済みの操作だけ」「read-only role のレビュー結果は coordinator が代理投稿する」の 3 点を保っており、他の 4 つの Requirement（継続記録の復元・安全停止・品質工程・回帰検証）に手が入っていないことを見る

## 7. バージョンと全件テスト

- [x] 7.1 `plugins/dev-workflow/.claude-plugin/plugin.json` の version を 2.13.8 から 2.13.9 に上げる
- [x] 7.2 `.claude-plugin/marketplace.json` の dev-workflow エントリの version を 2.13.9 に揃える
- [ ] 7.3 push 前の全件は次の 2 本で、両方の成功件数・総件数・exit code と対象 HEAD を記録する。`scripts/test.sh` は git 追跡下の `*.bats` だけを走らせ、`plugins/dev-workflow/tests/test_codex_worker.py` を拾う bats スイートは無いので、Python 側は別に走らせないと今回の変更の回帰が 1 件も走らない
  - `bash scripts/test.sh`（常時注入分を触っていないので `tests/injection-budget.bats` も含めて通ること）
  - `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_worker.py`
- [ ] 7.4 `openspec validate align-codex-worker-permissions --strict` を実行し、exit code を記録する
