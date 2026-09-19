## 1. 仕様レビューと実装前提

- [ ] 1.1 coordinator が issue #320 に仕様化判断とオーナー確定の受け入れ条件を記録し、独立 R1 が修正仕様を再レビューする。四点の採用案・却下理由と unknown 時の削除延期は R1 判定を維持し、修正仕様の APPROVE 前には実装を開始しない。

## 2. Red: 回帰試験

- [ ] 2.1 test_codex_worker.py の fake App Server で implement/spec-write の TMPDIR と writableRoots の一致、一 job 一領域、同じ run の別 job の非共有、Git 管理外・0700 を検査する失敗テストを先に作る。
- [ ] 2.2 全 role の networkAccess=false、approvalPolicy=never、workspace-write の excludeSlashTmp/excludeTmpdirEnvVar=true、read-only role の既存 policy、danger-full-access 不使用を固定する。
- [ ] 2.3 正常終了・失敗・確認済み取消・開始前失敗・unknown・cleanup 失敗を検査し、親/cwd/認証元/symlink 参照先を消さないことと終了直後の cleanup 観測順を固定する。

## 3. Green: 専用一時領域

- [ ] 3.1 承認済み design に従って codex-worker.py に専用領域の生成・検証、Rpc への TMPDIR 伝播、限定 writableRoots、終了処理を実装し、2 の試験を通す。別 job への割り当て・再利用を禁止し、確認済み終了後は ack を待たず削除する。
- [ ] 3.2 CODEX-WORKER.md の「追加 writableRoots は cwd のみ、/tmp 追加許可なし」を実装した許可範囲、role、寿命、unknown の制約に合わせて更新し、plugins/dev-workflow/.claude-plugin/plugin.json のバージョンを上げる。常時注入ファイルと injection-budget.txt は変更しない。

## 4. 実環境の受け入れ検証

- [ ] 4.1 `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_worker.py -v` を実行し、件数と exit code を記録する。
- [ ] 4.2 coordinator が更新版 worker で fresh implement job を起動する。その Codex 自身が `$TMPDIR` の実パス・0700・Git 管理外を確認し、TMPDIR を上書きせず `scripts/test.sh` 全件を実行する。対象 HEAD、コマンド、成功/総件数、exit code を記録し、失敗または中断なら完了扱いにしない。
- [ ] 4.3 coordinator が起動時の TMPDIR の設定有無・解決した親を記録し、元 TMPDIR（未設定・空なら `/tmp`）の検証先を確定して渡す。検証先は cwd/専用領域外とし、砂場外では実行ユーザーが書き込めることを先に確認する。その前提を用意できなければ needs-coordinator として受け入れ検証を未完了にする。Codex 内から専用領域への書き込み成功、cwd/専用領域外の `/tmp/<一意名>` と元 TMPDIR の書き込み拒否をコマンド・出力・exit code 付きで記録する。元 TMPDIR が /tmp と同一ならその事実を記録し、専用領域内のプローブと混同しない。
- [ ] 4.4 coordinator が実 Codex job の専用領域のパスを控え、実行終了と worker の cleanup 完了を確認した後、ack 前にその領域が存在しないことを観測し、確認コマンド・出力・exit code を記録する。観測に必要な環境を用意できなければ needs-coordinator として受け入れ検証を未完了にし、fake の結果で代替しない。
- [ ] 4.5 `OPENSPEC_TELEMETRY=0 openspec validate isolate-codex-worker-job-tmp --strict` と `git diff --check` を実行し、全受け入れ証拠を coordinator に返す。独立レビュー・archive・PR 操作は coordinator の工程に従う。
