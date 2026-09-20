## Why

指揮役は Claude Code で、呼び出し先が Claude のサブエージェントでも Codex の worker でも、工程の流れと各担当がやることを同じにする、というのがこの仕組みの前提である。いま Codex の worker だけが job ごとに専用の一時ディレクトリを新規作成し、App Server と子ツールの `TMPDIR` / `TMPPREFIX` をそこへ差し替え、終了時に削除している（`codex-worker.py` の `JobTmp`）。Claude のサブエージェントにはこの仕組みが無く、親の `TMPDIR` をそのまま引き継ぐ。つまり「Codex のときはこう、Claude のときはこう」の場合分けが 1 つ残っている。

この仕組みを入れた理由は、Codex の OS 砂場が `/tmp` と呼び出し元 `TMPDIR` を塞いでいて（`excludeSlashTmp` / `excludeTmpdirEnvVar`）、書ける一時領域が無いと全件テストが流れなかったことにある。書く役（implement / spec-write）の砂場は `danger-full-access` に変わり、`excludeSlashTmp` / `excludeTmpdirEnvVar` を渡す経路そのものが消えた（`61b8bdf`）。塞ぐものが無くなった以上、専用領域を作って差し替える必要も無い。

## What Changes

- **BREAKING（仕様の撤去）**: `codex-worker` の Requirement「workspace-write ジョブは専用の Git 管理外一時領域を使う」と「一時領域を別ジョブへ割り当てず確認済み終了後に片付ける」を取り除き、「書く役は親の `TMPDIR` をそのまま引き継ぐ」要件に置き換える
- 書く役の job で、専用一時ディレクトリの新規作成・場所の検査（cwd 外 / Git 管理外 / 0700 / 所有者一致）・`TMPDIR` と `TMPPREFIX` の差し替え・`job-tmp.json` への記録・終了時の削除をやめる。`JobTmp` クラスと `job_tmp_*` の `error_kind` 群（`job_tmp_not_private` / `job_tmp_in_cwd` / `job_tmp_in_git` / `job_tmp_parent_not_directory` / `job_tmp_not_normalized` / `job_tmp_identity_changed` / `job_tmp_safe_cleanup_unavailable` / `job_tmp_cleanup_failed`）はコードから無くなる
- 子へ渡す環境変数の扱いを変える。`DROPPED_ENV`（親から落とす一律の 13 個）から `TMPDIR` と `TMPPREFIX` を外し、書く役の子には親の値がそのまま届くようにする。読む役（review / spec-review / impl-review / decider）にはこれまでどおりどちらも渡さない（読む役は `readOnly` 砂場で一切書けないので一時領域の指定に意味が無く、この扱いは Codex 側だけにある制約ではない）
- 撤去の結果として失われる性質を仕様に明記する: 同時に走る job の一時ファイルが同じ親ディレクトリに混ざりうること、残骸を `job-tmp.json` で追跡する手段が無くなること。Claude のサブエージェントも同じ条件で動いているので、追跡が必要になったときは Codex 側だけに戻すのではなく Claude 側と揃えて入れる
- 実 Codex の受け入れ証跡の要件から「専用一時領域の 0700 と終了時削除」を外し、代わりに「子シェルの `TMPDIR` が親の `TMPDIR` と一致すること」と「素の `mktemp -d` を使う外部スクリプトが worker の中で完走すること」を求める
- `thread/start` / `turn/start` にサーバーが id 付きエラーを返したとき専用領域が残る不具合（#333）は、領域そのものが無くなることで起きなくなる。あわせて `turn_submitted`（ターンを投げたか）と `turn_accepted`（サーバーが受理を返したか）の意味の違いをコード上で読み取れるようにする
- `plugins/dev-workflow/scripts/CODEX-WORKER.md` の一時領域に関する 2 段落を実態に合わせる

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `codex-worker`: 一時領域の要件を改める。（a）専用領域の新規作成・`TMPDIR` / `TMPPREFIX` の差し替え・別 job への再利用禁止・`job-tmp.json` への記録・確認済み終了後の削除を求める 2 つの Requirement を撤去し、書く役が親の `TMPDIR` を引き継ぐ要件に置き換える（b）読む役に `TMPDIR` / `TMPPREFIX` を渡さない扱いは維持し、その理由を「読む役は書けないので一時領域の指定に意味が無い」と書き直す（c）撤去によって失われる性質（job 間で一時ファイルが混ざりうる・残骸を追跡しない）を明記し、追跡が要るときは Claude 側と揃えて入れると定める（d）実 Codex の受け入れ証跡から専用領域の 0700 と終了時削除を外し、親 `TMPDIR` の一致と素の `mktemp -d` を使う外部スクリプトの完走に置き換える（e）書く役の Requirement に残っている「専用一時領域の作成・差し替え・削除は維持しなければならない」を取り除く

## Impact

- `plugins/dev-workflow/scripts/codex-worker.py`: `JobTmp` クラスの削除、`DROPPED_ENV` から `TMPDIR` / `TMPPREFIX` を外す、`Rpc.__init__` の `job_tmp` 引数を読む役かどうかの指定に置き換える、`worker()` の `job_tmp` 生成 / `job-tmp.json` 書き出し / `finally` の cleanup 分岐の削除、`turn_submitted` と `turn_accepted` の違いを示すコメント
- `plugins/dev-workflow/tests/test_codex_worker.py`: `JobTmpTest` クラス全体（6 件）と、`test_job_tmp_is_private_external_and_not_reused` / `test_tmp_cleanup_for_confirmed_outcomes_and_symlink_contents` / `test_unknown_retains_tmp_and_ownership` / `test_replaced_tmp_reports_cleanup_failure_without_following_symlink` / `test_invalid_tmp_parent_rejects_without_fallback` の削除。`test_child_inherits_parent_environment_except_the_dropped_names` の期待値の更新。書く役の子の `TMPDIR` / `TMPPREFIX` が親と一致することを固定する新規テスト。`test_read_only_child_gets_neither_tmpdir_nor_tmpprefix` は残す
- `plugins/dev-workflow/scripts/CODEX-WORKER.md`: 一時領域の 2 段落（専用領域の作成と差し替え／片付けと `job_tmp_cleanup_failed`）の書き換え
- `openspec/specs/codex-worker/spec.md`: archive 時に反映（Purpose の「Git 管理外の専用一時領域を作り」も外す）
- `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json`: dev-workflow のバージョンを 2.13.11 にする（2.13.10 は並行中の別作業が取る）
- 受け入れるリスク: 同時に走る job が同じ名前の一時ファイルを作れば壊れうる。Claude のサブエージェントも同じ条件で動いており、Codex 側だけが増やすリスクではない
- 触らないもの: runtime `CODEX_HOME` の隔離（job ごとの 0700 ディレクトリと `auth.json` の symlink）、認証帰属の照合、account ごとの同時実行と枠判定、ack と台帳、砂場の水準（書く役 `danger-full-access` / 読む役 `readOnly`）、`approvalPolicy: never`、worker 自身の git 呼び出しの固定 allowlist（`git_env()`。`TMPDIR` を含むが、これは worker 本体の git が使う値で子の環境ではない）
