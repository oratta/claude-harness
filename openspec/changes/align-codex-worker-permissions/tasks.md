## 1. 現状の確認

- [ ] 1.1 `plugins/dev-workflow/scripts/codex-worker.py` の `clean_env()`・`Rpc.__init__`・`runtime_home()`・turn の `sandboxPolicy` 生成箇所を読み、Git 共通ディレクトリの値が既にどこで取れているかを確認する
- [ ] 1.2 `plugins/dev-workflow/tests/test_codex_worker.py` の fake App Server が `thread/start` / `turn/start` のパラメータと子環境をどう捕まえているかを確認し、追加テストの置き場を決める

## 2. 失敗するテストを先に書く（Red）

- [ ] 2.1 implement / spec-write の turn policy が `networkAccess: True` で、`writableRoots` が cwd・job 専用一時領域・cwd の Git 共通ディレクトリの 3 つであることを検査するテストを追加する
- [ ] 2.2 review / spec-review / impl-review の turn policy が `{'type':'readOnly','networkAccess':True}`、decider が `{'type':'readOnly','networkAccess':False}` であり、どの read-only role にも `writableRoots` が付かないことを検査するテストを追加する
- [ ] 2.3 子プロセスの環境が親の環境を引き継ぎ、`CODEX_HOME` は runtime のパスで上書きされ、Codex 自身が認証に読む変数が落ちていることを検査するテストを追加する（親に無関係な変数を 1 つ入れて届くことも見る）
- [ ] 2.4 read-only role の子環境に `TMPDIR` / `TMPPREFIX` が現れないことを、親に両方が設定された状態で検査するテストを追加する（既存の同趣旨のテストが環境引き継ぎで壊れないための回帰）
- [ ] 2.5 `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_worker.py -v` を実行し、追加分が落ちること（Red）と件数・exit code を記録する

## 3. 第 1 段の実装（workspace-write + network + Git 共通ディレクトリ）

- [ ] 3.1 Git 共通ディレクトリの絶対パスを 1 か所で算出する形に整え、`writableRoots` に加える
- [ ] 3.2 workspace-write の turn policy を `networkAccess: True` にする。`excludeSlashTmp` / `excludeTmpdirEnvVar` / `approvalPolicy: never` は変えない
- [ ] 3.3 read-only の turn policy を role ごとに分け、review / spec-review / impl-review を `networkAccess: True`、decider を `False` にする
- [ ] 3.4 `clean_env()` を「親を引き継ぎ、落とすものだけ落とす」形に置き換える（落とすのは `CODEX_HOME` / `TMPDIR` / `TMPPREFIX` と、Codex 自身が認証に読む変数）。`Rpc.__init__` の TMPDIR / TMPPREFIX の扱い（read-only には渡さない）を保つ
- [ ] 3.5 `clean_env()` を使っている `git` 呼び出し（`validate_request` / `runtime_home` / `JobTmp.validate_location`）が新しい環境で同じ判定を続けることを確認する（Git の経路を変える変数が親から入ったときに判定が変わらないか）
- [ ] 3.6 fake テストを通す（Green）。`PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_worker.py -v` の件数と exit code を記録する

## 4. 実 Codex での実測（第 1 段）

- [ ] 4.1 この worktree を cwd にして implement role の job を投げ、worker の中で `python3 -m http.server` 等でループバックに待ち受けを立て、`curl -sS http://127.0.0.1:<port>/` が応答することを実測する。コマンド・出力・exit code を記録する
- [ ] 4.2 同じ job の中で `git commit`（空コミットでよい）を実行し、linked worktree で成立することを実測する。失敗したら出力と exit code を記録する
- [ ] 4.3 同じ job の中で feature branch への `git push`、`gh pr create --draft`、`gh issue comment` を実行し、それぞれの結果と作成物の URL を記録する
- [ ] 4.4 Codex の環境変数ポリシーが子シェルへの引き継ぎを絞っているかを、worker の中で親に入れた目印の変数と認証変数の有無を出力して確認する。絞られていれば runtime `config.toml` に引き継ぎ設定を足し、絞られていなければ足さない
- [ ] 4.5 外部リポのローカルサーバーを立てるテストスクリプト（flatmate の `scripts/test-task-store-worker.sh`。対象 worktree のパスは実行時に指定する）を worker の中で完走させ、成功件数・exit code・対象 HEAD を記録する
- [ ] 4.6 許可外への書き込みプローブ（`/tmp/<一意名>` と呼び出し元 `TMPDIR/<一意名>`）が拒否されること、専用領域が 0700 で終了後に消えていることを実環境で確認する

## 5. 第 2 段（第 1 段で足りなかった role だけ）

- [ ] 5.1 第 1 段で完了できなかった操作があれば、role ごとに失敗したコマンド・出力・exit code を change の記録先へ記録する（この記録が無い状態で 5.2 に進まない）
- [ ] 5.2 足りない role だけ `thread/start` の `sandbox` を `danger-full-access`、turn の `sandboxPolicy` を `{'type':'dangerFullAccess'}` にし、その role を第 2 段にした理由を記録する
- [ ] 5.3 第 2 段にした role で 4.1〜4.5 のうち失敗していた操作を再実測し、結果を記録する
- [ ] 5.4 第 2 段でも完了できない操作が残った場合、項目ごとに「試したこと・失敗の出力・揃えられない理由」を記録先と `plugins/dev-workflow/scripts/CODEX-WORKER.md` に書く

## 6. ドキュメントの整合

- [ ] 6.1 `plugins/dev-workflow/scripts/CODEX-WORKER.md` の砂場と環境変数の記述を実際の範囲に直す（role ごとの段・`networkAccess` の値・`writableRoots` の 3 か所・落とす環境変数・残った代理実行の項目）
- [ ] 6.2 `plugins/dev-workflow/references/codex-develop.md` から、ネットワーク無効と commit 拒否を理由にした本体の代理実行の記述を削る。5.4 で残った項目があればその項目だけを残す
- [ ] 6.3 `plugins/dev-workflow/docs/codex-develop.md` の同趣旨の段落を同じ方針で直す
- [ ] 6.4 `openspec/specs/codex-worker/spec.md` の Purpose が `TBD` のままなので、archive 時に埋める内容を決めておく

## 7. バージョンと全件テスト

- [ ] 7.1 `plugins/dev-workflow/.claude-plugin/plugin.json` の version を 2.13.8 から 2.13.9 に上げる
- [ ] 7.2 `.claude-plugin/marketplace.json` の dev-workflow エントリの version を 2.13.9 に揃える
- [ ] 7.3 `bash scripts/test.sh` を実行し、成功件数・総件数・exit code と対象 HEAD を記録する（常時注入分を触っていないので `tests/injection-budget.bats` も含めて通ること）
- [ ] 7.4 `openspec validate align-codex-worker-permissions --strict` を実行し、exit code を記録する
