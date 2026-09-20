## Context

`plugins/dev-workflow/scripts/codex-worker.py` は job ごとに `JobTmp` を作る。`JobTmp.create()` は起動元の非空 `TMPDIR`（未設定・空なら `/tmp`）を親として、そこに `codex-worker-` 接頭辞の 0700 ディレクトリを `tempfile.mkdtemp` で作り、cwd 外・Git 管理外・正規化済みであることを検査する。`Rpc.__init__` はその絶対パスを子の `TMPDIR` に、その下の `zsh` を `TMPPREFIX` に入れる。パスと identity（`st_dev` / `st_ino` / `st_uid`）を runtime の `job-tmp.json` に書き、`worker()` の `finally` で `turn_submitted` が偽か `execution_confirmed` が真のときだけ `cleanup()` する。`cleanup()` は親ディレクトリの fd を開いて inode を突き合わせ、symlink の置き換えを踏まないように削除する。失敗は `error_kind=job_tmp_cleanup_failed` で残る。

この一式は PR #327（issue #320）で入った。当時の書く役の砂場は `workspace-write` で、policy に `excludeSlashTmp: true` / `excludeTmpdirEnvVar: true` が付いていたため、子は `/tmp` にも呼び出し元 `TMPDIR` にも書けなかった。`writableRoots` に載る書ける一時領域を worker 側で用意しない限り、`mktemp -d` を使う外部スクリプトも zsh の here-document も動かなかった。

PR #343（issue #334、`61b8bdf`）で書く役の砂場は `danger-full-access` になり、`writableRoots` / `excludeSlashTmp` / `excludeTmpdirEnvVar` / `networkAccess` を渡すこと自体が仕様で禁じられた。塞ぐ主体が消えたので、専用領域は「OS の強制を伴わない、Codex 側だけにある慣習」として残っている。現行 spec もそう書いている（「砂場が無くなったので OS による強制は伴わず、これは Codex 側だけにある差分として残る」）。

Claude 側の対応物: 本体が起こすサブエージェントは親の環境をそのまま受け取り、一時領域の隔離も残骸の追跡も無い。

## Goals / Non-Goals

**Goals:**

- 書く役の job の子プロセスが、親（worker を起動したプロセス）の `TMPDIR` をそのまま受け取る
- 一時領域に関する分岐・検査・記録・片付けをコードから無くす（「Codex のときはこう」の場合分けを 1 つ減らす）
- 撤去によって失われる性質を仕様に残し、後から「なぜ追跡をやめたか」を辿れるようにする
- 専用領域が残る不具合（#333）を、不具合を直すのではなく発生源を無くす形で解消する

**Non-Goals:**

- runtime `CODEX_HOME` の隔離には手を付けない。これは認証（`auth.json` の symlink）と設定の隔離であって一時領域ではなく、Claude 側にも「サブエージェントごとに別の認証を割り当てる」対応物が無い以上の理由（登録済み account 以外の課金経路に移さない）で必要である
- 砂場の水準・`approvalPolicy`・ack・台帳・同時実行の枠判定は変えない
- 一時ファイルの衝突を検出・回避する仕組みを新しく入れない（Claude 側に無いものを Codex 側だけに作らない、が今回の方針そのもの）

## Decisions

### 専用領域は「作らない」にする。「作るが差し替えない」にはしない

中間案として「専用領域は作り続けるが `TMPDIR` は差し替えない」（残骸の追跡だけ残す）が考えられる。採らない。誰も使わないディレクトリを job ごとに作って消すだけになり、`job-tmp.json` が追跡するのは自分で作った空ディレクトリになる。追跡対象は子が実際に書いた一時ファイルでなければ意味がない。

### 読む役に `TMPDIR` / `TMPPREFIX` を渡さない扱いは残す

今回の方針は「Codex 側にだけある制約で、Claude 側に対応物が無いものは外す」である。読む役にこれらを渡さないのは、この方針に反していない。読む役は `readOnly` 砂場で動き、`/tmp` を含むどこにも書けないので、一時領域の指定に意味が無い。値を渡しても渡さなくても子の振る舞いは変わらず、渡さないほうが「この役は書かない」が環境から読める。

ただし現行 spec が書いている理由（「Claude 側の読む役がシェルを持たないことと対応する」）はそのままでは使えない。Claude 側で review / spec-review / impl-review に当たるのは汎用サブエージェントで、シェルを持つ。シェルを持たないのは decider だけである。理由を「読む役は書けないので一時領域の指定に意味が無い」に書き直す。

実装上は、`DROPPED_ENV`（全 role から一律に落とす名前の組）から `TMPDIR` / `TMPPREFIX` を外し、読む役のときだけ落とす扱いに移す。`Rpc` は `job_tmp` を受け取る代わりに、その job が読む役かどうかを受け取る。

