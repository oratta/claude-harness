## 1. テストを先に直す（Red）

- [ ] 1.1 `plugins/dev-workflow/tests/test_codex_worker.py` の `JobTmpTest` クラス（`test_cleanup_removes_owned_tree_but_preserves_symlink_target` / `test_cleanup_refuses_replaced_root` / `test_cleanup_refuses_root_replaced_by_a_plain_directory` / `test_cleanup_deletes_through_the_opened_fd_when_the_name_is_swapped` / `test_cleanup_error_is_not_silenced` / `test_creation_refuses_git_parent` の 6 件）を削除する
- [ ] 1.2 `WorkerTest` から専用領域に依存する 5 件（`test_job_tmp_is_private_external_and_not_reused` / `test_tmp_cleanup_for_confirmed_outcomes_and_symlink_contents` / `test_unknown_retains_tmp_and_ownership` / `test_replaced_tmp_reports_cleanup_failure_without_following_symlink` / `test_invalid_tmp_parent_rejects_without_fallback`）を削除する
- [ ] 1.3 書く役の子の `TMPDIR` / `TMPPREFIX` が親の値と一致することを固定するテストを足す（fake App Server が記録する子の環境を使う）
- [ ] 1.4 親に `TMPDIR` も `TMPPREFIX` も無いとき、書く役の子にもどちらも現れず job が拒否されないことを固定するテストを足す
- [ ] 1.5 `test_child_inherits_parent_environment_except_the_dropped_names` の期待値を、`TMPDIR` / `TMPPREFIX` が落ちない前提に直す
- [ ] 1.6 `test_read_only_child_gets_neither_tmpdir_nor_tmpprefix` を削除する（読む役の子にも親の値が届く形に変わるので、このテストが固定していた性質は成立しない）
- [ ] 1.7 `test_all_role_policies_remain_restricted` を直す。書く役側の `assertIsNotNone(self.tmp_info()['path'])` と「専用領域は砂場撤去後も残っている」というコメントを外し、書く役・読む役とも `TMPDIR` / `TMPPREFIX` が親の値と一致することを見る形にする
- [ ] 1.8 fake App Server（`test_codex_worker.py` の `FAKE`）から `tmp_symlink` / `replace_tmp` の分岐と専用領域の `mode` / `uid` / `git` の測定を落とす（消したテストだけが使う。`replace_tmp` は親の `TMPDIR` を `rmdir` しようとするので残すと危険）。子が見た `TMPDIR` を測る `child` は残す
- [ ] 1.9 `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_worker.py` を実行し、新規テストが落ちること（Red）を出力で確認する

## 2. worker から一時領域の仕組みを外す（Green）

- [ ] 2.1 `plugins/dev-workflow/scripts/codex-worker.py` の `JobTmp` クラス全体を削除する（`validate_location` / `create` / `cleanup` を含む）。使わなくなる import（`tempfile` 等）があれば落とす
- [ ] 2.2 `DROPPED_ENV` から `TMPDIR` と `TMPPREFIX` を外し、先頭のコメントを「worker が自分で決める値」が `CODEX_HOME` だけになった形に直す
- [ ] 2.3 `Rpc.__init__` の `job_tmp` 引数と、その中の `TMPDIR` / `TMPPREFIX` の差し替えを削除する（読む役かどうかの引数は新設しない。全 role が親の値をそのまま受け取る）
- [ ] 2.4 `worker()` から `job_tmp` 変数・`JobTmp.create()` の呼び出し・runtime への `job-tmp.json` 書き出しを削除し、`Rpc(...)` の呼び出しを 2.3 の形に合わせる
- [ ] 2.5 `worker()` の `finally` にある一時領域の cleanup 分岐（`if job_tmp is not None and (not turn_submitted or execution_confirmed):` とその中身、`job_tmp_cleanup_failed` の記録）を削除し、`auth.json` の削除に関するコメント（「This is removed after job TMPDIR cleanup」）を実態に合わせて直す
- [ ] 2.6 `git_env()` のコメントから「一時領域の場所の検査」への言及を外す（`TMPDIR` を allowlist に残すことは変えない。これは worker 本体の git が使う値）
- [ ] 2.7 `turn_submitted`（ターンを投げた）と `turn_accepted`（サーバーが受理を返した）の意味の違いが読み取れるコメントを、両方が宣言されている箇所に置く（#333 の受け入れ条件のうち領域の撤去では満たされない 1 つ）
- [ ] 2.8 `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_worker.py` を実行し、全件通ること（Green）を exit code 付きで確認する

## 3. ドキュメントとバージョン

- [ ] 3.1 `plugins/dev-workflow/scripts/CODEX-WORKER.md` の専用領域の作成と差し替えを説明する段落（「書く役は起動元の非空TMPDIRを親として…撤去は別issueで扱う。」）を、親の `TMPDIR` をそのまま引き継ぐ実態に書き直す。失われる性質（job 間で一時ファイルが混ざりうる・残骸を追跡しない）も書く
- [ ] 3.2 同ファイルの片付けを説明する段落（「成功・失敗・確認済み取消・turn開始前失敗ではackを待たず専用領域を削除する。…」）を削除する
- [ ] 3.3 同ファイルの環境変数の段落から、落とす変数が 13 個で `TMPDIR` / `TMPPREFIX` を含むという記述を 11 個の実態に直し、「read-onlyには`TMPDIR`も`TMPPREFIX`も渡さない」の一文を削除する（役によらず親の値が届く）。worker 自身の git 呼び出しの説明から「一時領域の場所の検査」を外す
- [ ] 3.4 `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の dev-workflow のバージョンを `2.13.11` にする（他プラグインのバージョンは触らない）

## 4. 検証

- [ ] 4.1 `openspec validate inherit-codex-worker-parent-tmpdir --strict` が通ることを確認する
- [ ] 4.2 `bash scripts/test.sh` を全件実行し、成功件数・総件数・exit code を記録する
- [ ] 4.3 `grep -rn "job_tmp\|job-tmp\|JobTmp" plugins/ openspec/specs/` で、archive 済みの change 以外に残骸が無いことを確認する
- [ ] 4.4 実 Codex の implement role で、子シェルの `TMPDIR` が worker を起動した親の `TMPDIR` と一致することと、`mktemp -d` を使う外部スクリプト（flatmate の `scripts/test-task-store-worker.sh`）が worker の中で完走することを実測し、コマンド・出力・exit code・対象 HEAD を記録先に記録する
- [ ] 4.5 archive 時に `openspec/specs/codex-worker/spec.md` の Purpose から「Git 管理外の専用一時領域を作り」を外す（delta spec は Requirement しか扱わないので、Purpose は archive の反映で直す）