### 片付けの分岐（#333 の発生源）はテストごと消す

`finally` の `if job_tmp is not None and (not turn_submitted or execution_confirmed):` が #333 の発生源である。`ServerRejected` の経路では `turn_submitted` が真になった後にエラーが出るので条件が偽になり、領域が残る。今回 `job_tmp` が常に `None` 相当になるので、この行ごと消える。

#333 の受け入れ条件のうち、「サーバーの id 付きエラーで失敗した job の領域が ack を待たず消える」と「停止未確認では領域を保持する」は、領域が存在しないので成立しようがない（空になる）。残る 1 つ「判定に使う値が『ターンが受理されたか』であることがコードから読み取れる」は独立しており、`turn_submitted`（投げた）と `turn_accepted`（サーバーが受理を返した）の違いを示すコメントを `worker()` に置いて満たす。この 2 つの値は領域の片付けが消えた後も job の終了状態（`unknown` / `failed`）の判定に残るため、区別の説明は依然として要る。

### 削るテストと足すテスト

`JobTmpTest`（6 件）は `JobTmp` の削除とともに消える。`WorkerTest` 側で消えるのは領域の生成・片付け・親の妥当性に依存する 5 件（`test_job_tmp_is_private_external_and_not_reused` / `test_tmp_cleanup_for_confirmed_outcomes_and_symlink_contents` / `test_unknown_retains_tmp_and_ownership` / `test_replaced_tmp_reports_cleanup_failure_without_following_symlink` / `test_invalid_tmp_parent_rejects_without_fallback`）。

足すのは 1 件、「書く役の子の `TMPDIR` / `TMPPREFIX` が親の値と一致する」。fake App Server は既に子が見た環境を記録しているので（`tmp_info()` / `seen`）、期待値を親の値に変えるだけで固定できる。`test_read_only_child_gets_neither_tmpdir_nor_tmpprefix` と `test_child_inherits_parent_environment_except_the_dropped_names` は残し、後者は `DROPPED_ENV` の縮小に合わせて期待値を直す。

### 実環境の証跡の置き換え

現行の Requirement「実 Codex のテスト完走と拒否の証拠を残す」は「専用一時領域の 0700 と終了時削除も実環境で確認しなければならない（MUST）」を含む。対象が無くなるのでこれを外し、issue #338 の受け入れ条件に対応する 2 つに置き換える: 子シェルの `TMPDIR` が親の `TMPDIR` と一致すること（実測のコマンドと出力）、素の `mktemp -d` を使う外部スクリプトが worker の中で完走すること。後者は砂場撤去の証跡（PR #343 で flatmate の `scripts/test-task-store-worker.sh` が PASS=261 / exit 0）と同じ対象を使えるが、今回は `TMPDIR` が親のものである状態で取り直す。

## Risks / Trade-offs

- [同時に走る job の一時ファイルが同じ親 `TMPDIR` に混ざり、同じ名前を作った job が壊れうる] → 受け入れる。`mktemp` を使う限り衝突しないので、壊れるのは固定名の一時ファイルを作る場合に限られる。Claude のサブエージェントは同じ条件で動いており、Codex 側だけが増やすリスクではない。衝突が実際に起きたら、Codex 側だけに戻すのではなく Claude 側と揃えて入れる
- [job が残した一時ファイルの出どころを追えなくなる（`job-tmp.json` が無くなる）] → 受け入れる。追跡先が親 `TMPDIR` 全体になるので、残骸は OS と利用者の通常の掃除に委ねる。現行でも「運用回復は未実装であり、最終的な自動削除は保証しない」と書かれており、追跡の記録があっても掃除はされていなかった
- [子が `TMPDIR` を汚す範囲が広がる（親と共有する）] → 砂場が無いので子は元々どこへでも書ける。共有範囲が広がるのは一時領域だけで、増える権限は無い
- [`cleanup()` の fd ベースの削除（symlink 置き換え対策）という実装ごと失う] → 受け入れる。守っていた対象（worker が自分で作ったディレクトリ）が無くなるので、守る先が無い

## Migration Plan

仕組みの撤去だけで、保存される状態のスキーマは変わらない。台帳（`ownership.sqlite` / job DB）にも `job-tmp.json` のパスは入っていない（runtime ディレクトリの中のファイルで、runtime ごと使い捨てられる）。

進行中の job がある状態でこの変更を入れた場合、その job は古いコードのプロセスが最後まで面倒を見る（worker は起動時に読み込んだコードで動き続ける）。新旧が混ざるのは「古い worker が作った領域が残り、新しい worker はそれを知らない」形だけで、残骸が 1 つ残る以上のことは起きない。

戻す場合は revert で足りる。
